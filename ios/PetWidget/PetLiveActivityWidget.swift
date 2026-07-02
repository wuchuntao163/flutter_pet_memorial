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

@available(iOS 16.1, *)
struct PetLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PetLiveActivityAttributes.self) { context in
      lockScreenView(context: context)
        .activityBackgroundTint(Color.orange.opacity(0.15))
        .activitySystemActionForegroundColor(Color.primary)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          petImageView(size: 44)
            .id(context.state.imageRevision)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(context.state.subtitle)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.trailing)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.state.petName)
            .font(.headline)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if !context.state.memorialTitle.isEmpty {
            Text(context.state.memorialTitle)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }
      } compactLeading: {
        petImageView(size: 22)
          .id(context.state.imageRevision)
      } compactTrailing: {
        Text(compactSubtitle(context.state.subtitle))
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      } minimal: {
        petImageView(size: 18)
          .id(context.state.imageRevision)
      }
      .keylineTint(Color.orange.opacity(0.8))
    }
  }

  @ViewBuilder
  private func lockScreenView(context: ActivityViewContext<PetLiveActivityAttributes>) -> some View {
    HStack(spacing: 12) {
      petImageView(size: 40)
        .id(context.state.imageRevision)
      VStack(alignment: .leading, spacing: 4) {
        Text(context.state.petName)
          .font(.headline)
          .lineLimit(1)
        if !context.state.memorialTitle.isEmpty {
          Text(context.state.memorialTitle)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
        Text(context.state.subtitle)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 4)
  }

  @ViewBuilder
  private func petImageView(size: CGFloat) -> some View {
    if let image = LiveActivityShared.loadCachedPetImage() {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(Circle())
    } else {
      Image(systemName: "pawprint.fill")
        .font(.system(size: size * 0.55))
        .foregroundColor(.orange.opacity(0.8))
        .frame(width: size, height: size)
    }
  }

  private func compactSubtitle(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.count <= 8 { return trimmed }
    return String(trimmed.prefix(8))
  }
}
