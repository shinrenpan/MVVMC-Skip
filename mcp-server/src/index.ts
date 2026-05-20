import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

// MARK: - MVVMC Content

const ARCHITECTURE_OVERVIEW = `
# MVVMC 架構總覽

四層職責嚴格分離，SwiftUI + UIKit 混合架構，iOS 17+。

| 層 | 檔案命名 | 職責 |
|---|---|---|
| M | FeatureViewModel+Models.swift | State / Domain Models / DTOs |
| VM | FeatureViewModel.swift + FeatureViewModel+APIs.swift | @Observable @MainActor，doAction 單一進入點 |
| V | FeatureView.swift | 純 SwiftUI，零導航邏輯 |
| C | FeatureHostController.swift | UIKit 橋接，Router 導航唯一責任者 |

## Feature 建立順序
M → VM → V → C

## 標準檔案結構
\`\`\`
Pages/FeatureName/
├── FeatureNameViewModel+Models.swift   ← M
├── FeatureNameViewModel.swift          ← VM
├── FeatureNameViewModel+APIs.swift     ← VM（EndPoint 定義，視需要）
├── FeatureNameView.swift               ← V
├── FeatureNameMocks.swift              ← Mock（#if DEBUG，視需要）
└── FeatureNameHostController.swift     ← C
\`\`\`

## 資料流
\`\`\`
使用者操作
  → View: Task { await viewModel.doAction(.view(.xxx)) }
  → VM handleViewAction → doAction(.apiRequest(...))

API 請求:
  → VM handleAPIRequest → 呼叫 API → doAction(.apiResponse(...))
  → VM handleAPIResponse → 更新 state → View 自動刷新

導航:
  → VM: onRoute?(.toXxx)
  → HostController → AppRouter.shared.to(vc, from: self)

跨 VC 回傳:
  → 子 VM: onCallback?(.xxx)
  → 父 HostController → AppRouter.shared.back(from: self) → 處理結果
\`\`\`
`.trim();

