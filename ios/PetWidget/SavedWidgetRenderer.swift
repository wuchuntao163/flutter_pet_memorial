#if swift(>=5.9)
import AppIntents
#endif
import Combine
import SwiftUI
import UIKit
import WidgetKit

private final class CompatibleImageLoader: ObservableObject {
  @Published var image: UIImage?
  private let url: URL

  init(url: URL) {
    self.url = url
  }

  func load() {
    guard image == nil else { return }
    if url.isFileURL {
      image = UIImage(contentsOfFile: url.path)
      return
    }
    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      guard let data = data, let value = UIImage(data: data) else { return }
      DispatchQueue.main.async { self?.image = value }
    }.resume()
  }
}

struct CompatibleRemoteImage: View {
  @StateObject private var loader: CompatibleImageLoader
  private let contentMode: ContentMode

  init(url: URL, contentMode: ContentMode) {
    _loader = StateObject(wrappedValue: CompatibleImageLoader(url: url))
    self.contentMode = contentMode
  }

  var body: some View {
    Group {
      if let image = loader.image {
        if contentMode == .fill {
          // fill 用 overlay，避免图片理想尺寸撑破父布局（条宽/文字跑偏）
          Color.clear
            .overlay(
              Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
            )
            .clipped()
        } else {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: contentMode)
        }
      } else {
        Color.clear
      }
    }
    .onAppear { loader.load() }
  }
}

struct SavedWidgetConfiguration {
  let widgetId: Int
  let title: String
  let image: String
  let template: Int
  let settings: [String: String]

