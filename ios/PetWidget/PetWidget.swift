import WidgetKit
import SwiftUI

private enum WidgetShared {
    static let appGroupId = AppGroupConfig.id
    static let widgetDataFileName = "petWidgetData.json"
    static let widgetImageName = "petWidgetImage.png"
}

struct PetWidgetData: Codable {
    let petName: String
    let petType: String
    let petAge: String
    let petImageUrl: String
    let memorials: String

    static let preview = PetWidgetData(
        petName: "小猫咪",
        petType: "2",
        petAge: "30",
        petImageUrl: "",
        memorials: "[]"
    )

    static let empty = PetWidgetData(
        petName: "",
        petType: "",
        petAge: "",
        petImageUrl: "",
        memorials: "[]"
    )
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: PetWidgetData.preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let data = context.isPreview ? PetWidgetData.preview : (loadWidgetData() ?? PetWidgetData.empty)
        completion(SimpleEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let data = loadWidgetData() ?? PetWidgetData.empty
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!

        let entry = SimpleEntry(date: currentDate, data: data)
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
            memorials: dict["memorials"] as? String ?? "[]"
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: PetWidgetData
}

struct PetWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        petContent
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
        } else if let urlString = entry.data.petImageUrl.isEmpty ? nil : entry.data.petImageUrl,
                  let url = URL(string: urlString) {
            if #available(iOS 15.0, *) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        petImage(image)
                    case .failure:
                        placeholderPet
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderPet
                    }
                }
            } else {
                placeholderPet
            }
        } else {
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
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetShared.appGroupId
        ) else {
            return nil
        }
        let path = container.appendingPathComponent(WidgetShared.widgetImageName)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
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
            PetWidgetEntryView(entry: SimpleEntry(date: Date(), data: PetWidgetData.preview))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            PetWidgetEntryView(entry: SimpleEntry(date: Date(), data: PetWidgetData.preview))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}
