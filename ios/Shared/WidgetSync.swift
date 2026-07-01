import Foundation
import UIKit
import WidgetKit

enum WidgetSync {
  static let kind = "PetWidget"
  static let dataFileName = "petWidgetData.json"
  static let imageFileName = "petWidgetImage.png"

  static func appGroupContainer() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: AppGroupConfig.id
    )
  }

  static func saveWidgetData(_ widgetData: [String: Any]) -> Bool {
    guard let container = appGroupContainer() else { return false }
    let destination = container.appendingPathComponent(dataFileName)
    guard let data = try? JSONSerialization.data(withJSONObject: widgetData) else {
      return false
    }
    do {
      try data.write(to: destination, options: .atomic)
      return true
    } catch {
      NSLog("[PetWidget] write widget json failed: \(error)")
      return false
    }
  }

  static func widgetImageExists() -> Bool {
    guard let container = appGroupContainer() else { return false }
    let destination = container.appendingPathComponent(imageFileName)
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: destination.path),
          let size = attrs[.size] as? NSNumber else {
      return false
    }
    return size.intValue > 0
  }

  static func removeWidgetImage() {
    guard let container = appGroupContainer() else { return }
    let destination = container.appendingPathComponent(imageFileName)
    try? FileManager.default.removeItem(at: destination)
  }

  static func writeWidgetImageData(_ data: Data) -> Bool {
    guard let container = appGroupContainer(),
          let image = UIImage(data: data),
          let png = image.pngData() else {
      return false
    }
    let destination = container.appendingPathComponent(imageFileName)
    do {
      try png.write(to: destination, options: .atomic)
      return true
    } catch {
      NSLog("[PetWidget] write widget image failed: \(error)")
      return false
    }
  }

  static func copyWidgetImage(fromLocalPath path: String) -> Bool {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    var filePath = trimmed
    if filePath.hasPrefix("file://") {
      filePath = String(filePath.dropFirst("file://".count))
    }

    let source = URL(fileURLWithPath: filePath)
    guard FileManager.default.fileExists(atPath: source.path),
          let data = try? Data(contentsOf: source) else {
      NSLog("[PetWidget] local image missing: \(filePath)")
      return false
    }
    return writeWidgetImageData(data)
  }

  static func downloadWidgetImage(
    from urlString: String,
    authToken: String,
    completion: @escaping (Bool) -> Void
  ) {
    guard let url = URL(string: urlString),
          appGroupContainer() != nil else {
      completion(false)
      return
    }

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
      guard let data = data else {
        completion(false)
        return
      }
      completion(writeWidgetImageData(data))
    }.resume()
  }

  static func reloadTimelines() {
    guard #available(iOS 14.0, *) else { return }
    WidgetCenter.shared.reloadTimelines(ofKind: kind)
    WidgetCenter.shared.reloadAllTimelines()
  }
}

/// Flutter MethodChannel 统一处理（App Group 读写均在原生完成）
enum WidgetChannelHandler {
  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.example.flutterPetMemorial/widget",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getAppGroupPath":
        result(WidgetSync.appGroupContainer()?.path)
      case "syncWidget":
        handleSyncWidget(call: call, result: result)
      case "reloadWidget", "updateWidget":
        handleReloadWidget(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("[PetWidget] Method channel registered")
  }

  private static func handleSyncWidget(call: FlutterMethodCall, result: @escaping FlutterResult) {
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

    let args = call.arguments as? [String: Any] ?? [:]
    let widgetData: [String: Any] = [
      "petId": args["petId"] as? String ?? "",
      "petName": args["petName"] as? String ?? "",
      "petType": args["petType"] as? String ?? "",
      "petAge": args["petAge"] as? String ?? "",
      "petImageUrl": args["petImageUrl"] as? String ?? "",
      "memorials": args["memorials"] as? String ?? "[]",
    ]

    guard WidgetSync.saveWidgetData(widgetData) else {
      result(
        FlutterError(
          code: "WRITE_JSON_FAILED",
          message: "写入小组件数据失败",
          details: nil
        )
      )
      return
    }

    let localPath = args["localImagePath"] as? String ?? ""
    let imageBase64 = args["imageBase64"] as? String ?? ""
    let petImageUrl = args["petImageUrl"] as? String ?? ""
    let authToken = args["authToken"] as? String ?? ""
    let clearImage = args["clearImage"] as? Bool ?? false

    let finish: (Bool) -> Void = { imageWritten in
      WidgetSync.reloadTimelines()
      result([
        "imageWritten": imageWritten,
        "jsonWritten": true,
      ])
    }

    if clearImage {
      WidgetSync.removeWidgetImage()
      finish(false)
      return
    }

    if !localPath.isEmpty, WidgetSync.copyWidgetImage(fromLocalPath: localPath) {
      NSLog("[PetWidget] syncWidget copied local image")
      finish(true)
      return
    }

    if !imageBase64.isEmpty,
       let data = Data(base64Encoded: imageBase64),
       WidgetSync.writeWidgetImageData(data) {
      NSLog("[PetWidget] syncWidget wrote base64 image")
      finish(true)
      return
    }

    if !petImageUrl.isEmpty {
      NSLog("[PetWidget] syncWidget download: \(petImageUrl)")
      WidgetSync.downloadWidgetImage(from: petImageUrl, authToken: authToken) { ok in
        DispatchQueue.main.async {
          if !ok {
            NSLog("[PetWidget] syncWidget download failed, json only")
          }
          finish(ok)
        }
      }
      return
    }

    WidgetSync.removeWidgetImage()
    finish(false)
  }

  private static func handleReloadWidget(call: FlutterMethodCall, result: @escaping FlutterResult) {
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
      finish()
      return
    }

    if WidgetSync.widgetImageExists() {
      finish()
      return
    }

    guard !petImageUrl.isEmpty else {
      finish()
      return
    }

    WidgetSync.downloadWidgetImage(from: petImageUrl, authToken: authToken) { _ in
      DispatchQueue.main.async { finish() }
    }
  }
}
