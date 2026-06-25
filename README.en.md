([繁體中文](./README.md)｜English)

# MVVMC-Skip

> **MVVMC** + [Skip.tools](https://skip.tools): bring the existing MVVMC iOS architecture to Android with **zero changes on iOS**.

MVVMC-Skip doesn't rewrite the architecture or rework navigation — it uses `#if SKIP` / `#if !SKIP` conditional compilation to substitute a SwiftUI equivalent for the UIKit-based C layer on Android. iOS UX, code structure, and behaviour stay identical to the main [MVVMC](https://github.com/shinrenpan/MVVMC) repo.

---

## Relationship to MVVMC

|              | MVVMC                         | MVVMC-Skip (this repo)             |
|---           |---                            |---                                 |
| C layer      | UIKit `HostController`        | UIKit `HostController` (preserved) |
| Cross-platform approach | (iOS only)         | `#if SKIP`, two navigation impls   |
| iOS behaviour | baseline                     | **identical to baseline**          |
| Target audience | new iOS-only project       | **existing MVVMC project adding Android** |
| Article      | (baseline reference)          | **Article A**                      |

> MVVMC-Skip's core promise: existing iOS architecture is not disturbed. If your project is already MVVMC, adding Android support requires no refactor — only `#else` branches.

---

## Baseline

| Item | Value |
|---|---|
| Forked from | [shinrenpan/MVVMC](https://github.com/shinrenpan/MVVMC) |
| Baseline version | `v1.1.0` |
| Baseline commit | [`db9013d`](https://github.com/shinrenpan/MVVMC/commit/db9013d) |
| Skip mode | **Skip Lite** (Swift → Kotlin/Compose transpilation) |

> The first commit is an exact mirror of MVVMC v1.1.0; subsequent commits introduce the minimum changes needed to enable Skip.

---

## Why Skip Lite

- **Transpiles to real Kotlin + Compose**: Android engineers can read and maintain the output
- **Small APK**: pure Kotlin output, no Swift runtime bundling
- **Open source**: both transpiler and runtime are open source
- **Learning byproduct**: forces understanding of the SwiftUI ↔ Compose concept mapping

---

## Repo status

✅ **Implementation complete** (2026-06-26). All 10 steps (Steps 1–9 + bugfix M21) are committed.

Detailed Skip adaptation rules and the rationale behind each decision are recorded in `CLAUDE.md`'s Migration Log (M0–M21).

---

## Article

This repo backs **Article A**: MVVMC + Skip — bringing the existing UIKit-nav architecture to Android via `#if SKIP`.

---

## License

[MIT](./LICENSE)
