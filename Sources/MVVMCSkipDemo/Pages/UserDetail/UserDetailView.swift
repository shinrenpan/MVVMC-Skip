import SwiftUI

struct UserDetailView: View {
  let viewModel: UserDetailViewModel

  var body: some View {
    Group {
      switch viewModel.state.api.fetchUser {
      case .loading:
        // Equivalent to `case .loading where user == nil`: show ProgressView
        // only when we have no cached user yet. Rewritten because Kotlin
        // forbids case-pattern guards (`case … where …`).
        if let user = viewModel.state.user {
          UserInfoView(user: user)
        } else {
          ProgressView()
        }
      case let .error(message):
        // SkipUI doesn't implement ContentUnavailableView yet — idiom #8 shim.
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
        if let user = viewModel.state.user {
          UserInfoView(user: user)
        }
      }
    }
    .navigationTitle(viewModel.state.user?.name ?? "User \(viewModel.userId)")
    .navigationBarTitleDisplayMode(.inline)
    // `.task` on Compose cancels on every View disappear/reappear during
    // navigation transitions, which throws JobCancellationException mid-API.
    // `.onAppear` + an unowned `Task` survives the transition (the Task lives
    // on the structured concurrency of the dispatching coroutine, not on the
    // View's composition lifetime).
    .onAppear {
      Task { await viewModel.doAction(.view(UserDetailViewModel.ViewAction.isFirstAppear)) }
    }
  }
}

// MARK: - Subviews

private extension UserDetailView {
  struct UserInfoView: View {
    let user: UserDetailViewModel.User

    var body: some View {
      List {
        Section {
          LabeledContent("Name", value: user.name)
          LabeledContent("Email", value: user.email)
          LabeledContent("Company", value: user.company)
        }
      }
    }
  }
}

#if DEBUG
#Preview {
  let vm = UserDetailViewModel(userId: 1)
  vm.state.user = .init(id: 1, name: "Alice Chen", email: "alice@example.com", company: "MVVMC Corp")
  return NavigationStack {
    UserDetailView(viewModel: vm)
  }
}
#endif
