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

    NSLog("[PetWidget] saved widget data for \(petName)")

    let finish: () -> Void = {
      WidgetSync.reloadTimelines()
      result(nil)
    }

    if let imageData = arguments["petImageBytes"] as? FlutterStandardTypedData {
      if savePetImageToAppGroup(imageData.data) {
        finish()
      } else if !petImageUrl.isEmpty {
        cachePetImage(from: petImageUrl) { success in
          DispatchQueue.main.async {
            if !success {
              WidgetSync.removeWidgetImage()
            }
            finish()
          }
        }
      } else {
        WidgetSync.removeWidgetImage()
        finish()
      }
      return
    }

    if petImageUrl.isEmpty {
      WidgetSync.removeWidgetImage()
      finish()
      return
    }

    cachePetImage(from: petImageUrl) { success in
      DispatchQueue.main.async {
        if !success {
          WidgetSync.removeWidgetImage()
        }
        finish()
      }
    }
  }

  private func savePetImageToAppGroup(_ data: Data) -> Bool {
    guard let container = WidgetSync.appGroupContainer() else {
      NSLog("[PetWidget] app group container unavailable for image write")
      return false
    }

    let destination = container.appendingPathComponent(WidgetSync.imageFileName)

    guard let image = UIImage(data: data) else {
      NSLog("[PetWidget] failed to decode widget image bytes")
      return false
    }

    let processed = Self.prepareWidgetImage(image)
    guard let pngData = processed.pngData() else {
      NSLog("[PetWidget] failed to encode widget image png")
      return false
    }

    do {
      try pngData.write(to: destination, options: .atomic)
      NSLog("[PetWidget] saved widget image to \(destination.path)")
      return true
    } catch {
      NSLog("[PetWidget] write widget image failed: \(error)")
      return false
    }
  }

  private func cachePetImage(from urlString: String, completion: @escaping (Bool) -> Void) {
    guard let url = URL(string: urlString),
          let container = WidgetSync.appGroupContainer() else {
      completion(false)
      return
    }

    let destination = container.appendingPathComponent(WidgetSync.imageFileName)

    URLSession.shared.dataTask(with: url) { data, _, error in
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
      let processed = Self.prepareWidgetImage(image)
      guard let pngData = processed.pngData() else {
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

  private static func prepareWidgetImage(_ image: UIImage) -> UIImage {
    trimTransparentEdges(renderImageWithAlpha(image))
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

  /// AI 生成图常有大量透明留白，裁掉后小组件里宠物不会显得过小
  private static func trimTransparentEdges(_ image: UIImage) -> UIImage {
    guard let cgImage = image.cgImage else { return image }

    let width = cgImage.width
    let height = cgImage.height
    guard width > 1, height > 1 else { return image }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: colorSpace,
      bitmapInfo: bitmapInfo
    ) else {
      return image
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let data = context.data else { return image }
    let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

    var minX = width
    var minY = height
    var maxX = 0
    var maxY = 0

    for y in 0..<height {
      for x in 0..<width {
        let offset = (y * width + x) * 4
        let alpha = pixels[offset + 3]
        if alpha > 12 {
          minX = min(minX, x)
          minY = min(minY, y)
          maxX = max(maxX, x)
          maxY = max(maxY, y)
        }
      }
    }

    if maxX <= minX || maxY <= minY {
      return image
    }

    let cropRect = CGRect(
      x: minX,
      y: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1
    )
    guard let cropped = cgImage.cropping(to: cropRect) else { return image }
    return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
  }
}
