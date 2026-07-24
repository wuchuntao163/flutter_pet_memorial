import Foundation

enum AppGroupConfig {
  static let id: String = {
    if let raw = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String {
      let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      if !value.isEmpty, !value.hasPrefix("$(") {
        return value
      }
    }
    return "group.com.jnr.flutterPetMemorial"
  }()
}
