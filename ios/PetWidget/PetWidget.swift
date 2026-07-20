import WidgetKit
import SwiftUI
import UIKit

// Extension module is named PetWidget — do not declare a type with that same name.

enum WidgetShared {
    static let appGroupId = AppGroupConfig.id
    static let widgetDataFileName = "petWidgetData.json"
    static let widgetImageName = "petWidgetImage.png"

    static func cachedImagePath() -> String? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) else {
            return nil
        }
        let path = container.appendingPathComponent(widgetImageName).path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    static func cachedImageRevision() -> Int64 {
        guard let path = cachedImagePath() else { return 0 }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modified = attrs[.modificationDate] as? Date else {
            return 0
        }
        return Int64(modified.timeIntervalSince1970 * 1000)
    }
}

struct PetWidgetData: Codable, Sendable {
    let petName: String
    let petType: String
    let petAge: String
    let petImageUrl: String
    let memorials: String
    let updatedAt: Int64

    static let preview = PetWidgetData(
        petName: "小猫咪",
        petType: "2",
        petAge: "30",
        petImageUrl: "",
        memorials: "[]",
        updatedAt: 0
    )

    static let empty = PetWidgetData(
        petName: "",
        petType: "",
        petAge: "",
        petImageUrl: "",
        memorials: "[]",
        updatedAt: 0
    )
}

struct SimpleEntry: TimelineEntry, Sendable {
    let date: Date
    let data: PetWidgetData
    /// Selected「我的组件」id；nil = 未配置，显示图二引导
    let widgetId: Int?
    let isGalleryPreview: Bool

    static func setup(date: Date = Date(), preview: Bool = false) -> SimpleEntry {
        SimpleEntry(date: date, data: .empty, widgetId: nil, isGalleryPreview: preview)
    }
}

enum PetWidgetDataLoader {
    static func load() -> PetWidgetData {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetShared.appGroupId
        ) else {
            return .empty
        }
        let url = container.appendingPathComponent(WidgetShared.widgetDataFileName)
        guard let raw = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
            return .empty
        }
        return PetWidgetData(
            petName: dict["petName"] as? String ?? "",
            petType: dict["petType"] as? String ?? "",
            petAge: dict["petAge"] as? String ?? "",
            petImageUrl: dict["petImageUrl"] as? String ?? "",
            memorials: dict["memorials"] as? String ?? "[]",
            updatedAt: parseUpdatedAt(dict["updatedAt"])
        )
    }

    private static func parseUpdatedAt(_ value: Any?) -> Int64 {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? Double { return Int64(value) }
        if let value = value as? String, let parsed = Int64(value) { return parsed }
        return 0
    }
}

// MARK: - 图二：未配置时的桌面占位引导

struct WidgetSetupGuideView: View {
    @Environment(\.widgetFamily) private var family

    private let stepYellow = Color(red: 1.0, green: 0.839, blue: 0.039)
    private let stepText = Color(red: 0.235, green: 0.235, blue: 0.263)
    private let lineColor = Color(red: 0.82, green: 0.82, blue: 0.84)

    private var title: String {
        family == .systemMedium ? "中号组件" : "小号组件"
    }

    private let steps = [
        "长按进入编辑模式",
        "点击编辑小组件",
        "选择所需的小组件",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.orange)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 10)

            GeometryReader { geo in
                let rowH = geo.size.height / CGFloat(steps.count)
                ZStack(alignment: .topLeading) {
                    Path { path in
                        let x = CGFloat(9)
                        path.move(to: CGPoint(x: x, y: rowH * 0.35))
                        path.addLine(to: CGPoint(x: x, y: rowH * (CGFloat(steps.count) - 0.35)))
                    }
                    .stroke(lineColor, lineWidth: 1.5)

                    VStack(spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                            HStack(alignment: .center, spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(stepYellow)
                                        .frame(width: 18, height: 18)
                                    Text("\(index + 1)")
                                        .font(.system(size: 11, weight: .bold).italic())
                                        .foregroundColor(.black)
                                }
                                Text(text)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(stepText)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                                Spacer(minLength: 0)
                            }
                            .frame(height: rowH, alignment: .center)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - 图一：系统组件库里的预览内容（最多 2 个「我的组件」缩略图）

struct WidgetGalleryPreviewView: View {
    let thumbs: [SavedWidgetConfiguration]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                Text("哈基米纪念日")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Text("点击下方")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12, weight: .semibold))
                Text("添加小组件")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.blue))

            Text("将组件添加到桌面")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer(minLength: 0)

            if !thumbs.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(thumbs.prefix(2).enumerated()), id: \.offset) { _, item in
                        galleryThumb(item)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    @ViewBuilder
    private func galleryThumb(_ item: SavedWidgetConfiguration) -> some View {
        Group {
            if let url = URL(string: item.image), !item.image.isEmpty {
                CompatibleRemoteImage(url: url, contentMode: .fill)
            } else {
                ZStack {
                    Color(white: 0.93)
                    Text(String(item.title.prefix(1)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white, lineWidth: 2)
        )
    }
}

// MARK: - Entry view

struct PetWidgetEntryView: View {
    let entry: SimpleEntry

    var body: some View {
        Group {
            if entry.isGalleryPreview {
                WidgetGalleryPreviewView(
                    thumbs: Array(SavedWidgetConfiguration.loadAll().prefix(2))
                )
            } else if let config = resolvedConfig {
                SavedWidgetTemplateView(config: config)
                    .id("\(config.widgetId)-\(entry.data.updatedAt)-\(WidgetShared.cachedImageRevision())")
            } else {
                // 图二：已放到桌面但尚未「编辑小组件」选择样式
                WidgetSetupGuideView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resolvedConfig: SavedWidgetConfiguration? {
        guard let widgetId = entry.widgetId else { return nil }
        return SavedWidgetConfiguration.loadAll().first { $0.widgetId == widgetId }
    }
}

// MARK: - Static provider (iOS 16.2 fallback：无法系统配置时用首个「我的组件」)

struct PetWidgetTimelineProvider: TimelineProvider {
    typealias Entry = SimpleEntry

    func placeholder(in context: Context) -> SimpleEntry {
        .setup(preview: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        if context.isPreview {
            completion(.setup(preview: true))
            return
        }
        let id = SavedWidgetConfiguration.loadAll().first?.widgetId
        completion(SimpleEntry(
            date: Date(),
            data: PetWidgetDataLoader.load(),
            widgetId: id,
            isGalleryPreview: false
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let id = SavedWidgetConfiguration.loadAll().first?.widgetId
        let entry = SimpleEntry(
            date: Date(),
            data: PetWidgetDataLoader.load(),
            widgetId: id,
            isGalleryPreview: false
        )
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct HomeScreenPetWidgetSmall: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PetWidgetSmall", provider: PetWidgetTimelineProvider()) { entry in
            PetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("小号")
        .description("选择你要添加的组件尺寸添加到桌面")
        .supportedFamilies([.systemSmall])
    }
}

struct HomeScreenPetWidgetMedium: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PetWidgetMedium", provider: PetWidgetTimelineProvider()) { entry in
            PetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("中号")
        .description("选择你要添加的组件尺寸添加到桌面")
        .supportedFamilies([.systemMedium])
    }
}
