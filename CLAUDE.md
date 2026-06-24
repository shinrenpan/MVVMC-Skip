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
