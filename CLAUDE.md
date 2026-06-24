# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Repository context

This repo is the **Article A** target: bring the existing [MVVMC](https://github.com/shinrenpan/MVVMC) iOS architecture to Android via [Skip.tools](https://skip.tools), keeping iOS behaviour identical to baseline.

The core promise: **iOS architecture (M / VM / V / C separation, UIKit host pattern) stays untouched**. Cross-platform support is added by wrapping UIKit-specific files in `#if !SKIP` and providing a SwiftUI equivalent in the matching `#else` branch — never by refactoring the iOS-side architecture.

**What is allowed to change in feature code** (revised 2026-06-24, see Migration Log M5):
- ✅ Swift 6 concurrency fixes required by the toolchain (e.g. `nonisolated(unsafe)` on global associated-object keys).
- ✅ Skip-transpiler-friendly Swift style: e.g. lift nested leading-dot enums into an explicitly-typed `let` before passing them, so Skip can infer types.
- ✅ Wrapping iOS-only files in `#if !SKIP`.
- ❌ **Not allowed**: architectural refactors. M / VM / V / C boundaries, the HostController + AppRouter pattern, the `doAction` single-entry-point ViewModel shape — none of these may be reshaped.

| | |
|---|---|
| Baseline | MVVMC `v1.1.0` (commit `db9013d`) |
| Skip mode | Skip Lite (Swift → Kotlin/Compose) |
| Swift toolchain | swift-tools 6.1, Swift 6 language mode |
| iOS behaviour | Identical to baseline |
| Android substrate | Pure SwiftUI (via Skip transpilation) |

---

## Architecture rules — defer to the MVVMC main repo

M / VM / V / C layer rules **live in the [MVVMC main repo's CLAUDE.md](https://github.com/shinrenpan/MVVMC/blob/main/CLAUDE.md)** and are not duplicated here. The Claude Code skills in `.claude/skills/` (mvvmc-model, mvvmc-viewmodel, mvvmc-view, mvvmc-hostcontroller, etc.) are the canonical iOS-side specification and apply directly.

This repo only documents **Skip-specific deltas** on top of those rules.

---

## Skip adaptation rules

> 🚧 **To be filled in during implementation.**
>
> The Skip adaptation rules (which APIs need `#if !SKIP` guards, how `AppRouter` is mirrored on the Android side, how `SceneDelegate` deeplinks map to `.onOpenURL`, which Skip pattern rewrites are required, etc.) will be added here as the implementation progresses. Writing them speculatively before real transpiler feedback produces hollow rules that don't match reality.
>
> Reference: the sibling repo [MVVMR-Skip](https://github.com/shinrenpan/MVVMR-Skip) (private) has already captured Skip transpiler gotchas during its own pure-SwiftUI migration. Its `CLAUDE.md` "Skip Compatibility Rules" section is a useful starting point, but the MVVMC-Skip strategy (preserve UIKit on iOS) will surface a different set of issues.

---

## Sibling repos

- [`MVVMC`](https://github.com/shinrenpan/MVVMC) — iOS-only baseline (public)
- [`MVVMR-Skip`](https://github.com/shinrenpan/MVVMR-Skip) — pure-SwiftUI cross-platform variant; Article C target (private)
- `MVVMR` — pure-SwiftUI iOS-only evolution of MVVMC; Article B target (planned)

---

## Migration Log

A running journal of decisions and trade-offs made while bringing MVVMC to Skip. Each entry pairs the **commit** with the **why** — written for future Article-A reference and for any future Claude session picking up this repo cold.

> Convention: every commit message in this repo should include a `Why:` paragraph. The Migration Log is the curated narrative that survives even if commits get squashed/rebased.

### M0 — Baseline established (commit `db9013d`)
- **What**: Cloned from main MVVMC at v1.1.0, no modifications.
- **Why**: Same baseline as MVVMR-Skip so the two cross-platform strategies can be diffed apples-to-apples for Articles A & C.

### M1 — `mcp-server/` dropped (commit `ed232b0`)
- **What**: Removed the MCP server source tree.
- **Why**: The MCP server is the canonical MVVMC spec service; it lives only in the main MVVMC repo. Experiment forks (this repo, MVVMR-Skip) don't duplicate canonical infrastructure.

### M2 — Repo repositioned as Article A target (commit `0d17600`)
- **What**: README / README.en / CLAUDE.md rewritten to declare this repo's specific promise — "MVVMC + `#if SKIP`, iOS zero-change".
- **Why**: Avoid the trap MVVMR-Skip fell into (started as "MVVMC + Skip" but actually evolved into a different architecture). Stating the promise explicitly up front lets future commits be measured against it.

### M3 — Route B chosen for project layout (commit `49753a6`)
- **What**: Decided to migrate from `XcodeGen + Sources/Pages/` to the Skip Lite convention (`Package.swift` + `Sources/MVVMCSkipDemo/Pages/` + `Darwin/` + `Android/`). XcodeGen will be retired.
- **Why**: Skip transpiler assumes SPM as the source-of-truth. Running XcodeGen alongside SPM creates a dual-track that fights Skip's implicit expectations (the path MVVMR-Skip discovered the hard way before eventually retiring XcodeGen in its own Commit 3).
- **Scope clarification**: "iOS zero-change" applies to **feature code content** (M/VM/V/C `.swift` files in `Pages/`). Project scaffolding (`Package.swift`, `Skip.env`, `Darwin/`, `Android/`, `Project.xcworkspace`) is necessarily new. File **locations** may move; **contents** do not.

### M4 — `Package.swift` added as SPM source-of-truth (commit `5d5b9ec`)
- **What**: Added a minimal `Package.swift` (swift-tools 5.10, iOS 17) declaring one library target `MVVMCDemo` with `path: "Sources"` (excluding `App/Info.plist`) and a matching `MVVMCDemoTests` target at `Tests/`. Also gitignored `.swiftpm/`.
- **Why**: Step 1 of the Route B migration — prove SPM can see the existing iOS code without any content changes, before any Skip tooling enters the picture. Target name kept as `MVVMCDemo` (not yet `MVVMCSkipDemo`) so the existing `@testable import MVVMCDemo` in `Tests/` stays valid; the rename will happen together with the `git mv` to `Sources/MVVMCSkipDemo/` in Step 3.
- **Verification**: `swift build` alone fails (defaults to macOS SDK → `UIKit` missing), as expected. `xcodebuild -scheme MVVMCDemo -destination 'generic/platform=iOS Simulator' build` succeeds — `** BUILD SUCCEEDED **`. The temporarily-stashed empty `MVVMCDemo.xcodeproj` (only `contents.xcworkspacedata` is tracked; `project.pbxproj` is XcodeGen-generated and gitignored) needed to be moved aside during the build so xcodebuild would pick `Package.swift` instead of the broken project shell. The shell is restored and will be retired entirely in Step 4.

### M5 — Skip scaffold + policy revision (this commit)
- **What**:
  - Bumped `Package.swift` to swift-tools 6.1 (Swift 6 language mode default), library type `.dynamic`, added deps on `skip` 1.9.3+ and `skip-ui` 1.0.0+, plus `SkipUI` / `SkipTest` as target dependencies. **Plugin `skipstone` intentionally NOT yet bound to the targets** (see below).
  - Added `Skip.env` at repo root (`PRODUCT_NAME = MVVMCDemo`, bundle id `com.joe.mvvmc.demo`, `ANDROID_PACKAGE_NAME = com.joe.mvvmc.demo`). Module rename to `MVVMCSkipDemo` deferred to Step 3.
  - Added `Sources/Skip/skip.yml` declaring `mode: 'transpiled'`.
  - Fixed Swift 6 concurrency in `Sources/App/AppRouter.swift`: `private var appTransitionStyleKey` → `nonisolated(unsafe) private var appTransitionStyleKey`. Required by Swift 6 strict concurrency for global mutable storage backing `objc_getAssociatedObject` keys.
  - Revised the "iOS zero-change" promise in the top of this file: feature code may be edited for Swift 6 concurrency fixes and Skip-transpiler-friendly Swift style; architectural refactors remain forbidden.
- **Why — the discovery that drove the policy revision**: The original Plan assumed Step 2 could "add the Skip plugin" as a passive wiring step. In reality the `skipstone` plugin is **eager**: once bound to a target, every `xcodebuild` triggers Kotlin transpilation, and transpilation surfaces real issues in the existing iOS code:
  1. Swift 6 strict concurrency rejects bare global `var` (e.g. `appTransitionStyleKey`).
  2. Kotlin forbids referencing local variables in `super.init(...)` calls (every HostController does this).
  3. Skip's type inference is weaker than Swift's and rejects nested leading-dot enums like `.apiResponse(.fetchUserDidFinish(.success(dto)))` — used by every ViewModel in the codebase.
  
  Issue (1) is a small, isolated fix. Issues (2) and (3) span the entire codebase. Sibling repo [MVVMR-Skip](https://github.com/shinrenpan/MVVMR-Skip) solved (3) by lifting nested enums into an explicitly-typed `let result: Result<...> = .success(dto)` before the outer call — the same fix is needed across MVVMC-Skip's ViewModels, but that touches every feature and belongs to Step 7's per-feature work, not to Step 2.
  
  **Decision**: defer plugin binding to Step 7 (where each feature is converted one commit at a time: wrap HostController in `#if !SKIP`, rewrite VM for Skip type inference, verify Skip transpiles that feature). Step 2 ships only as scaffolding: deps declared, env file present, `skip doctor` green, Swift 6 concurrency hole closed. iOS xcodebuild remains identical to M4 (still green).
  
  **Why the iOS-zero-change promise was relaxed**: forcing "zero feature code change" forced Swift 5 language mode (because `appTransitionStyleKey` violates Swift 6). That left the entire repo stuck on a previous-generation toolchain just to preserve a slogan, while every realistic Skip migration needs the same kind of pin-prick fixes anyway. Relaxing to "minimal, necessary fixes — architecture untouched" matches the work actually needed without losing the architectural promise that gives the article its thesis.
- **Verification**:
  - `xcodebuild -scheme MVVMCDemo -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation build` → `** BUILD SUCCEEDED **`.
  - `skip doctor` → `Skip 1.9.3 doctor succeeded`.
  - The plugin wiring + per-feature `#if !SKIP` wrapping + ViewModel rewrites that we explored mid-session were intentionally reverted; the in-tree changes here are only the scaffold + the one concurrency fix.

---

## Next Steps (start here in the next session)

Open this repo cold and these are the steps in order. Each step is one commit with a `Why:` paragraph.

1. ~~**Add `Package.swift` pointing at existing `Sources/` paths**~~ ✅ Done in M4.
2. ~~**Add Skip scaffold** — `Skip.env`, `Sources/Skip/skip.yml`, swift-tools 6.1, skip / skip-ui deps. Plugin binding deferred to Step 7.~~ ✅ Done in M5.
3. **Restructure `Sources/Pages/` → `Sources/MVVMCSkipDemo/Pages/`** — `git mv` plus the matching target rename in `Package.swift`, `Skip.env`'s `PRODUCT_NAME`, and `@testable import MVVMCDemo` in `Tests/`. Treated as scaffolding rename — no feature-code semantics change.
4. **Add `Darwin/` shell** — `Info.plist`, `Main.swift` (`@main` entry that wraps `SceneDelegate` for iOS), Assets, `MVVMCSkipDemo.xcconfig`, `MVVMCSkipDemo.xcodeproj`. Retire the broken `MVVMCDemo.xcodeproj` shell + `project.yml`.
5. **Add `Project.xcworkspace`** at repo root referencing `Package.swift` + `Darwin/MVVMCSkipDemo.xcodeproj`. Verify `skip app launch --ios` boots a real device/simulator build with the actual UIKit app running.
6. **Add `Android/` shell** — Gradle scaffolding, `Main.kt` entry, `settings.gradle.kts`. At this point `skip app launch --android` will not yet succeed (plugin still unbound); that's expected.
7. **First real Skip adaptation — bind plugin + convert one feature end-to-end**:
   1. Bind the `skipstone` plugin to the `MVVMCDemo` target in `Package.swift`.
   2. Wrap `AppDelegate`, `SceneDelegate`, `AppRouter`, `Deeplink`, and *all* `*HostController.swift` files in `#if !SKIP` (mechanical file-level wrap; no logic edits).
   3. Pick the smallest feature (likely `Settings`) and convert its ViewModel to Skip-friendly Swift style: lift nested leading-dot enums into explicitly-typed `let` bindings (see `MVVMR-Skip/.../UserDetailViewModel.swift` for the pattern).
   4. Add an Android-side entry: a SwiftUI shell (`@main` or equivalent) + a router stub that mounts the `Settings` view.
   5. `skip app launch --android` should now reach a running Android app showing the Settings screen.
8. **Per-feature Skip conversion** — one commit per feature: rewrite that feature's ViewModel for Skip type inference, ensure its View transpiles, verify Android renders it. Repeat for `Profile`, `PostList`, `PostFilter`, `PostDetail`, `UserDetail` in roughly that order of complexity.

Each step's `Why:` and any gotchas land back in the Migration Log above as they happen.
