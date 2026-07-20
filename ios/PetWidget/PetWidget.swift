import WidgetKit
import SwiftUI
import UIKit

// Extension module is named PetWidget — do not declare a type with that name.

private enum WidgetShared {
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

/// Entry must be Sendable. Do not embed `[String: Any]` configs here.
struct SimpleEntry: TimelineEntry, Sendable {
    let date: Date
    let data: PetWidgetData
    let widgetId: Int?
}

struct PetWidgetTimelineProvider: TimelineProvider {
    typealias Entry = SimpleEntry

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: .preview, widgetId: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let data = context.isPreview ? PetWidgetData.preview : (loadWidgetData() ?? .empty)
        completion(SimpleEntry(
            date: Date(),
            data: data,
            widgetId: SavedWidgetConfiguration.loadAll().first?.widgetId
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let data = loadWidgetData() ?? .empty
        let now = Date()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: now)
            ?? now.addingTimeInterval(900)
        let entry = SimpleEntry(
            date: now,
            data: data,
            widgetId: SavedWidgetConfiguration.loadAll().first?.widgetId
        )
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadWidgetData() -> PetWidgetData? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetShared.appGroupId
        ) else {
            return nil
        }
        let url = container.appendingPathComponent(WidgetShared.widgetDataFileName)
        guard let raw = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
            return nil
        }
        return PetWidgetData(
            petName: dict["petName"] as? String ?? "",
            petType: dict["petType"] as? String ?? "",
            petAge: dict["petAge"] as? String ?? "",
            petImageUrl: dict["petImageUrl"] as? String ?? "",
            memorials: dict["memorials"] as? String ?? "[]",
            updatedAt: Self.parseUpdatedAt(dict["updatedAt"])
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

struct PetWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SimpleEntry

    var body: some View {
        Group {
            if let config = resolvedConfig {
                SavedWidgetTemplateView(config: config)
                    .id("\(config.widgetId)-\(entry.data.updatedAt)-\(WidgetShared.cachedImageRevision())")
            } else {
                petContent
                    .id("\(entry.data.updatedAt)-\(WidgetShared.cachedImageRevision())")
                    .padding(widgetPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resolvedConfig: SavedWidgetConfiguration? {
        let all = SavedWidgetConfiguration.loadAll()
        if let widgetId = entry.widgetId {
            return all.first { $0.widgetId == widgetId } ?? all.first
        }
        return all.first
    }

    private var widgetPadding: EdgeInsets {
        if family == .systemMedium {
            return EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        }
        return EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
    }

    @ViewBuilder
    private var petContent: some View {
        if let image = loadCachedPetImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            placeholderPet
        }
    }

    private var placeholderPet: some View {
        VStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange.opacity(0.7))
            if entry.data.petName.isEmpty {
                Text("打开应用同步宠物")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(entry.data.petName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
        }
        .padding(8)
    }

    private func loadCachedPetImage() -> UIImage? {
        guard let path = WidgetShared.cachedImagePath(),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return UIImage(data: data)
    }
}

struct HomeScreenPetWidgetSmall: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "PetWidgetSmall",
            provider: PetWidgetTimelineProvider()
        ) { entry in
            PetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("小号")
        .description("选择保存在我的组件中的样式")
        .supportedFamilies([.systemSmall])
    }
}

struct HomeScreenPetWidgetMedium: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "PetWidgetMedium",
            provider: PetWidgetTimelineProvider()
        ) { entry in
            PetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("中号")
        .description("选择保存在我的组件中的样式")
        .supportedFamilies([.systemMedium])
    }
}
