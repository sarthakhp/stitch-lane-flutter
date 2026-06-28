# Multi-device sync — implementation plan (single-writer model)

**Companion to** `MULTI_DEVICE_SYNC_DESIGN.md` (the *why*). This file is the *how*, grounded in the
**actual current code** (verified 2026-06-25, DB v12). Build phase by phase, in order. Each phase
must leave the app working and ship behind a flag that defaults OFF.

> This plan **refines design-doc decision #7**: instead of soft-delete columns on every table, we use
> a **deletion outbox + hard delete** (see "Why an outbox" below). Net effect on the cloud is the
> same (the reader removes deleted rows); the difference is we **never touch existing entity tables or
> existing read queries**, which is far safer for existing data.

---

## Golden rules (do not violate)

1. **The writer's existing local behavior never changes.** Flag OFF ⇒ app == today, exactly.
2. **Existing data is sacred.** Migrations are **additive only** (new tables / new columns; never
   rewrite or drop existing rows). **We do NOT add columns to `customers`/`orders`/`measurements`
   and do NOT modify any existing SELECT.** All sync bookkeeping lives in *new* side tables.
3. **Reader can never mutate** local entity data or the cloud — except the single `meta/control` doc
   during a handoff/takeover.
4. **Media stays on Google Drive.** Firestore carries only references (already in the entity JSON).
   No Firebase Storage.
5. **Clean, modular, small files.** All sync code under `domain/services/sync/`. Firestore SDK types
   stay behind one interface (`FirestoreGateway`) so the rest of the app and the tests never see them.
6. **No `Co-Authored-By` trailer in commits. Don't commit/push unless asked.**

**Before editing any existing file, READ it.** Paths below are verified but confirm before editing.

---

## Verified codebase facts (you can rely on these)

- **DB:** `app/lib/backend/database/sqlite_database.dart`, `class SqliteDatabase`, `_dbVersion = 12`
  → next is **13**. `_onCreate` creates tables; `_onUpgrade(db, oldVersion, newVersion)` uses guarded
  `if (oldVersion < N) { ALTER TABLE ... }` blocks. `rawQuery(sql)` is the AI's read path.
- **Entity tables (snake_case columns), all String UUID PKs:**
  - `customers(id, name, phone_number, description, created)`
  - `orders(id, customer_id, title, due_date, description, created, status, value, is_paid,
    image_paths, payment_date, payments, total_paid_amount, audio_file_path, audio_file_paths)` —
    `payments` and `image_paths` and `audio_file_paths` are **JSON-encoded text**; dates are ISO8601.
  - `measurements(id, customer_id, description, created, modified, audio_file_path, audio_file_paths,
    structured_data)`
  - Local-only, **NOT synced:** `settings` (wide single-row prefs), `ai_usage_events`,
    `measurement_fields` (see "What syncs" — optional).
- **Models:** `backend/models/{customer,order,measurement}.dart`, each with `toJson()/fromJson()/
  copyWith`. `Order.fromJson` parses `id`/`customerId` as `String`, dates via `DateTime.parse`,
  `payments` as a list of `PaymentEntry`. Use `toJson()` for the Firestore payload.
- **Repositories:** `backend/repositories/sqlite_*_repository.dart` implement interfaces
  (`OrderRepository`, etc.), provided via `RepositoryFactory.create*Repository()`. Order repo methods:
  `getAllOrders, getOrdersByCustomerId, getOrderById, addOrder, updateOrder, deleteOrder,
  deleteOrdersByCustomerId, clearAll, toMap, fromMap`. `addOrder` already upserts
  (`ConflictAlgorithm.replace`). **Customer/measurement repos follow the same shape — confirm their
  exact delete methods (esp. cascade deletes by customerId).**
