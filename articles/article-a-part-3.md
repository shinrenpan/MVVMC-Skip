# Article A — MVVMC × Skip（Part 3）：六個功能 × 三道 gauntlet × 一套 Router

> **系列索引**
> - Part 1：為什麼選 MVVMC-Skip？baseline 建立與 Skip scaffold（M0–M7）
> - Part 2：第一次 Android render，以及三道 gauntlet 的前兩道（M8–M13）
> - **Part 3（本篇）**：逐功能 Android port，Runtime gauntlet，Router 接線（M14–M20 + Step 9）

---

Part 2 的結尾，Settings 畫面剛在 Pixel 9 上點亮。其餘五個功能還用 `#if !SKIP` 牆圍著，只要牆在，Android 就看不到那些頁面。Step 8 的任務：一次拆一堵牆，讓每個功能都能 Android 渲染。

但每拆一堵牆，就撞上一道新問題。這篇文章的主線是**這些問題的形狀**——不是「我成功了」，而是「我以為會成功，然後撞上什麼」。

---

## 一、PostFilter：最簡單的那堵牆（M14）

第一個開牆的是 PostFilter——沒有 API call、沒有 deeplink、沒有推播，只有一個靜態清單讓使用者選 User。

把 `PostFilterView.swift` 的 `#if !SKIP` 移掉，馬上遇到之前已經認識的老朋友：

```swift
// 原本
await viewModel.doAction(.view(.showAll))

// 改成（idiom #6：展開 nested enum）
await viewModel.doAction(.view(PostFilterViewModel.ViewAction.showAll))
```

三個 `doAction` call site，三次展開，build 過，Android 渲染。不到半小時。

PostFilter 的輕鬆讓人誤以為 Step 8 會很快走完。

---

## 二、PostList：第三道 gauntlet 現身（M15 + M16）

PostList 是第一個有**真實 API 狀態機**的功能：`state.api.fetchPosts` 要從 `.prepare → .loading → .success` 走一遍，才能讓 `List` 出現資料。

### 牆拆掉，畫面出現了，但是空的

`ContentUnavailableView` 用 idiom #8 替換（SkipUI 還沒實作），`doAction` call sites 用 idiom #6 展開，build 過，Android 打開 Posts tab——

導覽列和 toolbar 都在，`List` 的區域是空的。沒有 `ProgressView`，沒有 row，沒有錯誤。

畫面**殼**出來了，但**資料**沒有。

### 快速隔離：同步 mutation 也沒用

為了確認問題出在哪，暫時把 `state.api.fetchPosts` 直接寫死成 `.loading`，重新 build。

Pixel 9 正確出現了 `ProgressView`。

代表 SwiftUI 的 `switch` 是對的，Compose 的 `is APIStatus.LoadingCase ->` 也能 match，`ProgressView()` 能渲染。**View 殼沒問題。**

再試更暴力的版本：在 `.onAppear` 裡直接寫 `viewModel.state.api.fetchPosts = .loading`。同步，不過任何 async。

結果：Compose 一樣沒有重繪。

**這不是 `.task` async chain 的問題——是更底層的：state mutation 根本沒有觸發 Compose 的 recompose。**

### 根因：`Observed<Value>.trackState()` 的閘

讀 SkipModel 的 `Observed.kt` 原始碼，找到了問題所在：

```kotlin
class Observed<Value> : StateTracker {
    var projectedValue: MutableState<Value>? = null  // 預設是 null

    override fun trackState() {
        if (projectedValue == null) {
            projectedValue = mutableStateOf(_wrappedValue)
        }
    }
}
```

讀和寫只有在 `trackState()` 被呼叫之後，才會走 Compose 的 `MutableState`。在那之前，mutation 直接穿過去，Compose 完全不知道。

**`trackState()` 只有在持有 `@Observable` 實例的地方本身也被 Compose 追蹤時才會觸發**——也就是 `@State`、`@StateObject`，或 `.environment(_:)`。

