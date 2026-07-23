import ActivityKit
import Flutter
import Foundation
import UIKit

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
    let combined = WidgetSync.liveActivityCombinedImageRevision()
    if combined > 0 {
      return combined
    }
    guard let container = WidgetSync.appGroupContainer() else { return 0 }
    let path = container.appendingPathComponent(WidgetSync.imageFileName).path
    guard FileManager.default.fileExists(atPath: path),
          let attrs = try? FileManager.default.attributesOfItem(atPath: path),
          let modified = attrs[.modificationDate] as? Date else {
      return 0
    }
    return Int64(modified.timeIntervalSince1970 * 1000)
  }

  static func contentState(from args: [String: Any]) -> PetLiveActivityAttributes.ContentState {
    let template = intValue(args["template"]) ?? 1
    let petName = stringValue(args["petName"])
    let subtitle = stringValue(args["subtitle"])
    let memorialTitle = stringValue(args["memorialTitle"])
    let timerTargetEpoch = doubleValue(args["timerTargetEpoch"]) ?? 0
    let daysText = stringValue(args["daysText"])
    let textColorARGB = uInt32Value(args["textColorARGB"]) ?? 0xFFFFFFFF
    let backgroundColorARGB = uInt32Value(args["backgroundColorARGB"]) ?? 0xFFFFC7B9
    let textFontSize = doubleValue(args["textFontSize"]) ?? 16
    let textNormX = doubleValue(args["textNormX"]) ?? 0.58
    let textNormY = doubleValue(args["textNormY"]) ?? 0.72
    let leadingEmoji = stringValue(args["compactLeadingEmoji"])
    let trailingEmoji = stringValue(args["compactTrailingEmoji"])
    return PetLiveActivityAttributes.ContentState(
      template: template,
      petName: petName,
      subtitle: subtitle,
      memorialTitle: memorialTitle,
      imageRevision: imageRevision(),
      timerTargetEpoch: timerTargetEpoch,
      daysText: daysText,
      textColorARGB: textColorARGB,
      backgroundColorARGB: backgroundColorARGB,
      textFontSize: textFontSize,
      textNormX: textNormX,
      textNormY: textNormY,
      compactLeadingEmoji: leadingEmoji,
      compactTrailingEmoji: trailingEmoji
    )
  }

  static func syncImages(
    petUrl: String,
    fourCloverUrl: String,
    authToken: String,
    completion: @escaping (Bool) -> Void
  ) {
    let pet = petUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    let clover = fourCloverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    if pet.isEmpty && clover.isEmpty {
      completion(false)
      return
    }

    let group = DispatchGroup()
    var petOk = false
    var cloverOk = false

    if !pet.isEmpty {
      group.enter()
      WidgetSync.downloadLiveActivityImage(from: pet, authToken: authToken) { ok in
        petOk = ok
        group.leave()
      }
    }

    if !clover.isEmpty {
      group.enter()
      WidgetSync.downloadFourCloverImage(from: clover, authToken: authToken) { ok in
        cloverOk = ok
        group.leave()
      }
    }

    group.notify(queue: .main) {
      let petSuccess = pet.isEmpty || petOk
      let cloverSuccess = clover.isEmpty || cloverOk
      completion(petSuccess && cloverSuccess)
    }
  }

  static func syncAsset(
    role: String,
    imagePath: String?,
    imageBase64: String?,
    completion: @escaping (Bool) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      let data: Data?
      if let path = imagePath?.trimmingCharacters(in: .whitespacesAndNewlines),
         !path.isEmpty {
        let cleaned = path.hasPrefix("file://")
          ? (URL(string: path)?.path ?? path)
          : path
        data = try? Data(contentsOf: URL(fileURLWithPath: cleaned))
      } else if let base64 = imageBase64, !base64.isEmpty {
        data = Data(base64Encoded: base64)
      } else {
        data = nil
      }
      guard let data, !data.isEmpty else {
        DispatchQueue.main.async { completion(false) }
        return
      }
      let ok = WidgetSync.replaceLiveActivityAsset(role: role, data: data)
      DispatchQueue.main.async { completion(ok) }
    }
  }

  @available(iOS 16.2, *)
  static func start(petId: String, state: PetLiveActivityAttributes.ContentState) throws -> String {
    endAllSync()

    let attributes = PetLiveActivityAttributes(petId: petId)
    var next = state
    next.imageRevision = imageRevision()
    let staleDate = Calendar.current.date(byAdding: .hour, value: 8, to: Date())
    let content = ActivityContent(state: next, staleDate: staleDate)

    let activity = try Activity.request(
      attributes: attributes,
      content: content,
      pushType: nil
    )
    saveActivityId(activity.id)
    NSLog("[LiveActivity] started id=\(activity.id) template=\(next.template)")
    return activity.id
  }

  @available(iOS 16.2, *)
  @discardableResult
  static func update(state: PetLiveActivityAttributes.ContentState) -> Bool {
    var next = state
    next.imageRevision = imageRevision()
    let staleDate = Calendar.current.date(byAdding: .hour, value: 8, to: Date())
    let content = ActivityContent(state: next, staleDate: staleDate)

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
    NSLog("[LiveActivity] updated count=\(activities.count) template=\(next.template)")
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

  private static func stringValue(_ raw: Any?) -> String {
    (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private static func intValue(_ raw: Any?) -> Int? {
    if let n = raw as? Int { return n }
    if let n = raw as? NSNumber { return n.intValue }
    if let s = raw as? String { return Int(s) }
    return nil
  }

  private static func doubleValue(_ raw: Any?) -> Double? {
    if let n = raw as? Double { return n }
    if let n = raw as? Int { return Double(n) }
    if let n = raw as? NSNumber { return n.doubleValue }
    if let s = raw as? String { return Double(s) }
    return nil
  }

  private static func uInt32Value(_ raw: Any?) -> UInt32? {
    if let n = raw as? UInt32 { return n }
    if let n = raw as? Int { return UInt32(truncatingIfNeeded: n) }
    if let n = raw as? NSNumber { return n.uint32Value }
    if let s = raw as? String, let v = UInt32(s) { return v }
    return nil
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
      case "syncImage":
        handleSyncImage(call: call, result: result)
      case "syncAsset":
        handleSyncAsset(call: call, result: result)
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
    let petId = (args["petId"] as? String) ?? ""
    let state = LiveActivitySync.contentState(from: args)

    // 模板 1 仍要求有宠物名；其它模板可用 subtitle / memorialTitle 兜底
    let hasIdentity = !state.petName.isEmpty
      || !state.subtitle.isEmpty
      || !state.memorialTitle.isEmpty
      || state.template != 1
    guard hasIdentity else {
      result(
        FlutterError(code: "INVALID_ARGS", message: "内容不能为空", details: nil)
      )
      return
    }

    do {
      let activityId = try LiveActivitySync.start(petId: petId, state: state)
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
    let state = LiveActivitySync.contentState(from: args)

    if LiveActivitySync.isActive() {
      result(LiveActivitySync.update(state: state))
      return
    }

    do {
      let petId = (args["petId"] as? String) ?? ""
      _ = try LiveActivitySync.start(petId: petId, state: state)
      result(true)
    } catch {
      NSLog("[LiveActivity] update-as-start failed: \(error)")
      result(false)
    }
  }

  private static func handleSyncImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let petImageUrl = args["petImageUrl"] as? String ?? ""
    let fourCloverUrl = args["fourCloverUrl"] as? String ?? ""
    let authToken = args["authToken"] as? String ?? ""

    LiveActivitySync.syncImages(
      petUrl: petImageUrl,
      fourCloverUrl: fourCloverUrl,
      authToken: authToken
    ) { ok in
      DispatchQueue.main.async {
        result(ok)
      }
    }
  }

  private static func handleSyncAsset(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let role = (args["role"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !role.isEmpty else {
      result(false)
      return
    }
    LiveActivitySync.syncAsset(
      role: role,
      imagePath: args["imagePath"] as? String,
      imageBase64: args["imageBase64"] as? String
    ) { ok in
      result(ok)
    }
  }
}
