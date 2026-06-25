#if !SKIP
import SwiftUI

@MainActor
final class PostDetailHostController: UIHostingController<PostDetailView> {
  private let viewModel: PostDetailViewModel

  init(id: Int, title: String, body: String) {
    let post = PostDetailViewModel.Post(id: id, title: title, body: body)
    self.viewModel = PostDetailViewModel(post: post)
    super.init(rootView: PostDetailView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
}
#else
import SwiftUI

// Android C-layer equivalent of the iOS UIHostingController above.
// Owns the VM via @State so Compose's snapshot system registers it.
@MainActor
struct PostDetailHostController: View {
  @State private var viewModel: PostDetailViewModel

  init(id: Int, title: String, body: String) {
    let post = PostDetailViewModel.Post(id: id, title: title, body: body)
    self._viewModel = State(initialValue: PostDetailViewModel(post: post))
  }

  var body: some View {
    PostDetailView(viewModel: viewModel)
  }
}
#endif