我們的 MVVMC 模式是 `let viewModel: PostListViewModel`（從外面傳進來），Compose 沒有訂閱這個 `let`，`_state` 的 `Observed` wrapper 永遠沒被安裝，mutation 靜悄悄地發生，Compose 看不到。

### 修法：Launcher 包一層 `@State`

```swift
// AppEntry.swift（#if SKIP）
@MainActor
struct PostsLauncher: View {
    @State private var viewModel = PostListViewModel()
    var body: some View { PostListView(viewModel: viewModel) }
}
```

`@State` 讓 Compose 在第一次 composition 時就呼叫 `trackState()`，`MutableState` 綁定完成。之後的 mutation 正確觸發 recompose。

把 `NavigationLink` 目標從 `PostListView(viewModel: PostListViewModel())` 改成 `PostsLauncher()`，資料出現了。

### 這個修法跟 MVVMC 架構的關係

Launcher 是**Android 端的 C-layer**——跟 iOS 的 `PostListHostController` 扮演相同角色：持有 VM、橋接畫面和平台的導航原語。iOS 用 `UINavigationController`，Android 用 `NavigationStack`。`PostListView` 本身的 `let viewModel:` 慣例不用動。

這個發現影響了之後所有功能的設計：**每個需要 reactive state 的 Android 功能都需要一個 `@State`-owning 的 Launcher（後來演化成 HostController `#else` struct）**。

---

## 三、Profile：ViewModel 裡的 iOS-only API（M17）

Profile 功能有兩個 deeplink 按鈕和兩個推播按鈕。這些都靠 `UIApplication.shared.open(url)` 和 `UNUserNotificationCenter`——純 UIKit 的 API。

### 修法：外科 `#if !SKIP` 進 ViewModel

之前的 `#if !SKIP` 都是整個檔案包住（HostController）。Profile 第一次需要**在 ViewModel 內部**做 platform 分支：

```swift
// ProfileViewModel.swift
case .triggerDeeplink(let url):
    #if !SKIP
    await UIApplication.shared.open(url)
    #else
    _ = url  // Android no-op：deeplink 路由留給 Step 9 Router 設計
    #endif
```

`import UIKit` 和 `import UserNotifications` 搬到頂部的 `#if !SKIP` 塊。`Action` / `Router` enum cases 保持兩平台可見——call sites 不需要改。

**架構規則未動**：ViewModel 的 `doAction` 單一入口、Router enum、`@Observable` 形狀全部不變。變的只是 case body 的副作用。

---

## 四、UserDetail：`.task` 的第三道 gauntlet（M18）

PostList 的 runtime gauntlet 發現了 `@State` 問題。UserDetail 帶來了另一個：

### `.task` 在 NavigationStack push 時被取消

`UserDetailView` 用 `.task { await viewModel.doAction(.view(.isFirstAppear)) }` 觸發 API call，跟 `PostListView` 完全一樣的模式。PostList 正常運作。UserDetail 出現了：

```
skip.lib.ErrorException: kotlinx.coroutines.JobCancellationException:
Job was cancelled; job=JobImpl{Cancelled}@a10d29e
```

API 啟動，`Task.sleep(1s)` 開始等，coroutine 在睡眠途中被取消，`do/catch` 把取消當成錯誤捕捉，VM 觸發 `.fetchUserDidFinish(.failure(.message(...)))`，畫面渲染了一個錯誤訊息。

### 為什麼 UserDetail 會，PostList 不會？

`.task` 在 Compose 上是把 Task 綁定到 View 的 composition 生命週期——View 離開 composition，Task 就被取消。

UserDetail 用了 `.navigationBarTitleDisplayMode(.inline)`，這個 modifier 在 NavigationStack push 動畫過程中會強迫 title 區域額外 recompose 一次，足以把 View 暫時從 composition 移除再加回來，Task 在這個空窗期被取消。PostList 用的是預設（large title），沒有觸發這個額外 cycle。

### 修法：非結構化 Task

