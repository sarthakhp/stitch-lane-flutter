# Multi-device sync — design notes

**Status:** active design (single-writer model). Supersedes the two-way design in Appendix A.
**Date:** 2026-06-25
**Scope:** live(-ish) sync between her tablet and phone (same Google account), offline-first, production-grade and cheap — with the **simplest, safest** shape we can ship.

## The decision that simplifies everything

**Single writer, multi reader.** Exactly one device (the shop tablet) is the **writer** and owns the data. Every other device is a **read-only mirror**.

- The **writer keeps its local SQLite as the source of truth, exactly as today.** Nothing about how it works locally changes → existing data carries **zero risk**.
- The writer **publishes** its rows to Firestore.
- Readers **subscribe** to Firestore and mirror down into their own local SQLite. A reader's DB is a disposable cache — wipe-and-rebuild from the cloud anytime, so losing it loses nothing.
- Readers' write UI is disabled. A reader can never touch the cloud or the writer's data.
- **Firebase only** for data/state. **Media stays in Google Drive** (references sync through Firestore); no Firebase Storage.

This is offline-first on both sides: the writer queues writes offline; the reader shows its last-mirrored data offline (read-only, so stale-but-readable is correct).

## Why this is the safe, low-bug choice

Because **only one device ever mutates data**, the entire "hard sub-problems" list from the old two-way design disappears:

