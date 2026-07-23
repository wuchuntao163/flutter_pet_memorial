import 'dart:async';
import 'dart:io';

import 'live_activity_service.dart';
import 'widget_service.dart';

/// 避免 AppCacheStore 与 PlatformPetSync 循环依赖
void scheduleWidgetSync() {
  if (!Platform.isIOS) return;
  unawaited(WidgetService.instance.updateWidget());
}

void scheduleLiveActivitySync() {
  if (!Platform.isIOS) return;
  // 按 active_island_template 重算 payload（纪念日天数、计时跨日目标等）
  unawaited(LiveActivityService.instance.syncIfEnabled());
}
