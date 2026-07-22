import Foundation
import UIKit
import WidgetKit

enum WidgetSync {
  static let kind = "PetWidget"
  /// 与 PetWidget.swift / ConfigurableHomeWidget 中的 kind 保持一致
  static let timelineKinds = ["PetWidgetSmall", "PetWidgetMedium", "PetWidget"]
  static let dataFileName = "petWidgetData.json"
  static let configsFileName = "savedWidgetConfigs.json"
  static let imageFileName = "petWidgetImage.png"
  static let imageTempFileName = "petWidgetImage.tmp.png"
  static let galleryRevisionFileName = "galleryRevision.txt"
  static let liveActivityImageFileName = "petLiveActivityImage.png"
  static let liveActivityImageTempFileName = "petLiveActivityImage.tmp.png"
  static let liveActivityCompactPetFileName = "petLiveActivityCompactPet.png"
  static let liveActivityCompactPetTempFileName = "petLiveActivityCompactPet.tmp.png"
  static let fourCloverImageFileName = "petLiveActivityFourClover.png"
  static let fourCloverImageTempFileName = "petLiveActivityFourClover.tmp.png"
  static let fourCloverCompactImageFileName = "petLiveActivityCompactClover.png"
  static let fourCloverCompactImageTempFileName = "petLiveActivityCompactClover.tmp.png"

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

