import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../models/widget_definition.dart';
import '../utils/language_id_util.dart';

class WidgetStore extends ChangeNotifier {
  WidgetStore._();

  static final WidgetStore instance = WidgetStore._();

  final Map<int, List<WidgetDefinition>> _lists = {};
  final Map<int, WidgetDefinition> _details = {};
  final Set<int> _loadingTypes = {};
  final Set<int> _loadingDetails = {};
  final Map<int, Object> _errors = {};

  List<WidgetDefinition> items(int type) =>
      List.unmodifiable(_lists[type] ?? const []);
  WidgetDefinition? detail(int id) => _details[id];
  bool isLoading(int type) => _loadingTypes.contains(type);
  bool isDetailLoading(int id) => _loadingDetails.contains(id);
  Object? error(int type) => _errors[type];

  Future<void> fetchList(int type, {bool forceRefresh = false}) async {
    if (!forceRefresh && (_lists[type]?.isNotEmpty ?? false)) return;
    if (_loadingTypes.contains(type)) return;
    _loadingTypes.add(type);
    _errors.remove(type);
    notifyListeners();
    try {
      final response = await Api.get(
        ApiPaths.getWidgets,
        query: LanguageIdUtil.withLanguageId({'type': type}),
      );
      final data = response.data;
      final rawList = data is Map ? data['list'] : data;
      final parsed = <WidgetDefinition>[];
      for (final raw in rawList is List ? rawList : const []) {
        if (raw is! Map) continue;
        final isShow = raw['is_show'];
        if (isShow == 0 || '$isShow' == '0') continue;
        final item = WidgetDefinition.fromJson(Map<String, dynamic>.from(raw));
        if (item.id > 0) parsed.add(item);
      }
      _lists[type] = parsed;
    } catch (error) {
      _errors[type] = error;
      if (kDebugMode) debugPrint('[WidgetStore] fetchList($type): $error');
    } finally {
      _loadingTypes.remove(type);
      notifyListeners();
    }
  }

  Future<WidgetDefinition?> fetchDetail(
    int id, {
    WidgetDefinition? fallback,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _details[id] != null) return _details[id];
    if (_loadingDetails.contains(id)) return _details[id] ?? fallback;
    _loadingDetails.add(id);
    notifyListeners();
    try {
      final response = await Api.get(ApiPaths.getWidgetInfo, query: {'id': id});
      final data = response.data;
      if (data is! Map) return fallback;
      final infoRaw = data['info'];
      if (infoRaw is! Map) return fallback;
      final options = <String, String>{};
      final optionsRaw = data['options'];
      if (optionsRaw is Map) {
        for (final entry in optionsRaw.entries) {
          options['${entry.key}'] = '${entry.value}';
        }
      }
      final info = Map<String, dynamic>.from(infoRaw);
      final detail = fallback == null
          ? WidgetDefinition.fromJson(info, options: options)
          : fallback.copyWithDetail(info, options);
      _details[id] = detail;
      return detail;
    } catch (error) {
      if (kDebugMode) debugPrint('[WidgetStore] fetchDetail($id): $error');
      return fallback;
    } finally {
      _loadingDetails.remove(id);
      notifyListeners();
    }
  }
}
