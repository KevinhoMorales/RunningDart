import Foundation
import WatchConnectivity

enum WatchScreenState: Equatable {
  case loading
  case loginRequired
  case membershipRequired
  case qrReady
}

final class WatchSessionStore: NSObject, ObservableObject {
  @Published private(set) var state: WatchScreenState = .loading
  @Published private(set) var qrPayload: String?
  @Published private(set) var qrImageBase64: String?
  @Published private(set) var displayName: String?

  override init() {
    super.init()
    activateSession()
    applyContext(WCSession.default.receivedApplicationContext)
  }

  private func activateSession() {
    guard WCSession.isSupported() else {
      state = .loginRequired
      return
    }

    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func requestRefresh() {
    guard WCSession.isSupported() else {
      return
    }

    let session = WCSession.default
    guard session.isReachable else {
      applyContext(session.receivedApplicationContext)
      return
    }

    session.sendMessage(["request": "refresh"], replyHandler: nil) { _ in
      DispatchQueue.main.async {
        self.applyContext(session.receivedApplicationContext)
      }
    }
  }

  private func applyContext(_ context: [String: Any]) {
    let isLoggedIn = context["isLoggedIn"] as? Bool ?? false
    let canShowQr = context["canShowQr"] as? Bool ?? false

    if !isLoggedIn {
      qrPayload = nil
      qrImageBase64 = nil
      displayName = nil
      state = .loginRequired
      return
    }

    if canShowQr,
       let payload = context["qrPayload"] as? String,
       !payload.isEmpty,
       let imageBase64 = context["qrImageBase64"] as? String,
       !imageBase64.isEmpty
    {
      qrPayload = payload
      qrImageBase64 = imageBase64
      displayName = context["displayName"] as? String
      state = .qrReady
      return
    }

    qrPayload = nil
    qrImageBase64 = nil
    displayName = context["displayName"] as? String
    state = .membershipRequired
  }
}

extension WatchSessionStore: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async {
      self.applyContext(session.receivedApplicationContext)
    }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    DispatchQueue.main.async {
      self.applyContext(applicationContext)
    }
  }
}
