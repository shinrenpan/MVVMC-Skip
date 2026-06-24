#if !SKIP
import SwiftUI

struct ProfileView: View {
  let viewModel: ProfileViewModel

  var body: some View {
    List {
      Section("App") {
        LabeledContent("版本", value: "1.0.0")
      }
      Section {
        Button("前往文章列表") {
          Task { await viewModel.doAction(.view(.toPosts)) }
        }
        Button("設定") {
          Task { await viewModel.doAction(.view(.toSettings)) }
        }
      }
      Section("Deeplink Demo") {
        Button("mvvmc://settings") {
          Task { await viewModel.doAction(.view(.triggerDeeplink(URL(string: "mvvmc://settings")!))) }
        }
        Button("mvvmc://posts/1") {
          Task { await viewModel.doAction(.view(.triggerDeeplink(URL(string: "mvvmc://posts/1")!))) }
        }
      }
      Section("Push Notification Demo") {
        Button("5 秒後推播 → mvvmc://settings") {
          Task { await viewModel.doAction(.view(.scheduleNotification(deeplinkURL: "mvvmc://settings"))) }
        }
        Button("5 秒後推播 → mvvmc://posts/1") {
          Task { await viewModel.doAction(.view(.scheduleNotification(deeplinkURL: "mvvmc://posts/1"))) }
        }
      }
    }
    .navigationTitle("Profile")
  }
}

#if DEBUG
#Preview {
  ProfileView(viewModel: ProfileViewModel())
}
#endif
#endif