| Old problem (two-way) | Why it's gone (single-writer) |
|---|---|
| Conflict resolution / field-level LWW | One writer → nothing to merge. Writer's word is final. |
| Payment ledger *for correctness* | No concurrent edits → no lost-write race. (Payments stay as rows for modeling, but it's no longer load-bearing.) |
| Tombstones & deleted-row resurrection | No reader recreates rows → deletes can't come back. Delete = "row gone/soft-deleted on writer → delete locally on reader." |
| Optimistic-apply vs server LWW flicker | Writer reads its own local SQLite (instant, unchanged). Reader just mirrors. No reconcile. |
| Idempotency races in the applier | Reader upserts by id → applying a snapshot twice is a no-op by construction. |

The sync applier shrinks from "the most dangerous algorithm" to: **make my local mirror equal the cloud snapshot.**

The only residual data-loss vector is **role handoff** (see below), which we close with an online+synced gate plus a fencing token.

## Architecture

```
WRITER (tablet)                         CLOUD (Firestore)                 READER (phone)
─────────────────                       ─────────────────                 ───────────────
local SQLite  ← source of truth         users/{uid}/                      local SQLite  ← mirror (disposable)
   │  repo write sets dirty=1             customers/{id}                     ▲  idempotent upsert / delete
   ▼                                       orders/{id}                       │
push pump ── upsert ──────────────────►   measurements/{id}  ──── snapshot listeners ──┘
(fence-checked)                            payments/{id}
                                           _control/writer { deviceId, epoch, ... }
media refs only ──────────────────────────────────────────────────────────────────────
   │
   ▼  (unchanged)
Google Drive  ◄──── lazy download ──── reader resolves media by Drive reference on view
```

- **Repository boundary stays the seam.** UI/state see only domain models. The writer's repos gain a `dirty` write; the reader's repos are fed by the sync applier. Firestore types never leak upward.
- **Same SQLite schema on both** — the reader's DB is identical in shape, just populated from the cloud. The app and the AI NL-to-SQL on the reader are unchanged and stay instant + offline.

## Decisions taken (locked in)

| # | Decision | Why |
|---|---|---|
| 1 | **Single writer, multi reader.** One device owns the data; others mirror read-only. | Removes all conflict/merge/tombstone machinery. Simplest, least bug-prone, safest for existing data. |
| 2 | **Firestore as cloud system-of-record; local SQLite kept on every device.** | Free, zero-ops; keeps AI NL-to-SQL fast + offline; offline write queue built into the SDK. |
| 3 | **Media stays in Google Drive; only references sync via Firestore.** No Firebase Storage. | Zero new storage cost; reuses the working Drive pipeline + `DriveAuthService` recovery. References are instant, media is the lazy tier. |
| 4 | **Flat collections under `users/{uid}/...`** with a standard doc envelope (`id`, `createdAt`, `updatedAt`, `deletedAt`, `schemaVersion`). | Simple cross-cutting reads; soft-delete via `deletedAt`; schema evolution from one shape. |
| 5 | **Client-generated IDs; reuse existing local IDs.** | Offline-safe creates; trivial, idempotent backfill (upsert by existing id, never regenerate). |
| 6 | **Delivery rides the Firestore SDK's durable offline write queue;** we add a lightweight `dirty`/`syncedAt` flag only for reconciliation + health UI + the handoff gate. | Don't reimplement a queue Firestore already gives us; the flag is cheap insurance (re-push anything still dirty) and powers "0 dirty rows" checks. |
| 7 | **Deletes propagate via a writer-side deletion outbox + hard delete** (writer deletes the row and the Firestore doc; reader removes its mirror on the `removed` event + a cold-start reconcile). | No resurrection risk (single writer); and crucially this needs **no `deletedAt` columns and no changes to existing read queries** — the sacred entity tables stay untouched. See the implementation plan ("Why an outbox"), which refines this from the original soft-delete idea. |
| 8 | **Reader is strictly read-only**; write UI disabled in reader mode. | Makes it impossible for a second device to corrupt the master. |
| 9 | **Role stored in one control doc** `users/{uid}/_control/writer = { deviceId, deviceName, epoch, claimedAt }`. | Single source of truth for who may write; `epoch` is the fencing token. |
| 10 | **Drive backup keeps its current role** (cold, periodic) and gates the one-time backfill + force takeover as a rollback artifact. | Already hardened; belt-and-suspenders. |

## Role management & handoff (the one careful part)

Only one device writes; the rest is just choosing which. On launch a device compares its `deviceId` to `_control/writer` → **writer mode** (read/write UI) or **reader mode** (read-only UI).

### Normal handoff — safe by gate
"Make this the writing device" is allowed only when **both devices are online and the current writer has 0 dirty rows**. A Firestore transaction bumps `epoch` and sets the new `deviceId`; the old writer (subscribed to the control doc) sees the change and demotes cleanly. Because there's never queued offline work straddling a handoff, **divergence is impossible**.

### Force takeover — for a lost/broken/sold primary
When the old writer is unreachable, another device can seize the role **without** the online+synced handshake. To stop a resurrected old writer from clobbering the new one, we use a **fencing token**:

1. Force takeover takes a **fresh Drive snapshot first** (rollback) and requires an explicit confirm naming the device being demoted.
2. The transaction **bumps `epoch`** and sets the new `deviceId`.
3. The writer's push pump is **fence-checked**: before draining its queue it reads the current control doc. If `deviceId != me` or `epoch > myEpoch`, it is fenced → it **does not push**, demotes to reader, and re-mirrors from cloud.
4. **Quarantine, not discard:** the fenced device's unsynced rows move into a local "couldn't sync — another device took over" list, surfaced for review. Nothing vanishes silently.

When online, the fenced device learns immediately (control-doc listener). When offline it keeps queuing locally; the fence check runs at reconnect **before** the drain — the only dangerous moment, and when control-doc state is freshest.

## Conflict policy

There is effectively none. Single writer → last (and only) writer wins everywhere. The fencing token handles the one cross-device race (takeover). Payments remain individual rows (good modeling) but no longer need to be a ledger for correctness.

## Security

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth.uid == uid;
    }
  }
}
```

Tenant isolation is enforced server-side. Single-writer is a **client-app invariant** (acceptable for one trusted user). Optional later hardening: pin writes to the control-doc `deviceId` in rules once staff accounts exist.

## Cost

Single-writer is also the cheapest shape. Listener attach reads each doc once (hundreds of rows — trivial); after that you're billed only for *changed* docs, which is low with one writer. Free tier (50K reads/day) is far above one shop on two devices. Discipline: listen per-collection with ordering so deltas stay small; avoid broad `{document=**}` listeners that re-read large collections on every change.

## Build plan (phased, each ships independently)

1. **Firebase/Firestore setup + security rules + `deviceId` + `_control/writer` doc + role state** gating the UI (reader vs writer). Writer behavior unchanged when alone.
2. **Writer publish path:** `dirty`/`syncedAt` columns + push pump → Firestore upsert; soft-delete via `deletedAt`. At the existing repository seam.
3. **Reader subscribe path:** per-collection snapshot listeners → idempotent upsert/delete into local SQLite; read-only UI mode.
4. **Media references** in docs + reader lazy Drive download (writer keeps current Drive upload).
5. **Bootstrap:** writer one-time backfill of existing local data (idempotent upsert by id, guarded by a fresh Drive backup); new reader pulls full snapshot before "ready."
6. **Sync-health UI** (role, dirty/pending count, last-synced) — reuse the `backup_health_card.dart` pattern.
7. **Handoff + force takeover** (online+synced gate; transactional epoch bump; fence check + quarantine in the pump; Drive-snapshot-before-takeover).

## Media references — resolved (Phase 5)

**Decision.** Stored media refs (`imagePaths`, `audioFilePaths`) are **device-absolute
file paths whose basename is the stable cross-device identity** — the basename is exactly
the Google Drive file name (Drive syncs media by name into `order_images/` and
`audio_backups/` folders). The full absolute path is device-local and does **not** resolve
on another device; the basename does.

**Reader resolution (lazy, on view).** A reader resolves any stored ref to
`<this device's media dir>/<basename>` and, if absent, **lazy-downloads from Drive by
basename on view** — never in lists. Implemented by `MediaResolver` (`resolveImage` /
`resolveAudio`): (1) stored path exists → use it (writer / single device — unchanged, no
network); (2) basename already cached locally → use it; (3) download by basename from
Drive → cache → use it; else `null` → the existing "unavailable" affordance. Wired into
`LocalImage` (all image displays) and `RecordingsCard` (detail audio). The
all-present-locally fast path keeps the writer/single-device experience byte-for-byte the
same.

