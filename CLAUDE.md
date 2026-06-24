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

> **Conventions**:
> - Every commit message in this repo includes a `Why:` paragraph. The Migration Log is the curated narrative that survives even if commits get squashed/rebased.
> - Each entry has up to four sub-sections:
>   - **What** — the diff in plain English.
>   - **Why** — the reasoning that justifies the diff.
>   - **Journey** — only present when the path to the diff was non-trivial. A beat-by-beat narrative (premise → obstacles → forks → resolution), written as article-ready prose. Skip this section for mechanical steps where the journey wouldn't carry a paragraph.
>   - **Verification** — the proof that "done" means done.

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
- **Journey** (the path from "Step 2 is two lines" to what actually shipped — article material):

  *Premise.* The original Next Steps line read: *"Add Skip plugin to `Package.swift` + create `Skip.env`. Run `skip doctor`."* Two lines. A passive wiring step. The plan author (also me, in M3) expected to land it in a single small commit.

  *First wall — toolchain disagreement.* `swift build` immediately failed: no `UIKit`. Of course — SPM defaults to the macOS SDK on a Mac host, and Swift Package Manager has no native cross-compile story for iOS. Pivoted to `xcodebuild -destination 'generic/platform=iOS Simulator'`. iOS green. Annoying but expected — this is the *price of using SPM as source-of-truth* on a UIKit codebase, and it shows up in every commit that doesn't go through Xcode.

  *Second wall — the empty xcodeproj shell.* `xcodebuild` insisted on opening `MVVMCDemo.xcodeproj` over `Package.swift`. But the xcodeproj is an XcodeGen artefact: only `contents.xcworkspacedata` is tracked, `project.pbxproj` is gitignored. Locally the shell is broken. Workaround: temporarily move the shell aside before `xcodebuild`, restore after. Ugly, but transient — Step 4 retires the shell entirely. *Lesson for the article: dual-track (XcodeGen + SPM) doesn't fade out cleanly; you live with one ugly workaround until you commit to the SPM-only side.*

  *Third wall — `skipstone` is eager.* Wired the plugin. Build instantly failed in a new place: the plugin had **already started transpiling Swift to Kotlin during the iOS build**. Earlier mental model was wrong — the plugin isn't a passive declaration that activates only on `skip app launch --android`. It binds itself to the build graph and runs every time the target compiles. *This is the single biggest discovery of Step 2.* It rewrites how every subsequent step has to be planned: the question is no longer "when does Skip code start being needed" but "when does the plugin start being allowed to look at the codebase."

  *The Swift 5 reflex (and why it was wrong).* First Skip-triggered error was on `AppRouter.swift`'s `private var appTransitionStyleKey: UInt8 = 0` — Swift 6 strict concurrency rejects global `var`. My reflex was to set `swiftLanguageVersions: [.v5]` in `Package.swift` to preserve the old code unchanged. *The user pushed back here* — "用 Swift 6, iOS feature code 零改太嚴格了". That intervention pivoted the whole policy: the slogan "zero iOS change" was forcing the entire repo onto a previous-generation toolchain just to avoid a one-line `nonisolated(unsafe)`. Relaxed the policy to *"architecture zero-change; minimal, necessary content fixes allowed"*. Reverted the Swift 5 pin. Fixed `appTransitionStyleKey` properly with `nonisolated(unsafe)`. *Lesson: a "zero-change" promise that requires a toolchain time-machine isn't an architectural promise — it's a cargo-cult promise. The real promise is the architecture, not the bytes.*

  *The big-bang attempt.* With the policy relaxed and the plugin still bound, tried to push through: wrap all 10 iOS-only files (4 App-layer, 6 HostControllers) in `#if !SKIP`, fix the concurrency hole, rebuild. iOS went green. Skip plugin made it further into the codebase — and then crashed on ViewModels with `Skip is unable to determine the owning type for member 'success'`. The offending pattern is *every* MVVMC ViewModel's API response shape: `await doAction(.apiResponse(.fetchUserDidFinish(.success(dto))))`. Nested leading-dot enums. Swift compiler handles them fine through bidirectional type inference; Skip's transpiler doesn't. *Hit a wall that isn't 10 files — it's the entire codebase.*

  *The MVVMR-Skip evidence.* Looked at the sibling repo. Same author, same VM shape, same problem — solved by lifting the nested enum into an explicitly-typed local before the outer call:
  ```swift
  let result: Result<UserDTO, APIError> = .success(dto)
  await doAction(.apiResponse(.fetchUserDidFinish(result)))
  ```
  Two lines instead of one. Works. But this fix is needed *per call site*, in every ViewModel. It's not a Step 2 fix — it's a Step 7 fix, and it scales linearly with feature count.

  *The retreat.* Reverted the 10 `#if !SKIP` wraps. Unbound the plugin. Kept the policy revision (Swift 6 + Skip-friendly style allowed). Kept the `AppRouter` concurrency fix (independently correct, Swift 6 needs it). Kept `Skip.env`, `skip.yml`, and the new dependencies. Re-shaped Step 7 from "wrap AppRouter, one screen renders" into "bind plugin + wrap *all* iOS-only files + convert one feature end-to-end + render on Android" — a heavier step but with a clearer success criterion.

  *Resolution.* Step 2 ships as scaffolding: Skip declared as a dependency, `Skip.env` present, `skip doctor` green, Swift 6 concurrency hole closed, iOS xcodebuild still identical to M4. **No Kotlin code has been generated yet.** Skip is "in the project" but hasn't been "given the project to read." That handover is Step 7.

  *Why this story matters for Article A.* The article isn't "how I ran `skip init` and got Android." It's "how an existing UIKit + MVVMC iOS app meets Skip's expectations." That meeting is genuinely uncomfortable: dual-build-tools, eager transpilation, type-inference asymmetry, a slogan that turns into a toolchain straitjacket. Step 2's "two-line job" expanding into a policy revision is itself the lesson — and the reason a sibling repo (MVVMR-Skip) chose to abandon UIKit entirely rather than fight this. MVVMC-Skip's bet is that the fight is worth it. M5 is the first proof of how it's fought.

