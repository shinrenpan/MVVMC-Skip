# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Repository context

This repo is the **Article A** target: bring the existing [MVVMC](https://github.com/shinrenpan/MVVMC) iOS architecture to Android via [Skip.tools](https://skip.tools), with **zero changes on iOS**.

The core promise: existing MVVMC code stays untouched. Cross-platform support is added by wrapping UIKit-specific code in `#if !SKIP` and providing a SwiftUI equivalent in the matching `#else` branch — never by refactoring the iOS-side architecture.

| | |
|---|---|
| Baseline | MVVMC `v1.1.0` (commit `db9013d`) |
| Skip mode | Skip Lite (Swift → Kotlin/Compose) |
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

### M3 — Route B chosen for project layout (this commit)
- **What**: Decided to migrate from `XcodeGen + Sources/Pages/` to the Skip Lite convention (`Package.swift` + `Sources/MVVMCSkipDemo/Pages/` + `Darwin/` + `Android/`). XcodeGen will be retired.
- **Why**: Skip transpiler assumes SPM as the source-of-truth. Running XcodeGen alongside SPM creates a dual-track that fights Skip's implicit expectations (the path MVVMR-Skip discovered the hard way before eventually retiring XcodeGen in its own Commit 3).
- **Scope clarification**: "iOS zero-change" applies to **feature code content** (M/VM/V/C `.swift` files in `Pages/`). Project scaffolding (`Package.swift`, `Skip.env`, `Darwin/`, `Android/`, `Project.xcworkspace`) is necessarily new. File **locations** may move; **contents** do not.
- **Not yet done**: actual migration. This entry records the decision; execution is the next session's first task.

---

## Next Steps (start here in the next session)

Open this repo cold and these are the steps in order. Each step is one commit with a `Why:` paragraph.

1. **Add `Package.swift` pointing at existing `Sources/` paths** — sanity check that SPM can see the existing iOS code unchanged. `swift build` should succeed on iOS host before any Skip work.
2. **Add Skip plugin to `Package.swift`** + create `Skip.env` (copy MVVMR-Skip's as a template, adjust bundle ID / module name to `MVVMCSkipDemo`). Run `skip doctor`.
3. **Restructure `Sources/Pages/` → `Sources/MVVMCSkipDemo/Pages/`** — this is a `git mv` only; no file content edits. Update `Package.swift` source paths.
4. **Add `Darwin/` shell** — `Info.plist`, `Main.swift` (`@main` entry that wraps `SceneDelegate` for iOS), Assets. Retire `MVVMCDemo.xcodeproj` + `project.yml`.
5. **Add `Project.xcworkspace`** at repo root referencing `Package.swift` + `Darwin/<Name>.xcodeproj`. Verify `skip app launch --ios` boots.
6. **Add `Android/` shell** — Gradle scaffolding, `Main.kt` entry. Verify `skip app launch --android` reaches the build phase (likely to fail at first Kotlin compile — that's expected and starts the real `#if !SKIP` work).
7. **First real Skip adaptation**: wrap the smallest unit — likely `AppRouter.swift`'s UIKit imports — in `#if !SKIP` and add an `#else` SwiftUI router stub. Get one screen to render on Android.

Each step's `Why:` and any gotchas land back in the Migration Log above as they happen.
