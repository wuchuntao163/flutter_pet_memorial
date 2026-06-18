/// 非 iOS 平台的空实现，避免 Android 等平台触发原生 Widget 通道。
class WidgetServiceImpl {
  Future<void> updateWidget() async {}
}
