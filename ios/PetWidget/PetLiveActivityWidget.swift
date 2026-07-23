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
  static let bannerBgFileName = "petLiveActivityBannerBg.png"
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

  static func loadBannerBg() -> UIImage? {
    loadValidUIImage(named: bannerBgFileName)
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
        .activityBackgroundTint(lockScreenTint(for: context.state))
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

  private func lockScreenTint(
    for state: PetLiveActivityAttributes.ContentState
  ) -> Color {
    // 自定义面板 / 已有背景图：透明 tint，让内容区背景色真正生效
    if state.template == 6 { return Color.clear }
    if LiveActivityShared.loadBannerBg() != nil { return Color.clear }
    return LiveActivityShared.color(from: state.backgroundColorARGB)
  }

  @ViewBuilder
  private func compactLeading(
    context: ActivityViewContext<PetLiveActivityAttributes>
  ) -> some View {
    let state = context.state
    switch state.template {
    case 2:
      // 仅相册图在灵动岛 compact 显示正圆
      if let image = LiveActivityShared.loadCompactPhoto() {
        islandCircleImage(uiImage: image, size: 24)
      } else {
        imageOrEmoji(
          image: nil,
          emoji: state.compactLeadingEmoji,
          systemName: "photo",
          size: 24
        )
      }
    case 3, 4, 5:
      imageOrEmoji(
        image: LiveActivityShared.loadCompactIcon(),
        emoji: state.compactLeadingEmoji.isEmpty ? "❤️" : state.compactLeadingEmoji,
        systemName: "heart.fill",
        size: 24
      )
    case 6:
      // 自定义：相册上传图标正圆
      if let image = LiveActivityShared.loadCompactLeftIcon() {
        islandCircleImage(uiImage: image, size: 24)
      } else {
        imageOrEmoji(
          image: nil,
          emoji: state.compactLeadingEmoji.isEmpty ? "🌈" : state.compactLeadingEmoji,
          systemName: "sparkles",
          size: 24
        )
      }
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
      if let image = LiveActivityShared.loadCompactRightIcon() {
        islandCircleImage(uiImage: image, size: 20)
      } else {
        imageOrEmoji(
          image: nil,
          emoji: state.compactTrailingEmoji.isEmpty ? "🔔" : state.compactTrailingEmoji,
          systemName: "bell.fill",
          size: 20
        )
      }
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
    let state = context.state
    if state.template == 6 {
      customPanel(state: state, height: 72)
        .id(state.imageRevision)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    } else {
      bodyContent(context: context, expanded: true)
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
    }
  }

  @ViewBuilder
  private func lockScreenView(
    context: ActivityViewContext<PetLiveActivityAttributes>
  ) -> some View {
    let state = context.state
    // 自定义面板全幅铺满，去掉外层 padding（否则上下左右会留缝）
    if state.template == 6 {
      customPanel(state: state, height: 104)
        .id(state.imageRevision)
        .frame(maxWidth: .infinity)
    } else {
      bodyContent(context: context, expanded: false)
        .padding(.leading, state.template == 2 ? 16 : 18)
        .padding(.trailing, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background {
          // 含宠物岛 template=1：与 App 预览背景一致
          if state.template >= 1 && state.template <= 5 {
            Group {
              if let bg = LiveActivityShared.loadBannerBg() {
                Image(uiImage: bg)
                  .resizable()
                  .scaledToFill()
              } else {
                LiveActivityShared.color(from: state.backgroundColorARGB)
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
  }

  @ViewBuilder
  private func bodyContent(
    context: ActivityViewContext<PetLiveActivityAttributes>,
    expanded: Bool
  ) -> some View {
    let state = context.state
    let imageSize: CGFloat = expanded ? 56 : 62
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
          .font(
            .system(
              size: CGFloat(max(12, min(24, state.textFontSize))),
              weight: .semibold
            )
          )
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
      customPanel(state: state, height: expanded ? 72 : 104)
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
            .fill(LiveActivityShared.color(from: state.backgroundColorARGB))
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
    let font = Font.system(size: compact ? 12 : 20, weight: .bold).monospacedDigit()
    if state.timerTargetEpoch <= 0 {
      Text("--:--")
        .font(font)
        .foregroundColor(.primary)
    } else {
      // 过去日期正计时、未来日期倒计时，与 App 内按「目标时间」计算一致
      Text(Date(timeIntervalSince1970: state.timerTargetEpoch), style: .timer)
        .font(font)
        .foregroundColor(.primary)
        .multilineTextAlignment(compact ? .trailing : .leading)
        .monospacedDigit()
    }
  }

  @ViewBuilder
  private func imageOrEmoji(
    image: UIImage?,
    emoji: String,
    systemName: String,
    size: CGFloat,
    circular: Bool = false
  ) -> some View {
    if (let image) {
      if circular {
        islandCircleImage(uiImage: image, size: size)
      } else {
        islandCompactImage(uiImage: image, size: size, cornerRadius: size * 0.22)
      }
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
  private func islandCircleImage(uiImage: UIImage, size: CGFloat) -> some View {
    // 正圆：固定正方形 + Circle，并用 fixedSize 避免灵动岛 compact 槽位横向拉伸成椭圆
    Image(uiImage: uiImage)
      .resizable()
      .interpolation(.high)
      .antialiased(true)
      .scaledToFill()
      .frame(width: size, height: size)
      .clipShape(Circle())
      .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
      .frame(width: size, height: size)
      .fixedSize()
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
