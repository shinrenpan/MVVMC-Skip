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

/// The Android root view. Step 7d renders only `Settings` as a proof of life;
/// later steps will mirror iOS's `Posts` / `Profile` tab structure.
public struct MVVMCSkipDemoRootView: View {
  public init() {}

  public var body: some View {
    NavigationStack {
      SettingsView(viewModel: SettingsViewModel())
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
