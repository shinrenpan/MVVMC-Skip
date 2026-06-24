import SwiftUI

struct SettingsView: View {
  let viewModel: SettingsViewModel

  var body: some View {
    List {
      Section("一般") {
        LabeledContent("版本", value: "1.0.0")
        LabeledContent("Build", value: "1")
      }
    }
    .navigationTitle("設定")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("關閉") {
          // Skip's transpiler drops the outer-class qualifier when a
          // nested enum lives in an extension — `.view(.close)` becomes
          // bare `ViewAction.close` in Kotlin, which doesn't resolve.
          // Fully qualify both ends so the generated Kotlin uses
          // `SettingsViewModel.ViewAction.close`.
          Task {
            await viewModel.doAction(.view(SettingsViewModel.ViewAction.close))
          }
        }
      }
    }
  }
}

#if DEBUG
#Preview {
  NavigationStack {
    SettingsView(viewModel: SettingsViewModel())
  }
}
#endif