  static func loadAll() -> [SavedWidgetConfiguration] {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: AppGroupConfig.id
    ) else { return [] }
    let url = container.appendingPathComponent("savedWidgetConfigs.json")
    guard let data = try? Data(contentsOf: url),
          let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return []
    }
    return list.compactMap { value in
      let id = value["widget_id"] as? Int ?? Int(value["widget_id"] as? String ?? "") ?? 0
      let template = value["template"] as? Int ?? Int(value["template"] as? String ?? "") ?? 0
      guard id > 0, (1...7).contains(template) else { return nil }
      let rawSettings = value["settings"] as? [String: Any] ?? [:]
      var settings: [String: String] = [:]
      for (key, item) in rawSettings {
        if let text = item as? String {
          settings[key] = text
        } else if let number = item as? NSNumber {
          settings[key] = number.stringValue
        } else if JSONSerialization.isValidJSONObject(item),
                  let data = try? JSONSerialization.data(withJSONObject: item),
                  let text = String(data: data, encoding: .utf8) {
          settings[key] = text
        } else {
          settings[key] = String(describing: item)
        }
      }
      return SavedWidgetConfiguration(
        widgetId: id,
        title: value["title"] as? String ?? "小组件",
        image: value["image"] as? String ?? "",
        template: template,
        settings: settings
      )
    }
  }

  func string(_ key: String, fallback: String = "") -> String {
    settings[key] ?? fallback
  }

  func int(_ key: String, fallback: Int = 0) -> Int {
    if let value = settings[key], let parsed = Int(value) { return parsed }
    return fallback
  }

  func argb(_ key: String, fallback: UInt32) -> UInt32 {
    guard let raw = settings[key], !raw.isEmpty else { return fallback }
    if let value = UInt32(raw) { return value }
    if let value = Int64(raw) { return UInt32(truncatingIfNeeded: value) }
    return fallback
  }

  var textColor: Color { Color(argb: argb("text_color", fallback: 0xFF000000)) }

  var backgroundColor: Color {
    Color(argb: argb("background_color", fallback: 0xFFF1F2F5))
  }

  /// 含倒计时/日历的模板（无预览图时模板用实时天数）
  var needsLiveDayRender: Bool {
    switch template {
    case 2, 3, 4, 5, 6, 7: return true
    default: return false
    }
  }

  /// 静态样例保存的组件：天数/展示日期冻结，不随今天变化
  var daysAreFixed: Bool {
    let raw = string("days_fixed")
    return raw == "1" || raw.lowercased() == "true"
  }

  /// 按 memorial_date 实时计算天数；days_fixed 时用保存的 memorial_days
  var liveMemorialDays: Int {
    if daysAreFixed {
      return int("memorial_days")
    }
    if let date = Self.parseMemorialDate(string("memorial_date")) {
      return Self.calendarDayDistance(to: date)
    }
    return int("memorial_days")
  }

  /// 多纪念日条目（保存时写入 memorial_items JSON）
  var liveMemorialItems: [(title: String, days: Int, badgeBg: UInt32, badgeText: UInt32, typeLabel: String)] {
    let defaultBg: UInt32 = 0xFFD9E9F9
    let defaultText: UInt32 = 0xFF5B7B9B
    let raw = string("memorial_items")
    if let data = raw.data(using: .utf8),
       let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
       !list.isEmpty {
      return list.prefix(3).map { item in
        let title = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateRaw = (item["date"] as? String) ?? ""
        let itemFixed = Self.isTruthy(item["days_fixed"]) || daysAreFixed
        let days: Int
        if itemFixed {
          if let d = item["days"] as? Int {
            days = d
          } else if let d = Int(item["days"] as? String ?? "") {
            days = d
          } else {
            days = 0
          }
        } else if let date = Self.parseMemorialDate(dateRaw) {
          days = Self.calendarDayDistance(to: date)
        } else if let d = item["days"] as? Int {
          days = d
        } else if let d = Int(item["days"] as? String ?? "") {
          days = d
        } else {
          days = 0
        }
        let bg = Self.argbValue(item["badge_bg"], fallback: defaultBg)
        let text = Self.argbValue(item["badge_text"], fallback: defaultText)
        let label = (item["type_label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (
          title?.isEmpty == false ? title! : "纪念日",
          days,
          bg,
          text,
          label
        )
      }
    }
    let title = string("memorial_title", fallback: self.title)
    return [(title.isEmpty ? "纪念日" : title, liveMemorialDays, defaultBg, defaultText, "")]
  }

  private static func isTruthy(_ raw: Any?) -> Bool {
    if let b = raw as? Bool { return b }
    if let n = raw as? Int { return n != 0 }
    if let n = raw as? Int64 { return n != 0 }
    if let s = raw as? String {
      let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      return v == "1" || v == "true" || v == "yes"
    }
    return false
  }

  func digitUIImage(_ digit: Int) -> UIImage? {
    guard (0...9).contains(digit),
          let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConfig.id
          ) else { return nil }
    let path = container
      .appendingPathComponent("savedWidgetDigits_\(widgetId)", isDirectory: true)
      .appendingPathComponent("\(digit).png")
      .path
    return UIImage(contentsOfFile: path)
  }

  var hasCustomDigits: Bool {
    // 必须 0–9 齐全，否则按普通数字逐位绘制（避免切回普通后仍残留旧图）
    (0..<10).allSatisfy { digitUIImage($0) != nil }
  }

  func iconUIImage() -> UIImage? {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: AppGroupConfig.id
    ) else { return nil }
    let path = container.appendingPathComponent("savedWidgetIcon_\(widgetId).png").path
    return UIImage(contentsOfFile: path)
  }

  private static func argbValue(_ raw: Any?, fallback: UInt32) -> UInt32 {
    if let n = raw as? UInt32 { return n }
    if let n = raw as? Int { return UInt32(truncatingIfNeeded: n) }
    if let n = raw as? Int64 { return UInt32(truncatingIfNeeded: n) }
    if let n = raw as? NSNumber { return UInt32(truncatingIfNeeded: n.int64Value) }
    if let s = raw as? String, let n = UInt32(s) { return n }
    if let s = raw as? String, let n = Int64(s) { return UInt32(truncatingIfNeeded: n) }
    return fallback
  }

  static func parseMemorialDate(_ raw: String) -> Date? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: trimmed) { return date }
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: trimmed) { return date }
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
    if let date = formatter.date(from: trimmed) { return date }
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    if let date = formatter.date(from: trimmed) { return date }
    let dayOnly = String(trimmed.prefix(10))
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: dayOnly)
  }

  static func calendarDayDistance(to date: Date, from now: Date = Date()) -> Int {
    let cal = Calendar.current
    let today = cal.startOfDay(for: now)
    let target = cal.startOfDay(for: date)
    return abs(cal.dateComponents([.day], from: today, to: target).day ?? 0)
  }

  /// 桌面刷新：优先次日 00:00:05，保证跨天更新倒计时
  static func nextTimelineRefreshDate(from now: Date = Date()) -> Date {
    let cal = Calendar.current
    if let midnight = cal.nextDate(
      after: now,
      matching: DateComponents(hour: 0, minute: 0, second: 5),
      matchingPolicy: .nextTime
    ) {
      return midnight
    }
    return now.addingTimeInterval(3600)
  }

  /// 系统组件库预览：优先读 App Group 本地预览图（网络图在 gallery snapshot 常加载失败）
  func previewUIImage() -> UIImage? {
    if let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: AppGroupConfig.id
    ) {
      let preview = container.appendingPathComponent("savedWidgetPreview_\(widgetId).png")
      if let image = UIImage(contentsOfFile: preview.path) {
        return image
      }
    }
    let raw = image.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return nil }
    if raw.hasPrefix("file://"), let url = URL(string: raw) {
      return UIImage(contentsOfFile: url.path)
    }
    if raw.hasPrefix("/") {
      return UIImage(contentsOfFile: raw)
    }
    return nil
  }

  /// 桌面实时渲染用的本地背景（保存时写入 App Group）
  func backgroundUIImage() -> UIImage? {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: AppGroupConfig.id
    ) else { return nil }
    let path = container.appendingPathComponent("savedWidgetBackground_\(widgetId).png").path
    return UIImage(contentsOfFile: path)
  }

  /// 背景文件修改戳，用于强制桌面刷新
  static func backgroundRevision(widgetId: Int) -> Int64 {
    guard widgetId > 0,
          let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConfig.id
          ) else { return 0 }
    let path = container.appendingPathComponent("savedWidgetBackground_\(widgetId).png").path
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
          let modified = attrs[.modificationDate] as? Date else {
      return 0
    }
    return Int64(modified.timeIntervalSince1970 * 1000)
  }

  var remoteImageURL: URL? {
    let raw = image.trimmingCharacters(in: .whitespacesAndNewlines)
    guard raw.hasPrefix("http://") || raw.hasPrefix("https://") else { return nil }
    return URL(string: raw)
  }

  /// 中号：column>1，或中号类模板（5 生日倒计时 / 7 中号）
  var isMediumSize: Bool {
    let column = int("widget_column", fallback: 0)
    if column > 1 { return true }
    return template == 5 || template == 7
  }

  static func loadForFamily(_ family: WidgetFamily) -> [SavedWidgetConfiguration] {
    let wantMedium = family == .systemMedium
    return loadAll().filter { $0.isMediumSize == wantMedium }
  }

  /// 供 WidgetKit 判断 gallery 预览是否变化（配置列表 + 预览图修改时间 + bump 戳）
  static func galleryRevision() -> Int64 {
    let items = loadAll()
    var rev = Int64(items.count)
    if let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: AppGroupConfig.id
    ) {
      let bumpURL = container.appendingPathComponent("galleryRevision.txt")
      if let bumpText = try? String(contentsOf: bumpURL, encoding: .utf8),
         let bump = Int64(bumpText.trimmingCharacters(in: .whitespacesAndNewlines)) {
        rev = rev &* 31 &+ bump
      }
      let configsURL = container.appendingPathComponent("savedWidgetConfigs.json")
      if let attrs = try? FileManager.default.attributesOfItem(atPath: configsURL.path),
         let modified = attrs[.modificationDate] as? Date {
        rev = rev &* 31 &+ Int64(modified.timeIntervalSince1970 * 1000)
      }
      for item in items.prefix(4) {
        rev = rev &* 31 &+ Int64(item.widgetId)
        let preview = container.appendingPathComponent("savedWidgetPreview_\(item.widgetId).png")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: preview.path),
           let modified = attrs[.modificationDate] as? Date {
          rev = rev &* 31 &+ Int64(modified.timeIntervalSince1970 * 1000)
        } else {
          rev = rev &* 31 &+ 1
        }
        rev = rev &* 31 &+ backgroundRevision(widgetId: item.widgetId)
      }
    }
    return rev
  }
}

