import Intents

/// Intents Extension 入口：系统「编辑小组件 → 选取」会调用这里提供选项
class IntentHandler: INExtension {
  override func handler(for intent: INIntent) -> Any {
    self
  }
}

extension IntentHandler: SelectSmallSavedWidgetIntentHandling {
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
    completion(SavedWidgetOptionsProvider.makeTransparentCollection(filter: .small), nil)
  }

  func defaultTransparentPosition(for intent: SelectSmallSavedWidgetIntent) -> String? {
    SavedWidgetOptionsProvider.transparentOff
  }
}

extension IntentHandler: SelectMediumSavedWidgetIntentHandling {
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
    completion(SavedWidgetOptionsProvider.makeTransparentCollection(filter: .medium), nil)
  }

  func defaultTransparentPosition(for intent: SelectMediumSavedWidgetIntent) -> String? {
    SavedWidgetOptionsProvider.transparentOff
  }
}