- **Verification**:
  - `xcodebuild -scheme MVVMCDemo -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation build` → `** BUILD SUCCEEDED **`.
  - `skip doctor` → `Skip 1.9.3 doctor succeeded`.
  - The plugin wiring + per-feature `#if !SKIP` wrapping + ViewModel rewrites that we explored mid-session were intentionally reverted; the in-tree changes here are only the scaffold + the one concurrency fix.

### M6 — Module rename to `MVVMCSkipDemo` + Skip-canonical source layout (commit `2bbcfdf`)
- **What**:
  - `git mv Sources/{App,Pages,Shared,Skip} Sources/MVVMCSkipDemo/` — every existing source file moved one directory deeper. No file content edits.
  - `Package.swift`: target / product / library names `MVVMCDemo` → `MVVMCSkipDemo`; target `path` `Sources` → `Sources/MVVMCSkipDemo`.
  - `Skip.env`: `PRODUCT_NAME` and reference comment updated to `MVVMCSkipDemo`.
  - `Tests/*.swift`: `@testable import MVVMCDemo` → `@testable import MVVMCSkipDemo` (3 files).
- **Why**: Skip Lite's transpiler keys off the SPM target's `path`, and its plugin looks for `<targetPath>/Skip/skip.yml` relative to that path. With the source tree at `Sources/`, the implicit module name didn't match the eventual product name (`MVVMCSkipDemo`), and a future binding of the `skipstone` plugin would have looked for `Sources/Skip/skip.yml` — which is awkward because it sits next to feature folders rather than belonging to one module. Promoting everything into `Sources/MVVMCSkipDemo/` makes (a) the SPM module name, (b) the on-disk folder name, (c) `Skip.env`'s `PRODUCT_NAME`, and (d) `@testable import` all agree — which is what Skip's tooling assumes when it later generates `Darwin/MVVMCSkipDemo.xcconfig` and `Android/settings.gradle.kts` from `Skip.env`. This step is pure scaffolding: zero feature-code edits, every file's git history preserved through `git mv`.
- **Verification**: `xcodebuild -scheme MVVMCSkipDemo -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation build` → `** BUILD SUCCEEDED **`. (Note: scheme name auto-updated by SPM to track the renamed product; no manual scheme edit needed.)