extension Color {
  init(argb: UInt32) {
    self.init(
      .sRGB,
      red: Double((argb >> 16) & 0xff) / 255,
      green: Double((argb >> 8) & 0xff) / 255,
      blue: Double(argb & 0xff) / 255,
      opacity: Double((argb >> 24) & 0xff) / 255
    )
  }
}

/// 倒计时数字：自定义字体用 App Group 的 0–9 图；普通数字逐位绘制，且不用 SF 系统字
struct WidgetDigitNumber: View {
  let value: Int
  let config: SavedWidgetConfiguration
  let digitHeight: CGFloat
  let fontSize: CGFloat
  let fontWeight: Font.Weight
  let fallbackColor: Color
  /// 普通数字逐位间距（0：不挤；自定义图片字体用 spacing 0）
  var digitSpacing: CGFloat = 0
  /// 单位「天」：与数字同一 HStack，保证基线/底部对齐
  var unit: String? = nil
  var unitFontSize: CGFloat? = nil
  /// 自定义数字图时，「天」相对底部的光学微调
  var unitBottomPadding: CGFloat = 0

  init(
    value: Int,
    config: SavedWidgetConfiguration,
    digitHeight: CGFloat,
    fontSize: CGFloat = 40,
    weight: Font.Weight = .bold,
    color: Color = .white,
    digitSpacing: CGFloat = 0,
    unit: String? = nil,
    unitFontSize: CGFloat? = nil,
    unitBottomPadding: CGFloat = 0
  ) {
    self.value = max(0, value)
    self.config = config
    self.digitHeight = digitHeight
    self.fontSize = fontSize
    self.fontWeight = weight
    self.fallbackColor = color
    self.digitSpacing = digitSpacing
    self.unit = unit
    self.unitFontSize = unitFontSize
    self.unitBottomPadding = unitBottomPadding
  }

