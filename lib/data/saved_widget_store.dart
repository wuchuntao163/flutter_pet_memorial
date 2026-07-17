import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_widget.dart';
import '../models/widget_definition.dart';

class SavedWidgetStore extends ChangeNotifier {
  SavedWidgetStore._();

  static final SavedWidgetStore instance = SavedWidgetStore._();
  static const _storageKey = 'saved_widget_library_v1';

  final List<SavedWidget> _items = [];
  bool _loaded = false;

  List<SavedWidget> get items => List.unmodifiable(_items);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map(
                (item) => SavedWidget.fromJson(Map<String, dynamic>.from(item)),
              ),
            );
        }
      } catch (error) {
        debugPrint('[SavedWidgetStore] load failed: $error');
      }
    }
    notifyListeners();
  }

  Future<void> saveDefinition(WidgetDefinition definition) async {
    if (definition.type != 1 || definition.id <= 0) return;
    await load();
    final item = SavedWidget(
      widgetId: definition.id,
      title: definition.title,
      image: definition.image,
      template: definition.template,
      savedAt: DateTime.now(),
    );
    final index = _items.indexWhere((value) => value.widgetId == item.widgetId);
    if (index == -1) {
      _items.insert(0, item);
    } else {
      _items
        ..removeAt(index)
        ..insert(0, item);
    }
    await _persist();
  }

  Future<void> remove(int widgetId) async {
    await load();
    _items.removeWhere((item) => item.widgetId == widgetId);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
    notifyListeners();
  }
}
