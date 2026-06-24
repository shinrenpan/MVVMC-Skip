// iOS app entry point.
//
// Skip Lite's canonical Main.swift is a SwiftUI `@main struct AppMain: App`,
// designed to share lifecycle code with Android. MVVMC-Skip deliberately
// preserves the UIKit AppDelegate + SceneDelegate lifecycle on iOS, so this
// file is a thin shim that boots UIApplicationMain pointing at the
// AppDelegate exported by the MVVMCSkipDemo SPM library.
//
// The Android entry point lives in Android/Sources/, not here — they do not
// share a Main.

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
