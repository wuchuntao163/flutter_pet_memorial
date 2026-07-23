import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

private enum LiveActivityShared {
  static let appGroupId = AppGroupConfig.id
  // 文件名需与 Runner 侧 WidgetSync 写入保持一致（扩展目标不编译 WidgetSync）
  static let liveActivityImageName = "petLiveActivityImage.png"
  static let liveActivityCompactPetName = "petLiveActivityCompactPet.png"
  static let fourCloverImageName = "petLiveActivityFourClover.png"
  static let fourCloverCompactImageName = "petLiveActivityCompactClover.png"
  static let widgetImageName = "petWidgetImage.png"
  static let photoFileName = "petLiveActivityPhoto.png"
  static let photoCompactFileName = "petLiveActivityCompactPhoto.png"
  static let iconFileName = "petLiveActivityIcon.png"
  static let iconCompactFileName = "petLiveActivityCompactIcon.png"
  static let panelFileName = "petLiveActivityPanel.png"
  static let leftIconFileName = "petLiveActivityLeftIcon.png"
  static let leftIconCompactFileName = "petLiveActivityCompactLeftIcon.png"
  static let rightIconFileName = "petLiveActivityRightIcon.png"
  static let rightIconCompactFileName = "petLiveActivityCompactRightIcon.png"

  static func cachedImagePath(named fileName: String) -> String? {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId
    ) else {
      return nil
    }
    let path = container.appendingPathComponent(fileName).path
    return FileManager.default.fileExists(atPath: path) ? path : nil
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
    if let image = loadValidUIImage(named: liveActivityImageName) {
      return image
    }
    return loadValidUIImage(named: widgetImageName)
  }

  static func loadCompactPetImage() -> UIImage? {
    loadValidUIImage(named: liveActivityCompactPetName)
  }

  static func loadCompactCloverImage() -> UIImage? {
    loadValidUIImage(named: fourCloverCompactImageName)
  }

  static func loadPhoto() -> UIImage? {
    loadValidUIImage(named: photoFileName)
  }

  static func loadCompactPhoto() -> UIImage? {
    loadValidUIImage(named: photoCompactFileName) ?? loadPhoto()
  }

  static func loadIcon() -> UIImage? {
    loadValidUIImage(named: iconFileName)
  }

  static func loadCompactIcon() -> UIImage? {
    loadValidUIImage(named: iconCompactFileName) ?? loadIcon()
  }

  static func loadPanel() -> UIImage? {
    loadValidUIImage(named: panelFileName)
  }

  static func loadCompactLeftIcon() -> UIImage? {
    loadValidUIImage(named: leftIconCompactFileName)
      ?? loadValidUIImage(named: leftIconFileName)
  }

  static func loadCompactRightIcon() -> UIImage? {
    loadValidUIImage(named: rightIconCompactFileName)
      ?? loadValidUIImage(named: rightIconFileName)
  }

  static func color(from argb: UInt32) -> Color {
    let a = Double((argb >> 24) & 0xFF) / 255.0
    let r = Double((argb >> 16) & 0xFF) / 255.0
    let g = Double((argb >> 8) & 0xFF) / 255.0
    let b = Double(argb & 0xFF) / 255.0
    return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
  }
}

