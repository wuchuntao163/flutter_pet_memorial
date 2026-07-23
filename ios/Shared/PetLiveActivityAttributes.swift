import ActivityKit
import Foundation

/// Live Activity / 灵动岛共享数据模型（主 App 与 Widget Extension 均需编译）
struct PetLiveActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// 1 宠物 / 2 图文 / 3 正计时 / 4 倒计时 / 5 纪念日 / 6 自定义
    var template: Int
    var petName: String
    var subtitle: String
    var memorialTitle: String
    var imageRevision: Int64
    /// 模板 3/4：目标时刻（Unix 秒）；正计时为起点，倒计时为终点
    var timerTargetEpoch: Double
    /// 模板 5：如「2555天」
    var daysText: String
    var textColorARGB: UInt32
    /// 模板 6 文案归一化坐标 0–1
    var textNormX: Double
    var textNormY: Double
    var compactLeadingEmoji: String
    var compactTrailingEmoji: String

    enum CodingKeys: String, CodingKey {
      case template
      case petName
      case subtitle
      case memorialTitle
      case imageRevision
      case timerTargetEpoch
      case daysText
      case textColorARGB
      case textNormX
      case textNormY
      case compactLeadingEmoji
      case compactTrailingEmoji
    }

    init(
      template: Int = 1,
      petName: String = "",
      subtitle: String = "",
      memorialTitle: String = "",
      imageRevision: Int64 = 0,
      timerTargetEpoch: Double = 0,
      daysText: String = "",
      textColorARGB: UInt32 = 0xFFFFFFFF,
      textNormX: Double = 0.58,
      textNormY: Double = 0.72,
      compactLeadingEmoji: String = "",
      compactTrailingEmoji: String = ""
    ) {
      self.template = template
      self.petName = petName
      self.subtitle = subtitle
      self.memorialTitle = memorialTitle
      self.imageRevision = imageRevision
      self.timerTargetEpoch = timerTargetEpoch
      self.daysText = daysText
      self.textColorARGB = textColorARGB
      self.textNormX = textNormX
      self.textNormY = textNormY
      self.compactLeadingEmoji = compactLeadingEmoji
      self.compactTrailingEmoji = compactTrailingEmoji
    }

    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      template = try c.decodeIfPresent(Int.self, forKey: .template) ?? 1
      petName = try c.decodeIfPresent(String.self, forKey: .petName) ?? ""
      subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
      memorialTitle = try c.decodeIfPresent(String.self, forKey: .memorialTitle) ?? ""
      imageRevision = try c.decodeIfPresent(Int64.self, forKey: .imageRevision) ?? 0
      timerTargetEpoch = try c.decodeIfPresent(Double.self, forKey: .timerTargetEpoch) ?? 0
      daysText = try c.decodeIfPresent(String.self, forKey: .daysText) ?? ""
      textColorARGB = try c.decodeIfPresent(UInt32.self, forKey: .textColorARGB) ?? 0xFFFFFFFF
      textNormX = try c.decodeIfPresent(Double.self, forKey: .textNormX) ?? 0.58
      textNormY = try c.decodeIfPresent(Double.self, forKey: .textNormY) ?? 0.72
      compactLeadingEmoji = try c.decodeIfPresent(String.self, forKey: .compactLeadingEmoji) ?? ""
      compactTrailingEmoji = try c.decodeIfPresent(String.self, forKey: .compactTrailingEmoji) ?? ""
    }
  }

  var petId: String
}
