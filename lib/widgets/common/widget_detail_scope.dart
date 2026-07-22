import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../models/widget_definition.dart';
import '../../data/saved_widget_store.dart';
import '../../utils/memorial_image_capture.dart';

class WidgetDetailScope extends InheritedWidget {
  const WidgetDetailScope({
    super.key,
    required this.definition,
    required super.child,
  });

  final WidgetDefinition definition;

  static WidgetDefinition? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<WidgetDetailScope>()
        ?.definition;
  }

  @override
  bool updateShouldNotify(WidgetDetailScope oldWidget) =>
      definition != oldWidget.definition;
}

bool widgetOptionEnabled(
  BuildContext context,
  String key, {
  bool fallback = true,
}) {
  final definition = WidgetDetailScope.maybeOf(context);
  if (definition == null) return fallback;
  return definition.config.contains(key);
}

String widgetOptionLabel(BuildContext context, String key, String fallback) {
  final definition = WidgetDetailScope.maybeOf(context);
  if (definition == null) return fallback;
  final label = definition.options[key]?.trim() ?? '';
  return label.isEmpty ? fallback : label;
}

DecorationImage? widgetDefaultBackgroundDecoration(BuildContext context) {
  final value = WidgetDetailScope.maybeOf(context)?.defaultBackground.trim();
  if (value == null || value.isEmpty) return null;
  final provider = value.startsWith('http://') || value.startsWith('https://')
      ? NetworkImage(value)
      : AssetImage(value) as ImageProvider;
  return DecorationImage(image: provider, fit: BoxFit.cover);
}

Future<void> saveWidgetToLibrary(
  WidgetDefinition? definition, {
  Map<String, dynamic> settings = const {},
  GlobalKey? previewBoundaryKey,
  GlobalKey? backgroundBoundaryKey,
}) async {
  if (definition == null || definition.isIsland) return;

  Uint8List? previewPng;
  Uint8List? backgroundPng;
  if (previewBoundaryKey != null || backgroundBoundaryKey != null) {
    try {
      // 等布局与背景图绘制完成再截图（网络图略多等一会）
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (previewBoundaryKey != null) {
        previewPng = await MemorialImageCapture.capturePng(
          previewBoundaryKey,
          pixelRatio: 3,
        );
      }
      if (backgroundBoundaryKey != null) {
        backgroundPng = await MemorialImageCapture.capturePng(
          backgroundBoundaryKey,
          pixelRatio: 3,
        );
      }
    } catch (error) {
      debugPrint('[saveWidgetToLibrary] capture failed: $error');
    }
  }

  await SavedWidgetStore.instance.saveDefinition(
    definition,
    settings: settings,
    previewPng: previewPng,
    backgroundPng: backgroundPng,
  );
}
