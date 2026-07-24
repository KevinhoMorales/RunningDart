import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let watchChannelName = "com.devlokos.runningdart/watch"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    application.registerForRemoteNotifications()

    if let controller = window?.rootViewController as? FlutterViewController {
      configureWatchBridge(controller: controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureWatchBridge(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: watchChannelName,
      binaryMessenger: controller.binaryMessenger
    )

    WatchSessionManager.shared.configure(channel: channel)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "updateContext":
        guard let jsonString = call.arguments as? String else {
          result(
            FlutterError(
              code: "invalid_args",
              message: "Expected JSON string",
              details: nil
            )
          )
          return
        }
        WatchSessionManager.shared.updateContext(jsonString: jsonString)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