```swift
// 原本
.task { await viewModel.doAction(.view(UserDetailViewModel.ViewAction.isFirstAppear)) }

// 改成
.onAppear {
    Task { await viewModel.doAction(.view(UserDetailViewModel.ViewAction.isFirstAppear)) }
}
```

`.onAppear` 裡的 `Task { }` 是非結構化的——生命週期不綁 View composition，1 秒的 `Task.sleep` 能完整跑完，API 結果正確回來。

這是 **idiom #10**：當 View 有觸發額外 recompose 的 navigation modifier（確認的是 `.navigationBarTitleDisplayMode(.inline)`），把初始化 API call 從 `.task` 改成 `.onAppear { Task { } }`。

---

## 五、PostDetail：最輕鬆的那堵牆（M19）

PostDetail 是「純渲染」——state 在 init 設定，永遠不會 mutate。沒有 API，沒有 Router action，沒有 Task。

拆 `#if !SKIP`，加 Launcher，done。

Step 8 完成：六個 MVVMC 功能全部在 Android 上獨立渲染。

---

## 六、三道 gauntlet 總結

回顧完整的 Skip gauntlet 形狀：

| Gauntlet | 時間點 | 類型 | 修法 |
|---|---|---|---|
| #1 Transpile | M10–M12 | Swift → Kotlin 語法 | idiom #3 case where、#4 typed-let、#5 split case |
| #2 Kotlin compile | M13 | Transpiled Kotlin → AndroidX/Compose | idiom #6 qualifier、#7 explicit type、#8 API shim |
| #3 Runtime | M15–M18 | Compose snapshot 系統 | idiom #9 @State Launcher、#10 .onAppear Task |

每道 gauntlet 的形狀都不同，解法也不重疊。**「Skip 轉譯成功」和「Kotlin 編譯成功」和「Compose 正確 recompose」是三個獨立的關卡。**

---

## 七、Step 9：Router 接線

Step 8 結束時，六個功能能獨立渲染，但彼此孤立——PostList 的 row 點下去沒有 PostDetail，Profile 的「前往文章列表」按鈕沒有反應。

Step 9 的任務：把 iOS UIKit `AppRouter` 的導航語意，翻譯成 Android SwiftUI 的狀態驅動導航。

### 設計原則

使用者（本文作者）的指令是：**不建立新的 `*Router.swift`，而是在既有的 `*HostController.swift` 加 `#else` branch，實作同名的 SwiftUI struct**。

這讓每個 HostController 檔案同時包含兩個平台的 C-layer 實作，命名、init 簽名都相同：

```swift
// PostDetailHostController.swift

#if !SKIP
// iOS：UIHostingController 子類別
final class PostDetailHostController: UIHostingController<PostDetailView> {
    init(id: Int, title: String, body: String) { ... }
}
#else
// Android：SwiftUI struct，同名、同 init
struct PostDetailHostController: View {
    @State private var viewModel: PostDetailViewModel
    init(id: Int, title: String, body: String) {
        let post = PostDetailViewModel.Post(id: id, title: title, body: body)
        self._viewModel = State(initialValue: PostDetailViewModel(post: post))
    }
    var body: some View { PostDetailView(viewModel: viewModel) }
}
#endif
```

### Android AppRouter：Observable singleton

iOS 的 `AppRouter` 是 UIKit imperative（`to(_:from:)`、`back(from:)`）。Android 端加了一個 `#else` branch，換成 SwiftUI 宣告式狀態：

```swift
#else
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var tab: AppTab = .posts
    var postsPath: [AppRoute] = []
    var profilePath: [AppRoute] = []
    var sheetRoute: SheetRoute?
    var postFilterViewModel: PostFilterViewModel?

    func push(_ route: AppRoute) { ... }
    func switchTab(_ tab: AppTab) { ... }
    func presentSheet(_ route: SheetRoute) { ... }
    func dismissSheet() { ... }
}
#endif
```

Root view 的 `TabView` 把 `postsPath` / `profilePath` 綁到 `NavigationStack(path:)`，把 `sheetRoute` 綁到 `.sheet(item:)`。

