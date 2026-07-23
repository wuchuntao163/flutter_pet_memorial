import WidgetKit
import SwiftUI
import UIKit
import Intents

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
    /// Selected「我的组件」id；nil = 未配置，显示引导
    let widgetId: Int?
    let isGalleryPreview: Bool
    /// 「透明位置」：关闭 / 位置名；用于壁纸透明叠加
    let transparentPosition: String?

    static func setup(date: Date = Date(), preview: Bool = false) -> SimpleEntry {
        let revision = preview ? SavedWidgetConfiguration.galleryRevision() : 0
        let data = PetWidgetData(
            petName: "",
            petType: "",
            petAge: "",
            petImageUrl: "",
            memorials: "[]",
            updatedAt: revision
        )
        return SimpleEntry(
            date: Date(),
            data: data,
            widgetId: nil,
            isGalleryPreview: preview,
            transparentPosition: nil
        )
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

struct AppBrandLogo: View {
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let image = Self.resolveLogo() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // 资源未打进 appex 时的兜底，避免空白
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color.orange.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }

    /// Bundle AppLogo 优先（纪念日），App Group 仅作兜底，避免旧缓存闪出倒数日
    private static func resolveLogo() -> UIImage? {
        if let image = UIImage(named: "AppLogo") {
            return image
        }
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConfig.id
        ) {
            let path = container.appendingPathComponent("appBrandLogo.png").path
            if let image = UIImage(contentsOfFile: path) {
                return image
            }
        }
        return nil
    }
}

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

    private var isMedium: Bool { family == .systemMedium }

    /// 小号宽度紧，步骤文案必须单行；字号与边距略收
    private var stepFontSize: CGFloat { isMedium ? 12 : 10 }
    private var stepCircle: CGFloat { isMedium ? 18 : 16 }
    private var hPadding: CGFloat { isMedium ? 18 : 12 }
    private var stepSpacing: CGFloat { isMedium ? 8 : 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                AppBrandLogo(size: 16)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.bottom, isMedium ? 10 : 8)

            GeometryReader { geo in
                let rowH = geo.size.height / CGFloat(steps.count)
                ZStack(alignment: .topLeading) {
                    Path { path in
                        let x = stepCircle / 2
                        path.move(to: CGPoint(x: x, y: rowH * 0.35))
                        path.addLine(to: CGPoint(x: x, y: rowH * (CGFloat(steps.count) - 0.35)))
                    }
                    .stroke(lineColor, lineWidth: 1.5)

                    VStack(spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                            HStack(alignment: .center, spacing: stepSpacing) {
                                ZStack {
                                    Circle()
                                        .fill(stepYellow)
                                        .frame(width: stepCircle, height: stepCircle)
                                    Text("\(index + 1)")
                                        .font(.system(size: isMedium ? 11 : 10, weight: .bold).italic())
                                        .foregroundColor(.black)
                                }
                                Text(text)
                                    .font(.system(size: stepFontSize, weight: .medium))
                                    .foregroundColor(stepText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .allowsTightening(true)
                                Spacer(minLength: 0)
                            }
                            .frame(height: rowH, alignment: .center)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, hPadding)
        .padding(.top, isMedium ? 20 : 16)
        .padding(.bottom, isMedium ? 20 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - 图一：系统组件库里的预览内容（最多 2 个「我的组件」缩略图）
// 小号：方块缩略图；中号：长条缩略图（与中号组件比例一致）

struct WidgetGalleryPreviewView: View {
    let thumbs: [SavedWidgetConfiguration]
    @Environment(\.widgetFamily) private var family

    private let accentBlue = Color(red: 0.23, green: 0.51, blue: 0.96)

    private var isMedium: Bool { family == .systemMedium }

    /// 中号约 2.1:1；小号正方形
    private var thumbSize: CGSize {
        isMedium ? CGSize(width: 118, height: 56) : CGSize(width: 44, height: 44)
    }

    private var thumbCorner: CGFloat { isMedium ? 12 : 10 }

    private var thumbStackOffset: CGFloat { isMedium ? 36 : 26 }

    private var thumbsRowHeight: CGFloat { thumbSize.height + 4 }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    AppBrandLogo(size: 16)
                    Text("哈基米纪念日")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 10)

                Spacer(minLength: 6)

                Group {
                    if isMedium {
                        // 中号：引导文案同一行
                        HStack(spacing: 4) {
                            Text("点击下方")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            HStack(spacing: 2) {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .bold))
                                Text("添加小组件")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.leading, 5)
                            .padding(.trailing, 6)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(accentBlue))
                            Text("将组件添加到桌面")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    } else {
                        VStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Text("点击下方")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: true, vertical: false)
                                HStack(spacing: 2) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("添加小组件")
                                        .font(.system(size: 11, weight: .semibold))
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .foregroundColor(.white)
                                .padding(.leading, 5)
                                .padding(.trailing, 6)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(accentBlue))
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .lineLimit(1)

                            Text("将组件添加到桌面")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer(minLength: 8)

                galleryThumbsRow
                    .frame(height: thumbsRowHeight)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, isMedium ? 14 : 16)
        }
    }

    @ViewBuilder
    private var galleryThumbsRow: some View {
        let items = Array(thumbs.prefix(2))
        if items.isEmpty {
            Color.clear.frame(height: thumbSize.height)
        } else {
            ZStack {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    galleryThumb(item)
                        .offset(
                            x: CGFloat(index) * thumbStackOffset
                                - (items.count > 1 ? thumbStackOffset / 2 : 0)
                        )
                        .zIndex(Double(index))
                }
            }
        }
    }

    @ViewBuilder
    private func galleryThumb(_ item: SavedWidgetConfiguration) -> some View {
        Group {
            if let image = item.previewUIImage() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let url = item.remoteImageURL {
                CompatibleRemoteImage(url: url, contentMode: .fill)
            } else {
                ZStack {
                    Color(white: 0.93)
                    Text(String(item.title.prefix(1)))
                        .font(.system(size: isMedium ? 16 : 14, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: thumbSize.width, height: thumbSize.height)
        .clipShape(RoundedRectangle(cornerRadius: thumbCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: thumbCorner, style: .continuous)
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Entry view

struct PetWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SimpleEntry

    var body: some View {
        Group {
            if entry.isGalleryPreview {
                WidgetGalleryPreviewView(
                    thumbs: Array(SavedWidgetConfiguration.loadForFamily(family).prefix(2))
                )
                .id("\(entry.data.updatedAt)-\(family)")
                .petWidgetContainerBackground(wallpaper: nil)
            } else if let config = resolvedConfig {
                let wallpaper = SavedWidgetHomeView.wallpaperImage(
                    for: entry.transparentPosition,
                    family: family
                )
                SavedWidgetHomeView(
                    config: config,
                    transparentPosition: entry.transparentPosition
                )
                .id("\(config.widgetId)-\(entry.data.updatedAt)-\(entry.transparentPosition ?? "")-\(Calendar.current.startOfDay(for: entry.date).timeIntervalSince1970)-\(WidgetShared.cachedImageRevision())-\(SavedWidgetConfiguration.backgroundRevision(widgetId: config.widgetId))")
                .petWidgetContainerBackground(wallpaper: wallpaper)
            } else {
                WidgetSetupGuideView()
                    .petWidgetContainerBackground(wallpaper: nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resolvedConfig: SavedWidgetConfiguration? {
        guard let widgetId = entry.widgetId else { return nil }
        return SavedWidgetConfiguration.loadAll().first { $0.widgetId == widgetId }
    }
}

/// iOS 17+：假透明时必须把壁纸裁切放进 containerBackground（Color.clear 会被换成白底）
private extension View {
    @ViewBuilder
    func petWidgetContainerBackground(wallpaper: UIImage?) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            modifier(PetWidgetFullBleedModifier(wallpaper: wallpaper))
        } else {
            self
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct PetWidgetFullBleedModifier: ViewModifier {
    @Environment(\.widgetContentMargins) private var margins
    let wallpaper: UIImage?

    func body(content: Content) -> some View {
        content
            .padding(-margins)
            .containerBackground(for: .widget) {
                if let wallpaper {
                    GeometryReader { geo in
                        Image(uiImage: wallpaper)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                } else {
                    Color.clear
                }
            }
    }
}

/// 桌面已配置组件：倒计时类 = 本地背景 + 自定义数字字体 + 实时天数
struct SavedWidgetHomeView: View {
    @Environment(\.widgetFamily) private var family
    let config: SavedWidgetConfiguration
    let transparentPosition: String?

    private var isTransparent: Bool {
        SavedWidgetOptionsProvider.isTransparentEnabled(transparentPosition)
    }

    private var wallpaper: UIImage? {
        guard isTransparent else { return nil }
        return Self.wallpaperImage(for: transparentPosition, family: family)
    }

    private var useFakeTransparent: Bool {
        isTransparent && wallpaper != nil
    }

    var body: some View {
        ZStack {
            // iOS 16：壁纸铺在内容下；iOS 17+ 已在 containerBackground 里
            if useFakeTransparent {
                if #unavailable(iOSApplicationExtension 17.0) {
                    if let wall = wallpaper {
                        Color.clear
                            .overlay(
                                Image(uiImage: wall)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            )
                            .clipped()
                    }
                }
            }

            if useFakeTransparent {
                SavedWidgetTemplateView(config: config, hideBackground: true)
            } else if config.needsLiveDayRender {
                SavedWidgetTemplateView(config: config)
            } else if let preview = config.previewUIImage() {
                Color.clear
                    .overlay(
                        Image(uiImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipped()
            } else if let url = config.remoteImageURL {
                CompatibleRemoteImage(url: url, contentMode: .fill)
            } else {
                SavedWidgetTemplateView(config: config)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    static func wallpaperImage(for position: String?, family: WidgetFamily) -> UIImage? {
        let preferMedium = family == .systemMedium
        guard let key = SavedWidgetOptionsProvider.transparentFileKey(
                position,
                preferMedium: preferMedium
              ),
              let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppGroupConfig.id
              ) else {
            return nil
        }
        let path = container.appendingPathComponent("widgetTransparent_\(key).png").path
        if let image = UIImage(contentsOfFile: path) {
            return image
        }
        // 中号缺图时回退小号方位
        if preferMedium,
           let fallback = SavedWidgetOptionsProvider.transparentFileKey(
             position,
             preferMedium: false
           ) {
            let fallbackPath = container
              .appendingPathComponent("widgetTransparent_\(fallback).png").path
            return UIImage(contentsOfFile: fallbackPath)
        }
        return nil
    }
}

// MARK: - Intent provider（长按「编辑小组件」可选「我的组件」；未选中时显示引导）

struct PetWidgetSmallIntentProvider: IntentTimelineProvider {
    typealias Intent = SelectSmallSavedWidgetIntent
    typealias Entry = SimpleEntry

    func placeholder(in context: Context) -> SimpleEntry {
        .setup(preview: true)
    }

    func getSnapshot(
        for configuration: SelectSmallSavedWidgetIntent,
        in context: Context,
        completion: @escaping (SimpleEntry) -> Void
    ) {
        if context.isPreview {
            completion(.setup(preview: true))
            return
        }
        completion(makeEntry(
            configuration.currentWidget,
            transparent: configuration.transparentPosition
        ))
    }

    func getTimeline(
        for configuration: SelectSmallSavedWidgetIntent,
        in context: Context,
        completion: @escaping (Timeline<SimpleEntry>) -> Void
    ) {
        let entry = makeEntry(
            configuration.currentWidget,
            transparent: configuration.transparentPosition
        )
        completion(Timeline(
            entries: [entry],
            policy: .after(SavedWidgetConfiguration.nextTimelineRefreshDate())
        ))
    }
}

struct PetWidgetMediumIntentProvider: IntentTimelineProvider {
    typealias Intent = SelectMediumSavedWidgetIntent
    typealias Entry = SimpleEntry

    func placeholder(in context: Context) -> SimpleEntry {
        .setup(preview: true)
    }

    func getSnapshot(
        for configuration: SelectMediumSavedWidgetIntent,
        in context: Context,
        completion: @escaping (SimpleEntry) -> Void
    ) {
        if context.isPreview {
            completion(.setup(preview: true))
            return
        }
        completion(makeEntry(
            configuration.currentWidget,
            transparent: configuration.transparentPosition
        ))
    }

    func getTimeline(
        for configuration: SelectMediumSavedWidgetIntent,
        in context: Context,
        completion: @escaping (Timeline<SimpleEntry>) -> Void
    ) {
        let entry = makeEntry(
            configuration.currentWidget,
            transparent: configuration.transparentPosition
        )
        completion(Timeline(
            entries: [entry],
            policy: .after(SavedWidgetConfiguration.nextTimelineRefreshDate())
        ))
    }
}

private func makeEntry(_ selected: String?, transparent: String?) -> SimpleEntry {
    let selectedId = SavedWidgetOptionsProvider.widgetId(from: selected)
    return SimpleEntry(
        date: Date(),
        data: PetWidgetDataLoader.load(),
        widgetId: selectedId,
        isGalleryPreview: false,
        transparentPosition: transparent
    )
}

struct HomeScreenPetWidgetSmall: Widget {
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: "PetWidgetSmall",
            intent: SelectSmallSavedWidgetIntent.self,
            provider: PetWidgetSmallIntentProvider()
        ) { entry in
            PetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("小号")
        .description("选择你要添加的组件尺寸添加到桌面")
        .supportedFamilies([.systemSmall])
    }
}

struct HomeScreenPetWidgetMedium: Widget {
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: "PetWidgetMedium",
            intent: SelectMediumSavedWidgetIntent.self,
            provider: PetWidgetMediumIntentProvider()
        ) { entry in
            PetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("中号")
        .description("选择你要添加的组件尺寸添加到桌面")
        .supportedFamilies([.systemMedium])
    }
}