const LAYER_GUIDES: Record<string, string> = {
  M: `
# M 層（Models）規範

檔案：FeatureNameViewModel+Models.swift

常見三個區塊：State / Domain Models / DTOs，各區塊用獨立 extension 隔開。

| 區塊 | 抽象層次 | 消費者 |
|---|---|---|
| State | UI 狀態 | SwiftUI View，直接綁定 |
| Domain Models | 業務語意 | ViewModel 邏輯、State |
| DTOs | API 原始資料 | Network Layer，解碼後立即 mapping |

## 規則
- State 是 struct，遵守 Sendable，所有欄位給定預設值
- DTO 是 Codable & Sendable struct，保留 API response 所有欄位
- DTO property 命名直接使用 API response key（如 user_id），不需要 CodingKeys
- DTO 提供 toDomain() 轉換為 Domain Model
- State 不持有 DTO

## 範例
\`\`\`swift
// MARK: - State
extension FeatureViewModel {
  struct State: Sendable {
    var items: [Item] = []
  }
}

// MARK: - Domain Models
extension FeatureViewModel {
  struct Item: Identifiable, Sendable {
    let id: String
    var name: String
  }
}

// MARK: - DTOs
extension FeatureViewModel {
  struct ItemDTO: Codable, Sendable {
    var item_id: String
    var item_name: String

    func toDomain() -> Item? {
      guard !item_id.isEmpty else { return nil }
      return .init(id: item_id, name: item_name)
    }
  }
}
\`\`\`
`.trim(),

  VM: `
# VM 層（ViewModel）規範

檔案：FeatureNameViewModel.swift（+ FeatureNameViewModel+APIs.swift）

## 核心結構
\`\`\`swift
@MainActor
@Observable
final class FeatureViewModel {
  enum Action: Sendable {
    case view(ViewAction)
    case apiRequest(APIRequest)
    case apiResponse(APIResponse)
  }

  var state: State = .init()

  @ObservationIgnored var onRoute: (@MainActor (Router) -> Void)?
  @ObservationIgnored var onCallback: (@MainActor (Callback) async -> Void)?

  func doAction(_ action: Action) async {
    switch action {
    case let .view(a):        await handleViewAction(a)
    case let .apiRequest(a):  await handleAPIRequest(a)
    case let .apiResponse(a): await handleAPIResponse(a)
    }
  }
}
\`\`\`

## 規則
- @MainActor @Observable final class
- 單一進入點：func doAction(_ action: Action) async
- onRoute — HostController 設定（同步），接收導航事件
- onCallback — 父 HostController 設定（async），接收跨 VC 回傳值
- 非 UI 相關 property 標注 @ObservationIgnored
- Router 不自行導航，統一呼叫 onRoute?(.toXxx)
- 跨 VC 回傳在 doAction handler 內呼叫 await onCallback?(.xxx)

## onCallback 使用
\`\`\`swift
// 子 ViewModel
case .didSelectItem(let item):
  await onCallback?(.didSelectItem(item))

// 父 HostController（不需要 Task）
childViewModel.onCallback = { [weak self] callback in
  guard let self else { return }
  switch callback {
  case .didSelectItem(let item):
    AppRouter.shared.back(from: self)
    await self.viewModel.doAction(.view(.itemSelected(item)))
  }
}
\`\`\`
`.trim(),

  V: `
# V 層（View）規範

檔案：FeatureNameView.swift

## 規則
- viewModel 以 let 持有（@Observable 自動追蹤，不需 @State 或 @Bindable）
- 使用者互動統一：Task { await viewModel.doAction(.view(.xxx)) }
- 子 View 做成 private extension FeatureView { struct SubView: View {...} }
- 子 View 若需回傳 action，接收 let doAction: @MainActor (Action) -> Void closure
- 零導航邏輯，零業務邏輯

## 範例
\`\`\`swift
struct FeatureView: View {
  let viewModel: FeatureViewModel

  var body: some View {
    List(viewModel.state.items) { item in
      Text(item.name)
        .onTapGesture {
          Task { await viewModel.doAction(.view(.itemDidTap(item))) }
        }
    }
    .navigationTitle("Title")
    .task {
      await viewModel.doAction(.view(.isFirstAppear))
    }
  }
}
\`\`\`

## 只執行一次（viewDidLoad 等價）
\`\`\`swift
// ViewAction
case isFirstAppear  // run once
case pullToRefresh  // 每次都跑

// ViewModel
case .isFirstAppear:
  guard state.isFirstAppear else { return }
  state.isFirstAppear = false
  await doAction(.apiRequest(.loadData))
\`\`\`
`.trim(),

  C: `
# C 層（HostController）規範

檔案：FeatureNameHostController.swift

## 核心結構
\`\`\`swift
@MainActor
final class FeatureHostController: UIHostingController<FeatureView> {
  private let viewModel: FeatureViewModel

  init(viewModel: FeatureViewModel) {
    self.viewModel = viewModel
    super.init(rootView: FeatureView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onRoute = { [weak self] router in
      self?.handleRouter(router)
    }
  }
}

private extension FeatureHostController {
  func handleRouter(_ router: FeatureViewModel.Router) {
    switch router {
    case let .toDetail(item):
      AppRouter.shared.to(DetailHostController(item: item), from: self)
    case .toFilter:
      let filterVM = FilterViewModel()
      filterVM.onCallback = { [weak self] callback in
        guard let self else { return }
        AppRouter.shared.back(from: self)
        await self.viewModel.doAction(.view(.filterApplied(callback)))
      }
      AppRouter.shared.to(FilterHostController(viewModel: filterVM), from: self, style: .modal)
    }
  }
}
\`\`\`

## 規則
- @MainActor final class，繼承 UIHostingController<FeatureView>
- 純 Router：所有導航透過 AppRouter.shared（to / sheet / back / backTo / backToRoot / tab / deeplink）
- ❌ 禁止直接呼叫 navigationController?.pushViewController / present / dismiss
- ❌ 禁止在 HostController 內寫業務邏輯
- ❌ 禁止 HostController 直接操作 ViewModel 的 state
- ❌ 禁止 HostController 啟動 Task 觸發 ViewModel 邏輯
- viewDidLoad：設定 viewModel.onRoute / onCallback
- closure 用 [weak self]，不需要手動 nil 清空
- required init?(coder:) 標記 @available(*, unavailable) + fatalError

## 跨 feature 傳 primitive
\`\`\`swift
// 父 HostController 傳 primitive，子 C 層組裝 ViewModel
init(id: Int, title: String, body: String) {
  let post = PostDetailViewModel.Post(id: id, title: title, body: body)
  let viewModel = PostDetailViewModel(post: post)
  super.init(rootView: PostDetailView(viewModel: viewModel))
}
\`\`\`
`.trim(),
};

const APPROUTER_GUIDE = `
# AppRouter 規範

AppRouter.shared 是 App 唯一的導航入口。

## API 一覽
\`\`\`swift
// 前進（預設 push，原生右滑返回）
AppRouter.shared.to(DetailHostController(...), from: self)

// 前進（自訂轉場）
AppRouter.shared.to(FilterHostController(...), from: self, style: .modal)  // 由下往上
AppRouter.shared.to(SomeHostController(...), from: self, style: .fade)     // 淡入淡出

// Sheet（系統 pageSheet）
AppRouter.shared.sheet(SomeHostController(...), from: self)
AppRouter.shared.sheet(UINavigationController(rootViewController: SettingsHostController(...)), from: self)
AppRouter.shared.sheet(SomeHostController(...), from: self, detents: [.medium()])

// 後退（自動判斷：sheet → dismiss，其他 → pop）
AppRouter.shared.back(from: self)

// 後退到指定 VC
AppRouter.shared.backTo(targetVC, from: self)

// 後退到 root
AppRouter.shared.backToRoot(from: self)

// 切換 Tab
AppRouter.shared.tab(1, from: self)

// Deeplink（fullScreen present from rootVC，自動注入 Close button）
AppRouter.shared.deeplink(SomeHostController(...))
\`\`\`

## 設計原則
- 無狀態：不持有任何 stored property
- assertionFailure：source.navigationController 為 nil → developer 架構錯誤，Debug 立即崩潰
- 轉場動畫：UINavigationControllerDelegate，支援 .modal / .fade
- back() 自動判斷：appTransitionStyle == .sheet → dismiss，其他 → pop
- deeplink() 內部取 rootViewController，不需要 from: 參數

## SceneDelegate 設定
\`\`\`swift
let nav = UINavigationController(rootViewController: RootHostController())
window.rootViewController = nav
window.backgroundColor = .systemBackground  // 避免轉場黑背景
\`\`\`

AppRouter 在第一次 to() 時自動設定 nav.delegate 與手勢處理。
`.trim();