@available(iOS 16.2, *)
struct PetLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PetLiveActivityAttributes.self) { context in
      lockScreenView(context: context)
        .activityBackgroundTint(Color.orange.opacity(0.12))
        .activitySystemActionForegroundColor(Color.primary)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.bottom) {
          expandedContent(context: context)
        }
      } compactLeading: {
        compactLeading(context: context)
          .id(context.state.imageRevision)
      } compactTrailing: {
        compactTrailing(context: context)
          .id(context.state.imageRevision)
      } minimal: {
        compactLeading(context: context)
          .id(context.state.imageRevision)
      }
      .keylineTint(Color.orange.opacity(0.8))
    }
  }

  // MARK: - Compact

  @ViewBuilder
  private func compactLeading(
    context: ActivityViewContext<PetLiveActivityAttributes>
  ) -> some View {
    let state = context.state
    switch state.template {
    case 2:
      imageOrEmoji(
        image: LiveActivityShared.loadCompactPhoto(),
        emoji: state.compactLeadingEmoji,
        systemName: "photo",
        size: 28
      )
    case 3, 4, 5:
      imageOrEmoji(
        image: LiveActivityShared.loadCompactIcon(),
        emoji: state.compactLeadingEmoji.isEmpty ? "❤️" : state.compactLeadingEmoji,
        systemName: "heart.fill",
        size: 26
      )
    case 6:
      imageOrEmoji(
        image: LiveActivityShared.loadCompactLeftIcon(),
        emoji: state.compactLeadingEmoji.isEmpty ? "🌈" : state.compactLeadingEmoji,
        systemName: "sparkles",
        size: 26
      )
    default:
      if let image = LiveActivityShared.loadCompactPetImage() {
        islandCompactImage(uiImage: image, size: 28, cornerRadius: 28 * 0.22)
      } else {
        Image(systemName: "pawprint.fill")
          .font(.system(size: 14))
          .foregroundColor(.orange.opacity(0.8))
          .frame(width: 28, height: 28)
      }
    }
  }

  @ViewBuilder
  private func compactTrailing(
    context: ActivityViewContext<PetLiveActivityAttributes>
  ) -> some View {
    let state = context.state
    switch state.template {
    case 2:
      EmptyView()
    case 3, 4:
      timerText(state: state, compact: true)
    case 5:
      Text(state.daysText.isEmpty ? "—" : state.daysText)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.primary)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    case 6:
      imageOrEmoji(
        image: LiveActivityShared.loadCompactRightIcon(),
        emoji: state.compactTrailingEmoji.isEmpty ? "🔔" : state.compactTrailingEmoji,
        systemName: "bell.fill",
        size: 22
      )
    default:
      if let image = LiveActivityShared.loadCompactCloverImage() {
        islandCompactImage(uiImage: image, size: 22, cornerRadius: 22 * 0.18)
      } else {
        Image(systemName: "leaf.fill")
          .font(.system(size: 12))
          .foregroundColor(.orange.opacity(0.85))
          .frame(width: 22, height: 22)
      }
    }
  }

  // MARK: - Expanded / Lock

  @ViewBuilder
  private func expandedContent(
    context: ActivityViewContext<PetLiveActivityAttributes>
  ) -> some View {
    bodyContent(context: context, expanded: true)
      .padding(.leading, 14)
      .padding(.trailing, 12)
      .padding(.vertical, 6)
  }

  @ViewBuilder
  private func lockScreenView(
    context: ActivityViewContext<PetLiveActivityAttributes>
  ) -> some View {
    bodyContent(context: context, expanded: false)
      .padding(.leading, 16)
      .padding(.trailing, 14)
      .padding(.vertical, 10)
  }

  @ViewBuilder
  private func bodyContent(
    context: ActivityViewContext<PetLiveActivityAttributes>,
    expanded: Bool
  ) -> some View {
    let state = context.state
    let imageSize: CGFloat = expanded ? 56 : 60
    switch state.template {
    case 2:
      HStack(spacing: 12) {
        imageOrEmoji(
          image: LiveActivityShared.loadPhoto(),
          emoji: state.compactLeadingEmoji,
          systemName: "photo",
          size: imageSize
        )
        .id(state.imageRevision)
        Text(state.subtitle.isEmpty ? state.petName : state.subtitle)
          .font(.system(size: expanded ? 16 : 15, weight: .semibold))
          .foregroundColor(LiveActivityShared.color(from: state.textColorARGB))
          .lineLimit(2)
          .minimumScaleFactor(0.75)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    case 3, 4:
      HStack(spacing: 12) {
        imageOrEmoji(
          image: LiveActivityShared.loadIcon(),
          emoji: state.compactLeadingEmoji.isEmpty ? "🔔" : state.compactLeadingEmoji,
          systemName: "bell.fill",
          size: imageSize
        )
        .id(state.imageRevision)
        VStack(alignment: .leading, spacing: 4) {
          Text(state.subtitle.isEmpty ? state.memorialTitle : state.subtitle)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
            .lineLimit(1)
          timerText(state: state, compact: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    case 5:
      HStack(spacing: 12) {
        imageOrEmoji(
          image: LiveActivityShared.loadIcon(),
          emoji: state.compactLeadingEmoji.isEmpty ? "❤️" : state.compactLeadingEmoji,
          systemName: "heart.fill",
          size: imageSize
        )
        .id(state.imageRevision)
        VStack(alignment: .leading, spacing: 4) {
          Text(state.memorialTitle.isEmpty ? state.subtitle : state.memorialTitle)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
            .lineLimit(1)
          Text(state.daysText.isEmpty ? "—" : state.daysText)
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    case 6:
      customPanel(state: state, height: expanded ? 72 : 78)
        .id(state.imageRevision)
    default:
      HStack(alignment: .center, spacing: 12) {
        petImageView(size: imageSize)
          .id(state.imageRevision)
        Text(state.subtitle.isEmpty ? state.petName : state.subtitle)
          .font(.body)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .frame(maxWidth: .infinity, alignment: .leading)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private func customPanel(
    state: PetLiveActivityAttributes.ContentState,
    height: CGFloat
  ) -> some View {
    GeometryReader { geo in
      ZStack(alignment: .topLeading) {
        if let panel = LiveActivityShared.loadPanel() {
          Image(uiImage: panel)
            .resizable()
            .scaledToFill()
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        } else {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.orange.opacity(0.18))
        }
        Text(state.subtitle.isEmpty ? "每天都要开心" : state.subtitle)
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(LiveActivityShared.color(from: state.textColorARGB))
          .lineLimit(2)
          .padding(8)
          .position(
            x: max(24, min(geo.size.width - 24, geo.size.width * state.textNormX)),
            y: max(16, min(geo.size.height - 16, geo.size.height * state.textNormY))
          )
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  @ViewBuilder
  private func timerText(
    state: PetLiveActivityAttributes.ContentState,
    compact: Bool
  ) -> some View {
    let target = Date(timeIntervalSince1970: state.timerTargetEpoch)
    let countsDown = state.template == 4
    let font = Font.system(size: compact ? 12 : 20, weight: .bold).monospacedDigit()
    if state.timerTargetEpoch <= 0 {
      Text("--:--")
        .font(font)
        .foregroundColor(.primary)
    } else if countsDown {
      Text(timerInterval: Date()...max(target, Date().addingTimeInterval(1)), countsDown: true)
        .font(font)
        .foregroundColor(.primary)
        .multilineTextAlignment(.trailing)
    } else {
      let end = Date().addingTimeInterval(60 * 60 * 24 * 30)
      Text(timerInterval: min(target, Date())...end, countsDown: false)
        .font(font)
        .foregroundColor(.primary)
        .multilineTextAlignment(.trailing)
    }
  }

  @ViewBuilder
  private func imageOrEmoji(
    image: UIImage?,
    emoji: String,
    systemName: String,
    size: CGFloat
  ) -> some View {
    if let image {
      islandCompactImage(uiImage: image, size: size, cornerRadius: size * 0.22)
    } else if !emoji.isEmpty {
      Text(emoji)
        .font(.system(size: size * 0.72))
        .frame(width: size, height: size)
    } else {
      Image(systemName: systemName)
        .font(.system(size: size * 0.5))
        .foregroundColor(.orange.opacity(0.85))
        .frame(width: size, height: size)
    }
  }

  @ViewBuilder
  private func islandCompactImage(
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
  private func petImageView(size: CGFloat) -> some View {
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