- **State:** `domain/state/{order,measurement,customer}_state.dart` are `ChangeNotifier`s holding an
  in-memory list (e.g. `OrderState._orders`) with `setOrders/addOrder/updateOrder/removeOrder` +
  (presumably) `notifyListeners()`. **Find who calls `setOrders(...)` at startup** (the loader) — the
  reader applier must call the same path so the UI refreshes. (grep `setOrders(` / `setMeasurements(`).
- **Providers:** `main.dart` → `StitchGenieApp.build` → `MultiProvider` lists every `*State` +
  every `*Repository`. Add `SyncState` + sync services here.
- **Startup:** `main()` runs `DbSnapshotService.snapshotBeforeOpen()` (pre-open DB file snapshot to
  `<databases>/snapshots/<ts>/` — **reuse as the local rollback** before backfill/takeover),
  `DatabaseService.initialize()`, then `runApp`, then `StartupOrchestrator.instance.kickoff()` which
  initializes **Firebase + auth in the background**; the auth gate (`AppRoot`) waits for that.
- **Auth (already Firebase):** `AuthService` uses `FirebaseAuth.instance` + `GoogleSignIn`
  (Drive appdata scope). **uid = `AuthService.getCurrentUser()?.uid`**, reactive via
  `AuthService.authStateChanges()`. `signOut(...)` clears local DBs + files + cancels backup/reminders.
- **Connectivity:** `domain/services/connectivity/connectivity_service.dart` — `hasInternet()`,
  `offlineMessage`.
- **Drive media:** `domain/services/{drive_service, audio_sync_service, image_sync_service}.dart`.
  Entity JSON already carries media refs (`imagePaths`, `audioFilePaths`). **Confirm whether a stored
  ref resolves on another device** (Drive file id/name vs device-absolute path) — backup *import*
  already rewrites audio paths to the device dir; reuse that mapping for the reader.

**If any of these is wrong when you look, STOP and adapt the affected section — don't force the plan.**

---

## What syncs

- **Synced collections:** `customers`, `orders`, `measurements` only. (`orders` already embeds
  `payments`, so payment history rides along — no separate payments collection.)
- **Optional:** `measurement_fields` (global config). The reader does **not** need it to *display*
  measurements (each row's `structured_data` is self-contained), so **defer it** unless you want both
  devices' field config to match. If synced, treat exactly like an entity collection.
- **Never synced:** `settings`, `ai_usage_events`, and all sync bookkeeping tables (device-local).

## Why an outbox (not soft-delete columns)

- **Upserts:** when the writer creates/edits a row, we record `(collection, id, op=upsert)` in a new
  `sync_outbox` table (`INSERT OR REPLACE`, PK `(collection, id)` — multiple edits collapse to one
  pending push of the *latest* row state). Entity tables/reads are untouched.
- **Deletes:** the writer keeps doing its hard `db.delete(...)`; we additionally record
  `(collection, id, op=delete)` in the same outbox. (`INSERT OR REPLACE` means a delete after an
  upsert correctly becomes a single `delete`; a recreate after delete becomes `upsert`.)
- The **push pump** drains the outbox: `op=upsert` → read the row, `set()` the Firestore doc;
  `op=delete` → `delete()` the Firestore doc; on server-ack, remove the outbox entry.
- The **reader** learns deletes from Firestore `removed` change events (+ a full reconcile on cold
  start, below). No `deleted_at`, no read-query changes, no AI views. **Existing reads stay 100% as-is.**

---

## New tables (migration v13 — additive only)

In `_onUpgrade`, add `if (oldVersion < 13) { ... }`; also add these `CREATE TABLE` calls in
`_onCreate` for fresh installs (factor into small helpers like the existing
`_createMeasurementFieldsTable`).

```sql
-- writer push queue; coalesces to the latest intent per row
CREATE TABLE sync_outbox (
  collection  TEXT NOT NULL,
  entity_id   TEXT NOT NULL,
  op          TEXT NOT NULL,            -- 'upsert' | 'delete'
  enqueued_at INTEGER NOT NULL,         -- epoch millis (DateTime.now().millisecondsSinceEpoch)
  PRIMARY KEY (collection, entity_id)
);

-- device-local key/value config (NEVER synced): device id, role cache, epoch, flags, timestamps
CREATE TABLE sync_meta (
  key   TEXT PRIMARY KEY,
  value TEXT
);

-- fenced device's unsynced changes, set aside for review (never silently dropped)
CREATE TABLE sync_quarantine (
  id            TEXT PRIMARY KEY,       -- uuid
  collection    TEXT NOT NULL,
  entity_id     TEXT NOT NULL,
  op            TEXT NOT NULL,
  payload       TEXT,                   -- JSON of the row at quarantine time (for review)
  reason        TEXT NOT NULL,
  quarantined_at INTEGER NOT NULL
);
```

`sync_meta` keys used across phases: `device_id`, `device_name`, `sync_enabled` ('1'/'0'),
`writer_epoch` (the epoch this device claimed under), `cached_control` (JSON of last-seen control
doc, for offline role), `backfill_done` ('1'), `last_push_at`, `last_pull_at`.

---

## Cloud layout (Firestore)

```
users/{uid}/
  meta/control                  ← { writerDeviceId, writerDeviceName, epoch, pendingCount, claimedAt, updatedAt }
  customers/{id}                ← entity.toJson() + envelope
  orders/{id}
  measurements/{id}
```
**Envelope** added to each entity doc on publish: `updatedAt` (FieldValue.serverTimestamp()),
`schemaVersion` (the local `_dbVersion`), `writerEpoch`. (No `deletedAt` — deletes remove the doc.)
Ensure each model's `toJson()` emits Firestore-safe primitives (it does today: strings/ints/lists/
ISO-date strings). Verify no `toJson` key collides with an envelope key.

