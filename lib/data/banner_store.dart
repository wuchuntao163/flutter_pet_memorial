import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../utils/banner_util.dart';

/// 我的页 Banner（getBanner）
class BannerStore extends ChangeNotifier {
  BannerStore._();

  static final BannerStore instance = BannerStore._();

  final List<Map<String, dynamic>> _items = [];
  bool isLoading = false;
  bool listLoaded = false;

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  Future<void> fetchList({int bannerType = 0}) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await Api.get(
        ApiPaths.getBanner,
        query: {'banner_type': bannerType},
      );
      _items
        ..clear()
        ..addAll(BannerUtil.filterByPlatform(_parseList(res.data)));
      if (kDebugMode) {
        debugPrint('[BannerStore] getBanner ok: ${_items.length} items');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[BannerStore] fetchList failed: $e');
      }
    } finally {
      isLoading = false;
      listLoaded = true;
      notifyListeners();
    }
  }

  static List<Map<String, dynamic>> _parseList(dynamic data) {
    final list = data is Map ? data['list'] : data;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['image_url']?.toString() ?? '').isNotEmpty)
        .toList();
  }
}
