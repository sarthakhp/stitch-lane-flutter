<!-- Play Store publishing -->
## Play Store publishing

Publishing this app (Stitch Genie, package `com.stitchlane.app`) to the Play Store started 2026-09. Full plans, read the relevant one for detail rather than re-deriving:

- [PLAY_STORE_FAST_LAUNCH_PLAN.md](PLAY_STORE_FAST_LAUNCH_PLAN.md) — minimum to publish now; what's deferred to later updates.
- [PLAY_STORE_LAUNCH_PLAN.md](PLAY_STORE_LAUNCH_PLAN.md) — the full multi-track plan (accounts, security, legal, quality, listing, support) this app eventually needs.
- [WALLET_BILLING_IMPLEMENTATION_PLAN.md](WALLET_BILLING_IMPLEMENTATION_PLAN.md) — prepaid AI-usage wallet design (no markup yet, no subscriptions), including the streaming STT/TTS proxy design.

Current status: published to the **internal testing** track only, not yet in closed testing or production.

Gotchas already hit once — don't rediscover these:

- **Play Console wants an `.aab` (App Bundle), not `.apk`**, for any track. CI (`.github/workflows/build-release-apk.yml`) still only builds/publishes APKs to GitHub Releases (fine for ad-hoc sharing); a separate local `flutter build appbundle --release` is needed for Play uploads.
- **Play App Signing re-signs the app with its own certificate**, distinct from the upload keystore CI signs with. Any Gemini API key restriction by Android app (package + SHA-1) needs **both** SHA-1 fingerprints added — the upload key's (Cloud Console → get it via `keytool` against the CI keystore) and the Play App Signing key's (Play Console → Protected with Play → Play Store protection → Manage Play app signing). Missing the second one breaks the app for anyone who installed through Play, while local/CI-signed builds still work — a confusing partial failure if you don't know to check both.
- **Firebase Crashlytics Gradle plugin 3.x requires `google-services` plugin ≥4.4.1** — bumping `firebase_crashlytics` without checking `android/settings.gradle`'s pinned `com.google.gms.google-services` version breaks the AAB/APK build with an opaque R8/task-graph error.

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes_tool` or `query_graph_tool` instead of Grep
- **Understanding impact**: `get_impact_radius_tool` instead of manually tracing imports
- **Code review**: `detect_changes_tool` + `get_review_context_tool` instead of reading entire files
- **Finding relationships**: `query_graph_tool` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview_tool` + `list_communities_tool`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
| ------ | ---------- |
| `detect_changes_tool` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context_tool` | Need source snippets for review — token-efficient |
| `get_impact_radius_tool` | Understanding blast radius of a change |
| `get_affected_flows_tool` | Finding which execution paths are impacted |
| `query_graph_tool` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes_tool` | Finding functions/classes by name or keyword |
| `get_architecture_overview_tool` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes_tool` for code review.
3. Use `get_affected_flows_tool` to understand impact.
4. Use `query_graph_tool` pattern="tests_for" to check coverage.