  private var resolvedUnitSize: CGFloat { unitFontSize ?? fontSize }

  @ViewBuilder
  private var unitLabel: some View {
    if let unit = unit {
      Text(unit)
        .font(.system(size: resolvedUnitSize, weight: fontWeight))
        .foregroundColor(fallbackColor)
        .padding(.bottom, config.hasCustomDigits ? unitBottomPadding : 0)
    }
  }

  var body: some View {
    let chars = Array(String(value))
    if config.hasCustomDigits {
      HStack(alignment: .bottom, spacing: 0) {
        ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
          if let d = Int(String(ch)), let image = config.digitUIImage(d) {
            Image(uiImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(height: digitHeight)
          }
        }
        unitLabel
      }
    } else {
      // 普通数字 +「天」同一基线，避免外层再包一层导致对不齐
      HStack(alignment: .lastTextBaseline, spacing: digitSpacing) {
        ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
          Text(String(ch))
            .font(Self.plainDigitFont(size: fontSize, weight: fontWeight))
            .foregroundColor(fallbackColor)
        }
        unitLabel
      }
      .minimumScaleFactor(0.45)
      .lineLimit(1)
    }
  }

  /// 普通数字专用：优先 Avenir Next，避免 SF Pro 系统数字排版
  private static func plainDigitFont(size: CGFloat, weight: Font.Weight) -> Font {
    let name: String
    switch weight {
    case .ultraLight, .thin, .light:
      name = "AvenirNext-Regular"
    case .regular, .medium:
      name = "AvenirNext-Medium"
    case .semibold:
      name = "AvenirNext-DemiBold"
    default:
      name = "AvenirNext-Bold"
    }
    if UIFont(name: name, size: size) != nil {
      return Font.custom(name, size: size)
    }
    return .system(size: size, weight: weight, design: .rounded)
  }
}

struct SavedWidgetTemplateView: View {
  @Environment(\.widgetFamily) private var family
  let config: SavedWidgetConfiguration
  /// 假透明时不绘制纯色/图片底，才能叠上壁纸裁切片
  var hideBackground: Bool = false

