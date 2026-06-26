#if !SKIP
import UIKit

// MARK: - TransitionStyle

extension AppRouter {
  enum TransitionStyle: Equatable {
    case push
    case modal
    case fade
    case sheet
  }
}

// MARK: - UIViewController + appTransitionStyle

private final class TransitionStyleBox {
  let style: AppRouter.TransitionStyle
  init(_ style: AppRouter.TransitionStyle) { self.style = style }
}

nonisolated(unsafe) private var appTransitionStyleKey: UInt8 = 0

extension UIViewController {
  fileprivate var appTransitionStyle: AppRouter.TransitionStyle {
    get { (objc_getAssociatedObject(self, &appTransitionStyleKey) as? TransitionStyleBox)?.style ?? .push }
    set { objc_setAssociatedObject(self, &appTransitionStyleKey, TransitionStyleBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
  }
}

// MARK: - AppRouter

@MainActor
final class AppRouter: NSObject {
  static let shared = AppRouter()
  private override init() {}

  func to(_ destination: UIViewController, from source: UIViewController, style: TransitionStyle = .push, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.to(): source VC 沒有 navigationController，請確認 rootViewController 設定為 UINavigationController")
      return
    }
    if nav.delegate !== self {
      nav.delegate = self
      nav.interactivePopGestureRecognizer?.isEnabled = true
      nav.interactivePopGestureRecognizer?.delegate = self
      if #available(iOS 26, *) {
        nav.interactiveContentPopGestureRecognizer?.isEnabled = true
        nav.interactiveContentPopGestureRecognizer?.delegate = self
      }
    }
    destination.appTransitionStyle = style
    nav.pushViewController(destination, animated: animated)
  }

  func back(from source: UIViewController, animated: Bool = true) {
    let style = source.appTransitionStyle != .push
      ? source.appTransitionStyle
      : source.navigationController?.appTransitionStyle ?? .push
    switch style {
    case .sheet:
      (source.navigationController ?? source).dismiss(animated: animated)
    default:
      guard let nav = source.navigationController else {
        assertionFailure("AppRouter.back(): source VC 沒有 navigationController")
        return
      }
      nav.popViewController(animated: animated)
    }
  }

  func backTo(_ destination: UIViewController, from source: UIViewController, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.backTo(): source VC 沒有 navigationController")
      return
    }
    nav.popToViewController(destination, animated: animated)
  }

  func backToRoot(from source: UIViewController, animated: Bool = true) {
    guard let nav = source.navigationController else {
      assertionFailure("AppRouter.backToRoot(): source VC 沒有 navigationController")
      return
    }
    nav.popToRootViewController(animated: animated)
  }

  func sheet(
    _ destination: UIViewController,
    from source: UIViewController,
    detents: [UISheetPresentationController.Detent]? = nil,
    animated: Bool = true
  ) {
    destination.appTransitionStyle = .sheet
    destination.modalPresentationStyle = .pageSheet
    if let detents {
      destination.sheetPresentationController?.detents = detents
    }
    source.present(destination, animated: animated)
  }

  func deeplink(_ destination: UIViewController, animated: Bool = true) {
    let rootVC = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?.keyWindow?.rootViewController
    guard let rootVC else {
      assertionFailure("AppRouter.deeplink(): 找不到 rootViewController")
      return
    }
    destination.appTransitionStyle = .sheet
    destination.navigationItem.leftBarButtonItem = UIBarButtonItem(
      systemItem: .close,
      primaryAction: UIAction { [weak destination] _ in
        destination?.dismiss(animated: true)
      }
    )
    let nav = UINavigationController(rootViewController: destination)
    nav.modalPresentationStyle = .fullScreen
    rootVC.present(nav, animated: animated)
  }

  func tab(_ index: Int, from source: UIViewController) {
    guard let tabBar = source.tabBarController else {
      assertionFailure("AppRouter.tab(): source VC 沒有 tabBarController，請確認 rootViewController 設定為 UITabBarController")
      return
    }
    tabBar.selectedIndex = index
  }
}

// MARK: - UINavigationControllerDelegate

extension AppRouter: UINavigationControllerDelegate {
  func navigationController(
    _ navigationController: UINavigationController,
    animationControllerFor operation: UINavigationController.Operation,
    from fromVC: UIViewController,
    to toVC: UIViewController
  ) -> (any UIViewControllerAnimatedTransitioning)? {
    let style = operation == .push ? toVC.appTransitionStyle : fromVC.appTransitionStyle
    guard style != .push, style != .sheet else { return nil }
    return AppTransitionAnimator(style: style, isPush: operation == .push)
  }
}

// MARK: - UIGestureRecognizerDelegate

extension AppRouter: UIGestureRecognizerDelegate {
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let nav = gestureRecognizer.view?.next as? UINavigationController else { return true }
    guard nav.viewControllers.count > 1 else { return false }
    return (nav.topViewController?.appTransitionStyle ?? .push) == .push
  }
}

// MARK: - AppTransitionAnimator

