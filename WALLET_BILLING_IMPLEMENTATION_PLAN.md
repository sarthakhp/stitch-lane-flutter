# AI wallet + multi-tenant billing — implementation plan

**Status:** planned, not started.
**Depends on:** [MULTI_DEVICE_SYNC_DESIGN.md](MULTI_DEVICE_SYNC_DESIGN.md) / [MULTI_DEVICE_SYNC_IMPLEMENTATION_PLAN.md](MULTI_DEVICE_SYNC_IMPLEMENTATION_PLAN.md) — this plan reuses the existing `users/{uid}` tenant boundary and the `SyncState`/`WriterOnly` gating pattern; it does not change the sync design.

## Decisions locked in (from prior discussion)

1. **Prepaid wallet, not subscription.** No autopay/e-mandate. User tops up a balance (e.g. ₹50) via a one-time UPI payment; LLM calls deduct from it.
2. **No markup for now.** Deduct exactly what the provider charges, computed server-side from actual usage. Revisit once download numbers justify it — the deduction step is a single line to change later, not a redesign.
3. **Firebase/Firestore cost is not passed through to users** at this stage — absorbed as overhead, revisited only if it stops being negligible.
4. **Payment rail:** Razorpay or Cashfree, one-time UPI order (GPay/Paytm/PhonePe as UPI handles), not a subscription product.
5. **All AI calls must be blockable server-side** when a wallet is empty — the client must never be the source of truth for "can this call happen," only a fast local cache of it for UX.

## Why the client-side `AiGateway` is the right seam

[ai_gateway.dart](app/lib/domain/services/ai_gateway/ai_gateway.dart) is already documented as "the single entry point for every external AI provider call in the app," with a planned phase 2 where every call site routes through it instead of hitting SDKs directly. That migration is exactly what this plan needs anyway (to swap direct Gemini/Sarvam calls for calls to your backend proxy), so **this plan piggybacks on work you already scoped**, not a separate rewrite.

---

## Phase 0 — Backend foundations

- Stand up Cloud Functions (or Cloud Run) project wired to the existing Firebase project.
- Extend the tenant doc: `tenants/{uid}` gains `walletBalanceMinor` (store in paise, integer, to avoid float rounding), `plan` (reserved for later), and a `usage_ledger/{eventId}` subcollection (one doc per LLM call: cost, tokens, provider, model, timestamp) — this is the server-side counterpart of the existing local `ai_usage_repository.dart`/`usage_recorder.dart`, not a replacement for it (keep local recording for the on-device dashboard; the ledger is the billing source of truth).
- Firestore rules: `tenants/{uid}` and `tenants/{uid}/usage_ledger/**` are **read-only for the owner, no client writes** — only the Admin SDK (Cloud Functions) can write balance/ledger. This is the same "server-authoritative, client-reads-only" principle discussed for the plan doc earlier, applied to the wallet.
- Move [pricing.dart](app/lib/domain/services/ai_gateway/pricing.dart)'s pricing table to the backend (duplicate or share via a small shared package) — the deduction must use the same numbers the client shows, or the "0 dirty rows" style trust in your own UI breaks.

## Phase 1 — LLM proxy + wallet deduction

- One Cloud Function endpoint per **batch** AI capability called directly today (chat, multimodal, STT batch, TTS). The streaming STT/TTS sessions (`sarvam_streaming_stt_provider.dart`/`sarvam_streaming_tts_provider.dart`) don't fit this shape at all — they get their own design in Phase 1b below.
- Request flow per call:
  1. Verify the caller's Firebase ID token → resolves `uid`.
  2. Transactionally read `walletBalanceMinor`; if `<= 0`, return a typed `WALLET_EMPTY` error immediately (no provider call made — this is the hard stop).
  3. Call Gemini/Sarvam with the real, server-held API key.
  4. Compute actual cost from the provider's actual usage numbers (tokens/seconds/characters returned in the response), not an estimate.
  5. Transactionally deduct that cost from `walletBalanceMinor` and append a `usage_ledger` doc.
  6. Return the AI result **plus the new balance** in the same response, so the client can update its UI without a second round trip.
- Real API keys (`GEMINI_API_KEY` etc.) move out of the bundled `.env`/Flutter assets entirely once this phase ships — this also closes the key-exposure gap flagged earlier for Play Store distribution.

## Phase 2 — Client: `WalletState` + gating widgets

