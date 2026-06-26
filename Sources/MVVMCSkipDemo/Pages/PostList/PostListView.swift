import SwiftUI

struct PostListView: View {
  let viewModel: PostListViewModel

  var body: some View {
    Group {
      switch viewModel.state.api.fetchPosts {
      case .loading:
        // Rewritten from `case .loading where posts.isEmpty` — Kotlin
        // forbids case-pattern guards. See UserDetailView for the same fix.
        if viewModel.state.posts.isEmpty {
          ProgressView()
        } else {
          List(viewModel.state.posts) { post in
            PostRow(post: post) {
              Task { await viewModel.doAction(.view(PostListViewModel.ViewAction.postDidTap(post))) }
            } onUserTap: {
              Task { await viewModel.doAction(.view(PostListViewModel.ViewAction.userDidTap(post.userId))) }
            }
          }
        }
      case let .error(message):
        // SkipUI doesn't implement ContentUnavailableView yet; provide a
        // plain VStack fallback on Android so the error state still renders.
        #if !SKIP
        ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
        #else
        VStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
          Text(message)
        }
        .foregroundStyle(.secondary)
        #endif
      default:
        List(viewModel.state.posts) { post in
          PostRow(post: post) {
            Task { await viewModel.doAction(.view(PostListViewModel.ViewAction.postDidTap(post))) }
          } onUserTap: {
            Task { await viewModel.doAction(.view(PostListViewModel.ViewAction.userDidTap(post.userId))) }
          }
        }
      }
    }
    .navigationTitle(viewModel.state.filterUserId.map { "User \($0)'s Posts" } ?? "Posts")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Profile") {
          Task { await viewModel.doAction(.view(PostListViewModel.ViewAction.toProfile)) }
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("Filter") {
          Task { await viewModel.doAction(.view(PostListViewModel.ViewAction.showFilter)) }
        }
      }
    }
    #if !SKIP
    .task { await viewModel.doAction(.view(PostListViewModel.ViewAction.isFirstAppear)) }
    #else
    .onAppear {
      Task { await viewModel.doAction(.view(PostListViewModel.ViewAction.isFirstAppear)) }
    }
    #endif
  }
}

// MARK: - Subviews

private extension PostListView {
  struct PostRow: View {
    let post: PostListViewModel.Post
    let onTap: @MainActor () -> Void
    let onUserTap: @MainActor () -> Void

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        VStack(alignment: .leading, spacing: 4) {
          Text(post.title)
            .font(.headline)
            .foregroundStyle(.primary)
          Text(post.body)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if !SKIP
        // .contentShape(Rectangle()) is not yet implemented in SkipUI.
        // Drop it on Android — the row is still tappable via onTapGesture.
        .contentShape(Rectangle())
        #endif
        .onTapGesture { onTap() }

        Button("User \(post.userId)") {
          onUserTap()
        }
        .font(.caption)
        .foregroundStyle(Color.accentColor)
        .buttonStyle(.plain)
      }
      .padding(.vertical, 4)
    }
  }
}

#if DEBUG
#Preview {
  let vm = PostListViewModel()
  vm.state.posts = PostListViewModel.Post.mocks
  return NavigationStack {
    PostListView(viewModel: vm)
  }
}
#endif
