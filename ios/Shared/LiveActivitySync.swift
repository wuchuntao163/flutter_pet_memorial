import ActivityKit
import Flutter
import Foundation

enum LiveActivitySync {
  static let activityIdKey = "petLiveActivityId"

  static var isSupported: Bool {
    if #available(iOS 16.2, *) {
      return true
    }
    return false
  }

  static func areActivitiesEnabled() -> Bool {
    guard #available(iOS 16.2, *) else { return false }
    return ActivityAuthorizationInfo().areActivitiesEnabled
  }

  static func isActive() -> Bool {
    guard #available(iOS 16.2, *) else { return false }
    return !Activity<PetLiveActivityAttributes>.activities.isEmpty
  }

  static func imageRevision() -> Int64 {
    guard let container = WidgetSync.appGroupContainer() else { return 0 }
    let path = container.appendingPathComponent(WidgetSync.imageFileName).path
    guard FileManager.default.fileExists(atPath: path),
          let attrs = try? FileManager.default.attributesOfItem(atPath: path),
          let modified = attrs[.modificationDate] as? Date else {
      return 0
    }
    return Int64(modified.timeIntervalSince1970 * 1000)
  }

  @available(iOS 16.2, *)
  static func start(
    petId: String,
    petName: String,
    subtitle: String,
    memorialTitle: String
  ) throws -> String {
    endAllSync()

    let attributes = PetLiveActivityAttributes(petId: petId)
    let state = PetLiveActivityAttributes.ContentState(
      petName: petName,
      subtitle: subtitle,
      memorialTitle: memorialTitle,
      imageRevision: imageRevision()
    )
    let staleDate = Calendar.current.date(byAdding: .hour, value: 8, to: Date())
    let content = ActivityContent(state: state, staleDate: staleDate)

    let activity = try Activity.request(
      attributes: attributes,
      content: content,
      pushType: nil
    )
    saveActivityId(activity.id)
    NSLog("[LiveActivity] started id=\(activity.id)")
    return activity.id
  }

  @available(iOS 16.2, *)
  @discardableResult
  static func update(
    petName: String,
    subtitle: String,
    memorialTitle: String
  ) -> Bool {
    let state = PetLiveActivityAttributes.ContentState(
      petName: petName,
      subtitle: subtitle,
      memorialTitle: memorialTitle,
      imageRevision: imageRevision()
    )
    let staleDate = Calendar.current.date(byAdding: .hour, value: 8, to: Date())
    let content = ActivityContent(state: state, staleDate: staleDate)

    let activities = Activity<PetLiveActivityAttributes>.activities
    guard !activities.isEmpty else { return false }

    Task {
      for activity in activities {
        await activity.update(content)
      }
    }
    if let first = activities.first {
      saveActivityId(first.id)
    }
    NSLog("[LiveActivity] updated count=\(activities.count)")
    return true
  }

  static func endAllSync() {
    guard #available(iOS 16.2, *) else { return }
    let activities = Activity<PetLiveActivityAttributes>.activities
    guard !activities.isEmpty else {
      clearActivityId()
      return
    }
    Task {
      for activity in activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
    clearActivityId()
    NSLog("[LiveActivity] ended count=\(activities.count)")
  }

  private static func saveActivityId(_ id: String) {
    UserDefaults(suiteName: AppGroupConfig.id)?.set(id, forKey: activityIdKey)
  }

  private static func clearActivityId() {
    UserDefaults(suiteName: AppGroupConfig.id)?.removeObject(forKey: activityIdKey)
  }
}

enum LiveActivityChannelHandler {
  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.example.flutterPetMemorial/live_activity",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported":
        result(LiveActivitySync.isSupported)
      case "areActivitiesEnabled":
        result(LiveActivitySync.areActivitiesEnabled())
      case "isActive":
        result(LiveActivitySync.isActive())
      case "startActivity":
        handleStart(call: call, result: result)
      case "updateActivity":
        handleUpdate(call: call, result: result)
      case "endActivity":
        LiveActivitySync.endAllSync()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("[LiveActivity] Method channel registered")
  }

  private static func handleStart(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(
        FlutterError(code: "UNSUPPORTED", message: "Live Activity 需要 iOS 16.2+", details: nil)
      )
      return
    }

    let args = call.arguments as? [String: Any] ?? [:]
    let petId = args["petId"] as? String ?? ""
    let petName = args["petName"] as? String ?? ""
    let subtitle = args["subtitle"] as? String ?? ""
    let memorialTitle = args["memorialTitle"] as? String ?? ""

    guard !petName.isEmpty else {
      result(
        FlutterError(code: "INVALID_ARGS", message: "petName 不能为空", details: nil)
      )
      return
    }

    do {
      let activityId = try LiveActivitySync.start(
        petId: petId,
        petName: petName,
        subtitle: subtitle,
        memorialTitle: memorialTitle
      )
      result(activityId)
    } catch {
      NSLog("[LiveActivity] start failed: \(error)")
      result(
        FlutterError(
          code: "START_FAILED",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private static func handleUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(false)
      return
    }

    let args = call.arguments as? [String: Any] ?? [:]
    let petName = args["petName"] as? String ?? ""
    let subtitle = args["subtitle"] as? String ?? ""
    let memorialTitle = args["memorialTitle"] as? String ?? ""

    if LiveActivitySync.isActive() {
      result(
        LiveActivitySync.update(
          petName: petName,
          subtitle: subtitle,
          memorialTitle: memorialTitle
        )
      )
      return
    }

    guard !petName.isEmpty else {
      result(false)
      return
    }

    do {
      let petId = args["petId"] as? String ?? ""
      _ = try LiveActivitySync.start(
        petId: petId,
        petName: petName,
        subtitle: subtitle,
        memorialTitle: memorialTitle
      )
      result(true)
    } catch {
      NSLog("[LiveActivity] update-as-start failed: \(error)")
      result(false)
    }
  }
}