const DEEPLINK_GUIDE = `
# Deeplink / Push Notification 規範

## Deeplink enum（Sources/App/Deeplink.swift）
\`\`\`swift
enum Deeplink {
  case settings
  case postDetail(id: Int)

  init?(url: URL) {
    guard url.scheme == "myapp" else { return nil }
    switch url.host {
    case "settings": self = .settings
    case "posts":
      guard let id = url.pathComponents.dropFirst().first.flatMap(Int.init) else { return nil }
      self = .postDetail(id: id)
    default: return nil
    }
  }

  @MainActor func makeHostController() -> UIViewController {
    switch self {
    case .settings:           return SettingsHostController(viewModel: .init())
    case let .postDetail(id): return PostDetailHostController(id: id, ...)
    }
  }
}
\`\`\`

## SceneDelegate 三個入口
\`\`\`swift
// 1. 前景 / 背景 → URL Scheme
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
  guard let url = URLContexts.first?.url,
        let deeplink = Deeplink(url: url) else { return }
  AppRouter.shared.deeplink(deeplink.makeHostController())
}

// 2. Cold start → URL Scheme（makeKeyAndVisible 之後）
if let url = connectionOptions.urlContexts.first?.url,
   let deeplink = Deeplink(url: url) {
  AppRouter.shared.deeplink(deeplink.makeHostController())
}

// 3. 推播點擊（nonisolated，Task @MainActor 跳回 main）
nonisolated func userNotificationCenter(
  _ center: UNUserNotificationCenter,
  didReceive response: UNNotificationResponse,
  withCompletionHandler completionHandler: @escaping () -> Void
) {
  defer { completionHandler() }
  guard let urlString = response.notification.request.content.userInfo["deeplink"] as? String,
        let url = URL(string: urlString),
        let deeplink = Deeplink(url: url) else { return }
  Task { @MainActor in AppRouter.shared.deeplink(deeplink.makeHostController()) }
}
\`\`\`

## 推播 payload 約定
\`\`\`json
{ "deeplink": "myapp://settings" }
{ "deeplink": "myapp://posts/1" }
\`\`\`

## URL Scheme 設定（project.yml）
\`\`\`yaml
CFBundleURLTypes:
  - CFBundleURLName: com.your.bundle.id
    CFBundleURLSchemes:
      - myapp
\`\`\`
`.trim();

// MARK: - MCP Server

const server = new Server(
  { name: "mcp-mvvmc", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "get_architecture_overview",
      description:
        "MVVMC 整體架構說明：四層職責、檔案結構、資料流。適合開始新 feature 或需要理解整體架構時使用。",
      inputSchema: { type: "object", properties: {} },
    },
    {
      name: "get_layer_guide",
      description:
        "取得特定層的詳細規範與程式碼範例。layer 參數：M（Models）、VM（ViewModel）、V（View）、C（HostController）。",
      inputSchema: {
        type: "object",
        properties: {
          layer: {
            type: "string",
            enum: ["M", "VM", "V", "C"],
            description: "架構層級",
          },
        },
        required: ["layer"],
      },
    },
    {
      name: "get_approuter_guide",
      description:
        "AppRouter 完整 API 說明：to / sheet / back / backTo / backToRoot / tab / deeplink 的使用方式與設計原則。",
      inputSchema: { type: "object", properties: {} },
    },
    {
      name: "get_deeplink_guide",
      description:
        "Deeplink 與 Push Notification 處理模式：Deeplink enum 設計、SceneDelegate 三個入口、推播 payload 約定。",
      inputSchema: { type: "object", properties: {} },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case "get_architecture_overview":
      return { content: [{ type: "text", text: ARCHITECTURE_OVERVIEW }] };

    case "get_layer_guide": {
      const layer = (args as { layer: string }).layer;
      const guide = LAYER_GUIDES[layer];
      if (!guide) {
        return {
          content: [{ type: "text", text: `未知層級：${layer}。請使用 M / VM / V / C。` }],
          isError: true,
        };
      }
      return { content: [{ type: "text", text: guide }] };
    }

    case "get_approuter_guide":
      return { content: [{ type: "text", text: APPROUTER_GUIDE }] };

    case "get_deeplink_guide":
      return { content: [{ type: "text", text: DEEPLINK_GUIDE }] };

    default:
      return {
        content: [{ type: "text", text: `未知 tool：${name}` }],
        isError: true,
      };
  }
});

// MARK: - Start

const transport = new StdioServerTransport();
await server.connect(transport);
