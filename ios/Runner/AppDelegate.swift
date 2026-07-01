import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var widgetChannelRegistered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    DispatchQueue.main.async { [weak self] in
      self?.setupWidgetChannelIfNeeded()
    }
    return result
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    setupWidgetChannelIfNeeded()
  }

  private func setupWidgetChannelIfNeeded() {
    guard !widgetChannelRegistered else { return }
    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("[PetWidget] FlutterViewController not ready, will retry")
      return
    }

    widgetChannelRegistered = true

    let channel = FlutterMethodChannel(
      name: "com.example.flutterPetMemorial/widget",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getAppGroupPath":
        result(WidgetSync.appGroupContainer()?.path)
      case "reloadWidget":
        self?.handleReloadWidget(call: call, result: result)
      case "updateWidget":
        self?.handleReloadWidget(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("[PetWidget] Method channel registered")
  }

  /// Flutter 已写入 App Group，此处仅刷新小组件；必要时补下载图片
  private func handleReloadWidget(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard WidgetSync.appGroupContainer() != nil else {
      result(
        FlutterError(
          code: "APP_GROUP_UNAVAILABLE",
          message: "App Group 未配置",
          details: nil
        )
      )
      return
    }

    let args = call.arguments as? [String: Any]
    let petImageUrl = args?["petImageUrl"] as? String ?? ""
    let authToken = args?["authToken"] as? String ?? ""
    let flutterWroteImage = args?["imageWritten"] as? Bool ?? false

    let finish: () -> Void = {
      WidgetSync.reloadTimelines()
      result(nil)
    }

    if flutterWroteImage && WidgetSync.widgetImageExists() {
      NSLog("[PetWidget] reload with Flutter-written image")
      finish()
      return
    }

    if WidgetSync.widgetImageExists() {
      NSLog("[PetWidget] reload with existing cached image")
      finish()
      return
    }

    guard !petImageUrl.isEmpty else {
      WidgetSync.removeWidgetImage()
      NSLog("[PetWidget] reload without image url")
      finish()
      return
    }

    NSLog("[PetWidget] fallback download: \(petImageUrl)")
    cachePetImage(from: petImageUrl, authToken: authToken) { _ in
      DispatchQueue.main.async { finish() }
    }
  }

  private func cachePetImage(
    from urlString: String,
    authToken: String,
    completion: @escaping (Bool) -> Void
  ) {
    guard let url = URL(string: urlString),
          let container = WidgetSync.appGroupContainer() else {
      completion(false)
      return
    }

    let destination = container.appendingPathComponent(WidgetSync.imageFileName)
    var request = URLRequest(url: url)
    let token = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
    if !token.isEmpty {
      let value = token.hasPrefix("Bearer ") ? token : "Bearer \(token)"
      request.setValue(value, forHTTPHeaderField: "Authorization")
    }

    URLSession.shared.dataTask(with: request) { data, _, error in
      if let error = error {
        NSLog("[PetWidget] download failed: \(error.localizedDescription)")
        completion(false)
        return
      }
      guard let data = data, let image = UIImage(data: data), let png = image.pngData() else {
        NSLog("[PetWidget] download decode failed")
        completion(false)
        return
      }
      do {
        try png.write(to: destination, options: .atomic)
        completion(true)
      } catch {
        completion(false)
      }
    }.resume()
  }
}
