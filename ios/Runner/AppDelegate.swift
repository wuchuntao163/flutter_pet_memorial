import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let appGroupId = "group.com.gjl.PetMemorialDay"
  private static let widgetDataKey = "petWidgetData"
  private static let widgetDataFileName = "petWidgetData.json"
  private static let widgetImageName = "petWidgetImage.png"

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
      name: "com.gjl.PetMemorialDay/widget",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
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

    let petName = arguments["petName"] as? String ?? ""
    let petType = arguments["petType"] as? String ?? ""
    let petAge = arguments["petAge"] as? String ?? ""
    let petImageUrl = arguments["petImageUrl"] as? String ?? ""
    let memorialsJson = arguments["memorials"] as? String ?? ""

    let widgetData: [String: Any] = [
      "petName": petName,
      "petType": petType,
      "petAge": petAge,
      "petImageUrl": petImageUrl,
      "memorials": memorialsJson,
    ]

    guard let sharedDefaults = UserDefaults(suiteName: Self.appGroupId) else {
      NSLog("[PetWidget] App Group unavailable: \(Self.appGroupId)")
      result(
        FlutterError(
          code: "APP_GROUP_UNAVAILABLE",
          message: "App Group 未配置，请在 Xcode 为 Runner 和 PetWidget 开启 App Groups",
          details: nil
        )
      )
      return
    }

    sharedDefaults.set(widgetData, forKey: Self.widgetDataKey)
    sharedDefaults.synchronize()
    saveWidgetDataFile(widgetData)
    NSLog("[PetWidget] saved widget data for \(petName)")

    if let imageData = arguments["petImageBytes"] as? FlutterStandardTypedData {
      savePetImageToAppGroup(imageData.data)
    } else {
      cachePetImage(from: petImageUrl)
    }

    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }

    result(nil)
  }

  private func appGroupContainer() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: Self.appGroupId
    )
  }

  private func saveWidgetDataFile(_ widgetData: [String: Any]) {
    guard let container = appGroupContainer() else { return }
    let destination = container.appendingPathComponent(Self.widgetDataFileName)
    guard let data = try? JSONSerialization.data(withJSONObject: widgetData) else {
      return
    }
    do {
      try data.write(to: destination)
      NSLog("[PetWidget] saved widget json to \(destination.path)")
    } catch {
      NSLog("[PetWidget] write widget json failed: \(error)")
    }
  }

  private func savePetImageToAppGroup(_ data: Data) {
    guard let container = appGroupContainer() else {
      NSLog("[PetWidget] app group container unavailable for image write")
      return
    }

    let destination = container.appendingPathComponent(Self.widgetImageName)

    guard let image = UIImage(data: data), let pngData = Self.renderImageWithAlpha(image).pngData() else {
      NSLog("[PetWidget] failed to decode widget image bytes")
      return
    }

    do {
      try pngData.write(to: destination)
      NSLog("[PetWidget] saved widget image to \(destination.path)")
      if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadAllTimelines()
      }
    } catch {
      NSLog("[PetWidget] write widget image failed: \(error)")
    }
  }

  private func cachePetImage(from urlString: String) {
    guard !urlString.isEmpty,
          let url = URL(string: urlString),
          let container = appGroupContainer() else {
      return
    }

    let destination = container.appendingPathComponent(Self.widgetImageName)

    URLSession.shared.dataTask(with: url) { data, _, error in
      if let error = error {
        NSLog("[PetWidget] download image failed: \(error.localizedDescription)")
        return
      }
      guard let data = data, let image = UIImage(data: data) else {
        NSLog("[PetWidget] download image decode failed")
        return
      }
      let rendered = Self.renderImageWithAlpha(image)
      guard let pngData = rendered.pngData() else {
        return
      }
      do {
        try pngData.write(to: destination)
        NSLog("[PetWidget] cached remote widget image")
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
      } catch {
        NSLog("[PetWidget] write cached image failed: \(error)")
      }
    }.resume()
  }

  private static func renderImageWithAlpha(_ image: UIImage) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = false
    format.scale = image.scale
    let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
  }
}