Mirror the existing sync-role pattern instead of inventing a new one:

- `WalletState` (in `lib/domain/state/`, alongside [sync_state.dart](app/lib/domain/state/sync_state.dart)) — holds `balanceMinor`, `isLow` (below a configurable threshold, e.g. ₹10), `isEmpty`, refreshed (a) on app resume, (b) after every AI call response (using the balance returned in phase 1's response, no extra read), (c) via a lightweight Firestore listener on `tenants/{uid}` for cross-device consistency (a top-up on the phone should reflect on the tablet without a manual refresh).
- `AiFeatureGate` widget (in `lib/presentation/widgets/`, alongside [writer_only.dart](app/lib/presentation/widgets/sync/writer_only.dart)) — same shape as `WriterOnly`: wraps an AI entry point, shows it enabled when `!walletState.isEmpty`, otherwise shows a disabled/greyed variant or a "top up to continue" affordance instead of `fallback ?? SizedBox.shrink()` (unlike `WriterOnly`, you *want* something visible here, not a silent hide — the user needs to know why the mic button is dead).
- `AiGateway` calls that hit the phase 1 proxy should surface a typed exception on `WALLET_EMPTY` (mirroring the fencing/quarantine error handling already in `sync_fence_service.dart`'s style) so every call site has one place to catch it and show the same "top up" prompt, rather than each screen inventing its own error text.

### Where this actually plugs in (every current AI entry point needs the gate)

Audit and wrap each of these with `AiFeatureGate` (client) + confirm it goes through the phase-1 proxy (server):
- `ai_assistant_screen.dart` + `ai_input_bar.dart`/`ai_input_area.dart` — chat entry point.
- `order_creator_agent.dart`/`order_creator_controller.dart` — the AI order-creation flow.
- `measurement_extractor.dart`, `measurement_structurer.dart`, `money_extractor.dart` — LLM-based extraction from dictated text.
- STT/TTS: `gemini_stt_provider.dart`, `sarvam_stt_provider.dart`, `sarvam_streaming_stt_provider.dart`, `sarvam_streaming_tts_provider.dart`, `transcription_service.dart`, `streaming_transcription_service.dart` — anything that turns voice into text or text into voice costs money and needs the same gate; plain local audio *recording* (`audio_recording_service.dart`) does not, since it's not an AI call.
- `ai_query_dispatcher.dart` and its handlers (`raw_sql_handler.dart` etc.) — the NL-to-SQL feature is Gemini-backed too.

## Phase 1b — Streaming STT/TTS proxy (the part that isn't a simple HTTP call)

`sarvam_streaming_stt_provider.dart` and `sarvam_streaming_tts_provider.dart` currently open a **raw client-side WebSocket straight to Sarvam**, authenticated with `SARVAM_API_KEY` from `.env`, and track spend by counting audio bytes locally (`_totalAudioBytes` in the STT provider). That doesn't fit the request/response proxy from Phase 1 — a mid-conversation voice session can run for minutes, and cost accrues continuously, not as one lump sum at the end. It needs its own design:

- **The client must never hold the Sarvam key.** So the WebSocket has to terminate at your backend, not at Sarvam directly. Concretely: a Cloud Run service (Cloud Functions don't do long-lived WebSockets well) that the Flutter app connects to, authenticated with the Firebase ID token on connect; that service opens the actual upstream WebSocket to Sarvam using the real key and pipes audio/transcript frames through in both directions. `SarvamStreamingSttProvider`/`SarvamStreamingTtsProvider` become thin clients pointed at your Cloud Run URL instead of `wss://api.sarvam.ai/...` — the framing/protocol logic in those two files is otherwise reusable.
- **Pre-flight gate, same as batch calls**: on connect, the proxy checks `walletBalanceMinor > 0` before opening the upstream Sarvam socket at all. Empty wallet → reject the connection immediately with a typed close code the client maps to the same "top up" UI as the batch-call `WALLET_EMPTY` error, so `AiFeatureGate` doesn't need to know STT/TTS is a stream internally — it's still just "can this AI feature run right now."
- **Mid-stream cutoff**: since cost accrues continuously, the proxy needs a periodic check *during* the session, not just at connect — e.g. every N seconds of audio (or every K bytes, matching the existing `_totalAudioBytes` counting granularity), compute cost-so-far from actual bytes/characters and deduct from the wallet transactionally. If a deduction would take the balance below zero, the proxy closes the socket cleanly (a distinct close code, e.g. `WALLET_DEPLETED_MID_SESSION`) rather than continuing to accrue debt. Deducting incrementally rather than only at session end also means a dropped connection (app killed, network loss) can't leave a large unbilled tail — worst case is under-billing by less than one check interval.
- **Client-side handling of a mid-stream cutoff**: `StreamingSttEvent`/the TTS equivalent need a new event variant (e.g. `walletDepleted`) alongside the existing `connected`/etc. events in `streaming_stt_provider.dart`/`streaming_tts_provider.dart`, so `live_voice_input_controller.dart`/`streaming_voice_input.dart`/`streaming_voice_bottom_sheet.dart` can catch it and show "AI voice input stopped — wallet empty" instead of treating it as a generic connection error.
- **Reconnect behavior**: `WalletState` should refuse to let the UI re-open a streaming session while `isEmpty` is true (checked client-side before even attempting `connect()`), so a flaky-network auto-reconnect doesn't repeatedly hit the backend just to be told no.

## Phase 3 — UI surfaces

This directly answers "how do balance/low-balance/empty states show up":

1. **Persistent balance indicator** — small chip (e.g. "₹32 left") in the app bar or home tab, in the same visual language as `usage_kpi_row.dart`/`kpi_card.dart`. Tapping it opens the top-up screen. Always visible when there's a balance; this is the steady-state, not a warning.
2. **Low-balance banner** — same component shape as [reader_mode_banner.dart](app/lib/presentation/widgets/sync/reader_mode_banner.dart) (slim strip, self-hides when not applicable), shown when `WalletState.isLow`, e.g. "Low balance (₹8) — top up soon," dismissible per-session but reappearing next launch until resolved.
3. **Empty-wallet state** — this is the one that must be impossible to miss and impossible to bypass:
   - Every `AiFeatureGate`-wrapped control (mic buttons, "Ask AI" input, order-creator entry point) switches to a disabled visual state (greyed icon, "Top up to use AI" label) — **the button itself must not be tappable**, not just show an error after tapping, since a tap that reaches the network only to bounce is a worse experience and wastes a request.
   - A blocking-but-dismissible sheet/dialog the first time balance hits zero in a session: "AI features are paused — top up your wallet to continue," with a direct button into the top-up screen. Don't repeat this every single tap once dismissed; the persistently-disabled buttons already communicate the state.
   - Non-AI features (customer/order/measurement CRUD, local search, sync) are **completely unaffected** — this is the same "gate one feature area, leave the rest of the app alone" pattern `WriterOnly` already uses for reader mode, just gating on wallet state instead of sync role.
4. **Top-up screen** (`lib/screens/`, e.g. `wallet_topup_screen.dart`) — amount picker, Razorpay/Cashfree checkout SDK invocation, success/failure states, and a spend-history list reusing the visual pattern of [usage_event_tile.dart](app/lib/presentation/widgets/usage/usage_event_tile.dart) but sourced from the server-side `usage_ledger` instead of (or merged with) the local one.
5. Extend `developer_screen.dart`/settings with a wallet debug/admin view during development, the same way `ai_usage_screen.dart` already exists for the local usage dashboard.

## Phase 4 — Payment integration

- Razorpay (or Cashfree) Flutter SDK for checkout UI; backend creates the order, verifies the payment signature/webhook server-side, credits `walletBalanceMinor` transactionally — never trust a client-reported "payment succeeded."
- Idempotency: webhook delivery can retry — key the credit operation on the payment/order id so a duplicate webhook can't double-credit.

## Phase 5 — Play Store readiness (unblocked once phase 1 ships)

- Real API keys are now server-side only — resolves the key-exposure gap for public distribution.
- Data-safety form must now also disclose payment data handling (even though the payment provider, not you, holds card/UPI details).
- Everything else from the earlier Play Store checklist (signing, closed testing track, privacy policy hosting) is independent of this plan and can proceed in parallel.

## Deferred / explicitly out of scope for now

- Markup on LLM cost — architecture supports flipping it on later (phase 1's deduction step) without a redesign; not enabling it yet per your call.
- Passing Firestore/infra cost to users — revisit if it stops being negligible.
- Multi-staff-per-shop accounts — reopens concurrent-write problems the single-writer sync design deliberately avoided; separate design effort if ever needed.
- Subscriptions/autopay — deliberately not built; wallet only.