**Security rules (the USER publishes in Firebase console):**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

---

## The `FirestoreGateway` seam (all phases depend on it)

Create `domain/services/sync/firestore_gateway.dart` — the ONLY file that imports `cloud_firestore`.
Everything else depends on this interface so services are unit-testable with a fake.

```dart
abstract class FirestoreGateway {
  // control doc
  Future<ControlDoc?> readControl(String uid);
  Stream<ControlDoc?> watchControl(String uid);
  Future<void> runControlTransaction(String uid, ControlDoc? Function(ControlDoc? current) update);
  // entities
  Future<void> upsert(String uid, String collection, String id, Map<String, dynamic> data);
  Future<void> delete(String uid, String collection, String id);
  Future<void> upsertBatch(String uid, String collection, List<(String id, Map<String,dynamic>)> docs); // <=500
  Stream<List<DocChange>> watchCollection(String uid, String collection); // added/modified/removed
  Future<List<Map<String,dynamic>>> fetchAll(String uid, String collection); // for reconcile
}
```
Provide `FirebaseFirestoreGateway` (real) and `FakeFirestoreGateway` (in-memory, for tests).

---

## Phase 0 — Firestore dependency + gateway + flag  ·  **[Sonnet-OK]**

- `pubspec.yaml`: add `cloud_firestore` (version compatible with the pinned `firebase_core`/SDK; run
  `flutter pub get` from `app/`). `firebase_auth`/`firebase_core` already present.
- Implement `FirestoreGateway` + `FirebaseFirestoreGateway` + `FakeFirestoreGateway`.
- Add the `sync_enabled` flag accessor (reads `sync_meta`, default `'0'`). Provide a `SyncConfig`
  with a single `bool get enabled`. With it false, no sync code runs.
- No behavior change for the user. **Acceptance:** app builds + boots unchanged; gateway compiles;
  fake passes a trivial round-trip test. **Manual (USER):** create Firestore in the Firebase project
  + publish the rules above. List these in the PR.

## Phase 1 — Migration v13 + device identity + sync_meta repo  ·  **[Sonnet-OK]**

