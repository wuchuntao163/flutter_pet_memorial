import Flutter
import UIKit
import WidgetKit

private let appGroupId = "group.com.example.flutterPetMemorial"
private let petImageFileName = "pet_avatar.jpg"

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    let window = UIWindow(windowScene: windowScene)
    self.window = window

    let flutterViewController = FlutterViewController()
    GeneratedPluginRegistrant.register(with: flutterViewController)

    let widgetChannel = FlutterMethodChannel(
      name: "com.example.flutterPetMemorial/widget",
      binaryMessenger: flutterViewController.binaryMessenger
    )
    widgetChannel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "updateWidget":
        self?.updateWidget(with: call.arguments as? [String: Any])
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    window.rootViewController = flutterViewController
    window.makeKeyAndVisible()
  }

  private func updateWidget(with args: [String: Any]?) {
    let sharedDefaults = UserDefaults(suiteName: appGroupId)

    if let petName = args?["petName"] as? String {
      sharedDefaults?.set(petName, forKey: "petName")
    }
    if let petType = args?["petType"] as? String {
      sharedDefaults?.set(petType, forKey: "petType")
    }
    if let petAge = args?["petAge"] as? String {
      sharedDefaults?.set(petAge, forKey: "petAge")
    }
    if let memorials = args?["memorials"] as? String,
       let data = memorials.data(using: .utf8) {
      sharedDefaults?.set(data, forKey: "memorials")
    }

    if let imageUrl = args?["petImageUrl"] as? String, !imageUrl.isEmpty {
      sharedDefaults?.set(imageUrl, forKey: "petImageUrl")
      downloadPetImage(from: imageUrl)
    } else {
      sharedDefaults?.removeObject(forKey: "petImageUrl")
      sharedDefaults?.removeObject(forKey: "petImagePath")
      removeCachedPetImage()
    }

    sharedDefaults?.synchronize()
    reloadWidgetTimelines()
  }

  private func downloadPetImage(from urlString: String) {
    guard let url = URL(string: urlString),
          let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
          ) else {
      return
    }

    let destination = container.appendingPathComponent(petImageFileName)
    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data = data, UIImage(data: data) != nil else { return }
      do {
        try data.write(to: destination, options: .atomic)
        let defaults = UserDefaults(suiteName: appGroupId)
        defaults?.set(destination.path, forKey: "petImagePath")
        defaults?.synchronize()
        DispatchQueue.main.async {
          self.reloadWidgetTimelines()
        }
      } catch {
        // ignore cache write failures
      }
    }.resume()
  }

  private func removeCachedPetImage() {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId
    ) else {
      return
    }
    let destination = container.appendingPathComponent(petImageFileName)
    try? FileManager.default.removeItem(at: destination)
  }

  private func reloadWidgetTimelines() {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
