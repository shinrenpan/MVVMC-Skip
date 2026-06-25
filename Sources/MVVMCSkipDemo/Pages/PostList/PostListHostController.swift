#if !SKIP
import SwiftUI

@MainActor
final class PostListHostController: UIHostingController<PostListView> {
  private let viewModel: PostListViewModel

  init(viewModel: PostListViewModel) {
    self.viewModel = viewModel
    super.init(rootView: PostListView(viewModel: viewModel))
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

private extension PostListHostController {
  func handleRouter(_ router: PostListViewModel.Router) {
    switch router {
    case let .toDetail(post):
      AppRouter.shared.to(PostDetailHostController(id: post.id, title: post.title, body: post.body), from: self)

    case let .toUserDetail(userId):
      AppRouter.shared.to(UserDetailHostController(userId: userId), from: self, style: .fade)

    case .toProfile:
      AppRouter.shared.tab(1, from: self)

    case .toFilter:
      let filterVM = PostFilterViewModel()
      filterVM.onCallback = { [weak self] callback in
        guard let self else { return }
        switch callback {
        case let .didSelectUser(user):
          AppRouter.shared.back(from: self)
          await self.viewModel.doAction(.view(.didFilterUser(user.id)))
        case .showAll:
          AppRouter.shared.back(from: self)
          await self.viewModel.doAction(.view(.clearFilter))
        case .didCancel:
          AppRouter.shared.back(from: self)
        }
      }
      AppRouter.shared.to(PostFilterHostController(viewModel: filterVM), from: self, style: .modal)
    }
  }
}
#else
import SwiftUI

// Android C-layer for PostList. Mirrors the iOS HostController pattern:
// owns the VM, subscribes onRoute, and drives AppRouter.shared for navigation.
@MainActor
struct PostListHostController: View {
  @State private var viewModel = PostListViewModel()

  var body: some View {
    PostListView(viewModel: viewModel)
      .onAppear { bindRouter() }
  }

  private func bindRouter() {
    viewModel.onRoute = { router in
      switch router {
      case let .toDetail(post):
        AppRouter.shared.push(.postDetail(postId: post.id, title: post.title, body: post.body))

      case let .toUserDetail(userId):
        AppRouter.shared.push(.userDetail(userId: userId))

      case .toProfile:
        AppRouter.shared.switchTab(.profile)

      case .toFilter:
        let filterVM = PostFilterViewModel()
        filterVM.onCallback = { [weak viewModel] callback in
          switch callback {
          case let .didSelectUser(user):
            AppRouter.shared.dismissSheet()
            await viewModel?.doAction(.view(PostListViewModel.ViewAction.didFilterUser(user.id)))
          case .showAll:
            AppRouter.shared.dismissSheet()
            await viewModel?.doAction(.view(PostListViewModel.ViewAction.clearFilter))
          case .didCancel:
            AppRouter.shared.dismissSheet()
          }
        }
        AppRouter.shared.postFilterViewModel = filterVM
        AppRouter.shared.presentSheet(.postFilter)
      }
    }
  }
}
#endif
