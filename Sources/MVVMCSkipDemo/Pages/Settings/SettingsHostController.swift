#if !SKIP
import SwiftUI

@MainActor
final class SettingsHostController: UIHostingController<SettingsView> {
  private let viewModel: SettingsViewModel

  init(viewModel: SettingsViewModel) {
    self.viewModel = viewModel
    super.init(rootView: SettingsView(viewModel: viewModel))
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

private extension SettingsHostController {
  func handleRouter(_ router: SettingsViewModel.Router) {
    switch router {
    case .close:
      AppRouter.shared.back(from: self)
    }
  }
}
#else
import SwiftUI

@MainActor
struct SettingsHostController: View {
  @State private var viewModel = SettingsViewModel()

  var body: some View {
    SettingsView(viewModel: viewModel)
      .onAppear { bindRouter() }
  }

  private func bindRouter() {
    viewModel.onRoute = { router in
      switch router {
      case .close:
        AppRouter.shared.dismissSheet()
      }
    }
  }
}
#endif
