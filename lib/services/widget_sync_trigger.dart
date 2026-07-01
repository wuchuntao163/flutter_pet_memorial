import 'dart:async';
import 'dart:io';

import 'widget_service.dart';

/// 避免 AppCacheStore 与 PlatformPetSync 循环依赖
void scheduleWidgetSync() {
  if (!Platform.isIOS) return;
  unawaited(WidgetService.instance.updateWidget());
}
