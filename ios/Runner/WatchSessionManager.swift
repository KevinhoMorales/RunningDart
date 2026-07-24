import Foundation
import WatchConnectivity
import CoreImage
import UIKit
import Flutter

final class WatchSessionManager: NSObject {
  static let shared = WatchSessionManager()

  private var lastContext: [String: Any] = [:]
  private var refreshHandler: (() -> Void)?
  private weak var flutterChannel: FlutterMethodChannel?

  private override init() {
    super.init()
  }

  func configure(channel: FlutterMethodChannel) {
    flutterChannel = channel
    refreshHandler = { [weak self] in
      self?.requestRefreshFromFlutter()
    }

    guard WCSession.isSupported() else {
      return
    }

    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func updateContext(jsonString: String) {
    guard
      let data = jsonString.data(using: .utf8),
      var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return
    }

    object = sanitizeContext(object)

    if
      let canShowQr = object["canShowQr"] as? Bool,
      canShowQr,
      let payload = object["qrPayload"] as? String,
      let imageBase64 = QRCodeImageGenerator.makeBase64PNG(from: payload)
    {
      object["qrImageBase64"] = imageBase64
    } else {
      object.removeValue(forKey: "qrImageBase64")
      object.removeValue(forKey: "qrPayload")
    }

    lastContext = object
    sendContext(object)
  }

  func resendLastContext() {
    guard !lastContext.isEmpty else {
      return
    }
    sendContext(lastContext)
  }

  private func requestRefreshFromFlutter() {
    guard let channel = flutterChannel else {
      resendLastContext()
      return
    }

    channel.invokeMethod("requestRefresh", arguments: nil) { [weak self] _ in
      self?.resendLastContext()
    }
  }

  private func sanitizeContext(_ context: [String: Any]) -> [String: Any] {
    var sanitized = context
    let isLoggedIn = sanitized["isLoggedIn"] as? Bool ?? false

    if !isLoggedIn {
      sanitized["isLoggedIn"] = false
      sanitized["canShowQr"] = false
      sanitized.removeValue(forKey: "qrPayload")
      sanitized.removeValue(forKey: "qrImageBase64")
      sanitized.removeValue(forKey: "displayName")
    }

    return sanitized
  }

  private func sendContext(_ context: [String: Any]) {
    guard WCSession.isSupported() else {
      return
    }

    let session = WCSession.default
    guard session.activationState == .activated else {
      return
    }

    do {
      try session.updateApplicationContext(context)
    } catch {
      NSLog("WatchSessionManager updateApplicationContext failed: \(error)")
    }
  }
}

extension WatchSessionManager: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if activationState == .activated, !lastContext.isEmpty {
      sendContext(lastContext)
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard message["request"] as? String == "refresh" else {
      return
    }

    refreshHandler?()
  }
}

enum QRCodeImageGenerator {
  static func makeBase64PNG(from string: String) -> String? {
    guard
      let filter = CIFilter(name: "CIQRCodeGenerator"),
      let data = string.data(using: .utf8)
    else {
      return nil
    }

    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")

    guard let outputImage = filter.outputImage else {
      return nil
    }

    let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
    let context = CIContext()
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
      return nil
    }

    let image = UIImage(cgImage: cgImage)
    guard let pngData = image.pngData() else {
      return nil
    }

    return pngData.base64EncodedString()
  }
}
