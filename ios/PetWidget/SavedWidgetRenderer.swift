import SwiftUI
import WidgetKit
import AppIntents
import UIKit

private final class CompatibleImageLoader: ObservableObject {
  @Published var image: UIImage?
  private let url: URL

  init(url: URL) {
    self.url = url
  }

  func load() {
    guard image == nil else { return }
    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data = data, let value = UIImage(data: data) else { return }
      DispatchQueue.main.async { self.image = value }
    }.resume()
  }
}

private struct CompatibleRemoteImage: View {
  @StateObject private var loader: CompatibleImageLoader
  let contentMode: ContentMode

  init(url: URL, contentMode: ContentMode) {
    _loader = StateObject(wrappedValue: CompatibleImageLoader(url: url))
    self.contentMode = contentMode
  }

  var body: some View {
    Group {
      if let image = loader.image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: contentMode)
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
  let settings: [String: Any]

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
      return SavedWidgetConfiguration(
        widgetId: id,
        title: value["title"] as? String ?? "小组件",
        image: value["image"] as? String ?? "",
        template: template,
        settings: value["settings"] as? [String: Any] ?? [:]
      )
    }
  }

  func string(_ key: String, fallback: String = "") -> String {
    if let value = settings[key] as? String { return value }
    return settings[key].map(String.init(describing:)) ?? fallback
  }

  func int(_ key: String, fallback: Int = 0) -> Int {
    if let value = settings[key] as? Int { return value }
    if let value = settings[key] as? NSNumber { return value.intValue }
    return Int(string(key)) ?? fallback
  }

  var textColor: Color { Color(argb: UInt32(int("text_color", fallback: Int(0xFF000000)))) }
  var backgroundColor: Color {
    Color(argb: UInt32(int("background_color", fallback: Int(0xFFF1F2F5))))
  }
}

private extension Color {
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

struct SavedWidgetTemplateView: View {
  @Environment(\.widgetFamily) private var family
  let config: SavedWidgetConfiguration

  var body: some View {
    ZStack {
      config.backgroundColor
      backgroundImage
      content
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  @ViewBuilder private var backgroundImage: some View {
    let value = config.string("background_image")
    if let url = URL(string: value), !value.isEmpty {
      CompatibleRemoteImage(url: url, contentMode: .fill)
    }
  }

  @ViewBuilder private var content: some View {
    switch config.template {
    case 1: petTemplate
    case 2: photoCountdownTemplate
    case 3: simpleTemplate
    case 4: multiMemorialTemplate
    case 5: birthdayTemplate
    case 6: calendarTemplate
    case 7: mediumTemplate
    default: Text(config.title)
    }
  }

  private var petTemplate: some View {
    let value = config.string("pet_image")
    return Group {
      if let image = cachedPetImage() {
        Image(uiImage: image).resizable().scaledToFit().padding(12)
      } else if let url = URL(string: value), !value.isEmpty {
        CompatibleRemoteImage(url: url, contentMode: .fit).padding(12)
      } else {
        Image(systemName: "pawprint.fill")
          .font(.system(size: 42))
          .foregroundColor(.pink.opacity(0.75))
      }
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
    VStack(spacing: 5) {
      HStack(spacing: 5) {
        Text(config.string("memorial_title", fallback: config.title))
          .font(.system(size: 12, weight: .semibold))
        Image(systemName: "heart.fill").font(.system(size: 13))
      }
      Spacer(minLength: 0)
      Text("\(config.int("memorial_days"))")
        .font(.system(size: family == .systemMedium ? 42 : 34, weight: .bold))
      Spacer(minLength: 0)
      Text(dateText).font(.system(size: 10, weight: .medium))
    }
    .foregroundColor(config.textColor)
    .padding(14)
  }

  private var simpleTemplate: some View {
    VStack(spacing: 0) {
      Text(config.string("memorial_title", fallback: config.title))
        .font(.system(size: 12, weight: .semibold))
      Spacer(minLength: 4)
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text("\(config.int("memorial_days"))")
          .font(.system(size: family == .systemMedium ? 48 : 38, weight: .bold))
        Text("Days").font(.system(size: 15, weight: .semibold))
      }
      Spacer(minLength: 4)
    }
    .foregroundColor(config.textColor)
    .padding(14)
  }

  private var multiMemorialTemplate: some View {
    VStack(spacing: 7) {
      ForEach(0..<3, id: \.self) { index in
        HStack {
          Text(index == 0 ? config.title : "纪念日")
            .lineLimit(1)
          Spacer()
          Text(index == 0 ? "\(config.int("memorial_days"))天" : "--天")
            .fontWeight(.bold)
        }
        .font(.system(size: family == .systemMedium ? 12 : 10))
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 7))
      }
    }
    .foregroundColor(config.textColor)
    .padding(10)
  }