- Add the three tables (above) to `_onCreate` + `_onUpgrade` (`oldVersion < 13`).
- `domain/services/sync/device_identity.dart`: `Future<String> deviceId()` (read `sync_meta.device_id`;
  if absent, generate UUID v4, persist, return), `Future<String> deviceName()` (best-effort; default
  "Device" — `device_info_plus` optional).
- `backend/repositories/sync_meta_repository.dart` (+ sqlite impl, + factory + barrel): get/set/delete
  by key; plus typed helpers for the known keys. CRUD only — no Firestore.
- Unit tests: device id is stable across calls; sync_meta CRUD. **Acceptance:** migrate an existing
  v12 DB → v13 adds tables, all existing rows intact (write a migration test that seeds a v12-shaped
  DB, opens at v13, asserts customer/order/measurement rows unchanged + new tables exist).

## Phase 2 — Role state + control doc + write-UI gating  ·  **[mixed]**

- `domain/models/control_doc.dart` (`ControlDoc` + fromMap/toMap) — **[Sonnet-OK]**.
- `domain/services/sync/sync_control_service.dart` — wraps `FirestoreGateway` control ops:
  `claimWriter(uid, deviceId, name, expectedEpoch)` (transaction: abort if epoch moved),
  `forceTakeover(uid, deviceId, name)` (unconditional epoch bump), `watch/get`. **[Opus-grade]**
  (transaction/epoch correctness).
- `domain/services/sync/sync_role.dart` — **pure** `SyncRole computeRole({bool enabled, String? uid,
  String? myDeviceId, ControlDoc? control})` → `unconfigured | writer | reader`. Rules: flag off /
  uid null ⇒ unconfigured; control null ⇒ unconfigured (unclaimed); `control.writerDeviceId ==
  myDeviceId` ⇒ writer; else reader. **[Sonnet-OK]** with exhaustive unit tests (table of inputs).
- `domain/state/sync_state.dart` (`ChangeNotifier`): subscribes to `watchControl` + connectivity;
  exposes `role`, `online`, `writerDeviceName`, `pendingCount`, `lastError`, `bool get canWrite =>
  role != reader`. **Offline-first nuance [Opus-grade]:** cache the last-seen control doc in
  `sync_meta.cached_control`; when offline (no snapshot yet) compute role from the cache so an
  offline writer **stays a writer** and keeps editing. Only fail-safe to reader when there IS a
  control doc naming another device. Register in `MultiProvider`.
- **Gate write UI [Sonnet-OK, but be thorough]:** add `presentation/widgets/sync/writer_only.dart`
  (`WriterOnly({child, fallback})` reading `SyncState.canWrite`) and wrap every write entry point.
  Enumerate via grep — at minimum: add/edit/delete FABs & buttons on customers/orders/measurements
  lists + detail screens (`DeleteEntityButton`, edit routes), the order creator, measurement form,
  dictation buttons, AI assistant `propose_*` actions (disable writes; keep read/query), and
  settings that mutate shared data (measurement fields editor, common headings). Also: if role flips
  to reader while a write screen is open, block save with a message but keep the user's typed data.
- **Acceptance:** flag off ⇒ unchanged. Naming another device ⇒ all write affordances gone + a
  read-only banner; reads work. Fresh account (no control doc) ⇒ a "Use this device as primary?"
  prompt calling `claimWriter(expectedEpoch: 0)`.

## Phase 3 — Writer publish (outbox + push pump)  ·  **[Opus-grade core]**

