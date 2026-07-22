import Foundation
import Intents

/// 主 App 兜底：部分系统版本也会问 App 要动态选项
final class WidgetSelectionIntentHandler: NSObject,
  SelectSmallSavedWidgetIntentHandling,
  SelectMediumSavedWidgetIntentHandling
{
  func provideCurrentWidgetOptionsCollection(
    for intent: SelectSmallSavedWidgetIntent,
    with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void
  ) {
    completion(SavedWidgetOptionsProvider.makeCollection(filter: .small), nil)
  }

  func defaultCurrentWidget(for intent: SelectSmallSavedWidgetIntent) -> String? {
    nil
  }

  func provideTransparentPositionOptionsCollection(
    for intent: SelectSmallSavedWidgetIntent,
    with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void
  ) {
    completion(SavedWidgetOptionsProvider.makeTransparentCollection(), nil)
  }

  func defaultTransparentPosition(for intent: SelectSmallSavedWidgetIntent) -> String? {
    SavedWidgetOptionsProvider.transparentOff
  }

  func provideCurrentWidgetOptionsCollection(
    for intent: SelectMediumSavedWidgetIntent,
    with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void
  ) {
    completion(SavedWidgetOptionsProvider.makeCollection(filter: .medium), nil)
  }

  func defaultCurrentWidget(for intent: SelectMediumSavedWidgetIntent) -> String? {
    nil
  }

  func provideTransparentPositionOptionsCollection(
    for intent: SelectMediumSavedWidgetIntent,
    with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void
  ) {
    completion(SavedWidgetOptionsProvider.makeTransparentCollection(), nil)
  }

  func defaultTransparentPosition(for intent: SelectMediumSavedWidgetIntent) -> String? {
    SavedWidgetOptionsProvider.transparentOff
  }
}
