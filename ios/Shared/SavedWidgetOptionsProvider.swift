import Foundation
import Intents
import UIKit

/// 从 App Group 读取「我的组件」，供编辑小组件动态选项使用
enum SavedWidgetOptionsProvider {
  enum SizeFilter {
    case small
    case medium
  }

  struct Item {
    let id: Int
    let title: String
    let isMedium: Bool
  }

  /// 选项字符串：`标题 #id`（解析时取最后的 #id）
  static func makeCollection(filter: SizeFilter) -> INObjectCollection<NSString> {
    var items = load(filter: filter).map { item -> NSString in
      "\(item.title) #\(item.id)" as NSString
    }
    if items.isEmpty {
      // 避免系统提示「未提供此参数的选项」；选中后仍显示引导
      let hint = filter == .small
        ? "请先在 App「我的组件」保存小号样式"
        : "请先在 App「我的组件」保存中号样式"
      items = [hint as NSString]
    }
    let title = filter == .small ? "我的组件-小号" : "我的组件-中号"
    let section = INObjectSection(title: title, items: items)
    return INObjectCollection(sections: [section])
  }

  static func widgetId(from option: String?) -> Int? {
    guard let option = option?.trimmingCharacters(in: .whitespacesAndNewlines),
          !option.isEmpty else {
      return nil
    }
    if option.hasPrefix("请先") { return nil }
    if let hash = option.lastIndex(of: "#") {
      return Int(option[option.index(after: hash)...].trimmingCharacters(in: .whitespaces))
    }
    if let sep = option.range(of: " · ", options: .backwards) {
      return Int(option[sep.upperBound...].trimmingCharacters(in: .whitespaces))
    }
    return Int(option)
  }

  // MARK: - 透明位置

  static let transparentOff = "关闭"
  static let transparentRevisionDefaultsKey = "widgetTransparentRevision"
  /// 兼容已保存的旧选项（不再展示，升级后按关闭处理）
  private static let transparentFollowApp = "跟随 App 内设置"
  private static let transparentFollowAppLegacy = "跟随app内设置"
  private static let transparentEnableLegacy = "开启透明背景"

  private static let smallPositions = ["左上", "右上", "左中", "右中", "左下", "右下"]
  private static let mediumPositions = ["顶部", "中部", "底部"]

  /// 编辑小组件「透明位置」选项
  static func makeTransparentCollection(filter: SizeFilter) -> INObjectCollection<NSString> {
    let positions = filter == .small ? smallPositions : mediumPositions
    let items = ([transparentOff] + positions).map { $0 as NSString }
    let section = INObjectSection(title: "透明位置", items: items)
    return INObjectCollection(sections: [section])
  }

  /// 将 Intent 选项解析为实际位置。旧的 App 全局选项不再生效。
  static func resolvedTransparentPosition(_ position: String?) -> String {
    let raw = position?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if raw.isEmpty { return transparentOff }
    if isFollowAppOption(raw) || raw == transparentEnableLegacy {
      return transparentOff
    }
    return raw
  }

  private static func isFollowAppOption(_ raw: String) -> Bool {
    if raw == transparentFollowApp || raw == transparentFollowAppLegacy { return true }
    // Intent 文案偶发空格差异
    let compact = raw.replacingOccurrences(of: " ", with: "")
    return compact == "跟随App内设置" || compact == "跟随app内设置"
  }

  static func isTransparentEnabled(_ position: String?) -> Bool {
    let resolved = resolvedTransparentPosition(position)
    return smallPositions.contains(resolved)
      || mediumPositions.contains(resolved)
      || resolved == "居中"
  }

  /// 用作 App Group 文件名片段；旧版已选方位仍可继续显示。
  static func transparentFileKey(_ position: String?, preferMedium: Bool = false) -> String? {
    let resolved = resolvedTransparentPosition(position)
    if preferMedium {
      switch resolved {
      case "顶部", "左上", "右上": return "mediumTop"
      case "中部", "居中": return "mediumMiddle"
      case "底部", "左下", "右下": return "mediumBottom"
      default: return nil
      }
    }
    switch resolved {
    case "左上": return "topLeft"
    case "右上": return "topRight"
    case "左中": return "midLeft"
    case "右中": return "midRight"
    case "左下": return "bottomLeft"
    case "右下": return "bottomRight"
    default: return nil
    }
  }

  static func load(filter: SizeFilter) -> [Item] {
    loadAll().filter { item in
      switch filter {
      case .small: return !item.isMedium
      case .medium: return item.isMedium
      }
    }
  }

  static func loadAll() -> [Item] {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: AppGroupConfig.id
    ) else {
      NSLog("[PetWidgetIntents] App Group unavailable: \(AppGroupConfig.id)")
      return []
    }
    let url = container.appendingPathComponent("savedWidgetConfigs.json")
    guard let data = try? Data(contentsOf: url),
          let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      NSLog("[PetWidgetIntents] No savedWidgetConfigs.json at \(url.path)")
      return []
    }

    return list.compactMap { value -> Item? in
      let id = value["widget_id"] as? Int ?? Int(value["widget_id"] as? String ?? "") ?? 0
      let template = value["template"] as? Int ?? Int(value["template"] as? String ?? "") ?? 0
      guard id > 0, (1...7).contains(template) else { return nil }

      let rawTitle = (value["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      let title = (rawTitle?.isEmpty == false) ? rawTitle! : "小组件"
      let settings = value["settings"] as? [String: Any] ?? [:]
      let column = intValue(settings["widget_column"])
      let isMedium = column > 1 || template == 5 || template == 7
      return Item(id: id, title: title, isMedium: isMedium)
    }
  }

  private static func intValue(_ raw: Any?) -> Int {
    if let n = raw as? Int { return n }
    if let n = raw as? NSNumber { return n.intValue }
    if let s = raw as? String, let n = Int(s) { return n }
    return 0
  }
}
