([繁體中文](./README.md)｜English)

# MVVMC-Skip

> **MVVMC** + [Skip.tools](https://skip.tools): bring the existing MVVMC iOS architecture to Android with **zero changes on iOS**.

MVVMC-Skip doesn't rewrite the architecture or rework navigation — it uses `#if SKIP` / `#if !SKIP` conditional compilation to substitute a SwiftUI equivalent for the UIKit-based C layer on Android. iOS UX, code structure, and behaviour stay identical to the main [MVVMC](https://github.com/shinrenpan/MVVMC) repo.

---

## Relationship to the MVVMC family

|              | MVVMC                         | MVVMC-Skip (this repo)             | [MVVMR-Skip](https://github.com/shinrenpan/MVVMR-Skip) |
|---           |---                            |---                                 |---                                  |
| C layer      | UIKit `HostController`        | UIKit `HostController` (preserved) | SwiftUI Router                      |
| Cross-platform approach | (iOS only)         | `#if SKIP`, two navigation impls   | Single SwiftUI codebase             |
| iOS behaviour | baseline                     | **identical to baseline**          | may diverge                         |
| Target audience | new iOS-only project       | **existing MVVMC project adding Android** | new cross-platform project   |
| Article      | (baseline reference)          | **Article A**                      | Article C                           |

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

🚧 **Currently private**, to be made public after **Article A** ships.

Concrete Skip adaptation rules (which APIs need guards, how to substitute `UINavigationController` on the Android side, etc.) will be added to this repo's `CLAUDE.md` as the implementation progresses — **not invented up front**.

---

## Article series

This repo backs the **first** article in a planned three-part series:

- [ ] **Article A** — MVVMC + Skip: bring the existing UIKit-nav architecture to Android via `#if SKIP` (**this repo**)
- [ ] **Article B** — MVVMC → MVVMR: why the C layer moves from UIKit HostController to a SwiftUI Router (repo: `MVVMR`, planned)
- [ ] **Article C** — MVVMR + Skip: a single SwiftUI codebase for iOS + Android (repo: [`MVVMR-Skip`](https://github.com/shinrenpan/MVVMR-Skip), private)

---

## License

[MIT](./LICENSE)
