#if !SKIP
import SwiftUI

@MainActor
final class PostFilterHostController: UIHostingController<PostFilterView> {
  private let viewModel: PostFilterViewModel

  init(viewModel: PostFilterViewModel) {
    self.viewModel = viewModel
    super.init(rootView: PostFilterView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
}
#else
import SwiftUI

// Android C-layer for PostFilter. On iOS, PostListHostController creates the
// PostFilterViewModel, sets its onCallback, and passes it to this controller
// directly. On Android the same VM is stored in AppRouter.shared.postFilterViewModel
// before presentSheet(.postFilter) fires, so this struct can read it at init time.
@MainActor
struct PostFilterHostController: View {
  @State private var viewModel: PostFilterViewModel

  init() {
    self._viewModel = State(initialValue: AppRouter.shared.postFilterViewModel ?? PostFilterViewModel())
  }

  var body: some View {
    PostFilterView(viewModel: viewModel)
  }
}
#endif