- **Enqueue at the repo seam [Sonnet-OK once pattern is fixed]:** add a tiny `SyncOutbox.enqueue(
  collection, id, op)` and call it from `add*`/`update*` (`op: upsert`) and `delete*` (`op: delete`)
  in the customer/order/measurement sqlite repos. **Cascade:** `deleteOrdersByCustomerId` /
  `deleteMeasurementsByCustomerId` and customer delete must enqueue a `delete` op **per affected id**
  — enumerate ids BEFORE deleting. Guard enqueue behind `SyncConfig.enabled` so flag-off is a no-op.
  `clearAll` (used by signOut) must NOT enqueue (it's a local wipe, not a data delete).
- `domain/services/sync/sync_serializer.dart` — `Map<String,dynamic> docFor(collection, row)` =
  `model.toJson()` + envelope. **[Sonnet-OK]**.
- `domain/services/sync/sync_push_pump.dart` — **[Opus-grade]**:
  - Runs when `role == writer` && `enabled`: on start, after a write (debounced ~1s), on reconnect.
  - Re-entrancy guard (`_running`). **Fence check first** (Phase 7). Then read outbox rows; for each:
    `upsert` → load row via repo (skip if gone — a later delete supersedes), push; `delete` → push
    delete. Batch upserts (≤500). On ack, remove outbox row. Update `sync_meta.last_push_at` and the
    control doc's `pendingCount` (= outbox size) so the handoff gate can read it.
  - Offline: Firestore SDK queues writes; the outbox is the reconciliation backstop (anything still
    present is retried next run). Idempotent (`set`/`delete` by id).
- Wire pump lifecycle to role in a `domain/services/sync/sync_coordinator.dart` (start/stop on role
  change; also start applier in Phase 3-reader). **[Opus-grade]**.
- **Acceptance:** as writer, create/edit/delete a customer/order/measurement → correct docs
  appear/disappear in the Firestore console; offline edits flush on reconnect; deleting a customer
  removes its orders+measurements docs too. Tests (with `FakeFirestoreGateway`): enqueue→push clears
  outbox; coalescing (2 edits → 1 upsert); upsert-then-delete → single delete; cascade enqueues all
  child ids.

## Phase 4 — Reader subscribe (mirror)  ·  **[Opus-grade core]**

- `domain/services/sync/sync_applier.dart` — **[Opus-grade]**: per synced collection, subscribe to
  `watchCollection`. Apply `DocChange`s: `added`/`modified` → map via `Model.fromJson` →
  repo upsert through a **dedicated sync-only path** that does NOT enqueue to the outbox (add e.g.
  `upsertFromSync(model)` to each repo, or pass an `enqueue: false` flag) so the mirror never becomes
  dirty; `removed` → repo hard-delete (no enqueue). After a batch, refresh the matching `*State` via
  the same loader the app uses at startup (so UI updates live, no flicker). Update
  `sync_meta.last_pull_at`.
  - **Cold-start reconcile:** on first attach per collection, `fetchAll` ids and
    `DELETE FROM <table> WHERE id NOT IN (...)` (no enqueue) to drop rows deleted while this device's
    Firestore cache was absent. Log counts.
  - Tolerant reads: ignore unknown doc fields; `fromJson` must tolerate missing fields (verify).
- Reader UI is already read-only from Phase 2; the applier is the only writer to the reader's DB.
- **Acceptance:** changes on writer A appear on reader B within seconds; deletes disappear; B's AI SQL
  reflects mirror; B offline shows last mirror. Tests: applier maps added/modified/removed correctly;
  reconcile deletes stale ids; sync upsert path does not touch the outbox.

## Phase 5 — Media references (Drive unchanged)  ·  **[mixed]**

- Entity media refs already sync inside the JSON. Determine if a ref resolves cross-device
  (Drive id/name vs device-absolute path). **If device-absolute**, store/sync a Drive-relative
  identifier and have the reader resolve it via the existing Drive download into its own media dir
  (reuse the backup-import path-rewrite). **[Opus-grade decision; Sonnet implements once decided].**
- Reader lazy-downloads on view (detail/play), never blocks lists; missing media → existing
  "unavailable" affordance. **Retention/cleanup + Drive prune run on the WRITER only** (guard the
  existing empty-set prune); the reader must never prune Drive. **[Sonnet-OK]**.
- **Acceptance:** media created on writer shows on reader after Drive upload + on-view download;
  missing media degrades gracefully; reader never deletes Drive files.

## Phase 6 — Backfill + reader bootstrap  ·  **[Opus-grade]**

- `domain/services/sync/sync_backfill_service.dart`: triggered explicitly by the "Enable as primary"
  action. Steps: (1) ensure a fresh **rollback snapshot** (`DbSnapshotService.snapshotBeforeOpen`
  semantics, or trigger a Drive backup) — abort on failure; (2) for every row in each synced table,
  `INSERT OR REPLACE` an `upsert` outbox entry; (3) run the pump to completion with progress;
  (4) set `sync_meta.backfill_done`. Idempotent (safe to re-run; never auto-runs after done).
- Reader first run: initial snapshot delivery is the full pull; show loading until the first
  snapshot of each core collection applies. **Before adopting reader mode, if the device already has
  local data, take a snapshot/backup and confirm** ("This device will mirror <Tablet>; its local data
  will be replaced"), then let the applier's reconcile converge it to the mirror.
- **Acceptance:** enabling sync on the tablet publishes all existing rows (verify counts); a fresh
  reader downloads them; re-running backfill changes nothing; rollback snapshot taken first.

## Phase 7 — Handoff, force takeover, fencing, quarantine  ·  **[Opus-grade — most delicate]**

- **Normal handoff** (UI on a reader): enabled only when **this device online** AND
  `control.pendingCount == 0` AND control is fresh. Action: `claimWriter(expectedEpoch:
  control.epoch)` (transaction bumps epoch, sets this device). Old writer sees the control change →
  demotes (stop pump) → starts applier. No divergence (it had 0 pending).
- **Force takeover** (separate, guarded button, for a lost/broken primary): confirm dialog naming the
  demoted device + warning unsynced changes there will be set aside; take a fresh rollback snapshot;
  `forceTakeover` (unconditional epoch bump); transition this device reader→writer (ensure latest
  mirror, then start pump).
- **Fence check in the pump (every run, before pushing):** one-shot `readControl`. If
  `writerDeviceId != myDeviceId` OR `epoch > sync_meta.writer_epoch` ⇒ **fenced**: do NOT push; move
  every outbox row into `sync_quarantine` (with a JSON payload snapshot of the row for review),
  clear the outbox, demote to reader, start applier, raise a banner + a "Changes that couldn't sync
  (N)" review screen. Offline writer keeps queuing; the fence check at reconnect (before drain)
  prevents it clobbering the new primary.
- **signOut** must: stop pump + applier (via coordinator) and **leave `meta/control` intact** (cloud
  master survives sign-out); keep the existing local wipe. (`AuthService.signOut` already wipes local
  + cancels tasks — just stop sync first.)
- **Acceptance:** normal handoff swaps cleanly, no loss; force takeover works while old writer is off,
  and when the old writer returns it fences itself, quarantines its unsynced rows, becomes reader,
  does NOT overwrite the cloud; rollback snapshot taken before takeover. Tests: fence decision
  (myEpoch+control → push|fence); quarantine capture; claim transaction aborts on epoch drift.

## Phase 8 — Sync-health UI  ·  **[Sonnet-OK]**

- `presentation/widgets/sync/sync_health_card.dart` mirroring `backup_health_card.dart`: role
  (Primary / Mirror of <name> / Not set up), online/offline, pending count (outbox size), last
  push/pull times, last error. A "Sync" section on Settings: enable flag, "Make this the primary"
  + "Force takeover" buttons (Phase 7), device name, link to the quarantine review screen.
- **Acceptance:** card reflects reality (toggle airplane mode + make a write → pending rises then
  clears); matches the existing health-card visual language.

---

## Division of labor — what to do with Opus vs Sonnet

**Recommendation:** have **Opus implement the brain** (small, high-leverage, correctness-critical),
then switch to **Sonnet for the bulk** (scaffolding, migration, serializers, repo wiring, all UI,
tests, provider wiring) following this plan. Concretely:

**Worth doing with Opus now (≈4 files, the parts a wrong line silently loses/clobbers data):**
- `sync_push_pump.dart` (outbox drain + fence-check ordering + batching + offline/idempotency).
- `sync_applier.dart` (docChange handling + cold-start reconcile + flicker-free state refresh).
- `sync_control_service.dart` + the fence/quarantine + handoff/takeover logic (epoch correctness).
- `sync_role.dart`'s offline-cache role rule + the `sync_coordinator` lifecycle.
Plus a one-time Opus **review pass** before flipping the flag on (Golden Rule data-safety check).

**Safe for Sonnet (well-specified, low blast-radius):**
- Phase 0 (dep + `FirestoreGateway`/fake), Phase 1 (migration v13 + device id + sync_meta repo).
- `sync_serializer.dart`, `control_doc.dart` model, the repo **enqueue calls** (apply the fixed
  pattern across all three repos incl. cascades), the `upsertFromSync` no-enqueue path.
- All UI: `WriterOnly` + gating, sync health card, Settings "Sync" section, quarantine review screen.
- Provider wiring in `main.dart`; the pure `computeRole` + serializer + fence-decision **unit tests**.

Phases are tagged inline above (`[Opus-grade]` / `[Sonnet-OK]` / `[mixed]`). A pragmatic order:
Sonnet does 0–1, Opus does the cores of 2–4 and all of 7, Sonnet finishes 5/6/8 and tests, Opus reviews.

---

## Cross-cutting edge cases (check every phase)

- Offline-first writer never blocks a write on connectivity; outbox + Firestore queue replay later.
- Never trust device clocks across devices for ordering — Firestore `serverTimestamp()` for cloud;
  `sync_meta` millis are display-only.
- Schema skew: additive fields + tolerant `fromJson` + `schemaVersion` on docs; newer writer must not
  break older reader and vice-versa.
- Idempotency everywhere: push (`set`/`delete` by id) and apply (upsert by id) safe to repeat.
- No silent data loss: only a fenced device's unsynced rows are dropped — and they go to quarantine.
- AI `propose_*` disabled on reader; AI read/SQL works on both (queries the local mirror — unchanged,
  since we did NOT add `deleted_at` filtering).
- Backup/retention/Drive-prune on the writer only; the empty-set prune guard stays.
- Flag OFF ⇒ zero behavior change — the ultimate safety net; keep it true through every phase.

## Testing / verification (per phase, before moving on)

```bash
cd /Users/psarthak/personal/projects/stitch-lane-flutter/app
JAVA_HOME=/opt/homebrew/opt/openjdk@17 flutter analyze     # 0 issues
JAVA_HOME=/opt/homebrew/opt/openjdk@17 flutter test        # all pass
```
- Unit-test every pure function with `FakeFirestoreGateway` (no live backend): `computeRole`,
  serializer/envelope, applier mapping + reconcile, outbox coalescing/cascade, fence decision,
  quarantine capture, and a **v12→v13 migration test asserting existing rows survive**.
- Two-device manual smoke test after Phases 4, 6, 7 (writer+reader on real devices):
  `JAVA_HOME=/opt/homebrew/opt/openjdk@17 flutter run` (or the project run script).
- **Data-safety regression before enabling the flag:** build with flag OFF and confirm it behaves
  exactly like `main` (open existing customers/orders/measurements, take a measurement, record audio,
  run AI SQL, backup/restore).

## Anti-goals

No CRDTs / field-level LWW merge (single writer makes them unnecessary). No Firebase Storage. No
loading the whole dataset into memory to join. No Cloud Functions. No `deleted_at` columns / no
changes to existing read queries (outbox handles deletes). Don't refactor unrelated code; keep PRs
scoped, one (or two) phase(s) each, green on analyze+test, shippable with the flag off.
