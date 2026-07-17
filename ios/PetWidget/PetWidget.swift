import WidgetKit
import SwiftUI

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

struct PetWidgetData: Codable {
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

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: PetWidgetData.preview, config: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let data = context.isPreview ? PetWidgetData.preview : (loadWidgetData() ?? PetWidgetData.empty)
        completion(SimpleEntry(
            date: Date(),
            data: data,
            config: SavedWidgetConfiguration.loadAll().first
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let data = loadWidgetData() ?? PetWidgetData.empty
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!

        let hasImage = WidgetShared.cachedImagePath() != nil
        NSLog(
            "[PetWidget] timeline pet=\(data.petName) url=\(data.petImageUrl.isEmpty ? "-" : "set") image=\(hasImage)"
        )

        let entry = SimpleEntry(
            date: currentDate,
            data: data,
            config: SavedWidgetConfiguration.loadAll().first
        )
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadWidgetData() -> PetWidgetData? {
        loadWidgetDataFromFile()
    }

    private func loadWidgetDataFromFile() -> PetWidgetData? {
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

        return parseWidgetData(dict)
    }

    private func parseWidgetData(_ dict: [String: Any]) -> PetWidgetData {
        PetWidgetData(
            petName: dict["petName"] as? String ?? "",
            petType: dict["petType"] as? String ?? "",
            petAge: dict["petAge"] as? String ?? "",
            petImageUrl: dict["petImageUrl"] as? String ?? "",
            memorials: dict["memorials"] as? String ?? "[]",
            updatedAt: parseUpdatedAt(dict["updatedAt"])
        )
    }

    private func parseUpdatedAt(_ value: Any?) -> Int64 {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? Double { return Int64(value) }
        if let value = value as? String, let parsed = Int64(value) { return parsed }
        return 0
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: PetWidgetData
    let config: SavedWidgetConfiguration?
}

struct PetWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        Group {
            if let config = entry.config {
                SavedWidgetTemplateView(config: config)
            } else {
                petContent
            }
        }
            .id("\(entry.data.updatedAt)-\(WidgetShared.cachedImageRevision())")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(widgetPadding)
    }

    private var widgetPadding: EdgeInsets {
        switch family {
        case .systemMedium:
            return EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        default:
            return EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        }
    }

    @ViewBuilder
    private var petContent: some View {
        if let image = loadCachedPetImage() {
            petImage(Image(uiImage: image))
        } else {
            // iOS 17+ 小组件无法对鉴权 URL 使用 AsyncImage，只展示缓存图或昵称
            placeholderPet
        }
    }

    private func petImage(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .scaleEffect(1.0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderPet: some View {
        VStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange.opacity(0.7))

            if !entry.data.petName.isEmpty {
                Text(entry.data.petName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            } else {
                Text("打开应用同步宠物")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(8)
    }

    private func loadCachedPetImage() -> UIImage? {
        guard let path = cachedImagePath(),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return UIImage(data: data)
    }

    private func cachedImagePath() -> String? {
        WidgetShared.cachedImagePath()
    }
}

struct PetWidget: Widget {
    let kind: String = "PetWidget"

    var body: some WidgetConfiguration {
        if #available(iOS 17.0, *) {
            return StaticConfiguration(kind: kind, provider: Provider()) { entry in
                PetWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            }
            .configurationDisplayName("萌宠")
            .description("在桌面展示你的宠物")
            .supportedFamilies([.systemSmall, .systemMedium])
            .contentMarginsDisabled()
        } else {
            return StaticConfiguration(kind: kind, provider: Provider()) { entry in
                PetWidgetEntryView(entry: entry)
            }
            .configurationDisplayName("萌宠")
            .description("在桌面展示你的宠物")
            .supportedFamilies([.systemSmall, .systemMedium])
        }
    }
}

struct PetWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PetWidgetEntryView(entry: SimpleEntry(date: Date(), data: PetWidgetData.preview, config: nil))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            PetWidgetEntryView(entry: SimpleEntry(date: Date(), data: PetWidgetData.preview, config: nil))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}
