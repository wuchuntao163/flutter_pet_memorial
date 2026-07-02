import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/background_style_config.dart';
import '../models/memorial_day.dart';
import 'background_store.dart';

/// 纪念日详情页本地样式（背景 / 数字形式），接口不保存，需持久化到本地
class MemorialStylePrefs {
  MemorialStylePrefs._();

  static final MemorialStylePrefs instance = MemorialStylePrefs._();

  static const _key = 'memorial_style_prefs';

  SharedPreferences? _prefs;
  final Map<String, _MemorialStyleSnapshot> _byId = {};

  Future<void> ensureLoaded() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        if (entry.value is! Map) continue;
        final snapshot = _MemorialStyleSnapshot.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        _byId['${entry.key}'] = snapshot;
        snapshot.seedBackgroundStore();
      }
    } catch (_) {}
  }

  MemorialDay apply(MemorialDay day) {
    final snapshot = _byId[day.id.trim()];
    if (snapshot == null) return day;
    snapshot.seedBackgroundStore();
    return day.copyWith(
      fontStyleId: snapshot.fontStyleId,
      backgroundTab: snapshot.backgroundTab,
      backgroundStyleId: snapshot.backgroundStyleId,
      dayCountDisplayMode: snapshot.dayCountDisplayMode,
    );
  }

  Future<void> save(MemorialDay day, {String? backgroundImageUrl}) async {
    final id = day.id.trim();
    if (id.isEmpty) return;
    final previous = _byId[id];
    final resolvedUrl = _resolveBackgroundImageUrl(
      day: day,
      incoming: backgroundImageUrl,
      previous: previous?.backgroundImageUrl,
    );
    _byId[id] = _MemorialStyleSnapshot.fromDay(
      day,
      backgroundImageUrl: resolvedUrl,
    );
    _byId[id]!.seedBackgroundStore();
    await ensureLoaded();
    await _persist();
  }

  String? backgroundImageUrlFor(String memorialId) =>
      _byId[memorialId.trim()]?.backgroundImageUrl;

  String? cachedImageUrlForStyleId(String styleId) {
    final key = styleId.trim();
    if (key.isEmpty) return null;
    for (final snapshot in _byId.values) {
      if (snapshot.backgroundStyleId == key) {
        return snapshot.backgroundImageUrl;
      }
    }
    return null;
  }

  bool hasCachedStyle(String styleId) {
    final key = styleId.trim();
    if (key.isEmpty) return false;
    for (final snapshot in _byId.values) {
      if (snapshot.backgroundStyleId == key) return true;
    }
    return false;
  }

  Future<void> prepareForMemorial(String memorialId) async {
    await ensureLoaded();
    _byId[memorialId.trim()]?.seedBackgroundStore();
  }

  static String? _resolveBackgroundImageUrl({
    required MemorialDay day,
    String? incoming,
    String? previous,
  }) {
    if (BackgroundStyleConfig.isTypeColorStyle(day.backgroundStyleId)) {
      return null;
    }
    final trimmed = incoming?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final resolved = BackgroundStyleConfig.imageUrlFor(day.backgroundStyleId);
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return previous;
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    final normalized = id.trim();
    if (normalized.isEmpty) return;
    if (_byId.remove(normalized) == null) return;
    await _persist();
  }

  Future<void> clear() async {
    await ensureLoaded();
    if (_byId.isEmpty) return;
    _byId.clear();
    await _prefs?.remove(_key);
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final payload = <String, dynamic>{
      for (final entry in _byId.entries) entry.key: entry.value.toJson(),
    };
    await prefs.setString(_key, jsonEncode(payload));
  }
}

class _MemorialStyleSnapshot {
  final String fontStyleId;
  final String backgroundTab;
  final String backgroundStyleId;
  final String? backgroundImageUrl;
  final DayCountDisplayMode dayCountDisplayMode;

  const _MemorialStyleSnapshot({
    required this.fontStyleId,
    required this.backgroundTab,
    required this.backgroundStyleId,
    required this.backgroundImageUrl,
    required this.dayCountDisplayMode,
  });

  factory _MemorialStyleSnapshot.fromDay(
    MemorialDay day, {
    String? backgroundImageUrl,
  }) {
    return _MemorialStyleSnapshot(
      fontStyleId: day.fontStyleId,
      backgroundTab: day.backgroundTab,
      backgroundStyleId: day.backgroundStyleId,
      backgroundImageUrl: backgroundImageUrl,
      dayCountDisplayMode: day.dayCountDisplayMode,
    );
  }

  void seedBackgroundStore() {
    if (BackgroundStyleConfig.isTypeColorStyle(backgroundStyleId)) return;
    final url = backgroundImageUrl?.trim();
    if (backgroundStyleId.isEmpty || url == null || url.isEmpty) return;
    BackgroundStore.instance.rememberItem(
      id: backgroundStyleId,
      image: url,
      categoryKey: backgroundTab.trim() == BackgroundStore.customTabKey
          ? BackgroundStore.customTabKey
          : null,
    );
  }

  static _MemorialStyleSnapshot fromJson(Map<String, dynamic> json) {
    final imageUrl = json['backgroundImageUrl']?.toString().trim();
    return _MemorialStyleSnapshot(
      fontStyleId: json['fontStyleId']?.toString() ?? 'normal',
      backgroundTab: json['backgroundTab']?.toString() ?? '简约',
      backgroundStyleId: json['backgroundStyleId']?.toString() ?? '',
      backgroundImageUrl:
          imageUrl != null && imageUrl.isNotEmpty ? imageUrl : null,
      dayCountDisplayMode: _parseDisplayMode(json['dayCountDisplayMode']),
    );
  }

  Map<String, dynamic> toJson() => {
        'fontStyleId': fontStyleId,
        'backgroundTab': backgroundTab,
        'backgroundStyleId': backgroundStyleId,
        if (backgroundImageUrl != null && backgroundImageUrl!.isNotEmpty)
          'backgroundImageUrl': backgroundImageUrl,
        'dayCountDisplayMode': dayCountDisplayMode.name,
      };

  static DayCountDisplayMode _parseDisplayMode(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    for (final mode in DayCountDisplayMode.values) {
      if (mode.name == value) return mode;
    }
    return DayCountDisplayMode.days;
  }
}