### M7 — `Darwin/` iOS app shell + retire XcodeGen (commit `ebab12a`)
- **What**:
  - Added `Darwin/` populated from a freshly-scaffolded `skip init --transpiled-app … MVVMCSkipDemo` probe:
    - `Darwin/MVVMCSkipDemo.xcodeproj/` (real, working pbxproj — references the local SPM package at `..`)
    - `Darwin/MVVMCSkipDemo.xcconfig` (adapted: removed `INFOPLIST_KEY_UIApplicationSceneManifest_Generation` and `INFOPLIST_KEY_UILaunchScreen_Generation`, set `SKIP_ACTION = none` until Step 6 builds `Android/`)
    - `Darwin/Info.plist` (lifted from the old XcodeGen-managed plist — keeps `UIApplicationSceneManifest` pointing at `MVVMCSkipDemo.SceneDelegate` and the `mvvmc://` URL scheme)
    - `Darwin/Entitlements.plist`, `Darwin/Assets.xcassets/`, `Darwin/InfoPlist.xcstrings`
    - `Darwin/Sources/Main.swift` — rewritten from Skip's canonical SwiftUI `@main struct AppMain: App` into a 7-line `UIApplicationMain` shim that boots our existing UIKit `AppDelegate`. This is the keystone of the "preserve UIKit on iOS" promise.
  - `Sources/MVVMCSkipDemo/App/AppDelegate.swift`: dropped `@main`, made the class `public` so `Darwin/Sources/Main.swift` can pass `AppDelegate.self` to `UIApplicationMain`. Added explicit `public override init()`.
  - `Sources/MVVMCSkipDemo/App/SceneDelegate.swift`: made the class `public` (so Info.plist's string lookup `MVVMCSkipDemo.SceneDelegate` resolves across the library boundary) and propagated `public` to its `UISceneDelegate` / `UNUserNotificationCenterDelegate` protocol methods that Swift required.
  - `Darwin/Info.plist`: changed `UISceneDelegateClassName` from `$(PRODUCT_MODULE_NAME).SceneDelegate` to a hard-coded `MVVMCSkipDemo.SceneDelegate`, because the xcconfig sets `PRODUCT_MODULE_NAME = $(PRODUCT_NAME:c99extidentifier)App` (i.e. `MVVMCSkipDemoApp`) for the app target's Swift module — that's NOT where `SceneDelegate` lives. `SceneDelegate` lives in the library, whose module name is `MVVMCSkipDemo`.
  - Deleted `Sources/MVVMCSkipDemo/App/Info.plist` (moved into `Darwin/`).
  - `Package.swift`: removed the now-stale `exclude: ["App/Info.plist"]`.
  - Retired `MVVMCDemo.xcodeproj/` (the broken XcodeGen shell) and `project.yml` (the XcodeGen manifest) — `git rm`.
- **Why — the chosen route (Path A) and what it preserves**: Step 4 had to resolve the unavoidable "where does `@main` live?" question. iOS launches by looking for a `main` symbol in the app target's own executable — a `@main` inside a linked framework is not reachable as the app entry point. So `@main` had to leave the SPM library. Three routes were considered:
  - **Path A (chosen)** — keep almost everything in the SPM library; write a 7-line `Darwin/Sources/Main.swift` that calls `UIApplicationMain(…, AppDelegate.self)` so the existing `AppDelegate` and `SceneDelegate` remain the entry path. Cost: drop `@main` from `AppDelegate`, mark a handful of types `public`.
  - **Path B** — adopt Skip's canonical SwiftUI `@main struct AppMain: App` and adapt `AppDelegate` into a `UIApplicationDelegateAdaptor` callback proxy. Cost: the UIKit lifecycle gets wrapped by SwiftUI lifecycle — the iOS architecture changes shape at its entry point.
  - **Path E** — physically move all UIKit-only files (`AppDelegate`, `SceneDelegate`, `AppRouter`, `Deeplink`, six `*HostController.swift`) out of the library into `Darwin/Sources/`. Cost: dozens of `public` modifiers on Views / ViewModels / Routers, because the moved HostControllers now live in a different module and must reach back through the library's public surface.
  
  Path A wins on the *iOS-side* architectural-preservation axis (the entry chain is unchanged: `UIApplicationMain` → `AppDelegate` → `SceneDelegate` → `UITabBarController` → HostControllers, exactly as in the MVVMC baseline) AND on the *change-set size* axis (about 20 lines of edits vs Path E's dozens of access-modifier additions). Path B was rejected because rewriting the lifecycle entry point goes beyond the "minimal, necessary" budget set in M5.
- **Verification**: `xcodebuild -project Darwin/MVVMCSkipDemo.xcodeproj -scheme "MVVMCSkipDemo App" -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation build` → **`** BUILD SUCCEEDED **`**. This is the **first iOS `.app` bundle ever produced by this repo's Skip-aware layout** — previous green builds were the library framework, not a launchable app.

### M8 — `Project.xcworkspace` at repo root + `skip app launch --ios` verified (commit `7558842`)
- **What**:
  - Added `Project.xcworkspace/contents.xcworkspacedata` at the repo root, with a single `FileRef` pointing at `Darwin/MVVMCSkipDemo.xcodeproj`. The xcodeproj already references the local SPM package at `..`, so the workspace transitively sees `Package.swift` without a separate `FileRef`.
  - `.gitignore` cleanup: removed the now-obsolete `*.xcodeproj/project.pbxproj` entry (XcodeGen-era — it would silently ignore the real, tracked `Darwin/MVVMCSkipDemo.xcodeproj/project.pbxproj` if someone re-cloned).
- **Why**: Provides a single, canonical "open this" entry for both the Xcode IDE and the `skip` CLI. Without it, Xcode users would have to know to open `Darwin/MVVMCSkipDemo.xcodeproj` (a buried path) and the `skip` CLI would need explicit `-workspace` / `-project` flags. With the workspace at repo root, `open Project.xcworkspace` and `skip app launch --ios` both Just Work.
- **Verification**:
  - `xcodebuild -workspace Project.xcworkspace -scheme "MVVMCSkipDemo App" -destination 'generic/platform=iOS Simulator' build` → `** BUILD SUCCEEDED **`.
  - **`skip app launch --ios --plain` → `[✓] Launch Skip app succeeded in 2.6s`**.
  - `xcrun simctl listapps booted` confirms `com.joe.mvvmc.demo` is installed on the booted iPhone 17 simulator with a real `.app` bundle.
  - Simulator screenshot confirms the app renders the existing MVVMC `PostList` screen with `Posts` / `Profile` tab bar — i.e. `AppDelegate → SceneDelegate → UITabBarController → UINavigationController → PostListHostController → PostListView` chain works end-to-end through the new SPM-as-source-of-truth layout. The iOS-side behaviour is identical to the MVVMC baseline.

### M9 — `Android/` shell + expected-failure verification (commit `1ba78fa` + `6e6dcb1`)
- **What**:
  - Copied the Android/ scaffold from a fresh `skip init --transpiled-app MVVMCSkipDemo` probe: `app/build.gradle.kts`, `app/src/main/AndroidManifest.xml`, `app/src/main/kotlin/Main.kt` (the Skip-canonical `AndroidAppMain` + `MainActivity`), `app/src/main/res/mipmap-*` launcher icons, `gradle/wrapper/gradle-wrapper.properties`, `gradle.properties`, `settings.gradle.kts`. Dropped `fastlane/`.
  - Updated `Darwin/MVVMCSkipDemo.xcconfig` comment: `SKIP_ACTION` stays `none` until Step 7 (plugin binding + first-feature conversion), not Step 6 as the previous comment claimed. The reason is now precise: with the plugin unbound, no transpiled Kotlin module exists for `MVVMCSkipDemo`, so `gradle launchDebug` would fail mid-build, not at startup.
- **Why**: Android needs a real `app/` Gradle subproject with `Main.kt`, manifest, and launcher icons before Skip's `skip-plugin` can register and run the transpiled module against it. Putting this in place now (rather than bundling with Step 7) keeps the next commit's diff focused on the plugin-binding + ViewModel-rewriting story rather than mixing in pure Gradle scaffolding.
- **Verification**:
  - `xcodebuild -workspace Project.xcworkspace -scheme "MVVMCSkipDemo App" -destination 'generic/platform=iOS Simulator' build` → `** BUILD SUCCEEDED **` (iOS path unchanged).
  - `cd Android && gradle :app:assembleDebug` → fails with the expected `e: Could not locate transpiled module for MVVMCSkipDemo in .../.build/plugins/outputs`. This is the exact failure mode the original Plan predicted for "skip app launch --android" at this stage: shell present, gradle invokable, blocked only on the missing Skip-plugin output. **This failure is the start signal for Step 7.**
  - `skip app launch --android` *does not yet* exercise this code path because `SKIP_ACTION=none` short-circuits the iOS-xcodebuild's gradle phase to a noop. The honest "Android does not yet build" demonstration comes from running gradle directly, as documented above.

### M10 — Step 7a: bind `skipstone` plugin to the target (commit `fa063a9`)
- **What**: `Package.swift` now binds `plugins: [.plugin(name: "skipstone", package: "skip")]` to both the `MVVMCSkipDemo` library target and the `MVVMCSkipDemoTests` test target. Removed the previous deferral comment ("intentionally not yet bound… see M5"). No other code touched.
- **Why**: iOS xcodebuild is intentionally allowed to go red in this commit. The point of 7a is to let Skip's transpiler look at the codebase for the first time, and use **what it complains about first** to set the agenda for 7b/7c/7d. Binding-without-fixing is a deliberate diagnostic step.
- **Journey** — what we actually saw, vs. what M5 predicted:

  *Prediction (M5).* M5's Journey listed three classes of issue Skip would hit when given the codebase: Swift 6 strict concurrency, Kotlin constructor delegation, Skip's weaker type inference on nested leading-dot enums. M5 framed this as "an avalanche", and on that basis I deferred the plugin binding to a later step.

  *Reality (M10).* `skipstone` is **fail-fast**: it reports the *first* error and stops. So binding the plugin doesn't produce an avalanche — it produces exactly one error per build, with the rest of the codebase un-attempted.

  *The first error* was, alphabetically by file path, `Sources/MVVMCSkipDemo/Pages/UserDetail/UserDetailHostController.swift:10:52`:
  ```
  In Kotlin, delegating calls to 'self' or 'super' constructors can not use
  local variables other than the parameters passed to this constructor
  ```
  pointing at the `viewModel` local being passed into `super.init(rootView:)`. This is exactly M5's "issue (2)" — and it's also exactly the kind of thing 7b's `#if !SKIP` wrapping will *invisibilize*, not fix.

  *What this changes for the rest of Step 7.* The plan stays the same, but the framing improves. Each sub-step now has a precise "what error frontier moves to next" narrative beat:
  - 7b — wrap all `*HostController.swift` + UIKit-only `App/*.swift` files in `#if !SKIP`. The HostController-class errors disappear; the next frontier should be the VM-layer leading-dot enum issues (M5's "issue (3)").
  - 7c — rewrite Settings VM for Skip-friendly type inference; that feature transpiles clean.
  - 7d — Android root view + `skip app launch --android` → first Android render.

  *Why this is good news for the article.* "Avalanche" was a richer image, but fail-fast is a more honest one. Skip's diagnostic shape mirrors how a careful engineer would attack the same codebase — peel one onion layer at a time. The article can lean on this: instead of needing to triage a wall of errors, you watch Skip walk through the codebase with you, surfacing the next issue once the current one is out of the way.

- **Verification**:
  - `xcodebuild … build` → **`** BUILD FAILED **`**. Failure is in the `Skip MVVMCSkipDemo` custom build task; `exit=65`.
  - `grep "error:" /tmp/step7a-build.log | sort -u` → exactly **1** distinct error, at `UserDetailHostController.swift:10:52`. (Compare to a hypothetical avalanche: dozens of unique errors.)
  - iOS app target therefore does not produce a runnable `.app` in this commit. This is the only red commit in the chain; 7b restores green.

### M11 — Step 7b: wrap iOS-only files in `#if !SKIP` (commit `71b9284`)
- **What**: Top-and-tail wrapped these 10 files with `#if !SKIP` / `#endif`. No content changes inside, no logic edits.
  - `Sources/MVVMCSkipDemo/App/AppDelegate.swift`
  - `Sources/MVVMCSkipDemo/App/AppRouter.swift`
  - `Sources/MVVMCSkipDemo/App/Deeplink.swift`
  - `Sources/MVVMCSkipDemo/App/SceneDelegate.swift`
  - `Sources/MVVMCSkipDemo/Pages/{PostDetail,PostFilter,PostList,Profile,Settings,UserDetail}/<Feature>HostController.swift`
- **Why**: Make UIKit-touching files invisible to Skip's transpiler. These files have legitimate iOS-only patterns (UIKit class inheritance, `UIApplicationDelegate` conformance, `super.init(rootView:)` calls that reference local variables) that have no Kotlin equivalent — they shouldn't be transpiled, they should be excluded. `#if !SKIP` is the Skip-canonical way to do that without moving files around.
- **Journey** — the frontier moves, but not to where M5 predicted:

  *Prediction (M5).* "Wrapping UIKit-only files should leave only the VM-layer `.success(dto)` leading-dot-enum issues for Skip to complain about."

  *Reality (M11).* HostController constructor-delegation errors are gone (correct prediction). But the *next* error frontier isn't in a ViewModel — it's in a **View**:
  ```
  Sources/MVVMCSkipDemo/Pages/UserDetail/UserDetailView.swift:9:48:
  error: Kotlin does not support where conditions in case and catch matches.
  Consider using an if statement within the case or catch body
  ```
  The offending pattern is the SwiftUI-idiomatic `switch` with a guard:
  ```swift
  switch viewModel.state.api.fetchUser {
  case .loading where viewModel.state.user == nil:
      ProgressView()
  ...
  }
  ```
  Swift's pattern-matching `case … where` has no direct Kotlin equivalent. The fix per Skip's hint is to drop the `where` and put the condition inside the case body as an `if`.

  *Why M5's prediction was incomplete.* M5 had only run the plugin briefly and only seen errors in `UserDetailViewModel`. It generalized that into "VM-layer is the frontier." In reality each layer can have its own Skip-incompatible patterns — Views have `case … where`, ViewModels have nested leading-dot enums, HostControllers have constructor delegation. **Skip's transpile gauntlet is wider than one layer.**

  *What this changes for 7c.* The original plan ("rewrite Settings VM, watch Settings transpile clean") was based on the assumption that the only obstacles are VM-layer ones in features other than Settings. Now we know: Skip is **fail-fast across the whole module**, so it never reaches Settings's VM until it gets past every issue that appears alphabetically earlier — including `UserDetailView`. So 7c is no longer "rewrite Settings". It's "rewrite issues in the order Skip surfaces them, until the entire module transpiles clean." That's a longer sub-step than originally planned.

  *Side note on iOS xcodebuild.* iOS is still red in 7b. The `#if !SKIP` wrap removes the input that broke Skip's transpile in 7a, but Skip's gauntlet is now blocked by the next issue (`UserDetailView`'s `case where`) before the plugin task can finish — so the build-tool plugin task still fails and the iOS app target can't reach the link step. **iOS returns to green only when Skip's transpile of the whole module succeeds**, i.e. at the end of 7c. This is a clarification of the earlier promise "7b restores green" in M10 — wrong in retrospect, corrected here.

- **Verification**:
  - `xcodebuild … build` → still `** BUILD FAILED **`, exit 65.
  - `grep "error:" /tmp/step7b-build.log | sort -u` → exactly **1** distinct error, this time at `UserDetailView.swift:9:48` (`case where`), not at any `HostController.swift`.
  - The HostController family of errors is invisible to Skip — confirmed by `grep -l "HostController" /tmp/step7b-build.log` returning no transpile-error matches.

### M12 — Step 7c: run the Skip transpile gauntlet (commit `fdaaac1`)
- **What**: Fixed every Skip-incompatible Swift pattern in the order Skip surfaced them, until the entire `MVVMCSkipDemo` module transpiles to Kotlin without error. Three files touched:
  - `UserDetailView.swift` — rewrote `case .loading where viewModel.state.user == nil` into `case .loading` + `if let user = … else { ProgressView() }`. Semantics preserved (still falls back to displaying the cached user when reloading).
  - `UserDetailViewModel.swift` — at API call sites (`fetchUser`), lifted `.success(dto)` / `.failure(.message(…))` into explicitly-typed `let result: Result<UserDTO, APIError> = …`. In `handleAPIResponse`, split `case let .fetchUserDidFinish(.success(dto))` (nested destructuring in one `case`) into outer `case let .fetchUserDidFinish(result)` + inner `switch result`.
  - `PostListViewModel.swift` — same two transforms as `UserDetailViewModel`. Pattern is identical because both VMs follow MVVMC's `apiRequest` / `apiResponse` shape.
  - `PostListView.swift` — same `case .loading where posts.isEmpty` rewrite as `UserDetailView`. Plus a separate single-line `#if !SKIP` wrap around `.contentShape(Rectangle())` (modifier not yet implemented in SkipUI).
- **Why**: Three classes of Skip-incompatible Swift pattern existed in this codebase, in exactly two layers (V, VM). Each had a small, mechanical fix:
  1. `case … where` → move guard into case body as `if`.
  2. Nested leading-dot enum in call site → lift into explicitly-typed `let`.
  3. Nested case destructuring → outer match + inner `switch`.
  
  All three are well-documented Skip-friendly idioms (MVVMR-Skip uses the same shapes). None of them required architectural changes — they are syntactic accommodations to Kotlin's stricter grammar. The MVVMC architecture (M / VM / V / C, `doAction` single entry, `Router` enums, `@Observable` ViewModel) survived intact.
- **Journey** — the gauntlet as it actually ran:

  *The expected ordeal.* 7b's M11 entry warned that 7c would be "longer than originally planned" because Skip is fail-fast across the whole module — to make the article's target feature (Settings) transpile, every alphabetically-earlier file with Skip-incompatible patterns has to be fixed first.

  *The actual count.* Four rebuilds, four fixes:
  - **R1**: `UserDetailView.swift:9:48` — `case where` → if-in-body. ✅
  - **R2**: `UserDetailViewModel.swift` — five errors at lines 61 / 63 / 78 / 81, two patterns (lifted enum + split nested case). ✅
  - **R3**: `PostListViewModel.swift` — same two patterns as R2. Five errors, same fix shape. ✅
  - **R4**: `PostListView.swift:9` (`case where`) + `:62` (`.contentShape` not in SkipUI). ✅

  *The pleasant surprise.* After R4, `xcodebuild` returned `** BUILD SUCCEEDED **`. The other four feature ViewModels (`PostDetailViewModel`, `PostFilterViewModel`, `ProfileViewModel`, `SettingsViewModel`) and their Views needed **zero** Skip-targeted edits — because their state shapes don't include `Result<X, APIError>` payloads and their Views don't use `case … where`. The module's Skip surface area was smaller than M11 feared.

  *What this changes for 7d.* Originally 7d was framed as "Android renders Settings only", on the assumption that only Settings would be transpile-clean by end of 7c. With the entire module transpile-clean, 7d can target **any** feature. The full MVVMC tab-bar app is, in principle, available to Android — pending only the Android root-view wiring.

  *The MVVMC architecture verdict at this checkpoint.* `doAction(.apiResponse(…))` with nested enum payloads is the one MVVMC idiom Skip pushes back on. Lifting the payload into a local `let` and splitting the case match preserves the doAction pattern's call shape on iOS while making it Skip-transpilable. The article can claim: *MVVMC's architecture survives Skip with zero changes; only two well-localised Swift idioms (nested leading-dot enums, nested case destructuring) get lifted into a more verbose-but-equivalent form.*

- **Verification**:
  - `xcodebuild … build` → `** BUILD SUCCEEDED **`, exit 0.
  - `find … mvvmc-skip.output … -name "*.kt" | wc -l` → **62 Kotlin files generated** for the `MVVMCSkipDemo` module. (Files inside `#if !SKIP` blocks generate empty/minimal Kotlin stubs, but the transpiler does inspect them.)
  - `skip app launch --ios --plain` → `[✓] Launch Skip app succeeded in 8.8s`. iOS behaviour confirmed unchanged after the V/VM edits.
  - All four touched files preserve their original control-flow semantics (verified by inspection of pre/post diffs and by iOS app continuing to render correctly).

### M13 — Step 7d: Android renders Settings (commit `e4e934a`)
- **What**:
  - Added `Sources/MVVMCSkipDemo/Android/AppEntry.swift` (wrapped `#if SKIP`) declaring two `public` types that `Android/app/src/main/kotlin/Main.kt` resolves via `typealias`:
    - `MVVMCSkipDemoRootView` — Android root view; for Step 7d simply wraps `SettingsView` in a `NavigationStack`.
    - `MVVMCSkipDemoAppDelegate` — Android-side lifecycle proxy; empty `onInit/onLaunch/onResume/onPause/onStop/onDestroy/onLowMemory` implementations, sufficient to satisfy Skip's contract.
  - `Skip.env`: `ANDROID_PACKAGE_NAME = com.joe.mvvmc.demo` → `mvvmcskip.demo` (matches `Main.kt`'s `package` line and the Skip-derived module namespace). Added an explicit `ANDROID_APPLICATION_ID = com.joe.mvvmc.demo` so the Android app id still matches the iOS bundle id.
  - `Darwin/MVVMCSkipDemo.xcconfig`: `SKIP_ACTION` flipped `none` → `launch`. Each iOS xcodebuild now also drives the Android gradle pipeline.
  - Wrapped six non-Settings feature surfaces in `#if !SKIP` to keep Step 7d focused on a *single* end-to-end feature: `PostDetailView`, `PostFilterView`, `PostListView`, `ProfileView`, `UserDetailView`, plus `ProfileViewModel` (UIKit-using) and `ProfileViewModel+Models` (extension on the wrapped class). The wrapped Views and VM remain fully visible to iOS; Android simply doesn't see them yet.
  - Two targeted source fixes for issues surfaced by the **Kotlin compile gauntlet** (see Journey below):
    - `SettingsView.swift`: fully qualified `SettingsViewModel.ViewAction.close` at the only `doAction` call site. Skip's transpiler otherwise emits bare `ViewAction.close` (missing the outer class qualifier) when the nested enum is declared in an extension.
    - `PostFilterViewModel+Models.swift`: replaced `(1...5).map { .init(id: $0) }` with `(1...5).map { User(id: $0) }`. Leading-dot `.init(...)` resolves to Kotlin's `Any(...)` in Skip's output, which doesn't have an `id` parameter.
- **Why — the second gauntlet**: M12 closed Skip's **transpile** gauntlet — Swift → Kotlin syntax was clean for the entire module. M13 ran into a second gauntlet that M11/M12 did not anticipate: **the transpiled Kotlin still has to compile against the Android toolchain (Kotlin + SkipUI + AndroidX)**. The transpiler accepts plenty of code that the Kotlin compiler then refuses. Two distinct gauntlets, run in series.
- **Journey** — the realisation that "Skip transpile clean ≠ Android can build":

  *Initial expectation.* "Wire `MVVMCSkipDemoRootView` + `AppDelegate`, flip `SKIP_ACTION`, run `skip app launch --android`." Three lines of plan; the actual work was much larger.

  *First wall — Android package mismatch.* `gradle` could not resolve `com.joe.mvvmc.demo:MVVMCSkipDemo` because `ANDROID_PACKAGE_NAME` had been set to the iOS bundle id (a leftover from M5 where I conflated the two). Skip wants `ANDROID_PACKAGE_NAME` to be the *Kotlin package name* (`mvvmcskip.demo`) and `ANDROID_APPLICATION_ID` to be the *Android app id* (which can match the iOS bundle id). They are two separate concepts. Fixed.

  *Second wall — the Kotlin compile gauntlet appears.* With package resolution fixed, gradle reached `compileDebugKotlin` — and erupted. Two error classes:
  - **`Unresolved reference 'ViewAction'`** in every transpiled View that calls `viewModel.doAction(.view(.something))`. Skip's transpiler took the Swift call `.view(.close)` and produced Kotlin `SettingsViewModel.Action.view(ViewAction.close)` — but `ViewAction` is a nested type, so the bare identifier doesn't resolve. The fix is to fully-qualify the inner enum at the Swift call site: `.view(SettingsViewModel.ViewAction.close)`. Skip then emits the proper `SettingsViewModel.ViewAction.close`.
  - **`Unresolved reference 'ContentUnavailableView'`** in `UserDetailView` and `PostListView`. SkipUI hasn't implemented `ContentUnavailableView` yet — for these features the right play is to wrap the entire View in `#if !SKIP` for now and add per-feature Android-friendly alternatives later.

  *Third wall — Skip's silent type fallback.* `PostFilterViewModel+Models.swift`'s `(1...5).map { .init(id: $0) }` transpiled into Kotlin `(1..5).map { it -> Any(id = it) }`. Skip couldn't infer the target type for `.init` and silently fell back to Kotlin's `Any` — which doesn't have an `id` parameter. Spelling `User(id: $0)` explicitly fixes it. This is the same family of issue as M12's "leading-dot enum ambiguity", but in a constructor context.

  *The pragmatic narrowing.* Once the second-gauntlet shape was clear, I narrowed Step 7d's deliverable from "the whole MVVMC tab-bar app runs on Android" (which M12's success had tempted me to claim) back to "**one feature, end-to-end, on Android**". The other five features (`Profile`, `PostList`, `PostDetail`, `PostFilter`, `UserDetail`) each have their own Kotlin-compile issues (deeplinks, `UIApplication.shared`, `UNUserNotificationCenter`, more `.view(...)` qualifications, `ContentUnavailableView`, etc.). Each will get its own future commit. They're temporarily `#if !SKIP`-walled.

  *Settings wins.* Settings is the simplest feature — no API calls, no deeplinks, no notifications, one call site to qualify. After three targeted edits (`Skip.env`, `SettingsView` qualifier, `PostFilterViewModel+Models.init`), `skip app launch --android` reported success in 14.7 s. **The Settings screen renders on the Pixel 9 emulator with `關閉` / `設定` / `一般` / `版本 1.0.0` / `Build 1` correctly localised**.

  *What the article actually claims at this checkpoint.* Article A's central bet — *a UIKit-based MVVMC iOS app can be brought to Android via Skip with the iOS architecture left intact* — is **verified in principle by Settings**, **not in scope for the other five features yet**. The next chapter is per-feature work: tackle each feature's Kotlin compile issues, unwrap it on Android, expand the Android root to the full tab-bar app.

- **Verification**:
  - `skip app launch --android --plain` → `[✓] Launch Skip app succeeded in 14.71s`.
  - Pixel 9 emulator screenshot at `articles/images/m13-android-settings.png` shows the Settings screen with all UI elements (`關閉` button, `設定` navigation title, `一般` section header, `版本` / `Build` rows) correctly rendered in Compose.
  - `skip app launch --ios --plain` → `[✓] Launch Skip app succeeded in 11.63s`. iOS PostList tab + Tab Bar still render exactly as in M8. Architecture-zero-change confirmed at runtime after all M13 source edits.
  - iOS screenshot at `articles/images/m13-ios-postlist.png` shows the unchanged iOS surface.

- **Feature-code line tally at M13** (cumulative across all M-entries):

  | File | Touches | Lines | Class |
  |---|---|---|---|
  | `App/AppRouter.swift` | `nonisolated(unsafe)` | 1 | Swift 6 concurrency (M5) |
  | `App/AppDelegate.swift` | move `@main` + `public` ×3 | ~5 | cross-module entry (M7) |
  | `App/SceneDelegate.swift` | `public` ×6 | ~6 | cross-module entry (M7) |
  | App-layer `#if !SKIP` (4 files) | wrap | ~8 | Skip invisibility (M11) |
  | 6 × `*HostController.swift` | `#if !SKIP` wrap | ~12 | Skip invisibility (M11) |
  | `UserDetailView.swift` | `case where` → if-in-body, then `#if !SKIP` wrap | ~10 | Kotlin grammar (M12) + deferred (M13) |
  | `UserDetailViewModel.swift` | typed-let lift, nested case split | ~15 | Skip transpile (M12) |
  | `PostListViewModel.swift` | typed-let lift, nested case split | ~15 | Skip transpile (M12) |
  | `PostListView.swift` | `case where` rewrite, modifier `#if !SKIP`, then full-file wrap | ~12 | Kotlin grammar (M12) + deferred (M13) |
  | `SettingsView.swift` | qualify `SettingsViewModel.ViewAction.close` | ~3 | Skip type inference (M13) |
  | `PostFilterViewModel+Models.swift` | `.init(...)` → `User(...)` | ~1 | Skip type inference (M13) |
  | `ProfileView.swift`, `ProfileViewModel.swift`, `ProfileViewModel+Models.swift`, `PostDetailView.swift`, `PostFilterView.swift` | `#if !SKIP` wrap (Step 7e deferral) | ~10 | Future work (M13) |

  **Total ≈ 100 lines edited across ~22 files**. `MVVMC` architecture (M / VM / V / C separation, `doAction` single-entry-point, `Router` enums, `@Observable` ViewModel, UIKit `HostController` C-layer) **unchanged**. The Settings feature renders on both iOS (UIKit-native) and Android (Skip-transpiled Compose) **from the same Swift source**.

### M14 — Step 8a: PostFilter ports to Android (this commit)
- **What**:
  - Unwrapped `Sources/MVVMCSkipDemo/Pages/PostFilter/PostFilterView.swift` from `#if !SKIP` (added back in M13 deferral).
  - Applied **idiom #6** (qualify nested enum at call site) to all three `doAction` sites in `PostFilterView` — `.view(.showAll)` → `.view(PostFilterViewModel.ViewAction.showAll)`, etc.
  - Grew `MVVMCSkipDemoRootView` (Android-only, `Sources/MVVMCSkipDemo/Android/AppEntry.swift`) from a single `SettingsView` to a `NavigationStack` + `List` index with `NavigationLink`s into each ported feature. PostFilter is the second row.
- **Why**: First per-feature port after the Step 7d scaffolding. PostFilter is the simplest feature with `.view(...)` call sites (Settings only had one — `.close`). Three sites in PostFilter exercises idiom #6 enough times to verify the pattern is mechanical and stable across a real feature surface.
- **Verification**:
  - `skip app launch --android --plain` → `[✓] Launch Skip app succeeded in 11.28s`.
  - Pixel 9 screenshots at `articles/images/step8a-android-root.png` (the new feature-index root) and `articles/images/step8a-android-filter.png` (PostFilter screen with `Cancel` toolbar, `Filter by User` title, `Show All` + `User 1`–`User 5` rows correctly rendered, including idiom #7's `User(id: $0)` fix being exercised at runtime).
  - `skip app launch --ios --plain` → `Launch Skip app succeeded in 10.71s`. iOS PostList tab + UITabBarController unchanged.
  - `PostFilterView`'s edits are 3 idiom-#6 qualifications, ~3 lines net change. PostFilter feature surface (VM, View, Models) keeps its MVVMC shape intact.

---

## Next Steps (start here in the next session)

Open this repo cold and these are the steps in order. Each step is one commit with a `Why:` paragraph.

1. ~~**Add `Package.swift` pointing at existing `Sources/` paths**~~ ✅ Done in M4.
2. ~~**Add Skip scaffold** — `Skip.env`, `Sources/Skip/skip.yml`, swift-tools 6.1, skip / skip-ui deps. Plugin binding deferred to Step 7.~~ ✅ Done in M5.
3. ~~**Restructure `Sources/Pages/` → `Sources/MVVMCSkipDemo/Pages/`** + module rename to `MVVMCSkipDemo`.~~ ✅ Done in M6.
4. ~~**Add `Darwin/` shell**~~ ✅ Done in M7.
5. ~~**Add `Project.xcworkspace`** at repo root + verify `skip app launch --ios`.~~ ✅ Done in M8.
6. ~~**Add `Android/` shell**~~ ✅ Done in M9. `gradle :app:assembleDebug` fails with the expected "Could not locate transpiled module for MVVMCSkipDemo" — the start signal for Step 7.
7. **First real Skip adaptation — bind plugin + convert one feature end-to-end**. Broken into four sub-commits:
   - **7a** — Bind the `skipstone` plugin to the `MVVMCSkipDemo` target. iOS xcodebuild goes red (intentionally) with one fail-fast error from Skip. ✅ Done in M10.
   - **7b** — Wrap all `*HostController.swift` + UIKit-only App-layer files in `#if !SKIP`. ✅ Done in M11. Discovered the frontier moves to a *View* (`case where`), not a VM as M5 predicted.
   - **7c** — Fix Skip-transpile issues in the order Skip surfaces them, until the entire `MVVMCSkipDemo` module transpiles. ✅ Done in M12. Four rebuilds, four fixes, in two files each of V/VM (UserDetail + PostList). The four other features needed no edits.
   - **7d** — Add Android root view + wire `Main.kt` + flip `SKIP_ACTION`. ✅ Done in M13. **Settings renders on Pixel 9 emulator** (`articles/images/m13-android-settings.png`). Five other features `#if !SKIP`-walled, deferred to Step 8+.
8. **Per-feature Android conversion** — one commit per feature:
   - **8a** — PostFilter. ✅ Done in M14.
   - **8b** — PostList. Will need to replace/wrap `ContentUnavailableView` + multiple `.view(...)` qualifier sites.
   - **8c** — Profile. Has `UIApplication.shared.open` (deeplink) and `UNUserNotificationCenter` (push); needs Android-side substitutions or further `#if !SKIP` walls.
   - **8d** — UserDetail. API + `ContentUnavailableView`.
   - **8e** — PostDetail. After this, root can switch from feature-list to a TabView mirroring iOS.
8. **Per-feature Skip conversion** — one commit per feature: rewrite that feature's ViewModel for Skip type inference, ensure its View transpiles, verify Android renders it. Repeat for `Profile`, `PostList`, `PostFilter`, `PostDetail`, `UserDetail` in roughly that order of complexity.

Each step's `Why:` and any gotchas land back in the Migration Log above as they happen.