  var body: some View {
    // 内容决定布局；背景铺满且不参与测宽（iOS 14 兼容用 background(View)）
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        Group {
          if hideBackground {
            Color.clear
          } else {
            ZStack {
              config.backgroundColor
              widgetBackgroundImage
            }
          }
        }
      )
      .clipped()
  }

  /// 优先 App Group 本地缓存；没有则尝试网络 URL（与背景列表同源）
  @ViewBuilder private var widgetBackgroundImage: some View {
    if let image = config.backgroundUIImage() {
      GeometryReader { geo in
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: geo.size.width, height: geo.size.height)
          .clipped()
      }
    } else if let url = URL(string: config.string("background_image")),
              config.string("background_image").hasPrefix("http") {
      GeometryReader { geo in
        CompatibleRemoteImage(url: url, contentMode: .fill)
          .frame(width: geo.size.width, height: geo.size.height)
          .clipped()
      }
    }
  }

  @ViewBuilder private var content: some View {
    switch config.template {
    case 1:
      petTemplate
    case 2:
      photoCountdownTemplate
    case 3:
      simpleTemplate
    case 4, 5:
      // 4=多纪念日小号，5=生日倒计时/多纪念日中号（同列表布局，按 family 区分）
      multiMemorialTemplate
    case 6:
      calendarTemplate
    case 7:
      mediumTemplate
    default:
      Text(config.title)
    }
  }

  @ViewBuilder private var petTemplate: some View {
    if let image = cachedPetImage() {
      Image(uiImage: image).resizable().scaledToFit().padding(12)
    } else if let url = URL(string: config.string("pet_image")),
              !config.string("pet_image").isEmpty {
      CompatibleRemoteImage(url: url, contentMode: .fit).padding(12)
    } else {
      Image(systemName: "pawprint.fill")
        .font(.system(size: 42))
        .foregroundColor(.pink.opacity(0.75))
    }
  }

  private func cachedPetImage() -> UIImage? {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: AppGroupConfig.id
    ) else { return nil }
    let url = container.appendingPathComponent("petWidgetImage.png")
    guard let data = try? Data(contentsOf: url) else { return nil }
    return UIImage(data: data)
  }

  private var photoCountdownTemplate: some View {
    VStack(spacing: 0) {
      Text(config.string("memorial_title", fallback: config.title))
        .font(.system(size: 14, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      Spacer(minLength: 7)
      WidgetDigitNumber(
        value: config.liveMemorialDays,
        config: config,
        digitHeight: family == .systemMedium ? 48 : 40,
        fontSize: family == .systemMedium ? 42 : 40,
        weight: .semibold,
        color: config.textColor
      )
      Spacer(minLength: 7)
      Text(dateText)
        .font(.system(size: 12, weight: .medium))
        .opacity(0.82)
    }
    .foregroundColor(config.textColor)
    .padding(EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10))
  }

  /// 对应 Flutter simple 预览：右上角天数 + Days，底部标题与日期
  private var simpleTemplate: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Spacer(minLength: 0)
        VStack(alignment: .trailing, spacing: 0) {
          WidgetDigitNumber(
            value: config.liveMemorialDays,
            config: config,
            digitHeight: 41,
            fontSize: 41,
            weight: .semibold,
            color: config.textColor
          )
          Text("Days")
            .font(.system(size: 16, weight: .medium))
            .opacity(0.38)
            .offset(y: -5)
        }
      }
      Spacer(minLength: 0)
      Text(config.string("memorial_title", fallback: "纪念日还有"))
        .font(.system(size: 15, weight: .semibold))
        .lineLimit(1)
      Spacer().frame(height: 5)
      Text(shortDateText)
        .font(.system(size: 12, weight: .regular))
        .opacity(0.42)
    }
    .foregroundColor(config.textColor)
    .padding(EdgeInsets(top: 10, leading: 16, bottom: 11, trailing: 16))
  }

  private var multiMemorialTemplate: some View {
    let items = config.liveMemorialItems
    let isMedium = family == .systemMedium
    // 小号：条高 36、字号 13；中号：条高 37、字号 15。条间距大小号一致
    let rowHeight: CGFloat = isMedium ? 37 : 36
    let rowSpacing: CGFloat = 5
    let titleSize: CGFloat = isMedium ? 15 : 13
    let daysSize: CGFloat = isMedium ? 15 : 13
    let daysWidth: CGFloat = isMedium ? 60 : 50
    return VStack(spacing: rowSpacing) {
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
        HStack(spacing: 0) {
          // 天数：用 WidgetDigitNumber（自定义数字图 / Avenir），不用系统 SF 数字
          WidgetDigitNumber(
            value: item.days,
            config: config,
            digitHeight: daysSize,
            fontSize: daysSize,
            weight: .bold,
            color: Color(argb: item.badgeText),
            digitSpacing: 0,
            unit: "天",
            unitFontSize: daysSize,
            unitBottomPadding: 1
          )
          .frame(width: daysWidth)
          .frame(maxHeight: .infinity)
          .background(Color(argb: item.badgeBg))
          Text(item.title)
            .font(.system(size: titleSize, weight: .semibold))
            .foregroundColor(.black)
            .lineLimit(1)
            .padding(.leading, 6)
            .padding(.trailing, isMedium ? 0 : 7)
            .frame(maxWidth: .infinity, alignment: .leading)
          if isMedium, !item.typeLabel.isEmpty {
            Text(item.typeLabel)
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(Color(argb: item.badgeText))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color(argb: item.badgeBg))
              .clipShape(RoundedRectangle(cornerRadius: 5))
              .padding(.trailing, 7)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
    .padding(
      isMedium
        ? EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        : EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)
    )
  }

  private var calendarTemplate: some View {
    let now = Date()
    // 月份 / 星期固定英文；表头黑色条固定；天数按整卡（含表头）垂直居中
    // 桌面组件字号/尺寸大于 Flutter 预览
    let month = Self.format(now, pattern: "LLLL", locale: "en_US")
    let day = Calendar.current.component(.day, from: now)
    let weekday = Self.format(now, pattern: "EEEE", locale: "en_US")
    let dayBoxH: CGFloat = 87
    let weekdayGap: CGFloat = 4
    return GeometryReader { geo in
      let dayTop = (geo.size.height - dayBoxH) / 2
      ZStack(alignment: .topLeading) {
        VStack(spacing: 0) {
          Text(month)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(Color.black)
          Spacer(minLength: 0)
        }
        .frame(width: geo.size.width, height: geo.size.height)

        WidgetDigitNumber(
          value: day,
          config: config,
          digitHeight: 70,
          fontSize: 80,
          weight: .bold,
          color: config.textColor
        )
        .frame(width: geo.size.width, height: dayBoxH)
        .offset(y: dayTop)

        Text(weekday)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(config.textColor)
          .frame(width: geo.size.width)
          .offset(y: dayTop + dayBoxH + weekdayGap)
      }
    }
  }

  /// 对应 Flutter medium 预览：星期 / 标题 / 天数+天 / 日期
  private var mediumTemplate: some View {
    let memorialDate = SavedWidgetConfiguration.parseMemorialDate(config.string("memorial_date"))
    let weekdayLabels = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
    let fixedWeekday = config.string("memorial_weekday")
    let fixedDateLabel = config.string("memorial_date_label")
    let weekday: String = {
      if !fixedWeekday.isEmpty { return fixedWeekday }
      let date = memorialDate ?? Date()
      let wd = Calendar.current.component(.weekday, from: date)
      let idx = (wd + 5) % 7
      return weekdayLabels[idx]
    }()
    let dateLabel: String = {
      if !fixedDateLabel.isEmpty { return fixedDateLabel }
      guard let date = memorialDate else { return "" }
      let y = Calendar.current.component(.year, from: date)
      let m = Calendar.current.component(.month, from: date)
      let d = Calendar.current.component(.day, from: date)
      return "\(y).\(m).\(d)"
    }()
    return VStack(alignment: .leading, spacing: 0) {
      Text(weekday)
        .font(.system(size: 11, weight: .semibold))
      Spacer(minLength: 0)
      // 名称紧贴倒数日；倒数日与右侧日期底对齐
      VStack(alignment: .leading, spacing: 2) {
        Text(config.string("memorial_title", fallback: config.title))
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
          .offset(y: 5)
        HStack(alignment: config.hasCustomDigits ? .bottom : .lastTextBaseline, spacing: 2) {
          WidgetDigitNumber(
            value: config.liveMemorialDays,
            config: config,
            digitHeight: 49,
            fontSize: 51,
            weight: .semibold,
            color: config.textColor,
            unit: "天",
            unitFontSize: 15,
            unitBottomPadding: 5
          )
          Spacer(minLength: 0)
          Text(dateLabel)
            .font(.system(size: 11, weight: .medium))
            .opacity(0.82)
        }
      }
    }
    .foregroundColor(config.textColor)
    // 上 20 / 下 4，星期与名称+倒数日整体偏下
    .padding(EdgeInsets(top: 20, leading: 15, bottom: 4, trailing: 15))
  }

  private var dateText: String {
    let fixed = config.string("memorial_date_label")
    if !fixed.isEmpty { return fixed }
    let raw = config.string("memorial_date")
    guard let date = SavedWidgetConfiguration.parseMemorialDate(raw) else { return "" }
    let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    let cal = Calendar.current
    let y = cal.component(.year, from: date)
    let m = String(format: "%02d", cal.component(.month, from: date))
    let d = String(format: "%02d", cal.component(.day, from: date))
    let wd = cal.component(.weekday, from: date)
    let idx = (wd + 5) % 7
    return "\(y)-\(m)-\(d)  周\(weekdays[idx])"
  }

  private var shortDateText: String {
    // 静态样例：天数冻结；日期文案用保存时的 memorial_date（不再随跨天改天数）
    let raw = config.string("memorial_date")
    guard let date = SavedWidgetConfiguration.parseMemorialDate(raw) else { return "" }
    return Self.format(date, pattern: "yyyy-MM-dd")
  }

  private static func format(
    _ date: Date,
    pattern: String,
    locale: String = "zh_CN"
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: locale)
    formatter.dateFormat = pattern
    return formatter.string(from: date)
  }
}

