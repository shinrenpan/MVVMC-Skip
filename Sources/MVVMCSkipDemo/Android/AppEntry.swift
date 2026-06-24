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

/// The Android root view. Starts as a flat index that lists each
/// successfully-ported feature; each Step 8 commit appends one
/// `NavigationLink` row. When the full MVVMC tab-bar surface is ported, the
/// root can switch to a `TabView` mirroring iOS's `Posts` / `Profile` tabs.
public struct MVVMCSkipDemoRootView: View {
  public init() {}

  public var body: some View {
    NavigationStack {
      List {
        Section("Ported features") {
          NavigationLink("Settings") {
            SettingsView(viewModel: SettingsViewModel())
          }
          NavigationLink("Filter by User") {
            PostFilterView(viewModel: PostFilterViewModel())
          }
          NavigationLink("Posts") {
            PostListView(viewModel: PostListViewModel())
          }
        }
      }
      .navigationTitle("MVVMC × Skip")
    }
  }
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
