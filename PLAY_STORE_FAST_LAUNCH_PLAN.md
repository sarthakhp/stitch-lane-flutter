# Fast-path Play Store launch — minimum to publish now

**Status:** planning.
**Goal:** get the app published as quickly as possible, ship the rest ([PLAY_STORE_LAUNCH_PLAN.md](PLAY_STORE_LAUNCH_PLAN.md), [WALLET_BILLING_IMPLEMENTATION_PLAN.md](WALLET_BILLING_IMPLEMENTATION_PLAN.md)) as ordinary app updates afterward. Play Store apps update constantly — nothing here has to be "final," it just has to be safe to expose publicly.

## The one thing that changes the calculus

Right now the app has **no billing at all** — the Gemini/Sarvam API keys are bundled in the APK, and every install shares your key with no per-user cap. Publishing without the wallet (Track C of the full plan) means **you're personally paying for every AI call every stranger who installs the app makes**, with no enforcement stopping it. That's the one real risk of skipping straight to publish, and it needs a cheap mitigation even in the fast path — not the full wallet system, just a stopgap. See "Cost containment" below.

Everything else that felt necessary in the full plan turns out to be either already done, or safely deferrable to a later update.

## Minimum to publish (do these, nothing else)

1. **Play Console account** — $25 one-time, if not already registered.
2. **Signing** — already done. `.github/workflows/build-release-apk.yml` produces a signed release build from secrets. Nothing to add.
3. **Cost containment (the stopgap for skipping the wallet)** — pick the cheapest combination that bounds your downside:
   - Restrict the Gemini API key in Google Cloud Console to your Android app's package name + release SHA-1 fingerprint. This stops the key from being lifted out of the APK and reused elsewhere (it still won't stop a legitimate install of your own app from running up usage, but it kills the "key gets extracted and abused in some other app/script" scenario, which is the worse one).
   - Set a **GCP billing budget alert** (e.g. email at $X/day) so an unexpected cost spike reaches you fast, not at month-end.
   - Add a **remote kill switch** for AI features — a single boolean read from Firestore (e.g. `app_config/global.aiEnabled`) checked once at startup/resume. This is a few hours of work (a doc read + gating the same `AiGateway` seam the wallet plan already targets), and it means if costs run away, you flip one field and every installed app stops making AI calls within a session — no app-store update needed. This is the single highest-leverage cheap thing to add before publishing.
   - Sarvam's key can't be scoped the same way (it's used over a direct WebSocket, not a restricted REST key) — the kill switch and budget alert are your main coverage there.
4. **Privacy policy** — the existing draft ([privacy_policy.md](privacy_policy.md)) hosted at a public URL (GitHub Pages is enough) and linked in the Play listing. Update it to mention Google Sign-In, contacts, audio, and images — it doesn't need to mention payments yet, since there are none.
5. **Account deletion** — Play requires *a* path to request deletion for apps with account creation, but **it can be a web form/email, not an in-app flow**. Fastest option: a short Google Form or a `mailto:` link on a hosted page, handled manually for now. This satisfies the policy without building the Cloud Function subtree-delete from the full plan.
6. **Data Safety form** — fill in honestly for what the app *currently* does: Google account, contacts, audio, images. No payment data yet (skip that section). This is paperwork, not code — an hour, not a track.
7. **Content rating questionnaire + store listing assets** — icon (already exists), a handful of screenshots, short/long description. Doesn't need to be polished for a first submission.
8. **Closed testing track (12 testers / 14 days)** — this is a hard calendar requirement for a new developer account to reach production, so submit to closed testing **today**, in parallel with everything else above, since the 14-day clock is your real bottleneck, not the remaining work.
9. **Crash reporting** — not strictly required by Play, but cheap enough (Firebase is already integrated) that skipping it is a false economy — you'd otherwise be flying blind during the closed test, which is precisely when you most want visibility. Recommend keeping this in the fast path even though it's not a policy requirement.

That's the whole fast-path list. Everything below is explicitly **not** needed to publish.

## Explicitly deferred — ship as updates later

- **Full wallet/billing system** ([WALLET_BILLING_IMPLEMENTATION_PLAN.md](WALLET_BILLING_IMPLEMENTATION_PLAN.md)) — the kill switch + budget alert above is the temporary substitute. Build the real wallet once you have real install numbers and want to stop absorbing everyone's AI cost.
- **LLM proxy backend** — same reasoning; the key-restriction + kill switch cover the immediate risk without standing up Cloud Functions/Cloud Run yet.
- **Streaming STT/TTS proxy (Phase 1b)** — depends on the above; not needed until the wallet exists.
- **In-app account deletion / data export** — the web-form stopgap satisfies policy now; build the real Cloud Function version later, ideally before you have many tenants (easier to retrofit early).
- **Terms of Service** — genuinely only needed once money changes hands; write it before Track C ships, not before this first publish.
- **DPDP Act deep-dive, localization, staff accounts, onboarding flow, support channel beyond a bare email** — all real, all fine to build once you see actual usage tell you which matters first. Guessing at these now would be optimizing blind.
- **Staged rollout percentage tuning, Play vitals response process** — relevant once you're out of closed testing; nothing to do about it yet.

## What "publishing an update later" actually looks like

Once this is live, every item above ships the same way: bump `versionCode`/`versionName` in [pubspec.yaml](app/pubspec.yaml), push to `main` (the existing workflow builds and signs it), upload to Play Console as a new release, roll out staged (10-20% → 100%). None of the deferred work requires a different release process than what already exists — it's the same pipeline, just more commits over time. The kill switch means even the riskiest gap (unmetered AI cost) has a same-day mitigation that doesn't wait on a store review.