private final class AppTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  let style: AppRouter.TransitionStyle
  let isPush: Bool

  init(style: AppRouter.TransitionStyle, isPush: Bool) {
    self.style = style
    self.isPush = isPush
  }

  func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval { 0.35 }

  func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
    switch style {
    case .modal: animateModal(transitionContext)
    case .fade:  animateFade(transitionContext)
    case .push, .sheet: transitionContext.completeTransition(true)
    }
  }
}

private extension AppTransitionAnimator {
  func animateModal(_ ctx: any UIViewControllerContextTransitioning) {
    let duration = transitionDuration(using: ctx)
    if isPush {
      guard let toVC = ctx.viewController(forKey: .to), let toView = ctx.view(forKey: .to) else {
        ctx.completeTransition(false); return
      }
      let finalFrame = ctx.finalFrame(for: toVC)
      toView.frame = finalFrame.offsetBy(dx: 0, dy: finalFrame.height)
      ctx.containerView.addSubview(toView)
      UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut) {
        toView.frame = finalFrame
      } completion: { _ in
        ctx.completeTransition(!ctx.transitionWasCancelled)
      }
    } else {
      guard let fromVC = ctx.viewController(forKey: .from),
            let fromView = ctx.view(forKey: .from),
            let toView = ctx.view(forKey: .to) else {
        ctx.completeTransition(false); return
      }
      ctx.containerView.insertSubview(toView, belowSubview: fromView)
      let initialFrame = ctx.initialFrame(for: fromVC)
      UIView.animate(withDuration: duration, delay: 0, options: .curveEaseIn) {
        fromView.frame = initialFrame.offsetBy(dx: 0, dy: initialFrame.height)
      } completion: { _ in
        ctx.completeTransition(!ctx.transitionWasCancelled)
      }
    }
  }

  func animateFade(_ ctx: any UIViewControllerContextTransitioning) {
    let duration = transitionDuration(using: ctx)
    if isPush {
      guard let toView = ctx.view(forKey: .to) else { ctx.completeTransition(false); return }
      toView.alpha = 0
      ctx.containerView.addSubview(toView)
      UIView.animate(withDuration: duration) {
        toView.alpha = 1
      } completion: { _ in
        ctx.completeTransition(!ctx.transitionWasCancelled)
      }
    } else {
      guard let fromView = ctx.view(forKey: .from),
            let toView = ctx.view(forKey: .to) else {
        ctx.completeTransition(false); return
      }
      ctx.containerView.insertSubview(toView, belowSubview: fromView)
      UIView.animate(withDuration: duration) {
        fromView.alpha = 0
      } completion: { _ in
        ctx.completeTransition(!ctx.transitionWasCancelled)
      }
    }
  }
}

#else

// MARK: - AppTab / AppRoute / SheetRoute (Android-only navigation types)

import Observation
import SwiftUI

enum AppTab: Hashable, Sendable {
  case posts
  case profile
}

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

// MARK: - AppRouter (Android equivalent)
//
// Mirrors the iOS UIKit AppRouter as a SwiftUI navigation-state singleton.
// Owns the per-tab NavigationStack path arrays and the sheet/dismiss state
// driven by `viewModel.onRoute` translations inside each feature's
// `<Feature>HostController.swift` `#else` branch. Same call sites
// (`AppRouter.shared.push(...)`, `.popToCurrentRoot()`, `.switchTab(...)`,
// `.presentSheet(...)`, `.dismissSheet()`) read uniformly on both platforms.

@MainActor
@Observable
final class AppRouter {
  static let shared = AppRouter()
  private init() {}

  // Current tab.
  var tab: AppTab = .posts

  // Per-tab path stacks — bound to `NavigationStack(path:)` in the root view.
  var postsPath: [AppRoute] = []
  var profilePath: [AppRoute] = []

  // Single shared "modal sheet" slot. Feature hosts that want a sheet
  // (Settings from Profile, PostFilter from PostList) write into here;
  // the root view binds it via `.sheet(item:)`.
  var sheetRoute: SheetRoute?

  // PostFilter's VM is created by PostListHostController before presenting
  // the sheet, so PostFilterHostController can read it here and attach the
  // callback that routes results back to PostList.
  var postFilterViewModel: PostFilterViewModel?

  // MARK: - Path operations

  func push(_ route: AppRoute) {
    switch tab {
    case .posts:   postsPath.append(route)
    case .profile: profilePath.append(route)
    }
  }

  func popToCurrentRoot() {
    switch tab {
    case .posts:   postsPath.removeAll()
    case .profile: profilePath.removeAll()
    }
  }

  func switchTab(_ tab: AppTab) {
    self.tab = tab
  }

  // MARK: - Sheet operations

  func presentSheet(_ route: SheetRoute) {
    sheetRoute = route
  }

  func dismissSheet() {
    sheetRoute = nil
  }
}

// MARK: - SheetRoute

/// Routes that appear as a modal sheet rather than a NavigationStack push.
/// Kept separate from `AppRoute` because `.sheet(item:)` and
/// `NavigationStack(path:)` consume different state slots, and lumping them
/// into one enum would require both binding sites to filter.
enum SheetRoute: Hashable, Sendable, Identifiable {
  case settings
  case postFilter

  var id: SheetRoute { self }
}

#endif
