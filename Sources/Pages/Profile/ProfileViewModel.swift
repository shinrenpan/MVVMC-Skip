import Observation
import UIKit
import UserNotifications

@MainActor
@Observable
final class ProfileViewModel {
  enum Action: Sendable {
    case view(ViewAction)
  }

  var state: State = .init()

  @ObservationIgnored
  var onRoute: (@MainActor (Router) -> Void)?

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    }
  }
}

// MARK: - View Action

extension ProfileViewModel {
  enum ViewAction: Sendable {
    case toPosts
    case toSettings
    case triggerDeeplink(URL)
    case scheduleNotification(deeplinkURL: String)
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .toPosts:
      onRoute?(.toPosts)
    case .toSettings:
      onRoute?(.toSettings)
    case let .triggerDeeplink(url):
      await UIApplication.shared.open(url)
    case let .scheduleNotification(deeplinkURL):
      await scheduleDeeplinkNotification(url: deeplinkURL)
    }
  }

  private func scheduleDeeplinkNotification(url: String) async {
    let center = UNUserNotificationCenter.current()
    guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
    let content = UNMutableNotificationContent()
    content.title = "Deeplink Demo"
    content.body = url
    content.userInfo = ["deeplink": url]
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
    try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
  }
}

// MARK: - Router

extension ProfileViewModel {
  enum Router: Sendable {
    case toPosts
    case toSettings
  }
}
