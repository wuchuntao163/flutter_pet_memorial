import ActivityKit
import Foundation

/// Live Activity / 灵动岛共享数据模型（主 App 与 Widget Extension 均需编译）
struct PetLiveActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var petName: String
    var subtitle: String
    var memorialTitle: String
    var imageRevision: Int64
  }

  var petId: String
}
