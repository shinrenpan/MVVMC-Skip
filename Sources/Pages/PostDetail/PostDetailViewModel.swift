import Observation

@MainActor
@Observable
final class PostDetailViewModel {
  var state: State

  init(post: PostListViewModel.Post) {
    state = .init(post: post)
  }
}
