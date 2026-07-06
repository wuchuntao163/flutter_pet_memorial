import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

private enum LiveActivityShared {
  static let appGroupId = AppGroupConfig.id
  static let liveActivityImageName = "petLiveActivityImage.png"
  static let fourCloverImageName = "petLiveActivityFourClover.png"
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

  static func loadUIImage(named fileName: String) -> UIImage? {
    guard let path = cachedImagePath(named: fileName),
          let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
      return nil
    }
    return UIImage(data: data)
  }

  static func loadCachedPetImage() -> UIImage? {
    guard let path = cachedPetImagePath(),
          let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
      return nil
    }
    return UIImage(data: data)
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
        compactPetImageView(size: 28)
          .id(context.state.imageRevision)
      } compactTrailing: {
        fourCloverImageView(size: 22)
          .id(context.state.imageRevision)
      } minimal: {
        compactPetImageView(size: 22)
          .id(context.state.imageRevision)
      }
      .keylineTint(Color.orange.opacity(0.8))
    }
  }

  @ViewBuilder
  private func expandedContent(context: ActivityViewContext<PetLiveActivityAttributes>) -> some View {
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
  private func lockScreenView(context: ActivityViewContext<PetLiveActivityAttributes>) -> some View {
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
  private func compactPetImageView(size: CGFloat) -> some View {
    if let image = LiveActivityShared.loadCachedPetImage() {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    } else {
      Image(systemName: "pawprint.fill")
        .font(.system(size: size * 0.5))
        .foregroundColor(.orange.opacity(0.8))
        .frame(width: size, height: size)
    }
  }

  @ViewBuilder
  private func fourCloverImageView(size: CGFloat) -> some View {
    if let image = LiveActivityShared.loadUIImage(named: LiveActivityShared.fourCloverImageName) {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
    } else {
      Image(systemName: "leaf.fill")
        .font(.system(size: size * 0.55))
        .foregroundColor(.orange.opacity(0.85))
        .frame(width: size, height: size)
    }
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
