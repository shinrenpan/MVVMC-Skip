import SwiftUI

struct PostFilterView: View {
  let viewModel: PostFilterViewModel

  var body: some View {
    List {
      Button("Show All") {
        Task { await viewModel.doAction(.view(PostFilterViewModel.ViewAction.showAll)) }
      }
      ForEach(viewModel.state.users) { user in
        Button(user.displayName) {
          Task { await viewModel.doAction(.view(PostFilterViewModel.ViewAction.didSelectUser(user))) }
        }
      }
    }
    .navigationBarBackButtonHidden(true)
    .navigationTitle("Filter by User")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          Task { await viewModel.doAction(.view(PostFilterViewModel.ViewAction.cancel)) }
        }
      }
    }
  }
}

#if DEBUG
#Preview {
  PostFilterView(viewModel: PostFilterViewModel())
}
#endif
