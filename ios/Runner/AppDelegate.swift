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
      case "updateWidget":
        self?.handleUpdateWidget(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("[PetWidget] Method channel registered")
  }

  private func handleUpdateWidget(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "参数无效", details: nil))
      return
    }

    guard WidgetSync.appGroupContainer() != nil else {
      NSLog("[PetWidget] App Group unavailable: \(AppGroupConfig.id)")
      result(
        FlutterError(
          code: "APP_GROUP_UNAVAILABLE",
          message: "App Group 未配置，请在 Xcode 为 Runner 和 PetWidget 开启 App Groups",
          details: nil
        )
      )
      return
    }

    let petName = arguments["petName"] as? String ?? ""
    let petImageUrl = arguments["petImageUrl"] as? String ?? ""
    let authToken = arguments["authToken"] as? String ?? ""
    let imageWritten = arguments["imageWritten"] as? Bool ?? false
    let widgetData: [String: Any] = [
      "petName": petName,
      "petType": arguments["petType"] as? String ?? "",
      "petAge": arguments["petAge"] as? String ?? "",
      "petImageUrl": petImageUrl,
      "memorials": arguments["memorials"] as? String ?? "[]",
    ]

    guard WidgetSync.saveWidgetData(widgetData) else {
      result(
        FlutterError(
          code: "WRITE_FAILED",
          message: "小组件数据写入失败",
          details: nil
        )
      )
      return
    }

    let finish: () -> Void = {
      WidgetSync.reloadTimelines()
      result(nil)
    }

    if imageWritten && WidgetSync.widgetImageExists() {
      NSLog("[PetWidget] using Flutter-written image for \(petName)")
      finish()
      return
    }

    if petImageUrl.isEmpty {
      NSLog("[PetWidget] no image url for \(petName), imageWritten=\(imageWritten)")
      finish()
      return
    }

    NSLog("[PetWidget] fallback download image for \(petName)")
    cachePetImage(from: petImageUrl, authToken: authToken) { _ in
      DispatchQueue.main.async {
        finish()
      }
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
        NSLog("[PetWidget] download image failed: \(error.localizedDescription)")
        completion(false)
        return
      }
      guard let data = data, let image = UIImage(data: data) else {
        NSLog("[PetWidget] download image decode failed")
        completion(false)
        return
      }
      let pngData = image.pngData()
      guard let pngData else {
        completion(false)
        return
      }
      do {
        try pngData.write(to: destination, options: .atomic)
        NSLog("[PetWidget] cached remote widget image")
        completion(true)
      } catch {
        NSLog("[PetWidget] write cached image failed: \(error)")
        completion(false)
      }
    }.resume()
  }
}
