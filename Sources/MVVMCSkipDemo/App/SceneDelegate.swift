import UIKit
import UserNotifications

// `public` so UIKit's `NSClassFromString("$(PRODUCT_MODULE_NAME).SceneDelegate")`
// in Info.plist's scene manifest resolves to this class across the library
// boundary.
@MainActor
public final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  public override init() { super.init() }

  public var window: UIWindow?

  public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url,
          let deeplink = Deeplink(url: url) else { return }
    AppRouter.shared.deeplink(deeplink.makeHostController())
  }

  public func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let postsNav = UINavigationController(rootViewController: PostListHostController(viewModel: .init()))
    postsNav.tabBarItem = UITabBarItem(title: "Posts", image: UIImage(systemName: "list.bullet"), tag: 0)

    let profileNav = UINavigationController(rootViewController: ProfileHostController())
    profileNav.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), tag: 1)

    let tabBar = UITabBarController()
    tabBar.viewControllers = [postsNav, profileNav]

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = tabBar
    window.backgroundColor = .systemBackground
    window.makeKeyAndVisible()
    self.window = window

    UNUserNotificationCenter.current().delegate = self

    if let url = connectionOptions.urlContexts.first?.url,
       let deeplink = Deeplink(url: url) {
      AppRouter.shared.deeplink(deeplink.makeHostController())
    }
  }
}

// MARK: - UNUserNotificationCenterDelegate

extension SceneDelegate: UNUserNotificationCenterDelegate {
  public nonisolated func userNotificationCenter(
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

  public nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