// MARK: - App Intent：系统长按「编辑小组件」时选择「我的组件」
// 需要 Xcode 15+ / Swift 5.9；本机 Xcode 14.2 走 PetWidget.swift 里的 StaticConfiguration 兜底

#if swift(>=5.9)

@available(iOSApplicationExtension 17.0, *)
struct SavedWidgetEntity: AppEntity {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "我的组件")
  static var defaultQuery = SavedWidgetEntityQuery()

  var id: Int
  var title: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(title)")
  }
}

@available(iOSApplicationExtension 17.0, *)
struct SavedWidgetEntityQuery: EntityQuery {
  func entities(for identifiers: [Int]) async throws -> [SavedWidgetEntity] {
    SavedWidgetConfiguration.loadAll()
      .filter { identifiers.contains($0.widgetId) }
      .map { SavedWidgetEntity(id: $0.widgetId, title: $0.title) }
  }

  func suggestedEntities() async throws -> [SavedWidgetEntity] {
    // 列表里标注尺寸，避免编辑时误选中号/小号
    SavedWidgetConfiguration.loadAll().map {
      let tag = $0.isMediumSize ? "中号" : "小号"
      return SavedWidgetEntity(id: $0.widgetId, title: "\($0.title)（\(tag)）")
    }
  }

  func defaultResult() async -> SavedWidgetEntity? {
    // 不默认选中，避免小号桌面组件编辑时落到中号样式
    return nil
  }
}

