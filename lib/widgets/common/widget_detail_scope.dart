import 'package:flutter/widgets.dart';

import '../../models/widget_definition.dart';
import '../../data/saved_widget_store.dart';

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

Future<void> saveWidgetToLibrary(WidgetDefinition? definition) async {
  if (definition == null || definition.isIsland) return;
  await SavedWidgetStore.instance.saveDefinition(definition);
}
