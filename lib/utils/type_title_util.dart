import 'dart:convert';

import 'language_id_util.dart';

/// 纪念日类型 [title_json] 多语言标题解析
abstract final class TypeTitleUtil {
  TypeTitleUtil._();

  static String resolve(Map<String, dynamic> type) {
    final fallback = type['title']?.toString().trim() ?? '';
    final entries = _parseTitleJson(type['title_json']);
    if (entries == null || entries.isEmpty) return fallback;

    final languageId = LanguageIdUtil.resolve();
    if (languageId != null) {
      for (final raw in entries) {
        if (raw is! Map) continue;
        final entry = Map<String, dynamic>.from(raw);
        final entryLangId = int.tryParse('${entry['language_id']}');
        if (entryLangId != languageId) continue;
        final localized = entry['title']?.toString().trim() ?? '';
        if (localized.isNotEmpty) return localized;
      }
    }

    return fallback;
  }

  static List<dynamic>? _parseTitleJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) return raw;
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) return decoded;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
