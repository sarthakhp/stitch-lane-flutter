# Multi-device sync — design notes

**Status:** on hold. Captured to resume later.
**Date:** 2026-06-20
**Scope:** designing live two-way sync between her tablet and phone (same Google account), with offline support, while staying production-grade and cheap.

## Problem we were solving

She uses StitchGenie on a tablet and a phone. Today the DB is local SQLite per device, so the two devices are independent. We want a change on one to appear (near-)instantly on the other, work offline on both, and merge sanely when both come back online — without standing up an expensive backend.

It must also not regress the things we already invested in:

- AI Create-Order / NL-to-SQL via [`raw_sql_handler`](app/lib/domain/services/ai_query/handlers/raw_sql_handler.dart) (arbitrary, instant queries — the AI's most useful muscle).
- Google Drive backup + the new Drive re-auth recovery + empty-backup guard ([drive_auth_service.dart](app/lib/domain/services/drive_auth_service.dart), [backup_guard.dart](app/lib/domain/services/backup_guard.dart)).
- Offline-first feel; instant UI on old devices.

## Reframings that shaped the design

These are the load-bearing realizations — keep them in mind when picking this back up.

1. **Single user, two devices ≠ collaborative editing.** Conflicts are rare; one person can't edit on both devices simultaneously very often. No CRDTs / OT needed. Last-write-wins is fine *except* for money (use a ledger) and deletes (use tombstones).
2. **"Drop SQLite" doesn't mean lose offline.** Firestore's SDK has on-disk offline persistence + a durable write queue. But:
3. **Firestore is a document store, not a query engine.** No joins, no `SUM/GROUP BY`, indexes per query shape. That collides directly with the AI's NL-to-SQL feature.
4. **Loading the whole dataset into Dart memory to "join client-side"** is not production-grade — fine for hundreds of rows, not for a Play-Store app over years.
5. **BigQuery / OLAP is wrong here.** It's seconds-latency, online-only, built for huge cross-tenant scans. We have small per-user data that must be queried *instantly*. (I floated it; correctly rejected.)
6. **PowerSync/ElectricSQL solve this elegantly but are ~$49/mo from day one** + a Postgres to run. Disqualified on cost.
7. **The right shape is CQRS:** cloud system-of-record + a local relational read model. Keep a local SQLite that the app *and* the AI query; sync it from the cloud.

## Decisions taken (locked in)

| # | Decision | Why |
|---|---|---|
| 1 | **Architecture: Option B — Firestore as cloud system-of-record + local SQLite read model we build.** | Free, zero ops, keeps AI NL-to-SQL fast and offline, valuable to build ourselves for system-design learning. |
| 2 | **Firestore offline cache is durable + queryable;** writes queue offline and replay on reconnect. | This is why Firestore is a sane SoR even with no internet. |
| 3 | **Media stays in Google Drive, only references sync through Firestore.** No Firebase Storage. | Zero new cloud storage cost; reuses the working Drive media pipeline (and the [`DriveAuthService`](app/lib/domain/services/drive_auth_service.dart) recovery we just built). Media is the slow/lazy tier; references are instant. |
| 4 | **Flat collections under `users/{uid}/...`** (`customers`, `orders`, `measurements`, `payments`) with reference fields. | Cross-cutting queries ("all overdue") are simple; nesting earns its keep only at huge per-parent volumes. |
| 5 | **Conflict policy:** field-level **last-write-wins on server timestamps** for ordinary fields; **money = append-only ledger** (payments are docs; balance is computed, never overwritten); **deletes = soft-delete + tombstones**. | Avoids the two LWW landmines (lost payments, resurrected deletes); silent merge everywhere else. |
| 6 | **Standard doc envelope** on every entity: `id`, `createdAt`, `updatedAt` (server ts), `deletedAt`, `schemaVersion`. | Powers LWW, tombstones, and schema evolution from one shape. |
| 7 | **IDs are client-generated** (Firestore `doc().id` or UUIDv4). | Offline-safe creates; reuse existing local IDs in migration. |
| 8 | **Repository boundary stays the seam.** UI/state never sees Firestore types — only domain models and streams. | Lock-in protection; portability via the existing Drive JSON export as the canonical artifact. |
| 9 | **Backup keeps its current role** (cold, periodic, Drive). Drive becomes belt-and-suspenders; Firestore is the durable primary. | Already-built, hardened, and complementary. |

## Decisions explicitly rejected

- **PowerSync / ElectricSQL** — paid (~$49/mo) + a Postgres.
- **BigQuery as analytics mirror for AI queries** — wrong tool for small, instant per-user reads.
- **Cloud Functions for counter maintenance / denorm fan-out** — needed in a Firestore-only world; *not* needed once we have a local SQLite read model that joins/aggregates natively.
- **Loading all rows into Dart memory** to compute KPIs / joins client-side — doesn't scale on old devices for large datasets.
- **Per-device ack-and-delete media relay** — brittle; breaks on offline-for-weeks and fresh reinstall.
- **CRDTs** — overkill for one user / two devices.

## Open questions (to resume on)

1. **Cost-breakdown / line items on an order** — edited piecemeal, or rewritten as a whole? (Decides: sub-docs vs field-on-order.)
2. **Current local primary-key type** (int autoincrement vs string) — affects the migration seed (reuse vs regenerate ids).
3. **Initial seed source** — tablet is presumably authoritative, but confirm the phone holds nothing the tablet doesn't.
4. **Sign-out semantics under sync** — needs to clear local SQLite + detach listeners but never touch cloud data. Intersects directly with the work just done in [`AuthService.signOut`](app/lib/domain/services/auth_service.dart) (which already nukes local data — fine, just needs to also stop the sync applier cleanly).
5. **First-run UX while initial backfill is running** (loading vs empty state).
6. **Team / staff accounts** later — would reintroduce real concurrent editing; design leaves the door open but doesn't solve it.

## The build plan (when we pick this back up)

Phased so each phase teaches one concept and ships independently:

1. **Domain models + repository interfaces.** Lock the boundary. Ports & adapters. *Concept: CQRS split, dependency inversion.*
2. **Local SQLite read model + migrations + mappers.** Point the app's reads at it. *Concept: read model, indexing.*
3. **Firestore write path + security rules + optimistic local apply.** Writes go to cloud; UI updates instantly from the local row. *Concept: system of record, at-least-once delivery, read-your-writes.*
4. **The sync applier.** Listen to Firestore changes → idempotent upsert into SQLite → tombstones. *Concept: CDC, idempotency, eventual consistency. This is the most interesting algorithm.*
5. **Conflict policy in code:** server timestamps, ledger writes, tombstone handling. *Concept: conflict resolution.*
6. **One-time migration of her live data + new-device backfill.** Guarded by current Drive backup as rollback. *Concept: bootstrapping.*
7. **Sync-health UI** (status, pending writes, last-sync). Pattern from [`backup_health_card.dart`](app/lib/presentation/widgets/backup_health_card.dart). *Concept: observability.*
8. **Repoint AI [`raw_sql_handler`](app/lib/domain/services/ai_query/handlers/raw_sql_handler.dart) at the local SQLite read model.** It "just works" again.

## Hard sub-problems to design carefully

- **Idempotency** of the applier (same change seen twice = applied once).
- **Optimistic apply vs server LWW result** — reconcile without flicker.
- **Tombstones & GC** — prevent deleted-row resurrection.
- **Schema evolution under app-version skew** — two devices on different app versions hitting one cloud schema; additive fields, tolerant readers, lazy upcasting via `schemaVersion`.
- **Bootstrapping** — first run/new device pulls everything before app is "ready."
- **Multi-tenant security** — `request.auth.uid == uid` rules; the AI's SQL stays *local-only* and tenant-safe by construction.

## How this fits with existing systems

- **Backup ([`backup_service.dart`](app/lib/domain/services/backup_service.dart) / [`backup_flow.dart`](app/lib/presentation/backup_flow.dart) / `auto_backup_service.dart`)** — unchanged in spirit; reads from local SQLite (same as today). Drive remains the cold backup. The empty-backup guard and Drive re-auth recovery we just shipped continue to apply.
- **AI Create-Order ([`order_creator_*`](app/lib/domain/services/order_creator/))** — unchanged. Writes through the same repositories; sync handles the rest.
- **AI NL-to-SQL ([`raw_sql_handler`](app/lib/domain/services/ai_query/handlers/raw_sql_handler.dart))** — survives by querying the local SQLite read model. Offline + instant by construction.
- **Auth ([`auth_service.dart`](app/lib/domain/services/auth_service.dart) + [`drive_auth_service.dart`](app/lib/domain/services/drive_auth_service.dart))** — the firewall between app-identity (Firebase) and Drive grant we just established stays. Sync rides on the Firebase identity; Drive media reads ride on the Drive grant; the two remain independent.

## Why this is worth doing ourselves (not buying PowerSync)

This app is the forcing function for learning system design end-to-end with real stakes. PowerSync hides exactly the pieces worth learning: CQRS, CDC, idempotency, optimistic concurrency, eventual consistency, schema evolution, observability. Building Option B teaches all of them — and the engineering effort is bounded (lives behind the repository boundary; doesn't touch the rest of the app).

---

*Resume point: pick Open Question #1 (line items piecemeal vs whole-rewrite), then start Phase 1 (domain models + repository interfaces).*
