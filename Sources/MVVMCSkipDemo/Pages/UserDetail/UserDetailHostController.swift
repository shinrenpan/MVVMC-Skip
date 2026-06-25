#if !SKIP
import SwiftUI

@MainActor
final class UserDetailHostController: UIHostingController<UserDetailView> {
  private let viewModel: UserDetailViewModel

  init(userId: Int) {
    let viewModel = UserDetailViewModel(userId: userId)
    self.viewModel = viewModel
    super.init(rootView: UserDetailView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
}
#else
import SwiftUI

@MainActor
struct UserDetailHostController: View {
  @State private var viewModel: UserDetailViewModel

  init(userId: Int) {
    self._viewModel = State(initialValue: UserDetailViewModel(userId: userId))
  }

  var body: some View {
    UserDetailView(viewModel: viewModel)
  }
}
#endif
