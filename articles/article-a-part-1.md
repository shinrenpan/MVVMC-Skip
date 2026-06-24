# 把 MVVMC 帶到 Android（一）：從 XcodeGen 到第一個 `.app`

> Article A, Chapter 1。涵蓋 commit M4–M7（Steps 1–4）。
> 重點：把一個既有的 UIKit-based iOS 專案，搬進 Skip Lite 的 SPM-as-source-of-truth 架構，並產出第一個能 build 的 iOS `.app` bundle。VM / View / Model 一行未動。

---

## 一、為什麼是這條路？

[MVVMC](https://github.com/shinrenpan/MVVMC) 是我長期在用的一套 iOS 架構：UIKit + SwiftUI + Coordinator，VM 走 `@Observable` + `doAction` 單一進入點，C 層用 `UIHostingController` 把 SwiftUI View 嵌進 `UINavigationController`。它跑在 iOS 上很順，但 **跨平台這件事它從來沒想過**。

[Skip.tools](https://skip.tools) 是把 Swift 程式碼透過 transpile 變成 Kotlin / Compose 跑在 Android 上的工具鏈。看起來完美：iOS 寫一份、Android 自動有。但魔鬼藏在「自動」這兩個字裡。

跟 Skip 接觸時有三條押注方式：

- **押 A**：MVVMC + Skip — UIKit 留在 iOS，Android 由 Skip 翻 SwiftUI 到 Compose。**iOS 架構不動**。
- **押 B**：MVVMR（純 SwiftUI 改寫 MVVMC）— 為了跨平台，先把 iOS 從 UIKit 改成純 SwiftUI。然後 + Skip。
- **押 C**：MVVMR-Skip — 直接寫純 SwiftUI 跨平台版（這條 [我已經寫過](https://github.com/shinrenpan/MVVMR-Skip)，順但是它早就把 UIKit 丟掉了）。

這個 repo（`MVVMC-Skip`）押的是 A——也就是「**承諾架構不變、只在邊緣加 Skip-friendly 改寫**」。這承諾要兌現幾分，等下會驗。

---

## 二、第一個 commit：先讓 SPM 看見既有 iOS code

第一步看起來無聊但必要：寫一個 `Package.swift`，把現有的 `Sources/` 接到 SPM 上。

Skip 工具鏈把 SPM 當 source-of-truth。XcodeGen 跟 SPM 共存會打架（這是我做 MVVMR-Skip 時學到的痛）。所以這個 repo 一開始就決定：**XcodeGen 退役、SPM 上位**。

但 SPM 在 Mac host 上預設指 macOS SDK，所以 `swift build` 立刻在第一行炸：

```
Sources/App/AppDelegate.swift:1:8: error: no such module 'UIKit'
```

對。SPM 沒有原生 iOS cross-compile 能力。要 build iOS code 必須走 `xcodebuild`：

```bash
xcodebuild -scheme MVVMCDemo \
  -destination 'generic/platform=iOS Simulator' \
  build
```

這個 toolchain 二分（SPM 看 Mac、xcodebuild 看 iOS）會在後面每個 commit 都來敲一下，不會自己消失。

還碰到一個小但討厭的問題：repo 原本的 `MVVMCDemo.xcodeproj/` 是 XcodeGen 產生物（`project.pbxproj` gitignored），本地只剩個空殼。但 xcodebuild 看到 `*.xcodeproj` 就會優先選它，不會回頭 fallback 到 `Package.swift`。Workaround 是 build 時把空殼 dir 暫時移開、build 完還原——醜，但是是 transient state，Step 4 把它正式 retire 掉就好。

Step 1 結束時：`xcodebuild` 對 iOS Simulator build → `** BUILD SUCCEEDED **`。SPM 看到了所有既有 iOS 程式碼，**零改**。

---

## 三、第二個 commit：本來打算兩行設定的 Step 2

原 plan 寫得很樂觀：「Step 2 = 把 Skip plugin 接進 `Package.swift` + 建 `Skip.env`」。兩行設定。

實作中，這「兩行設定」展開成一連串撞牆。

### 撞牆 #1：`skipstone` plugin 不是 passive

我以為 plugin 接上去就好，等 Step 6 `skip app launch --android` 才會被觸發。**錯**。`skipstone` 一旦綁到 SPM target，每次 `xcodebuild` 都會立刻觸發 Swift → Kotlin 轉譯。這是 Step 2 的最大發現——後面每一步的規劃都要根據這個事實重新對齊。

第一個 Kotlin 轉譯錯誤打在 `AppRouter.swift`：

```swift
private var appTransitionStyleKey: UInt8 = 0
```

Swift 6 strict concurrency 不准 global `var`。

### 撞牆 #2：Swift 5 反射

我的反射動作是 `swiftLanguageVersions: [.v5]`——把整個 package 鎖回 Swift 5，這樣舊程式碼就不用動。

用戶當場踩煞車：「**用 Swift 6, iOS feature code 零改太嚴格了**」。

這句話比表面上更重。「iOS feature code 零改」這個 slogan 聽起來像架構承諾，但實際上它把整個 repo 鎖在「為了避免一行 `nonisolated(unsafe)` 而停留在前一代 Swift」的時光機裡。這不是架構承諾，是 cargo cult 承諾。

承諾被當場改寫為：

> **架構零變更；scaffold-related minimal, necessary fixes 允許。**

換句話說：M / VM / V / C 之間的關係不能動，`doAction` 模式不能動，HostController 的角色不能動。但 `nonisolated(unsafe)`、`public` modifier、`#if !SKIP` 包裹這種**型別屬性宣告級別**的修改，是允許的。

### 撞牆 #3：VM 層的型別推論

Swift 5 鎖回退之後，再試一次。這次認真把 10 個 UIKit-only 檔案（4 個 App-層 + 6 個 HostController）整檔包 `#if !SKIP`、iOS 那邊綠了。Skip plugin 往前推進——撞到 VM 層：

```swift
await doAction(.apiResponse(.fetchUserDidFinish(.success(dto))))
```

```
Skip is unable to determine the owning type for member 'success'
```

Skip 的型別推論比 Swift compiler 弱。**巢狀 leading-dot enum** 它認不出來。問題是 MVVMC 的每一個 ViewModel 都用這個模式回 API response。這不是 10 個檔案能解決的，是整個 codebase 的工程量。

回去翻 MVVMR-Skip（純 SwiftUI 跨平台版），同樣作者、同樣 VM 形狀，解法是把 `.success(dto)` 拉出來顯式宣告型別：

```swift
let result: Result<UserDTO, APIError> = .success(dto)
await doAction(.apiResponse(.fetchUserDidFinish(result)))
```

兩行解一個 call site。但要動每個 VM 的每個 API call。

### 戰略撤退

於是 Step 2 退回到「**scaffold-only**」：
- ✅ `Skip.env` 建好
- ✅ `Sources/Skip/skip.yml` 建好
- ✅ `Package.swift` 加 `skip` / `skip-ui` deps、bump 到 swift-tools 6.1（Swift 6 default）
- ✅ `AppRouter` 的 concurrency 修了（純 iOS Swift 6 修，跟 Skip 無關）
- ❌ **plugin 不接 target**——推到 Step 7，那時一 feature 一 feature 配合 VM 改寫一起做

每個 commit 都該 iOS 綠燈。Step 2 維持 iOS 綠燈，Skip 「掛在那」但還沒對程式碼開火。

這個故事對文章敘事很重要：「拿既有 iOS 專案上 Skip」**第一步不是 `skip init`**，而是「探索 + 拒絕中間 hack + 重新定義 step 顆粒度」。原 Plan 樂觀地以為 Step 2 是兩件事；真實 Step 2 = **掌握 plugin 行為 + 確認規模 + 戰略撤退**。

---

## 四、第三個 commit：對齊 Skip 預期的位置

`git mv Sources/{App,Pages,Shared,Skip} Sources/MVVMCSkipDemo/`。

35 個檔案 `git mv`、4 個 scaffold 檔調 module 名字（Package.swift、Skip.env、3 個 test import）。**0 行 feature code 內容變動**。

為什麼這層搬遷必要？因為 Skip Lite 的 plugin 是看 SPM target 的 `path` 來決定 transpile 範圍的，而它的 module name 也決定 transpile 出來的 Kotlin package。**SPM module name、on-disk 資料夾名、`Skip.env` 的 `PRODUCT_NAME`、`@testable import` 名稱——這四者一旦對齊，後面所有自動化（包括 Step 7 plugin 接上時）就不用一直 wiring**。

Step 3 是讓四者對齊。

---

## 五、第四個 commit：第一個 `.app`

Step 4 是 Step 1-3 後第一個直接撞到「**UIKit vs SwiftUI 入口點**」這個架構抉擇的 commit。

**核心約束**：iOS app 啟動時，系統在 app target 自己的 binary 裡找 `main` 符號。**`@main` 在 linked framework 裡是找不到的**。也就是說，目前 SPM library 裡那個 `@main` 的 `AppDelegate`，必須讓出 `@main`。

三條路：

| | Path A | Path B | Path E |
|---|---|---|---|
| Darwin 入口 | 7 行手寫 `UIApplicationMain(…AppDelegate…)` | Skip canonical `@main struct AppMain: App`（SwiftUI lifecycle） | 入口直接是搬過去的 `AppDelegate` |
| SPM lib `AppDelegate` | 移除 `@main`、加 `public` | 改造成 SwiftUI callback proxy（`onResume` / `onPause`） | 整個檔案搬到 Darwin/ |
| 其他 UIKit 檔案 | 留 lib，Step 7 包 `#if !SKIP` | 同左 | 整批搬到 Darwin/，VM/View 全要 public |
| 變動量 | ~20 行 | 中等（要寫 SwiftUI App + AppDelegate adapter） | 大（幾十個 public modifier） |
| iOS 啟動鏈 | `UIApplicationMain → AppDelegate → SceneDelegate → UITabBarController →` | `SwiftUI App → UIApplicationDelegateAdaptor → AppDelegate.onLaunch →` | 同 Path A |

**選 Path A**。理由：

1. **架構零變更軸**：Path A 保住的入口鏈 `UIApplicationMain → AppDelegate → SceneDelegate → UITabBarController` 跟 MVVMC baseline 一字不差。Path B 把 SwiftUI App lifecycle 套在外面，改了 entry shape。
2. **變動量軸**：Path A 改 ~20 行 access modifier。Path E 要把整個 lib 翻成 public API 庫。
3. **下個 commit 銜接性**：Path A 的「UIKit 檔案還在 lib 裡」意味著 Step 7 接 plugin 時需要 `#if !SKIP` 包它們——10 個檔案，純機械貼上。Path E 省下這 10 個 `#if`，但代價是 Step 4 就要寫幾十個 `public`，划不來。

Path A 的具體實作：

```swift
// Darwin/Sources/Main.swift（7 行核心）
import UIKit
import MVVMCSkipDemo

@main
enum AppLauncher {
  static func main() {
    UIApplicationMain(
      CommandLine.argc,
      CommandLine.unsafeArgv,
      nil,
      NSStringFromClass(AppDelegate.self)
    )
  }
}
```

```swift
// Sources/MVVMCSkipDemo/App/AppDelegate.swift
- @main
- final class AppDelegate: UIResponder, UIApplicationDelegate {
-   func application(_ application: UIApplication, ...
+ public final class AppDelegate: UIResponder, UIApplicationDelegate {
+   public override init() { super.init() }
+   public func application(_ application: UIApplication, ...
```

`SceneDelegate` 同樣加 `public`——並且因為 Swift 規定 public class 的 protocol-implementing 方法也要 public，連 4 個 `UISceneDelegate` / `UNUserNotificationCenterDelegate` 方法都要加 `public`。

`Info.plist` 裡的 `UISceneDelegateClassName` 從 `$(PRODUCT_MODULE_NAME).SceneDelegate`（會 expand 成 iOS app target 的 module name，不對）改成硬碼 `MVVMCSkipDemo.SceneDelegate`（library 的 module name，對）。

最後 `git rm` 掉 `MVVMCDemo.xcodeproj/`（XcodeGen 空殼）跟 `project.yml`。

驗證：

```bash
xcodebuild -project Darwin/MVVMCSkipDemo.xcodeproj \
  -scheme "MVVMCSkipDemo App" \
  -destination 'generic/platform=iOS Simulator' build
# ** BUILD SUCCEEDED **
```

`.app` bundle 真的長出來了。

---

## 六、盤點：feature code 改了幾行？

到此為止四個 commit，feature code 觸碰一覽：

| 檔案 | 改動 | 行數 | 性質 |
|---|---|---|---|
| `AppRouter.swift` | `nonisolated(unsafe)` 加在 global var key | 1 | Swift 6 concurrency |
| `AppDelegate.swift` | 移 `@main`、`public` × 3 | ~5 | 跨 module 入口 |
| `SceneDelegate.swift` | `public` × 6 | ~6 | 跨 module 字串查找 |

**M / VM / V** （Pages/ 底下整個資料夾）：**0 行**。

`Sources/MVVMCSkipDemo/Pages/` 底下所有 ViewModel、View、Model、Mocks 一字未改。MVVMC 的核心架構承諾在 Step 1-4 結束時完整成立——但它的方式不是「Sources/ 一字未動」，而是「**架構意義上零變化、scaffold-required `public` modifier 必要時加**」。文章意義上這是一個更可信的承諾，因為它對應到實際做得到的事，而不是過度許諾。

---

## 七、下一篇

Step 5（workspace + 真正 launch iOS）、Step 6（Android shell）、Step 7（plugin 接上 + 第一個 feature 端到端到 Android）—— 這些是下一篇的範圍，標題暫定「**拿 Skip plugin 對著真正的 codebase 開火**」。

那一篇會回答：MVVMC 的 `doAction` 模式、`Router` enum 模式、`@Observable` ViewModel 模式，**到底有多少能直接被 Skip transpile，多少要改寫**。第一個 feature 從哪個下手（最有可能是 `Settings`）、改寫 pattern 是什麼、Android 端怎麼接住 router 切頁。

到目前為止，這個 repo 證明的事是：**一個既有 UIKit + MVVMC iOS 專案，可以在不重寫架構的前提下，移進 Skip 的 SPM-as-source-of-truth scaffold，並且 iOS 端 100% 維持原本行為**。這是 Article A 第一章該交付的內容。

下一章要證明的事更難，也更有意思——**MVVMC 的核心 pattern 跟 Skip 友善的 Swift 風格之間，到底差多遠**。

---

> 本文涵蓋的 commit：[`5d5b9ec`](../../../commit/5d5b9ec)（Step 1）、[`5ae01a7`](../../../commit/5ae01a7)（Step 2）、[`2bbcfdf`](../../../commit/2bbcfdf)（Step 3）、[`ebab12a`](../../../commit/ebab12a)（Step 4）。
> 完整的決策軌跡 + verification 在 [`../CLAUDE.md`](../CLAUDE.md) 的 Migration Log M4-M7。