  private var birthdayTemplate: some View {
    HStack(spacing: 12) {
      Image(systemName: "birthday.cake.fill")
        .font(.system(size: 32))
        .foregroundColor(.pink)
      VStack(alignment: .leading, spacing: 6) {
        Text(config.string("memorial_title", fallback: config.title))
          .font(.system(size: 13, weight: .semibold))
        HStack(alignment: .firstTextBaseline, spacing: 3) {
          Text("\(config.int("memorial_days"))")
            .font(.system(size: 34, weight: .bold))
          Text("天").font(.system(size: 14, weight: .semibold))
        }
      }
      Spacer(minLength: 0)
    }
    .foregroundColor(config.textColor)
    .padding(16)
  }

  private var calendarTemplate: some View {
    let now = Date()
    let month = Self.format(now, pattern: "LLLL")
    let day = Calendar.current.component(.day, from: now)
    let weekday = Self.format(now, pattern: "EEEE")
    return VStack(spacing: 4) {
      Text(month).font(.system(size: 13, weight: .semibold))
      Spacer(minLength: 0)
      Text("\(day)").font(.system(size: 48, weight: .bold))
      Text(weekday).font(.system(size: 10, weight: .medium))
      Spacer(minLength: 0)
    }
    .foregroundColor(config.textColor)
    .padding(12)
  }

  private var mediumTemplate: some View {
    HStack {
      VStack(alignment: .leading, spacing: 7) {
        Text(config.string("memorial_title", fallback: config.title))
          .font(.system(size: 14, weight: .semibold))
        HStack(alignment: .firstTextBaseline, spacing: 3) {
          Text("\(config.int("memorial_days"))")
            .font(.system(size: 42, weight: .bold))
          Text("天").font(.system(size: 15, weight: .semibold))
        }
      }
      Spacer()
    }
    .foregroundColor(config.textColor)
    .padding(18)
  }

  private var dateText: String {
    let raw = config.string("memorial_date")
    guard let date = ISO8601DateFormatter().date(from: raw) else { return "" }
    return Self.format(date, pattern: "yyyy-MM-dd EEEE")
  }

  private static func format(_ date: Date, pattern: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = pattern
    return formatter.string(from: date)
  }
}

@available(iOSApplicationExtension 17.0, *)
struct SavedWidgetEntity: AppEntity, Identifiable {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "当前组件")
  static var defaultQuery = SavedWidgetEntityQuery()

  let id: Int
  let title: String

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
    SavedWidgetConfiguration.loadAll().map {
      SavedWidgetEntity(id: $0.widgetId, title: $0.title)
    }
  }

  func defaultResult() async -> SavedWidgetEntity? {
    guard let first = SavedWidgetConfiguration.loadAll().first else { return nil }
    return SavedWidgetEntity(id: first.widgetId, title: first.title)
  }
}

@available(iOSApplicationExtension 17.0, *)
struct SelectSavedWidgetIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "编辑小组件"
  static var description = IntentDescription("选择在桌面显示的组件")

  @Parameter(title: "当前组件")
  var widget: SavedWidgetEntity?
}

@available(iOSApplicationExtension 17.0, *)
struct SavedWidgetIntentProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(date: Date(), data: .preview, config: SavedWidgetConfiguration.loadAll().first)
  }

  func snapshot(
    for configuration: SelectSavedWidgetIntent,
    in context: Context
  ) async -> SimpleEntry {
    entry(for: configuration)
  }

  func timeline(
    for configuration: SelectSavedWidgetIntent,
    in context: Context
  ) async -> Timeline<SimpleEntry> {
    let entry = entry(for: configuration)
    let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
    return Timeline(entries: [entry], policy: .after(refresh))
  }

  private func entry(for intent: SelectSavedWidgetIntent) -> SimpleEntry {
    let configs = SavedWidgetConfiguration.loadAll()
    let selected = intent.widget.flatMap { entity in
      configs.first { $0.widgetId == entity.id }
    } ?? configs.first
    return SimpleEntry(date: Date(), data: .empty, config: selected)
  }
}

@available(iOSApplicationExtension 17.0, *)
struct ConfigurableSavedWidget: Widget {
  let kind = "PetWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: SelectSavedWidgetIntent.self,
      provider: SavedWidgetIntentProvider()
    ) { entry in
      PetWidgetEntryView(entry: entry)
        .containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName("萌宠组件")
    .description("从我的组件中选择桌面样式")
    .supportedFamilies([.systemSmall, .systemMedium])
    .contentMarginsDisabled()
  }
}