@available(iOSApplicationExtension 17.0, *)
struct SelectSavedWidgetIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "编辑小组件"
  static var description = IntentDescription("选择在桌面显示的「我的组件」样式")

  @Parameter(title: "当前组件")
  var widget: SavedWidgetEntity?
}

@available(iOSApplicationExtension 17.0, *)
struct SavedWidgetIntentProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    .setup(preview: true)
  }

  func snapshot(
    for configuration: SelectSavedWidgetIntent,
    in context: Context
  ) async -> SimpleEntry {
    if context.isPreview {
      return .setup(preview: true)
    }
    return makeEntry(configuration: configuration)
  }

  func timeline(
    for configuration: SelectSavedWidgetIntent,
    in context: Context
  ) async -> Timeline<SimpleEntry> {
    let entry = makeEntry(configuration: configuration)
    return Timeline(
      entries: [entry],
      policy: .after(SavedWidgetConfiguration.nextTimelineRefreshDate())
    )
  }

  private func makeEntry(configuration: SelectSavedWidgetIntent) -> SimpleEntry {
    // 未选择时保持 nil → 显示引导，不自动套用第一个
    let selectedId = configuration.widget?.id
    return SimpleEntry(
      date: Date(),
      data: PetWidgetDataLoader.load(),
      widgetId: selectedId,
      isGalleryPreview: false,
      transparentPosition: nil
    )
  }
}

@available(iOSApplicationExtension 17.0, *)
struct ConfigurableHomeWidgetSmall: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: "PetWidgetSmall",
      intent: SelectSavedWidgetIntent.self,
      provider: SavedWidgetIntentProvider()
    ) { entry in
      PetWidgetEntryView(entry: entry)
        .containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName("小号")
    .description("选择你要添加的组件尺寸添加到桌面")
    .supportedFamilies([.systemSmall])
    .contentMarginsDisabled()
  }
}

@available(iOSApplicationExtension 17.0, *)
struct ConfigurableHomeWidgetMedium: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: "PetWidgetMedium",
      intent: SelectSavedWidgetIntent.self,
      provider: SavedWidgetIntentProvider()
    ) { entry in
      PetWidgetEntryView(entry: entry)
        .containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName("中号")
    .description("选择你要添加的组件尺寸添加到桌面")
    .supportedFamilies([.systemMedium])
    .contentMarginsDisabled()
  }
}

#endif
