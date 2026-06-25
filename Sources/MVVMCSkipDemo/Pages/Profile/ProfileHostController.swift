#if !SKIP
import SwiftUI

@MainActor
final class ProfileHostController: UIHostingController<ProfileView> {
  private let viewModel: ProfileViewModel

  init() {
    let viewModel = ProfileViewModel()
    self.viewModel = viewModel
    super.init(rootView: ProfileView(viewModel: viewModel))
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

// MARK: - Router

private extension ProfileHostController {
  func handleRouter(_ router: ProfileViewModel.Router) {
    switch router {
    case .toPosts:
      AppRouter.shared.tab(0, from: self)
    case .toSettings:
      let nav = UINavigationController(rootViewController: SettingsHostController(viewModel: .init()))
      AppRouter.shared.sheet(nav, from: self)
    }
  }
}
#else
import SwiftUI

@MainActor
struct ProfileHostController: View {
  @State private var viewModel = ProfileViewModel()

  var body: some View {
    ProfileView(viewModel: viewModel)
      .onAppear { bindRouter() }
  }

  private func bindRouter() {
    viewModel.onRoute = { router in
      switch router {
      case .toPosts:
        AppRouter.shared.switchTab(.posts)
      case .toSettings:
        AppRouter.shared.presentSheet(.settings)
      }
    }
  }
}
#endif