  static func saveWidgetConfigs(_ raw: String) -> Bool {
    guard let container = appGroupContainer(),
          let data = raw.data(using: .utf8),
          (try? JSONSerialization.jsonObject(with: data)) is [Any] else {
      return false
    }
    do {
      try data.write(
        to: container.appendingPathComponent(configsFileName),
        options: .atomic
      )
      return true
    } catch {
      NSLog("[PetWidget] write configs failed: \(error)")
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

  /// 「我的组件」编辑后的预览图，供系统组件库缩略图同步显示
  static func previewFileName(widgetId: Int) -> String {
    "savedWidgetPreview_\(widgetId).png"
  }

  static func saveWidgetPreview(widgetId: Int, data: Data) -> Bool {
    guard widgetId > 0, !data.isEmpty else { return false }
    return replaceAppGroupImage(
      with: data,
      fileName: previewFileName(widgetId: widgetId),
      tempFileName: "savedWidgetPreview_\(widgetId).tmp.png",
      logTag: "SavedPreview"
    )
  }

  static func saveWidgetPreview(widgetId: Int, fromPath path: String) -> Bool {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let url: URL
    if trimmed.hasPrefix("file://"), let parsed = URL(string: trimmed) {
      url = parsed
    } else {
      url = URL(fileURLWithPath: trimmed)
    }
    guard let data = try? Data(contentsOf: url) else {
      NSLog("[SavedPreview] read failed: \(trimmed)")
      return false
    }
    return saveWidgetPreview(widgetId: widgetId, data: data)
  }

  static func removeWidgetPreview(widgetId: Int) {
    guard widgetId > 0, let container = appGroupContainer() else { return }
    let url = container.appendingPathComponent(previewFileName(widgetId: widgetId))
    try? FileManager.default.removeItem(at: url)
    let bg = container.appendingPathComponent(backgroundFileName(widgetId: widgetId))
    try? FileManager.default.removeItem(at: bg)
    let icon = container.appendingPathComponent(iconFileName(widgetId: widgetId))
    try? FileManager.default.removeItem(at: icon)
    if let digits = digitsDirectory(widgetId: widgetId) {
      try? FileManager.default.removeItem(at: digits)
    }
    NSLog("[SavedPreview] removed preview: \(widgetId)")
  }

  static func iconFileName(widgetId: Int) -> String {
    "savedWidgetIcon_\(widgetId).png"
  }

  static func digitsDirectory(widgetId: Int) -> URL? {
    guard widgetId > 0, let container = appGroupContainer() else { return nil }
    return container.appendingPathComponent("savedWidgetDigits_\(widgetId)", isDirectory: true)
  }

  static func digitFileURL(widgetId: Int, digit: Int) -> URL? {
    guard (0...9).contains(digit), let dir = digitsDirectory(widgetId: widgetId) else { return nil }
    return dir.appendingPathComponent("\(digit).png")
  }

  static func clearWidgetDigits(widgetId: Int) {
    guard widgetId > 0, let dir = digitsDirectory(widgetId: widgetId) else { return }
    try? FileManager.default.removeItem(at: dir)
    NSLog("[SavedDigits] cleared digits for widget \(widgetId)")
  }

  /// 缓存自定义数字字体 0–9（小组件实时天数用）
  static func saveWidgetDigits(
    widgetId: Int,
    urls: [String],
    authToken: String,
    completion: @escaping (Bool) -> Void
  ) {
    guard widgetId > 0, urls.count >= 10, let dir = digitsDirectory(widgetId: widgetId) else {
      completion(false)
      return
    }
    // 先清空旧字体，再写入新字体，避免混用
    try? FileManager.default.removeItem(at: dir)
    let fm = FileManager.default
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let group = DispatchGroup()
    var okCount = 0
    let lock = NSLock()
    for digit in 0..<10 {
      let raw = urls[digit].trimmingCharacters(in: .whitespacesAndNewlines)
      guard !raw.isEmpty, let dest = digitFileURL(widgetId: widgetId, digit: digit) else { continue }
      group.enter()
      downloadRawImageData(from: raw, authToken: authToken) { data in
        defer { group.leave() }
        guard let data = data, let image = UIImage(data: data) else { return }
        let scaled = resizeDigitImage(image) ?? image
        guard let png = scaled.pngData() else { return }
        do {
          try png.write(to: dest, options: .atomic)
          lock.lock()
          okCount += 1
          lock.unlock()
        } catch {
          NSLog("[SavedDigits] write \(digit) failed: \(error)")
        }
      }
    }
    group.notify(queue: .main) {
      NSLog("[SavedDigits] widget=\(widgetId) saved \(okCount)/10")
      if okCount < 10 {
        // 不完整则整套废弃，避免缺字导致天数「卡住」
        try? FileManager.default.removeItem(at: dir)
        completion(false)
        return
      }
      completion(true)
    }
  }

  static func saveWidgetIcon(
    widgetId: Int,
    remoteUrl urlString: String,
    authToken: String,
    completion: @escaping (Bool) -> Void
  ) {
    let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard widgetId > 0, !trimmed.isEmpty else {
      completion(false)
      return
    }
    downloadAppGroupImage(
      from: trimmed,
      authToken: authToken,
      replace: { data in
        replaceAppGroupImage(
          with: data,
          fileName: iconFileName(widgetId: widgetId),
          tempFileName: "savedWidgetIcon_\(widgetId).tmp.png",
          logTag: "SavedIcon"
        )
      },
      logTag: "SavedIcon",
      completion: completion
    )
  }

  private static func resizeDigitImage(_ image: UIImage) -> UIImage? {
    let maxSide: CGFloat = 160
    let size = image.size
    let longest = max(size.width, size.height)
    guard longest > maxSide, longest > 0 else { return image }
    let scale = maxSide / longest
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let result = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return result
  }

  private static func downloadRawImageData(
    from urlString: String,
    authToken: String,
    completion: @escaping (Data?) -> Void
  ) {
    let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("/") || trimmed.hasPrefix("file://") {
      let path = trimmed.hasPrefix("file://")
        ? (URL(string: trimmed)?.path ?? trimmed)
        : trimmed
      completion(try? Data(contentsOf: URL(fileURLWithPath: path)))
      return
    }
    guard let url = URL(string: trimmed) else {
      completion(nil)
      return
    }
    var request = URLRequest(
      url: url,
      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
      timeoutInterval: 30
    )
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    let token = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
    if !token.isEmpty {
      let value = token.hasPrefix("Bearer ") ? token : "Bearer \(token)"
      request.setValue(value, forHTTPHeaderField: "Authorization")
    }
    URLSession.shared.dataTask(with: request) { data, response, _ in
      if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
        completion(nil)
        return
      }
      completion(data)
    }.resume()
  }

  /// 桌面实时组件用的背景图（不依赖小组件内网络加载）
  static func backgroundFileName(widgetId: Int) -> String {
    "savedWidgetBackground_\(widgetId).png"
  }

  static func saveWidgetBackground(widgetId: Int, data: Data) -> Bool {
    guard widgetId > 0, !data.isEmpty else { return false }
    return replaceAppGroupImage(
      with: data,
      fileName: backgroundFileName(widgetId: widgetId),
      tempFileName: "savedWidgetBackground_\(widgetId).tmp.png",
      logTag: "SavedBackground"
    )
  }

  static func saveWidgetBackground(widgetId: Int, fromPath path: String) -> Bool {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let url: URL
    if trimmed.hasPrefix("file://"), let parsed = URL(string: trimmed) {
      url = parsed
    } else {
      url = URL(fileURLWithPath: trimmed)
    }
    guard let data = try? Data(contentsOf: url) else {
      NSLog("[SavedBackground] read failed: \(trimmed)")
      return false
    }
    return saveWidgetBackground(widgetId: widgetId, data: data)
  }

  /// 从网络 URL 拉取并缓存背景（主 App 保存组件时调用）
  static func saveWidgetBackground(
    widgetId: Int,
    remoteUrl urlString: String,
    authToken: String,
    completion: @escaping (Bool) -> Void
  ) {
    let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard widgetId > 0, !trimmed.isEmpty else {
      completion(false)
      return
    }
    if trimmed.hasPrefix("/") || trimmed.hasPrefix("file://") {
      completion(saveWidgetBackground(widgetId: widgetId, fromPath: trimmed))
      return
    }
    downloadAppGroupImage(
      from: trimmed,
      authToken: authToken,
      replace: { data in saveWidgetBackground(widgetId: widgetId, data: data) },
      logTag: "SavedBackground",
      completion: completion
    )
  }

  /// 删除已不在「我的组件」列表中的预览图，避免系统组件库仍显示旧缩略图
  static func pruneWidgetPreviews(keeping ids: Set<Int>) {
    guard let container = appGroupContainer() else { return }
    let contents = (try? FileManager.default.contentsOfDirectory(
      at: container,
      includingPropertiesForKeys: nil
    )) ?? []
    for url in contents {
      let name = url.lastPathComponent
      let isPreview = name.hasPrefix("savedWidgetPreview_") && name.hasSuffix(".png")
      let isBg = name.hasPrefix("savedWidgetBackground_") && name.hasSuffix(".png")
      let isIcon = name.hasPrefix("savedWidgetIcon_") && name.hasSuffix(".png")
      let isDigitsDir = name.hasPrefix("savedWidgetDigits_")
      guard (isPreview || isBg || isIcon || isDigitsDir), !name.contains(".tmp.") else { continue }
      let idPart = name
        .replacingOccurrences(of: "savedWidgetPreview_", with: "")
        .replacingOccurrences(of: "savedWidgetBackground_", with: "")
        .replacingOccurrences(of: "savedWidgetIcon_", with: "")
        .replacingOccurrences(of: "savedWidgetDigits_", with: "")
        .replacingOccurrences(of: ".png", with: "")
      guard let id = Int(idPart) else { continue }
      if !ids.contains(id) {
        try? FileManager.default.removeItem(at: url)
        NSLog("[SavedPreview] pruned orphan: \(name)")
      }
    }
  }

  static func replaceLiveActivityImage(with data: Data) -> Bool {
    guard let image = UIImage(data: data),
          let full = resizeForWidget(image),
          let compact = resizeForLiveActivityCompact(image) else {
      NSLog("[LiveActivity] replace image decode failed")
      return false
    }
    let fullOk = writePng(
      full,
      fileName: liveActivityImageFileName,
      tempFileName: liveActivityImageTempFileName,
      logTag: "LiveActivity"
    )
    let compactOk = writePng(
      compact,
      fileName: liveActivityCompactPetFileName,
      tempFileName: liveActivityCompactPetTempFileName,
      logTag: "LiveActivityCompactPet"
    )
    return fullOk && compactOk
  }

  static func replaceFourCloverImage(with data: Data) -> Bool {
    guard let image = UIImage(data: data),
          let full = resizeForWidget(image),
          let compact = resizeForLiveActivityCompact(image) else {
      NSLog("[LiveActivityFourClover] replace image decode failed")
      return false
    }
    let fullOk = writePng(
      full,
      fileName: fourCloverImageFileName,
      tempFileName: fourCloverImageTempFileName,
      logTag: "LiveActivityFourClover"
    )
    let compactOk = writePng(
      compact,
      fileName: fourCloverCompactImageFileName,
      tempFileName: fourCloverCompactImageTempFileName,
      logTag: "LiveActivityCompactClover"
    )
    return fullOk && compactOk
  }

  private static func writePng(
    _ image: UIImage,
    fileName: String,
    tempFileName: String,
    logTag: String
  ) -> Bool {
    guard let container = appGroupContainer(),
          let png = image.pngData() else {
      NSLog("[\(logTag)] png encode failed")
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

  private static func replaceAppGroupImage(
    with data: Data,
    fileName: String,
    tempFileName: String,
    logTag: String
  ) -> Bool {
    guard let image = UIImage(data: data),
          let resized = resizeForWidget(image) else {
      NSLog("[\(logTag)] replace image decode failed")
      return false
    }
    return writePng(resized, fileName: fileName, tempFileName: tempFileName, logTag: logTag)
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
    replace: @escaping (Data) -> Bool,
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
    liveActivityImageRevision()
      + fourCloverImageRevision()
      + fileRevision(for: liveActivityCompactPetFileName)
      + fileRevision(for: fourCloverCompactImageFileName)
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

  /// 主 App 启动时把纪念日 Logo 写入 App Group（覆盖可能残留的旧倒数日图）
  static func syncBrandLogoFromMainApp() {
    guard let container = appGroupContainer() else { return }
    guard let image = UIImage(named: "AppLogo"),
          let data = image.pngData() else {
      NSLog("[PetWidget] syncBrandLogo: AppLogo missing in main bundle")
      return
    }
    let dest = container.appendingPathComponent("appBrandLogo.png")
    do {
      try? FileManager.default.removeItem(at: dest)
      try data.write(to: dest, options: .atomic)
      NSLog("[PetWidget] synced appBrandLogo.png (\(data.count) bytes)")
    } catch {
      NSLog("[PetWidget] syncBrandLogo failed: \(error)")
    }
  }

  static func reloadTimelines() {
    guard #available(iOS 14.0, *) else { return }
    bumpGalleryRevision()
    reloadAllKnownTimelines()
  }

  private static func reloadAllKnownTimelines() {
    for kind in timelineKinds {
      WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
    WidgetCenter.shared.reloadAllTimelines()
  }

  /// 写入可被 Widget Extension 立即读到的版本戳，迫使 gallery snapshot 失效
  static func bumpGalleryRevision() {
    guard let container = appGroupContainer() else { return }
    let stamp = "\(Int(Date().timeIntervalSince1970 * 1000))"
    let url = container.appendingPathComponent(galleryRevisionFileName)
    try? stamp.write(to: url, atomically: true, encoding: .utf8)
    if let defaults = UserDefaults(suiteName: AppGroupConfig.id) {
      defaults.set(stamp, forKey: "galleryRevision")
      defaults.synchronize()
    }
    NSLog("[PetWidget] bumped galleryRevision=\(stamp)")
  }

  private static let widgetImageMaxSide: CGFloat = 1200
  /// 灵动岛紧凑区约 28pt，3x 下 84px；超过此尺寸系统会显示灰色占位
  private static let liveActivityCompactSide: CGFloat = 84

  private static func resizeForLiveActivityCompact(_ image: UIImage) -> UIImage? {
    let side = liveActivityCompactSide
    let aspect = min(side / image.size.width, side / image.size.height)
    let width = image.size.width * aspect
    let height = image.size.height * aspect
    let origin = CGPoint(x: (side - width) / 2, y: (side - height) / 2)
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = false
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
      image.draw(in: CGRect(origin: origin, size: CGSize(width: width, height: height)))
    }
  }

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
      case "syncWidgetConfigs":
        let args = call.arguments as? [String: Any] ?? [:]
        let raw = args["configs"] as? String ?? "[]"
        if WidgetSync.saveWidgetConfigs(raw) {
          let data = raw.data(using: .utf8)
          let configs = data.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]]
          } ?? []
          var keepIds = Set<Int>()
          for item in configs {
            let id = item["widget_id"] as? Int
              ?? Int(item["widget_id"] as? String ?? "")
              ?? 0
            if id > 0 { keepIds.insert(id) }
          }
          WidgetSync.pruneWidgetPreviews(keeping: keepIds)
          WidgetSync.reloadTimelines()
          result(nil)
        } else {
          result(
            FlutterError(
              code: "WRITE_WIDGET_CONFIGS_FAILED",
              message: "写入组件配置失败",
              details: nil
            )
          )
        }
      case "reloadWidget":
        handleReloadWidget(call: call, result: result)
      case "updateWidget":
        handleSyncWidget(call: call, result: result)
      case "saveWidgetPreview":
        handleSaveWidgetPreview(call: call, result: result)
      case "saveWidgetBackground":
        handleSaveWidgetBackground(call: call, result: result)
      case "saveWidgetDigits":
        handleSaveWidgetDigits(call: call, result: result)
      case "clearWidgetDigits":
        handleClearWidgetDigits(call: call, result: result)
      case "saveWidgetIcon":
        handleSaveWidgetIcon(call: call, result: result)
      case "removeWidgetPreview":
        handleRemoveWidgetPreview(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("[PetWidget] Method channel registered")
    WidgetSync.syncBrandLogoFromMainApp()
  }

  private static func handleRemoveWidgetPreview(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    let args = call.arguments as? [String: Any] ?? [:]
    let widgetId = args["widgetId"] as? Int
      ?? Int(args["widgetId"] as? String ?? "")
      ?? 0
    WidgetSync.removeWidgetPreview(widgetId: widgetId)
    WidgetSync.reloadTimelines()
    result(true)
  }

  private static func handleClearWidgetDigits(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    let args = call.arguments as? [String: Any] ?? [:]
    let widgetId = args["widgetId"] as? Int
      ?? Int(args["widgetId"] as? String ?? "")
      ?? 0
    WidgetSync.clearWidgetDigits(widgetId: widgetId)
    WidgetSync.reloadTimelines()
    result(true)
  }

  private static func handleSaveWidgetDigits(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
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
    let widgetId = args["widgetId"] as? Int
      ?? Int(args["widgetId"] as? String ?? "")
      ?? 0
    let token = args["authToken"] as? String ?? ""
    let urls = (args["digitUrls"] as? [String]) ?? []
    WidgetSync.saveWidgetDigits(
      widgetId: widgetId,
      urls: urls,
      authToken: token
    ) { ok in
      if ok {
        result(true)
      } else {
        // 字体下载失败不阻断保存；桌面回退系统字体
        NSLog("[SavedDigits] incomplete for widget \(widgetId)")
        result(true)
      }
    }
  }

  private static func handleSaveWidgetIcon(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
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
    let widgetId = args["widgetId"] as? Int
      ?? Int(args["widgetId"] as? String ?? "")
      ?? 0
    let token = args["authToken"] as? String ?? ""
    let remote = args["imageUrl"] as? String ?? ""
    if remote.isEmpty {
      result(true)
      return
    }
    WidgetSync.saveWidgetIcon(
      widgetId: widgetId,
      remoteUrl: remote,
      authToken: token
    ) { _ in
      result(true)
    }
  }

  private static func handleSaveWidgetBackground(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
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
    let widgetId = args["widgetId"] as? Int
      ?? Int(args["widgetId"] as? String ?? "")
      ?? 0
    let path = args["localImagePath"] as? String ?? ""
    let remote = args["imageUrl"] as? String ?? ""
    let base64 = args["imageBase64"] as? String ?? ""
    let token = args["authToken"] as? String ?? ""

    if !path.isEmpty {
      let ok = WidgetSync.saveWidgetBackground(widgetId: widgetId, fromPath: path)
      if ok { WidgetSync.reloadTimelines() }
      result(ok ? true : FlutterError(
        code: "WRITE_BACKGROUND_FAILED",
        message: "写入组件背景图失败",
        details: nil
      ))
      return
    }
    if !base64.isEmpty, let data = Data(base64Encoded: base64) {
      let ok = WidgetSync.saveWidgetBackground(widgetId: widgetId, data: data)
      if ok { WidgetSync.reloadTimelines() }
      result(ok ? true : FlutterError(
        code: "WRITE_BACKGROUND_FAILED",
        message: "写入组件背景图失败",
        details: nil
      ))
      return
    }
    if !remote.isEmpty {
      WidgetSync.saveWidgetBackground(
        widgetId: widgetId,
        remoteUrl: remote,
        authToken: token
      ) { ok in
        DispatchQueue.main.async {
          if ok {
            WidgetSync.reloadTimelines()
            result(true)
          } else {
            result(
              FlutterError(
                code: "WRITE_BACKGROUND_FAILED",
                message: "下载并写入组件背景图失败",
                details: nil
              )
            )
          }
        }
      }
      return
    }
    result(
      FlutterError(
        code: "WRITE_BACKGROUND_FAILED",
        message: "缺少背景图数据",
        details: nil
      )
    )
  }

  private static func handleSaveWidgetPreview(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
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
    let widgetId = args["widgetId"] as? Int
      ?? Int(args["widgetId"] as? String ?? "")
      ?? 0
    let path = args["localImagePath"] as? String ?? ""
    let base64 = args["imageBase64"] as? String ?? ""

    var ok = false
    if !path.isEmpty {
      ok = WidgetSync.saveWidgetPreview(widgetId: widgetId, fromPath: path)
    } else if !base64.isEmpty, let data = Data(base64Encoded: base64) {
      ok = WidgetSync.saveWidgetPreview(widgetId: widgetId, data: data)
    }

    if ok {
      // 不在这里 reload：等 syncWidgetConfigs 写完列表后再统一刷新，避免读到旧 configs
      result(true)
    } else {
      result(
        FlutterError(
          code: "WRITE_PREVIEW_FAILED",
          message: "写入组件预览图失败",
          details: nil
        )
      )
    }
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