### onRoute 訂閱模式

每個 `HostController #else` struct 在 `.onAppear` 裡綁 `viewModel.onRoute`，把 Router case 翻譯成 `AppRouter.shared` 的方法呼叫：

```swift
// PostListHostController.swift #else branch
private func bindRouter() {
    viewModel.onRoute = { router in
        switch router {
        case let .toDetail(post):
            AppRouter.shared.push(.postDetail(postId: post.id, title: post.title, body: post.body))
        case let .toUserDetail(userId):
            AppRouter.shared.push(.userDetail(userId: userId))
        case .toProfile:
            AppRouter.shared.switchTab(.profile)
        case .toFilter:
            let filterVM = PostFilterViewModel()
            filterVM.onCallback = { ... }
            AppRouter.shared.postFilterViewModel = filterVM
            AppRouter.shared.presentSheet(.postFilter)
        }
    }
}
```

這個形狀跟 iOS `PostListHostController.handleRouter(_:)` 幾乎是一對一的映射，只是把 UIKit 呼叫換成 `AppRouter.shared` 方法。

### PostFilter callback 的特殊處理

iOS 端，PostListHostController 建立 `PostFilterViewModel`，設好 `onCallback`，直接把整個 VM 傳給 `PostFilterHostController(viewModel:)`。兩個 VC 在記憶體裡直接溝通。

Android 端，`PostFilterHostController` 是透過 `.sheet(item:)` 由 root view 建立的，PostListHostController 沒辦法直接傳 VM 給它。

解法：PostListHostController 在 `presentSheet` 之前把設定好 callback 的 VM 存進 `AppRouter.shared.postFilterViewModel`，PostFilterHostController 在 `init` 時去讀它：

```swift
// PostFilterHostController.swift #else
struct PostFilterHostController: View {
    @State private var viewModel: PostFilterViewModel

    init() {
        self._viewModel = State(
            initialValue: AppRouter.shared.postFilterViewModel ?? PostFilterViewModel()
        )
    }
    var body: some View { PostFilterView(viewModel: viewModel) }
}
```

時序正確——PostListHostController 先 set，再 presentSheet，sheet 建立時 VM 已就位。

### 新舊 C-layer 並存的意義

完成 Step 9 之後，每個功能的 C-layer 都有兩個實作：

| 平台 | C-layer 型別 | 生命週期 | Router 訂閱方式 |
|---|---|---|---|
| iOS | `class *HostController: UIHostingController` | `viewDidLoad()` | closure 賦值 |
| Android | `struct *HostController: View` | `.onAppear` | closure 賦值 |

**MVVMC 架構的 C-layer 職責**（持有 VM、橋接導航、訂閱 Router）在兩平台上都成立，只是用不同的語言表達。

---

## 八、這一篇結束時，整個 MVVMC app 在哪裡

- **iOS**：UIKit MVVMC 架構完全未動。`UIApplicationMain → AppDelegate → SceneDelegate → UITabBarController → HostController → View` 的鏈條一條都沒斷。
- **Android**：`TabView(selection:)` + per-tab `NavigationStack(path:)` + `.sheet(item:)` 構成的 SwiftUI 導航圖，由 `AppRouter.shared` 統一管理狀態。六個功能的 Router 全部接通。

從同一份 Swift source 出發，兩個平台各跑自己的 C-layer，共用 M / VM / V 三層。

---

> 本篇涵蓋的 commit：M14（`9ecff44`）、M15（`800d40d`）、M16（`de014fc`）、M17（`6e812d4`）、M18（`c90c793`）、M19（`871e6ba`）、M20（`46be2f8`）、Step 9b（`ece0556`）、Step 9c（`cbbdd2a`）、Step 9d（`612a93a`）、Step 9e（`0d0675e`）、Step 9f（`b574a78`）
> 完整決策軌跡在 [`../CLAUDE.md`](../CLAUDE.md) Migration Log M14–M20。
