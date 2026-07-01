import Foundation
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

  static func reloadTimelines() {
    guard #available(iOS 14.0, *) else { return }
    WidgetCenter.shared.reloadTimelines(ofKind: kind)
    WidgetCenter.shared.reloadAllTimelines()
  }
}
