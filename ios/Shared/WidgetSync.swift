import Foundation
import UIKit
import WidgetKit

enum WidgetSync {
  static let kind = "PetWidget"
  static let dataFileName = "petWidgetData.json"
  static let imageFileName = "petWidgetImage.png"
  static let imageTempFileName = "petWidgetImage.tmp.png"
  static let liveActivityImageFileName = "petLiveActivityImage.png"
  static let liveActivityImageTempFileName = "petLiveActivityImage.tmp.png"
  static let fourCloverImageFileName = "petLiveActivityFourClover.png"
  static let fourCloverImageTempFileName = "petLiveActivityFourClover.tmp.png"

  static func appGroupContainer() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: AppGroupConfig.id
    )
  }

  static func saveWidgetData(_ widgetData: [String: Any]) -> Bool {
    guard let container = appGroupContainer() else { return false }
    let destination = container.appendingPathComponent(dataFileName)
    var payload = widgetData
    payload["updatedAt"] = Int(Date().timeIntervalSince1970 * 1000)
    guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
      return false
    }
    do {
      try data.write(to: destination, options: .atomic)
      NSLog("[PetWidget] wrote json: \(destination.path)")
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

  /// 先写临时文件再原子替换，避免高版本 iOS 读到半写入的图片
  static func replaceWidgetImage(with data: Data) -> Bool {
    replaceAppGroupImage(
      with: data,
      fileName: imageFileName,
      tempFileName: imageTempFileName,
      logTag: "PetWidget"
    )
  }

  static func replaceLiveActivityImage(with data: Data) -> Bool {
    replaceAppGroupImage(
      with: data,
      fileName: liveActivityImageFileName,
      tempFileName: liveActivityImageTempFileName,
      logTag: "LiveActivity"
    )
  }

  static func replaceFourCloverImage(with data: Data) -> Bool {
    replaceAppGroupImage(
      with: data,
      fileName: fourCloverImageFileName,
      tempFileName: fourCloverImageTempFileName,
      logTag: "LiveActivityFourClover"
    )
  }

  private static func replaceAppGroupImage(
    with data: Data,
    fileName: String,
    tempFileName: String,
    logTag: String
  ) -> Bool {
    guard let container = appGroupContainer(),
          let image = UIImage(data: data),
          let resized = resizeForWidget(image),
          let png = resized.pngData() else {
      NSLog("[\(logTag)] replace image decode failed")
      return false
    }

    let finalURL = container.appendingPathComponent(fileName)
    let tempURL = container.appendingPathComponent(tempFileName)
    let fm = FileManager.default

    do {
      try png.write(to: tempURL, options: .atomic)
      if fm.fileExists(atPath: finalURL.path) {
        _ = try fm.replaceItemAt(finalURL, withItemAt: tempURL)
      } else {
        try fm.moveItem(at: tempURL, to: finalURL)
      }
      NSLog("[\(logTag)] replaced image: \(png.count) bytes")
      return true
    } catch {
      NSLog("[\(logTag)] replace image failed: \(error)")
      try? fm.removeItem(at: tempURL)
      return false
    }
  }

  static func writeWidgetImageData(_ data: Data) -> Bool {
    replaceWidgetImage(with: data)
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
    return replaceWidgetImage(with: data)
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

    var request = URLRequest(
      url: url,
      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
      timeoutInterval: 30
    )
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    request.setValue("no-cache", forHTTPHeaderField: "Pragma")
    let token = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
    if !token.isEmpty {
      let value = token.hasPrefix("Bearer ") ? token : "Bearer \(token)"
      request.setValue(value, forHTTPHeaderField: "Authorization")
    }

    URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        NSLog("[PetWidget] download failed: \(error.localizedDescription)")
        completion(false)
        return
      }
      if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
        NSLog("[PetWidget] download http \(http.statusCode): \(urlString)")
        completion(false)
        return
      }
      guard let data = data else {
        completion(false)
        return
      }
      completion(replaceWidgetImage(with: data))
    }.resume()
  }

  static func downloadLiveActivityImage(
    from urlString: String,
    authToken: String,
    completion: @escaping (Bool) -> Void
  ) {
    downloadAppGroupImage(
      from: urlString,
      authToken: authToken,
      replace: replaceLiveActivityImage(with:),
      logTag: "LiveActivity",
      completion: completion
    )
  }

  static func downloadFourCloverImage(
    from urlString: String,
    authToken: String,
    completion: @escaping (Bool) -> Void
  ) {
    downloadAppGroupImage(
      from: urlString,
      authToken: authToken,
      replace: replaceFourCloverImage(with:),
      logTag: "LiveActivityFourClover",
      completion: completion
    )
  }

  private static func downloadAppGroupImage(
    from urlString: String,
    authToken: String,
    replace: (Data) -> Bool,
    logTag: String,
    completion: @escaping (Bool) -> Void
  ) {
    let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          let url = URL(string: trimmed),
          appGroupContainer() != nil else {
      completion(false)
      return
    }

    var request = URLRequest(
      url: url,
      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
      timeoutInterval: 30
    )
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    request.setValue("no-cache", forHTTPHeaderField: "Pragma")
    let token = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
    if !token.isEmpty {
      let value = token.hasPrefix("Bearer ") ? token : "Bearer \(token)"
      request.setValue(value, forHTTPHeaderField: "Authorization")
    }

    URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        NSLog("[\(logTag)] download failed: \(error.localizedDescription)")
        completion(false)
        return
      }
      if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
        NSLog("[\(logTag)] download http \(http.statusCode): \(trimmed)")
        completion(false)
        return
      }
      guard let data = data else {
        completion(false)
        return
      }
      completion(replace(data))
    }.resume()
  }

  static func liveActivityImageRevision() -> Int64 {
    fileRevision(for: liveActivityImageFileName)
  }

  static func fourCloverImageRevision() -> Int64 {
    fileRevision(for: fourCloverImageFileName)
  }

  static func liveActivityCombinedImageRevision() -> Int64 {
    liveActivityImageRevision() + fourCloverImageRevision()
  }

  private static func fileRevision(for fileName: String) -> Int64 {
    guard let container = appGroupContainer() else { return 0 }
    let path = container.appendingPathComponent(fileName).path
    guard FileManager.default.fileExists(atPath: path),
          let attrs = try? FileManager.default.attributesOfItem(atPath: path),
          let modified = attrs[.modificationDate] as? Date else {
      return 0
    }
    return Int64(modified.timeIntervalSince1970 * 1000)
  }

  static func reloadTimelines() {
    guard #available(iOS 14.0, *) else { return }
    WidgetCenter.shared.reloadTimelines(ofKind: kind)
    if #available(iOS 17.0, *) {
      // iOS 17+ 对 reload 有节流，补两次延迟刷新
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
      }
    }
    WidgetCenter.shared.reloadAllTimelines()
  }

  private static let widgetImageMaxSide: CGFloat = 512

  private static func resizeForWidget(_ image: UIImage) -> UIImage? {
    let size = image.size
    let maxSide = max(size.width, size.height)
    guard maxSide > widgetImageMaxSide else { return image }

    let scale = widgetImageMaxSide / maxSide
    let target = CGSize(
      width: floor(size.width * scale),
      height: floor(size.height * scale)
    )
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = false
    format.scale = 1
    return UIGraphicsImageRenderer(size: target, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }
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
        let path = WidgetSync.appGroupContainer()?.path ?? ""
        NSLog("[PetWidget] app group path: \(path)")
        result(path.isEmpty ? nil : path)
      case "syncWidget":
        handleSyncWidget(call: call, result: result)
      case "reloadWidget":
        handleReloadWidget(call: call, result: result)
      case "updateWidget":
        handleSyncWidget(call: call, result: result)
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
    }

    // 优先本地文件（AI 生成图），再 base64，最后带 Token 下载
    if !localPath.isEmpty, WidgetSync.copyWidgetImage(fromLocalPath: localPath) {
      NSLog("[PetWidget] syncWidget copied local image")
      finish(true)
      return
    }

    if !imageBase64.isEmpty,
       let data = Data(base64Encoded: imageBase64),
       WidgetSync.replaceWidgetImage(with: data) {
      NSLog("[PetWidget] syncWidget wrote base64 image")
      finish(true)
      return
    }

    if !petImageUrl.isEmpty {
      NSLog("[PetWidget] syncWidget download: \(petImageUrl)")
      WidgetSync.downloadWidgetImage(from: petImageUrl, authToken: authToken) { ok in
        DispatchQueue.main.async {
          if !ok {
            NSLog("[PetWidget] syncWidget download failed, keep existing image if any")
          }
          finish(ok)
        }
      }
      return
    }

    // 无图可写：保留已有缓存图，只更新 JSON
    finish(WidgetSync.widgetImageExists())
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

    let finish: () -> Void = {
      WidgetSync.reloadTimelines()
      result(nil)
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
