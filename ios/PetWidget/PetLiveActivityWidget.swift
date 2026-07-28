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
        islandCircleImage(uiImage: image, size: 28)
      } else {
        imageOrEmoji(
          image: nil,
          emoji: state.compactLeadingEmoji,
          systemName: "photo",
          size: 28
        )
      }
    case 3, 4, 5:
      // 相册图正圆；纯 emoji 图标不裁圆
      if let image = LiveActivityShared.loadCompactIcon() {
        islandCircleImage(uiImage: image, size: 28)
      } else {
        imageOrEmoji(
          image: nil,
          emoji: state.compactLeadingEmoji.isEmpty ? "❤️" : state.compactLeadingEmoji,
          systemName: "heart.fill",
          size: 28
        )
      }
    case 6:
      // 自定义：相册图正圆；emoji 不裁圆
      if let image = LiveActivityShared.loadCompactLeftIcon() {
        islandCircleImage(uiImage: image, size: 28)
      } else {
        imageOrEmoji(
          image: nil,
          emoji: state.compactLeadingEmoji.isEmpty ? "🌈" : state.compactLeadingEmoji,
          systemName: "sparkles",
          size: 28
        )
      }
    default:
      if let image = LiveActivityShared.loadCompactPetImage() {
        islandCircleImage(uiImage: image, size: 28)
      } else {
        Image(systemName: "pawprint.fill")
          .font(.system(size: 16))
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
      timerText(state: state, compact: true, color: .primary)
    case 5:
      Text(state.daysText.isEmpty ? "—" : state.daysText)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.primary)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    case 6:
      if let image = LiveActivityShared.loadCompactRightIcon() {
        islandCircleImage(uiImage: image, size: 24)
      } else if !state.compactTrailingEmoji.isEmpty {
        Text(state.compactTrailingEmoji)
          .font(.system(size: 24 * 0.9))
          .frame(width: 24, height: 24)
      } else {
        EmptyView()
      }
    default:
      if let image = LiveActivityShared.loadCompactCloverImage() {
        islandCircleImage(uiImage: image, size: 24)
      } else {
        Image(systemName: "leaf.fill")
          .font(.system(size: 14))
          .foregroundColor(.orange.opacity(0.85))
          .frame(width: 24, height: 24)
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
    // 高度对齐 App 展示台自定义预览（147）
    if state.template == 6 {
      customPanel(state: state, height: 147)
        .id(state.imageRevision)
        .frame(maxWidth: .infinity)
    } else {
      // 普通岛：高度 125；侧图 68；文案最多 4 行且不缩小字号
      // 纪念日/正倒计时锁屏再偏右，避免左侧圆角裁切图标
      let isTimerOrMemorial = state.template >= 3 && state.template <= 5
      let leadingInset: CGFloat = isTimerOrMemorial ? 50 : 37
      let verticalPad: CGFloat = isTimerOrMemorial ? 14 : 18
      bodyContent(context: context, expanded: false)
        .padding(.leading, leadingInset)
        .padding(.trailing, 16)
        .padding(.vertical, verticalPad)
        .frame(maxWidth: .infinity, minHeight: 125, alignment: .leading)
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
    // 锁屏侧图 68
    let imageSize: CGFloat = expanded ? 56 : 68
    switch state.template {
    case 2:
      HStack(alignment: .center, spacing: 14) {
        // 锁屏/展开：与 App 预览卡片一致的圆角矩形（正圆仅用于灵动岛 compact）
        Group {
          if let image = LiveActivityShared.loadPhoto() {
            islandCompactImage(
              uiImage: image,
              size: imageSize,
              cornerRadius: imageSize * 0.22
            )
          } else {
            imageOrEmoji(
              image: nil,
              emoji: state.compactLeadingEmoji,
              systemName: "photo",
              size: imageSize
            )
          }
        }
        .id(state.imageRevision)
        // 默认与宠物岛锁屏一致 17；用户调过字号则用配置值
        let photoFont: CGFloat = {
          let raw = state.textFontSize
          if raw <= 0 { return expanded ? 16 : 17 }
          // 旧默认 16 视为未调过，锁屏对齐宠物岛 17
          if !expanded && abs(raw - 16) < 0.01 { return 17 }
          return CGFloat(max(12, min(26, raw)))
        }()
        Text(state.subtitle.isEmpty ? state.petName : state.subtitle)
          .font(.system(size: photoFont, weight: .semibold))
          .foregroundColor(LiveActivityShared.color(from: state.textColorARGB))
          .lineLimit(expanded ? 2 : 4)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    case 3, 4:
      // 倒计时浅底用黑字；正计时黑底用白字
      // 锁屏：标题加粗加大；正计时名称纯白
      let labelColor: Color = state.template == 4 ? .black : .white
      let titleSize: CGFloat = expanded ? 13 : 18
      let titleWeight: Font.Weight = expanded ? .medium : .semibold
      let titleColor: Color = {
        if expanded { return labelColor.opacity(0.72) }
        // 正计时锁屏名称统一纯白
        return state.template == 3 ? .white : labelColor.opacity(0.85)
      }()
      let stackSpacing: CGFloat = expanded ? 4 : 10
      HStack(alignment: .center, spacing: 14) {
        Group {
          if let image = LiveActivityShared.loadIcon() {
            islandCompactImage(
              uiImage: image,
              size: imageSize,
              cornerRadius: imageSize * 0.22
            )
          } else {
            imageOrEmoji(
              image: nil,
              emoji: state.compactLeadingEmoji.isEmpty ? "🔔" : state.compactLeadingEmoji,
              systemName: "bell.fill",
              size: imageSize
            )
          }
        }
        .id(state.imageRevision)
        .layoutPriority(1)
        VStack(alignment: .leading, spacing: stackSpacing) {
          Text(state.subtitle.isEmpty ? state.memorialTitle : state.subtitle)
            .font(.system(size: titleSize, weight: titleWeight))
            .foregroundColor(titleColor)
            .lineLimit(1)
          timerText(
            state: state,
            compact: false,
            color: labelColor,
            lockScreenSize: expanded ? nil : 26
          )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    case 5:
      // 锁屏：标题加粗加大，标题与天数间距更大
      let titleSize: CGFloat = expanded ? 13 : 18
      let titleWeight: Font.Weight = expanded ? .medium : .semibold
      let daysSize: CGFloat = expanded ? 22 : 28
      let stackSpacing: CGFloat = expanded ? 4 : 10
      HStack(alignment: .center, spacing: 14) {
        Group {
          if let image = LiveActivityShared.loadIcon() {
            islandCompactImage(
              uiImage: image,
              size: imageSize,
              cornerRadius: imageSize * 0.22
            )
          } else {
            imageOrEmoji(
              image: nil,
              emoji: state.compactLeadingEmoji.isEmpty ? "❤️" : state.compactLeadingEmoji,
              systemName: "heart.fill",
              size: imageSize
            )
          }
        }
        .id(state.imageRevision)
        .layoutPriority(1)
        VStack(alignment: .leading, spacing: stackSpacing) {
          Text(state.memorialTitle.isEmpty ? state.subtitle : state.memorialTitle)
            .font(.system(size: titleSize, weight: titleWeight))
            .foregroundColor(expanded ? .black.opacity(0.72) : .black.opacity(0.85))
            .lineLimit(1)
          Text(state.daysText.isEmpty ? "—" : state.daysText)
            .font(.system(size: daysSize, weight: .bold))
            .foregroundColor(.black)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    case 6:
      customPanel(state: state, height: expanded ? 72 : 147)
        .id(state.imageRevision)
    default:
      HStack(alignment: .center, spacing: 14) {
        Group {
          if let image = LiveActivityShared.loadCachedPetImage() {
            islandCompactImage(
              uiImage: image,
              size: imageSize,
              cornerRadius: imageSize * 0.22
            )
          } else {
            petImageView(size: imageSize)
          }
        }
        .id(state.imageRevision)
        Text(state.subtitle.isEmpty ? state.petName : state.subtitle)
          .font(.system(size: expanded ? 16 : 17, weight: .semibold))
          .foregroundColor(.primary)
          .lineLimit(expanded ? 2 : 4)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
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
      let margin: CGFloat = 14
      let fontSize = CGFloat(max(14, min(24, state.textFontSize > 0 ? state.textFontSize : 18)))
      let textBlockH: CGFloat = fontSize * 1.35 + 4
      let normX = min(1, max(0, state.textNormX))
      let normY = min(1, max(0, state.textNormY))
      // 与 App 预览一致：左上角定位，预留右侧空间避免贴边溢出
      let left = margin + (geo.size.width - margin * 2 - CGFloat(100)) * normX
      let top = margin + (geo.size.height - margin * 2 - textBlockH) * normY
      let textMaxW = max(60, geo.size.width - left - margin)
      ZStack(alignment: .topLeading) {
        if let panel = LiveActivityShared.loadPanel() {
          Image(uiImage: panel)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFill()
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        } else {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LiveActivityShared.color(from: state.backgroundColorARGB))
        }
        // 未输入文字时不显示文案（允许纯图面板）
        if !state.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(state.subtitle)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(LiveActivityShared.color(from: state.textColorARGB))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: textMaxW, alignment: .leading)
            .offset(
              x: max(margin, left),
              y: max(margin, min(top, geo.size.height - margin - textBlockH))
            )
        }
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  @ViewBuilder
  private func timerText(
    state: PetLiveActivityAttributes.ContentState,
    compact: Bool,
    color: Color,
    lockScreenSize: CGFloat? = nil
  ) -> some View {
    let size: CGFloat = lockScreenSize ?? (compact ? 12 : 22)
    let font = Font.system(size: size, weight: .bold).monospacedDigit()
    let target = Date(timeIntervalSince1970: state.timerTargetEpoch)
    if state.timerTargetEpoch <= 0 {
      Text("--:--")
        .font(font)
        .foregroundColor(color)
    } else if state.template == 4 {
      // 倒计时：始终倒数到目标时刻（与 App 预览 target.difference(now) 一致）
      Text(
        timerInterval: Date(timeIntervalSince1970: 0)...target,
        countsDown: true,
        showsHours: true
      )
      .font(font)
      .foregroundColor(color)
      .multilineTextAlignment(compact ? .trailing : .leading)
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(0.7)
    } else {
      // 正计时：从目标时刻起正向累计（与 App 预览 now.difference(target) 一致）
      Text(
        timerInterval: target...Date.distantFuture,
        countsDown: false,
        showsHours: true
      )
      .font(font)
      .foregroundColor(color)
      .multilineTextAlignment(compact ? .trailing : .leading)
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(0.7)
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
    if let image = image {
      if circular {
        islandCircleImage(uiImage: image, size: size)
      } else {
        islandCompactImage(uiImage: image, size: size, cornerRadius: size * 0.22)
      }
    } else if !emoji.isEmpty {
      Text(emoji)
        .font(.system(size: size * 0.9))
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
    // fixedSize：避免 Live Activity 槽位压缩导致侧图被裁切一角
    Image(uiImage: uiImage)
      .resizable()
      .interpolation(.high)
      .antialiased(true)
      .scaledToFill()
      .frame(width: size, height: size)
      .clipped()
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .frame(width: size, height: size)
      .fixedSize()
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
