import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

private enum LiveActivityShared {
  static let appGroupId = AppGroupConfig.id
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

  static func loadCachedPetImage() -> UIImage? {
    guard let path = cachedImagePath(),
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
        petImageView(size: 28)
          .id(context.state.imageRevision)
      } compactTrailing: {
        Image(systemName: "heart.fill")
          .font(.caption2)
          .foregroundColor(.orange.opacity(0.85))
      } minimal: {
        petImageView(size: 22)
          .id(context.state.imageRevision)
      }
      .keylineTint(Color.orange.opacity(0.8))
    }
  }

  @ViewBuilder
  private func expandedContent(context: ActivityViewContext<PetLiveActivityAttributes>) -> some View {
    HStack(alignment: .center, spacing: 14) {
      Spacer(minLength: 10)
      petImageView(size: 64)
        .id(context.state.imageRevision)
      Text(context.state.subtitle)
        .font(.title3)
        .fontWeight(.semibold)
        .foregroundColor(.primary)
        .lineLimit(2)
        .minimumScaleFactor(0.85)
        .multilineTextAlignment(.leading)
      Spacer(minLength: 10)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
  }

  @ViewBuilder
  private func lockScreenView(context: ActivityViewContext<PetLiveActivityAttributes>) -> some View {
    HStack(alignment: .center, spacing: 16) {
      Spacer(minLength: 16)
      petImageView(size: 68)
        .id(context.state.imageRevision)
      Text(context.state.subtitle)
        .font(.title3)
        .fontWeight(.semibold)
        .foregroundColor(.primary)
        .lineLimit(2)
        .minimumScaleFactor(0.85)
        .multilineTextAlignment(.leading)
      Spacer(minLength: 16)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .padding(.horizontal, 12)
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
