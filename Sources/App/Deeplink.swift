import UIKit

// MARK: - Deeplink

enum Deeplink {
  case settings
  case postDetail(id: Int)
}

// MARK: - URL Parsing

extension Deeplink {
  init?(url: URL) {
    guard url.scheme == "mvvmc" else { return nil }
    switch url.host {
    case "settings":
      self = .settings
    case "posts":
      guard let idString = url.pathComponents.dropFirst().first,
            let id = Int(idString) else { return nil }
      self = .postDetail(id: id)
    default:
      return nil
    }
  }
}

// MARK: - HostController Factory

extension Deeplink {
  @MainActor func makeHostController() -> UIViewController {
    switch self {
    case .settings:
      return SettingsHostController(viewModel: .init())
    case let .postDetail(id):
      return PostDetailHostController(id: id, title: "Post #\(id)", body: "")
    }
  }
}
