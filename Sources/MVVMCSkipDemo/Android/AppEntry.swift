// Android-only entry-point types.
//
// Skip's `Android/app/src/main/kotlin/Main.kt` resolves the app root via the
// symbols `MVVMCSkipDemoRootView` and `MVVMCSkipDemoAppDelegate`. These names
// are Skip's canonical contract — the matching `typealias AppRootView = …` /
// `typealias AppDelegate = …` lines in Main.kt expect them.
//
// iOS deliberately does NOT use these types. The iOS entry chain is
// `UIApplicationMain → AppDelegate (App/) → SceneDelegate → UITabBarController`,
// preserving the MVVMC baseline lifecycle. This file is `#if SKIP` so it's
// invisible to the iOS Swift build.

#if SKIP
import SwiftUI

/// The Android root view. Mirrors iOS's `UITabBarController` structure:
/// `Posts` and `Profile` tabs, each with its own `NavigationStack` whose
/// path is bound to `AppRouter.shared` so feature-level `viewModel.onRoute`
/// callbacks can drive cross-feature navigation through a single
/// state-of-truth.
///
/// Per-tab navigation destinations (`PostDetail`, `UserDetail`, etc.) and
/// the shared sheet slot (`Settings`, `PostFilter`) are added in Step 9b–e
/// as each feature's `<Feature>HostController.swift` grows its `#else`
/// SwiftUI struct.
public struct MVVMCSkipDemoRootView: View {
  @Bindable private var appRouter = AppRouter.shared

  public init() {}

  public var body: some View {
    TabView(selection: $appRouter.tab) {
      NavigationStack(path: $appRouter.postsPath) {
        PostListHostController()
          .navigationDestination(for: AppRoute.self) { route in
            destinationView(for: route)
          }
      }
      .tabItem { Label("Posts", systemImage: "list.bullet") }
      .tag(AppTab.posts)

      NavigationStack(path: $appRouter.profilePath) {
        ProfileLauncher()
          .navigationDestination(for: AppRoute.self) { route in
            destinationView(for: route)
          }
      }
      .tabItem { Label("Profile", systemImage: "person") }
      .tag(AppTab.profile)
    }
    .sheet(item: $appRouter.sheetRoute) { route in
      sheetView(for: route)
    }
  }

  @ViewBuilder
  private func destinationView(for route: AppRoute) -> some View {
    switch route {
    case let .postDetail(postId, title, body):
      PostDetailHostController(id: postId, title: title, body: body)
    case let .userDetail(userId):
      UserDetailHostController(userId: userId)
    }
  }

  @ViewBuilder
  private func sheetView(for route: SheetRoute) -> some View {
    Text("Sheet not wired yet: \(String(describing: route))")
      .foregroundStyle(.secondary)
      .padding()
  }
}

@MainActor
struct ProfileLauncher: View {
  @State private var viewModel = ProfileViewModel()
  var body: some View { ProfileView(viewModel: viewModel) }
}

/// The Android `AppDelegate` analogue. Main.kt forwards lifecycle callbacks
/// (`onInit`, `onLaunch`, `onResume`, `onPause`, `onStop`, `onDestroy`,
/// `onLowMemory`) into `.shared`. Empty implementations are fine for now —
/// the iOS-side `AppDelegate` doesn't do anything in its callbacks either.
public final class MVVMCSkipDemoAppDelegate {
  public static let shared = MVVMCSkipDemoAppDelegate()
  private init() {}

  public func onInit() {}
  public func onLaunch() {}
  public func onResume() {}
  public func onPause() {}
  public func onStop() {}
  public func onDestroy() {}
  public func onLowMemory() {}
}
#endif
