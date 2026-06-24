#if !SKIP
import UIKit

// `@main` lives in Darwin/Sources/Main.swift (an iOS app target can only
// declare its entry inside its own sources, not inside a linked library).
// `public` lets `Darwin/Sources/Main.swift` reference this type for
// `NSStringFromClass(AppDelegate.self)`.
public final class AppDelegate: UIResponder, UIApplicationDelegate {
  public override init() { super.init() }

  public func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }
}
#endif
