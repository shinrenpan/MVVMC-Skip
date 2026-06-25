(繁體中文｜[English](./README.en.md))

# MVVMC-Skip

> **MVVMC** + [Skip.tools](https://skip.tools)：把現有 MVVMC iOS 架構帶到 Android,**iOS 端零改動**。

MVVMC-Skip 不重寫架構、不重做導航,只用 `#if SKIP` / `#if !SKIP` 條件編譯,把 UIKit-based 的 C 層在 Android 端替換為 SwiftUI 等價物。iOS 使用者體驗、程式碼結構與主 [MVVMC](https://github.com/shinrenpan/MVVMC) 一致。

---

## 與 MVVMC 的關係

|              | MVVMC                         | MVVMC-Skip（本 repo）              |
|---           |---                            |---                                 |
| C 層         | UIKit `HostController`        | UIKit `HostController`（保留）     |
| 跨平台手法   | (不跨平台)                    | `#if SKIP` 條件編譯,兩套導航實作   |
| iOS 行為     | 基準                          | **與基準完全一致**                 |
| 適用對象     | iOS-only 新專案               | **既有 MVVMC 專案要加 Android**    |
| 對應文章     | (基準參考)                    | **文章 A**                         |

> MVVMC-Skip 的核心訴求是「不破壞既有 iOS 架構」。如果你的專案已經是 MVVMC,加 Android 支援時無需重構,只要補 `#else` 分支。

---

## Baseline

| 項目 | 值 |
|---|---|
| Fork 自 | [shinrenpan/MVVMC](https://github.com/shinrenpan/MVVMC) |
| Baseline 版本 | `v1.1.0` |
| Baseline commit | [`db9013d`](https://github.com/shinrenpan/MVVMC/commit/db9013d) |
| Skip 模式 | **Skip Lite**（Swift → Kotlin/Compose 轉譯） |

> 第一個 commit 起即為 MVVMC v1.1.0 原貌,後續 commit 為加上 Skip 支援所做的最小幅度改動。

---

## 為什麼選 Skip Lite

- **轉譯成真實 Kotlin + Compose**：Android 工程師可讀、可維護
- **APK 小**：純 Kotlin 輸出,不需要打包 Swift runtime
- **開源**：transpiler 與 runtime 模組皆開源
- **學習副產物**：強迫理解 SwiftUI ↔ Compose 的概念對應

---

## Repo 狀態

✅ **實作完成**（2026-06-26）。所有 10 個步驟（Steps 1–9 + bugfix M21）皆已 commit。

詳細的 Skip 適配規則與每個決策的 Why 記錄在 `CLAUDE.md` 的 Migration Log（M0–M21）。

---

## 技術文章

本 repo 對應**文章 A**：MVVMC + Skip — 用 `#if SKIP` 把現有 UIKit-nav 架構帶到 Android。

---

## License

[MIT](./LICENSE)
