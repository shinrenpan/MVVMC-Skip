import Observation

@MainActor
@Observable
final class UserDetailViewModel {
  enum Action: Sendable {
    case view(ViewAction)
    case apiRequest(APIRequest)
    case apiResponse(APIResponse)
  }

  @ObservationIgnored
  let userId: Int

  var state: State = .init()

  init(userId: Int) {
    self.userId = userId
  }

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    case let .apiRequest(request): await handleAPIRequest(request)
    case let .apiResponse(response): await handleAPIResponse(response)
    }
  }
}

// MARK: - View Action

extension UserDetailViewModel {
  enum ViewAction: Sendable {
    case isFirstAppear
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      await doAction(.apiRequest(.fetchUser(userId: userId)))
    }
  }
}

// MARK: - API Request

extension UserDetailViewModel {
  enum APIRequest: Sendable {
    case fetchUser(userId: Int)
  }

  private func handleAPIRequest(_ request: APIRequest) async {
    switch request {
    case let .fetchUser(userId):
      guard !state.api.fetchUser.isLoading else { return }
      state.api.fetchUser = .loading
      do {
        let dto = try await UserDetailAPI.fetch(userId: userId)
        // Lifted into a typed let so Skip's transpiler can infer the
        // owning type of `.success` (it can't see through nested
        // leading-dot enums the way Swift's compiler can).
        let result: Result<UserDTO, APIError> = .success(dto)
        await doAction(.apiResponse(.fetchUserDidFinish(result)))
      } catch {
        let result: Result<UserDTO, APIError> = .failure(.message(error.localizedDescription))
        await doAction(.apiResponse(.fetchUserDidFinish(result)))
      }
    }
  }
}

// MARK: - API Response

extension UserDetailViewModel {
  enum APIResponse: Sendable {
    case fetchUserDidFinish(Result<UserDTO, APIError>)
  }

  private func handleAPIResponse(_ response: APIResponse) async {
    // Skip can't destructure nested enum patterns in a single `case`
    // (e.g. `case let .fetchUserDidFinish(.success(dto))`), so the
    // destructuring is split into one outer switch + inner switches.
    switch response {
    case let .fetchUserDidFinish(result):
      switch result {
      case let .success(dto):
        state.user = dto.toDomain()
        state.api.fetchUser = .success
      case let .failure(error):
        switch error {
        case let .message(msg):
          state.api.fetchUser = .error(msg)
        }
      }
    }
  }
}
