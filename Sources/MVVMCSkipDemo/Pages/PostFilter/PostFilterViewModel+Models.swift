import Foundation

// MARK: - State

extension PostFilterViewModel {
  struct State: Sendable {
    // `.init(id: $0)` would force Skip to infer `User` from leading-dot,
    // and Skip falls back to `Any(id = …)` which Kotlin rejects. Spell it.
    let users: [User] = (1...5).map { User(id: $0) }
  }
}

// MARK: - Domain Models

extension PostFilterViewModel {
  struct User: Identifiable, Equatable, Sendable {
    let id: Int
    var displayName: String { "User \(id)" }
  }
}

// MARK: - Callback

extension PostFilterViewModel {
  enum Callback: Equatable, Sendable {
    case didSelectUser(User)
    case showAll
    case didCancel
  }
}
