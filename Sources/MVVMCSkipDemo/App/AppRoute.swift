// Cross-feature navigation destinations addressable by value (Hashable),
// for use with SwiftUI's `NavigationStack(path:)`. Defined cross-platform
// (no `#if !SKIP`) because Skip transpiles the enum cleanly; the iOS
// codebase doesn't currently *use* it (iOS pushes UIKit HostController
// instances through `AppRouter.shared.to(_:from:)` directly), but having
// it visible on iOS keeps any cross-platform call sites — like a future
// Deeplink module — uniform.

import Foundation

// MARK: - Tabs

enum AppTab: Hashable, Sendable {
  case posts
  case profile
}

// MARK: - Routes

enum AppRoute: Hashable, Sendable {
  // `postId` / `userId` instead of `id` — Skip transpiles enum cases into
  // nested Kotlin classes where a parameter literally named `id` clashes
  // with the `id` property added by the `Identifiable` conformance below.
  case postDetail(postId: Int, title: String, body: String)
  case userDetail(userId: Int)
}

extension AppRoute: Identifiable {
  // Spelt as `AppRoute` instead of `Self` — Skip's transpiler doesn't
  // resolve `Self` in the Identifiable conformance position.
  var id: AppRoute { self }
}
