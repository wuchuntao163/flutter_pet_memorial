import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

private enum LiveActivityShared {
  static let appGroupId = AppGroupConfig.id
  static let liveActivityImageName = "petLiveActivityImage.png"
  static let liveActivityCompactPetName = "petLiveActivityCompactPet.png"
  static let fourCloverImageName = "petLiveActivityFourClover.png"
  static let fourCloverCompactImageName = "petLiveActivityCompactClover.png"
  static let widgetImageName = "petWidgetImage.png"

  static func cachedImagePath(named fileName: String) -> String? {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId
    ) else {
      return nil
    }
    let path = container.appendingPathComponent(fileName).path
    return FileManager.default.fileExists(atPath: path) ? path : nil
  }

  static func cachedPetImagePath() -> String? {
    if let livePath = cachedImagePath(named: liveActivityImageName) {
      return livePath
    }
    return cachedImagePath(named: widgetImageName)
  }

  static func cachedCompactPetImagePath() -> String? {
    cachedImagePath(named: liveActivityCompactPetName)
  }

  static func loadValidUIImage(named fileName: String) -> UIImage? {
    guard let path = cachedImagePath(named: fileName),
          let image = UIImage(contentsOfFile: path),
          let cgImage = image.cgImage,
          cgImage.width > 0,
          cgImage.height > 0 else {
      return nil
    }
    return image
  }

  static func loadCachedPetImage() -> UIImage? {
    guard let path = cachedPetImagePath(),
          let image = UIImage(contentsOfFile: path),
          let cgImage = image.cgImage,
          cgImage.width > 0,
          cgImage.height > 0 else {
      return nil
    }
    return image
  }

  static func loadCompactPetImage() -> UIImage? {
    loadValidUIImage(named: liveActivityCompactPetName)
  }

  static func loadCompactCloverImage() -> UIImage? {
    loadValidUIImage(named: fourCloverCompactImageName)
  }
}

/// 可在部署目标 < 16.2 的 WidgetBundle 中无条件注册；
/// 真实 Live Activity UI 仅在 iOS 16.2+ 生效。
struct PetLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    if #available(iOS 16.2, *) {
      ActivityConfiguration(for: PetLiveActivityAttributes.self) { context in
        LiveActivityViews.lockScreenView(context: context)
          .activityBackgroundTint(Color.orange.opacity(0.12))
          .activitySystemActionForegroundColor(Color.primary)
      } dynamicIsland: { context in
        DynamicIsland {
          DynamicIslandExpandedRegion(.bottom) {
            LiveActivityViews.expandedContent(context: context)
          }
        } compactLeading: {
          LiveActivityViews.compactPetImageView(size: 28)
            .id(context.state.imageRevision)
        } compactTrailing: {
          LiveActivityViews.fourCloverImageView(size: 22)
            .id(context.state.imageRevision)
        } minimal: {
          LiveActivityViews.compactPetImageView(size: 22)
            .id(context.state.imageRevision)
        }
        .keylineTint(Color.orange.opacity(0.8))
      }
    } else {
      // 低版本占位：不进入小组件库可见列表
      StaticConfiguration(
        kind: "PetLiveActivityWidget.unsupported",
        provider: UnsupportedLiveActivityProvider()
      ) { _ in
        EmptyView()
      }
      .supportedFamilies([])
    }
  }
}

private struct UnsupportedLiveActivityEntry: TimelineEntry {
  let date: Date
}

private struct UnsupportedLiveActivityProvider: TimelineProvider {
  func placeholder(in context: Context) -> UnsupportedLiveActivityEntry {
    UnsupportedLiveActivityEntry(date: Date())
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (UnsupportedLiveActivityEntry) -> Void
  ) {
    completion(UnsupportedLiveActivityEntry(date: Date()))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<UnsupportedLiveActivityEntry>) -> Void
  ) {
    completion(
      Timeline(entries: [UnsupportedLiveActivityEntry(date: Date())], policy: .never)
    )
  }
}

@available(iOS 16.2, *)
private enum LiveActivityViews {
  @ViewBuilder
  static func expandedContent(
    context: ActivityViewContext<PetLiveActivityAttributes>
  ) -> some View {
    HStack(alignment: .center, spacing: 12) {
      petImageView(size: 56)
        .id(context.state.imageRevision)
      Text(context.state.subtitle)
        .font(.body)
        .fontWeight(.semibold)
        .foregroundColor(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.leading, 14)
    .padding(.trailing, 12)
    .padding(.vertical, 6)
  }

  @ViewBuilder
  static func lockScreenView(
    context: ActivityViewContext<PetLiveActivityAttributes>
  ) -> some View {
    HStack(alignment: .center, spacing: 14) {
      petImageView(size: 60)
        .id(context.state.imageRevision)
      Text(context.state.subtitle)
        .font(.body)
        .fontWeight(.semibold)
        .foregroundColor(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.leading, 16)
    .padding(.trailing, 14)
    .padding(.vertical, 10)
  }

  @ViewBuilder
  static func compactPetImageView(size: CGFloat) -> some View {
    if let image = LiveActivityShared.loadCompactPetImage() {
      islandCompactImage(uiImage: image, size: size, cornerRadius: size * 0.22)
    } else {
      Image(systemName: "pawprint.fill")
        .font(.system(size: size * 0.5))
        .foregroundColor(.orange.opacity(0.8))
        .frame(width: size, height: size)
    }
  }

  @ViewBuilder
  static func fourCloverImageView(size: CGFloat) -> some View {
    if let image = LiveActivityShared.loadCompactCloverImage() {
      islandCompactImage(uiImage: image, size: size, cornerRadius: size * 0.18)
    } else {
      Image(systemName: "leaf.fill")
        .font(.system(size: size * 0.55))
        .foregroundColor(.orange.opacity(0.85))
        .frame(width: size, height: size)
    }
  }

  @ViewBuilder
  static func islandCompactImage(
    uiImage: UIImage,
    size: CGFloat,
    cornerRadius: CGFloat
  ) -> some View {
    Image(uiImage: uiImage)
      .resizable()
      .interpolation(.high)
      .antialiased(true)
      .scaledToFill()
      .frame(width: size, height: size)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
  }

  @ViewBuilder
  static func petImageView(size: CGFloat) -> some View {
    if let image = LiveActivityShared.loadCachedPetImage() {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
    } else {
      Image(systemName: "pawprint.fill")
        .font(.system(size: size * 0.5))
        .foregroundColor(.orange.opacity(0.8))
        .frame(width: size, height: size)
    }
  }
}
