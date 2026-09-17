# Play Store launch — overall plan

**Status:** planning.
**Scope:** everything needed to go from "personal single-shop app" to "public, multi-tenant app on the Play Store," across every track — not just billing. [WALLET_BILLING_IMPLEMENTATION_PLAN.md](WALLET_BILLING_IMPLEMENTATION_PLAN.md) is one track inside this plan (Track C); this document is the map of the rest.

## What's already solved (don't redo)

- **Signing & release build**: `.github/workflows/build-release-apk.yml` already restores a real keystore, `google-services.json`, and `.env` from GitHub secrets and produces a signed release APK on every push to `main`. This is further along than most pre-launch apps.
- **Sync architecture**: single-writer/multi-reader per tenant, already designed and implemented with real test coverage (`sync_*_test.dart` — fence, handoff, backfill, migration, push pump). Don't touch this for the launch.
- **Privacy policy**: a draft already exists ([privacy_policy.md](privacy_policy.md)) — needs updating, not writing from scratch (see Track D).

## The tracks

### Track A — Multi-tenant account foundations
*(Prerequisite for everything else — a public app can't launch on the current single-owner assumptions.)*
- Server-side tenant provisioning on first login (Cloud Function on Firebase Auth create-user trigger): initializes `tenants/{uid}`, `_control/writer`, wallet balance = 0.
- Account deletion path — Play Store policy requires an in-app way to request deletion of account + data for any app that supports account creation. Needs a Cloud Function that recursively deletes a tenant's Firestore subtree + associated Drive data reference, not just the client-side local wipe that exists today for sign-out.
- Data export — a "download my data" affordance; you already have `backup_export_service.dart`/`backup_import_service.dart` for the personal Drive backup flow, likely reusable as the basis for this rather than new code.
- Device/session limits tied to tenant state (how many devices a shop can register) — natural extension of the existing `deviceId`/`_control/writer` mechanism.

### Track B — Security & compliance
- **Remove the bundled API key** — `.env`/`GEMINI_API_KEY`/`SARVAM_API_KEY` currently ship inside the APK (extractable). This is a hard blocker for public distribution regardless of billing, and is solved as a side effect of Track C's LLM proxy — call this out as a shared dependency, not a separate task.
- **Data Safety form accuracy** — this app collects: Google account, device contacts (`flutter_contacts`), audio recordings, images, and (once Track C ships) payment-related data. Each needs an honest entry; contacts access especially draws Play Store scrutiny and may require a declaration form/demo video.
- **India's DPDP Act 2023** — this app stores *shop customers'* personal data (names, contacts, measurements — arguably sensitive) on behalf of the shop owner. Worth a deliberate look at what DPDP requires of you as the platform (consent flows, data-principal rights, breach notification) versus what's the shop owner's own responsibility as a data fiduciary for their customers. Not blocking for a first release necessarily, but should be a conscious decision, not an oversight.
- **Firestore security rules audit** — the existing rule (`request.auth.uid == uid`) is correct for the current shape; re-verify it once `tenants/{uid}` and `usage_ledger` are added (Track C), since those must be read-only to the client.
- **Secret scanning** — `.gitleaksignore` already shows gitleaks is in use; keep it running in CI (confirm it's actually wired into a workflow, not just configured) so a real key never lands in a commit as tenant count grows and more people might touch the repo.

### Track C — AI wallet & billing
Fully scoped separately in [WALLET_BILLING_IMPLEMENTATION_PLAN.md](WALLET_BILLING_IMPLEMENTATION_PLAN.md): LLM proxy (batch + streaming), wallet ledger, UI gating, Razorpay/Cashfree top-up. Treat as one parallel track feeding into the same Cloud Functions/Cloud Run backend as Track A.

### Track D — Legal
- **Terms of Service** — doesn't exist yet; needed once you're taking payments and hosting other businesses' customer data (personal-app privacy policy isn't enough).
- **Privacy policy update** — extend the existing draft to cover: multi-tenant hosting, payment data handled by Razorpay/Cashfree (not you), and the account-deletion/export flow from Track A.
- **Refund/dispute policy for wallet top-ups** — what happens if a UPI payment succeeds but the webhook fails, or a user wants a refund on unused balance. Needs a stated policy even if the volume is small at first — support requests will reference it.
- Both docs need to be hosted at a public URL for the Play Console listing (GitHub Pages off this repo is the cheapest option, if you don't already have a domain).

### Track E — App quality & observability
- **Crash reporting** — nothing is wired up yet (no Crashlytics/Sentry dependency found). Firebase Crashlytics is the natural choice since Firebase is already integrated; add before the closed-testing phase, not after, so early tester crashes are actually visible to you.
- **Backend observability** — once Track C's Cloud Functions/Cloud Run exist, they need error logging/alerting too (Cloud Logging + a budget alert on GCP billing, so a runaway LLM proxy bug can't silently burn money before you notice).
- **Play Console pre-launch report / vitals** — Play automatically flags crashes, ANRs, and battery/permission issues once you upload to a testing track; budget time to act on it before promoting to production, since Google gates visibility (and can restrict distribution) on bad vitals.
- **Manual QA pass** — multi-device sync (writer/reader/handoff), wallet empty/low/topped-up states, and the AI-disabled UI states (from the wallet plan) are the highest-risk areas to test by hand — they're new state machines, not just new screens.

### Track F — Store listing & release process
- **Play Console account** — one-time $25 registration if not already done.
- **Listing assets** — icon (already present via `flutter_launcher_icons`), screenshots, feature graphic, short/long description, content rating questionnaire, target-audience declaration, ads declaration (none, presumably).
- **Closed testing requirement** — Play now requires ~12 testers opted in for 14 continuous days before a new personal developer account gets full production access; this is a hard calendar dependency, so start it as early as the app is minimally stable, in parallel with Tracks A-E, not after them.
- **Staged rollout** — once out of closed testing, roll production out at a low percentage (e.g. 10-20%) first rather than 100%, given this is a new payment-touching surface.

### Track G — Support & ops
- **Support channel** — an email or in-app contact path is required by the Play Console listing anyway; doubly important once real money (wallet top-ups) is involved — someone will eventually ask "I paid but my balance didn't update."
- **Onboarding for new shops** — a first-run flow explaining wallet top-up + how sync/device roles work, since a new tenant won't have the context you do. Doesn't need to be elaborate for v1, but shouldn't be silently assumed.
- **Localization** — no `flutter_localizations`/`supportedLocales` setup found despite the dependency being declared in `pubspec.yaml`; worth deciding deliberately whether the initial audience is English-only or needs Hindi/regional language support, since tailoring shops are the target user and that's a real UX bar, not a nice-to-have.

## Suggested ordering

These tracks don't have to run strictly sequentially — several can overlap:

1. **Start immediately, runs in background the whole time**: Track F's closed-testing clock (needs only a minimally working build) + Track E's crash reporting (cheap to add now, valuable from day one of testing).
2. **Foundational, blocks Track C**: Track A (tenant provisioning) — Track C's wallet/ledger docs live under the same tenant shape.
3. **Parallel, feeds the same backend**: Track C (wallet/billing) — the biggest single chunk of new code.
4. **Alongside C, shares the "remove bundled key" fix**: Track B (security/compliance) — mostly policy/paperwork plus the API-key removal that Track C delivers as a side effect.
5. **Before submitting to Play Console**: Track D (legal docs must be live and linked in the listing).
6. **Last, but keep assets prepared early**: Track F's actual listing submission, once A-E are stable enough for the 14-day closed test to be meaningful rather than wasted on a broken build.
7. **Ongoing, not a gate**: Track G — start the support channel and onboarding copy early, refine after real users hit it.
