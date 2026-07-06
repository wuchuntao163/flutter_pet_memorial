import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var widgetChannelRegistered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    setupWidgetChannelIfNeeded()
    return result
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    setupWidgetChannelIfNeeded()
    if #available(iOS 16.2, *) {
      Task {
        await LiveActivitySync.dismissLingeringActivities()
        LiveActivitySync.observeExistingActivities()
      }
    }
  }

  private func setupWidgetChannelIfNeeded() {
    guard !widgetChannelRegistered else { return }
    guard let controller = findFlutterViewController() else {
      NSLog("[PetWidget] FlutterViewController not ready, will retry")
      return
    }

    widgetChannelRegistered = true
    WidgetChannelHandler.register(with: controller)
    LiveActivityChannelHandler.register(with: controller)
  }

  /// iOS 13+ 高版本可能通过 Scene 挂载窗口，不仅依赖 AppDelegate.window
  private func findFlutterViewController() -> FlutterViewController? {
    if let controller = window?.rootViewController as? FlutterViewController {
      return controller
    }

    if #available(iOS 13.0, *) {
      for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else { continue }
        for sceneWindow in windowScene.windows {
          if let controller = sceneWindow.rootViewController as? FlutterViewController {
            window = sceneWindow
            return controller
          }
        }
      }
    }

    return nil
  }
}