**Writer owns Drive media.** Upload + prune (`syncImagesToDrive` / `syncAudiosToDrive`)
run **only when `SyncMediaPolicy.canManageDriveMedia()` is true** — i.e. sync is off
(sole-owner/legacy) or this device is the writer. A reader never uploads and, critically,
never prunes Drive (the prune deletes Drive files not present locally, which on a reader is
most of them). The policy reads `sync_meta` directly so it also holds inside the
WorkManager background isolate, where the provider tree doesn't exist.

## How this fits existing systems

- **Backup** (`backup_service.dart` / `auto_backup_service.dart`) — unchanged; reads local SQLite (writer's truth). Drive stays the cold backup and the rollback artifact for backfill/takeover. Empty-backup guard + Drive re-auth recovery still apply.
- **AI Create-Order** (`order_creator_*`) — unchanged; writes through the same repositories on the writer; sync handles the rest. Disabled in reader mode.
- **AI NL-to-SQL** (`raw_sql_handler`) — unchanged; queries local SQLite on either device. Offline + instant by construction.
- **Auth** (`auth_service.dart` + `drive_auth_service.dart`) — the Firebase-identity vs Drive-grant firewall stays. Sync rides Firebase identity; Drive media rides the Drive grant. `signOut` already nukes local data; it must additionally detach listeners and — if this device was the writer — **leave the control doc intact** so the cloud master survives sign-out (re-login returns as reader until it reclaims the role).

## Resolved vs the old open questions

- **Line items piecemeal vs whole-rewrite** — moot; single writer rewrites the doc however it likes, no merge.
- **Primary-key type** — reuse existing local IDs as Firestore doc ids (Decision 5).
- **Initial seed source** — the tablet is the writer; the phone's local DB is discarded and re-mirrored. No merge.
- **Sign-out under sync** — see Auth above.
- **First-run UX during backfill** — reader shows a loading/empty state until the first full snapshot lands; writer is usable throughout.
- **Team/staff accounts** — out of scope; would reintroduce concurrent editing. Door left open via the control-doc + rules hardening note.

---

# Appendix A — prior two-way design (superseded 2026-06-25)

> Kept for history. We chose the single-writer model above because it removes all conflict/merge/tombstone machinery while preserving offline-first and the AI's local SQL. The CQRS framing and "media on Drive" decision below still hold; the conflict-resolution machinery does not.

## Problem we were solving

She uses StitchGenie on a tablet and a phone. Today the DB is local SQLite per device, so the two devices are independent. We want a change on one to appear (near-)instantly on the other, work offline on both, and merge sanely when both come back online — without standing up an expensive backend.

It must also not regress the things we already invested in:

- AI Create-Order / NL-to-SQL via `raw_sql_handler` (arbitrary, instant queries — the AI's most useful muscle).
- Google Drive backup + the Drive re-auth recovery + empty-backup guard (`drive_auth_service.dart`, `backup_guard.dart`).
- Offline-first feel; instant UI on old devices.

## Reframings that shaped the (old) design

1. **Single user, two devices ≠ collaborative editing.** Conflicts are rare. No CRDTs / OT. LWW is fine except money (ledger) and deletes (tombstones). — *In the new design, single-writer removes even this.*
2. **"Drop SQLite" doesn't mean lose offline.** Firestore's SDK has on-disk offline persistence + a durable write queue.
3. **Firestore is a document store, not a query engine.** No joins/`SUM`/`GROUP BY`. Collides with AI NL-to-SQL → keep local SQLite.
4. **Loading the whole dataset into Dart to "join client-side"** isn't production-grade for years of data.
5. **BigQuery / OLAP is wrong here** — seconds-latency, online-only.
6. **PowerSync/ElectricSQL** solve it elegantly but ~$49/mo + a Postgres. Disqualified on cost.
7. **The right shape is CQRS:** cloud system-of-record + a local relational read model. — *Retained in the new design.*

## (Old) decisions, since reframed

The two-way design locked in field-level LWW on server timestamps, an append-only payment ledger, soft-delete + tombstones, a standard doc envelope, client-generated IDs, the repository boundary as the portability seam, and Drive-only media. The envelope, IDs, repository seam, and Drive-media decisions survive into the single-writer design; **LWW, the ledger-for-correctness, and tombstone-resurrection handling are no longer needed** because only one device writes.

## (Old) hard sub-problems — now mostly moot

Idempotency of the applier (still relevant, but trivial via upsert-by-id), optimistic-apply vs server LWW reconciliation (gone), tombstones & GC (gone), schema evolution under version skew (still handled via additive fields + `schemaVersion`), bootstrapping (retained), multi-tenant security (retained: `request.auth.uid == uid`).

## Why build it ourselves (still true)

This app is the forcing function for learning system design with real stakes: CQRS, CDC-lite, idempotency, eventual consistency, schema evolution, observability — now with a fencing-token handoff as a bonus. Effort stays bounded behind the repository boundary.
