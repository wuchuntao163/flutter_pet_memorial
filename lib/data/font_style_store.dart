import 'dart:convert';



import 'package:flutter/foundation.dart';



import '../api/api.dart';

import '../utils/language_id_util.dart';



/// 倒数日数字字体样式（getFontStyles）

class FontStyleStore extends ChangeNotifier {

  FontStyleStore._();



  static final FontStyleStore instance = FontStyleStore._();



  final List<Map<String, dynamic>> _items = [];

  bool isLoading = false;



  List<Map<String, dynamic>> get items => List.unmodifiable(_items);



  Map<String, dynamic>? findById(String id) {

    for (final item in _items) {

      if ('${item['id']}' == id) return item;

    }

    return null;

  }



  Future<void> fetchList() async {

    isLoading = true;

    notifyListeners();

    try {

      final res = await Api.get(

        ApiPaths.getFontStyles,

        query: LanguageIdUtil.apply({}),

      );

      final data = res.data;

      _items

        ..clear()

        ..addAll(_parseList(data));

      if (kDebugMode) {

        debugPrint('[FontStyleStore] getFontStyles ok: ${_items.length} items');

      }

    } on ApiException catch (e) {

      if (kDebugMode) {

        debugPrint('[FontStyleStore] fetchList failed: $e');

      }

    } finally {

      isLoading = false;

      notifyListeners();

    }

  }



  static List<Map<String, dynamic>> _parseList(dynamic data) {

    final list = data is Map ? data['list'] : data;

    if (list is! List) return [];



    final result = <Map<String, dynamic>>[];

    for (final raw in list.whereType<Map>()) {

      final map = Map<String, dynamic>.from(raw);

      if (map['is_show'] != 0) result.add(map);

    }

    return result;

  }



  /// 解析接口 `images` 字段（JSON 字符串或数组）

  static List<String> parseImages(dynamic raw) {

    if (raw == null) return [];

    if (raw is List) {

      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();

    }

    if (raw is String) {

      final trimmed = raw.trim();

      if (trimmed.isEmpty) return [];

      try {

        final decoded = jsonDecode(trimmed);

        if (decoded is List) {

          return decoded

              .map((e) => e.toString())

              .where((s) => s.isNotEmpty)

              .toList();

        }

      } catch (_) {}

      if (trimmed.startsWith('http')) return [trimmed];

    }

    return [];

  }

}

