import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../services/pet_image_service.dart';
import '../utils/language_id_util.dart';

/// 倒数日背景：分类、列表、自定义上传/更新/删除
class BackgroundStore extends ChangeNotifier {
  BackgroundStore._();

  static final BackgroundStore instance = BackgroundStore._();

  static const customTabKey = 'custom';

  final List<Map<String, dynamic>> _categories = [];
  final Map<String, List<Map<String, dynamic>>> _itemsByCategory = {};
  final Map<String, Map<String, dynamic>> _itemById = {};

  List<Map<String, dynamic>> _currentItems = [];
  int? _selectedCategoryId;
  bool _isCustomTab = false;
  int? _loadedLanguageId;
  int _listRequestSeq = 0;

  bool categoriesLoading = false;
  bool listLoading = false;

  List<Map<String, dynamic>> get categories => List.unmodifiable(_categories);
  List<Map<String, dynamic>> get items => List.unmodifiable(_currentItems);
  int? get selectedCategoryId => _selectedCategoryId;
  bool get isCustomTab => _isCustomTab;

  /// 当前是否为分类列表第一项（默认背景仅在此项展示）
  bool get isFirstCategorySelected {
    if (_isCustomTab || _categories.isEmpty) return false;
    final firstId = _categoryId(_categories.first);
    return firstId != null && _selectedCategoryId == firstId;
  }

  Map<String, dynamic>? findById(String id) => _itemById[id];

  static bool isUserOwned(Map<String, dynamic> item) {
    final userId = item['user_id'];
    final parsed = userId is int ? userId : int.tryParse('$userId');
    return parsed != null && parsed > 0;
  }

  void _invalidateLanguageCache() {
    _categories.clear();
    _itemsByCategory.clear();
    _itemById.clear();
    _currentItems.clear();
    _loadedLanguageId = null;
  }

  void _markLanguageLoaded() {
    _loadedLanguageId = LanguageIdUtil.resolve();
  }

  Future<void> ensureReady({bool customTab = false}) async {
    final languageChanged = _loadedLanguageId != LanguageIdUtil.resolve();
    if (languageChanged) {
      _invalidateLanguageCache();
    }

    if (_categories.isEmpty) {
      await fetchCategories();
    }
    if (customTab) {
      await selectCustomTab(forceRefresh: languageChanged);
      return;
    }

    await selectFirstCategory(forceRefresh: languageChanged);
  }

  int? get firstCategoryId =>
      _categories.isNotEmpty ? _categoryId(_categories.first) : null;

  Future<void> selectFirstCategory({bool forceRefresh = false}) async {
    final categoryId = firstCategoryId;
    if (categoryId != null) {
      await selectCategory(categoryId, forceRefresh: forceRefresh);
    } else if (_currentItems.isEmpty) {
      await fetchList(forceRefresh: forceRefresh);
    }
  }

  Future<void> fetchCategories() async {
    categoriesLoading = true;
    notifyListeners();
    try {
      final res = await Api.get(
        ApiPaths.getBackgroundCategories,
        query: LanguageIdUtil.withLanguageId({}),
      );
      _categories
        ..clear()
        ..addAll(_parseCategories(res.data));
      _markLanguageLoaded();
      if (kDebugMode) {
        print(res.data);
        // debugPrint(
        //   '[BackgroundStore] getBackgroundCategories ok: ${_categories.length} items',
        // );
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[BackgroundStore] fetchCategories failed: $e');
      }
    } finally {
      categoriesLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectCategory(int categoryId, {bool forceRefresh = false}) async {
    final cacheKey = '$categoryId';
    final cached = _itemsByCategory[cacheKey];
    if (!forceRefresh &&
        !_isCustomTab &&
        _selectedCategoryId == categoryId &&
        _hasUsableCache(cached)) {
      _applyCachedList(cacheKey);
      return;
    }

    _selectedCategoryId = categoryId;
    _isCustomTab = false;

    if (!forceRefresh && _applyCachedList(cacheKey)) return;

    notifyListeners();
    await fetchList(categoryId: categoryId, forceRefresh: forceRefresh);
  }

  Future<void> selectCustomTab({bool forceRefresh = false}) async {
    final cached = _itemsByCategory[customTabKey];
    if (!forceRefresh && _isCustomTab && _hasUsableCache(cached)) {
      _applyCachedList(customTabKey);
      return;
    }

    _selectedCategoryId = null;
    _isCustomTab = true;

    if (!forceRefresh && _applyCachedList(customTabKey)) {
      return;
    }

    notifyListeners();
    await fetchList(customOnly: true, forceRefresh: forceRefresh);
  }

  static bool _hasUsableCache(List<Map<String, dynamic>>? cached) =>
      cached != null && cached.isNotEmpty;

  bool _applyCachedList(String cacheKey) {
    final cached = _itemsByCategory[cacheKey];
    if (!_hasUsableCache(cached)) return false;
    _currentItems = List<Map<String, dynamic>>.from(cached!);
    notifyListeners();
    return true;
  }

  Future<void> fetchList({
    int? categoryId,
    bool customOnly = false,
    bool forceRefresh = false,
  }) async {
    final query = LanguageIdUtil.withLanguageId(<String, dynamic>{});

    late final String cacheKey;
    if (customOnly) {
      final myUserId = AuthSessionStore.instance.userId;
      if (myUserId == null) {
        if (kDebugMode) {
          print('[BackgroundStore] selectCustomTab: user not logged in');
        }
        _currentItems = [];
        _itemsByCategory[customTabKey] = [];
        notifyListeners();
        return;
      }
      query['my_user_id'] = myUserId;
      cacheKey = customTabKey;
    } else {
      if (categoryId != null) query['category_id'] = categoryId;
      cacheKey = categoryId?.toString() ?? 'all';
    }

    if (!forceRefresh && _applyCachedList(cacheKey)) return;

    final seq = ++_listRequestSeq;
    listLoading = true;
    notifyListeners();
    try {
      final res = await Api.get(ApiPaths.getBackgrounds, query: query);
      if (seq != _listRequestSeq) return;

      final parsed = _parseList(res.data, categoryId: categoryId);
      if (parsed.isNotEmpty) {
        _itemsByCategory[cacheKey] = parsed;
      } else {
        _itemsByCategory.remove(cacheKey);
      }
      _currentItems = parsed;
      _mergeItems(parsed);
    } on ApiException catch (e) {
      if (seq != _listRequestSeq) return;
      if (kDebugMode) {
        debugPrint('[BackgroundStore] fetchList failed: $e');
      }
      _currentItems = [];
      notifyListeners();
    } finally {
      if (seq == _listRequestSeq) {
        listLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Map<String, dynamic>?> uploadCustomBackground({
    required String localPath,
    String? name,
  }) async {
    final imageUrl = await PetImageService.upload(localPath);
    final data = <String, dynamic>{
      'image': imageUrl,
      if (name != null && name.isNotEmpty) 'name': name,
    };
    final userId = AuthSessionStore.instance.userId;
    if (userId != null) data['user_id'] = userId;

    ApiResponse<dynamic> res;
    try {
      res = await Api.post(ApiPaths.uploadBackground, data: data);
      if (kDebugMode) {
        debugPrint('[BackgroundStore] uploadBackground res=$res');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[BackgroundStore] uploadBackground failed: $e');
      }
      rethrow;
    }

    final created = _normalizeCreatedItem(res.data, fallbackImage: imageUrl);
    if (created == null) return null;

    _mergeItems([created]);
    final cacheKey =
        _isCustomTab ? customTabKey : _selectedCategoryId?.toString() ?? 'all';
    final bucket = List<Map<String, dynamic>>.from(
      _itemsByCategory[cacheKey] ?? _currentItems,
    );
    if (!bucket.any((item) => '${item['id']}' == '${created['id']}')) {
      bucket.insert(0, created);
    }
    _itemsByCategory[cacheKey] = bucket;
    _currentItems = bucket;
    notifyListeners();
    return findById('${created['id']}') ?? created;
  }

  Future<bool> updateBackground({
    required int id,
    String? name,
    String? image,
    int? categoryId,
  }) async {
    final data = <String, dynamic>{'id': id};
    if (name != null && name.isNotEmpty) data['name'] = name;
    if (image != null && image.isNotEmpty) data['image'] = image;
    if (categoryId != null) data['category_id'] = categoryId;

    try {
      final res = await Api.post(ApiPaths.updateBackground, data: data);
      if (kDebugMode) {
        debugPrint('[BackgroundStore] updateBackground res=$res');
      }
      _patchLocalItem(id, name: name, image: image, categoryId: categoryId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[BackgroundStore] updateBackground failed: $e');
      }
      return false;
    }
  }

  Future<bool> deleteBackground(int id) async {
    try {
      final res = await Api.post(
        ApiPaths.deleteBackground,
        data: {'id': id},
      );
      if (kDebugMode) {
        debugPrint('[BackgroundStore] deleteBackground res=$res');
      }
      _removeLocalItem(id);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[BackgroundStore] deleteBackground failed: $e');
      }
      return false;
    }
  }

  void _mergeItems(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final id = '${item['id']}';
      if (id.isEmpty) continue;
      _itemById[id] = item;
    }
  }

  void _patchLocalItem(
    int id, {
    String? name,
    String? image,
    int? categoryId,
  }) {
    final key = '$id';
    void patchMap(Map<String, dynamic> item) {
      if (name != null && name.isNotEmpty) item['name'] = name;
      if (image != null && image.isNotEmpty) item['image'] = image;
      if (categoryId != null) item['category_id'] = categoryId;
    }

    final cached = _itemById[key];
    if (cached != null) patchMap(cached);

    for (final bucket in _itemsByCategory.values) {
      for (final item in bucket) {
        if ('${item['id']}' == key) patchMap(item);
      }
    }
    for (final item in _currentItems) {
      if ('${item['id']}' == key) patchMap(item);
    }
  }

  void _removeLocalItem(int id) {
    final key = '$id';
    _itemById.remove(key);
    for (final entry in _itemsByCategory.entries.toList()) {
      _itemsByCategory[entry.key] = entry.value
          .where((item) => '${item['id']}' != key)
          .toList();
    }
    _currentItems =
        _currentItems.where((item) => '${item['id']}' != key).toList();
  }

  static Map<String, dynamic>? _normalizeCreatedItem(
    dynamic data, {
    required String fallbackImage,
  }) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['id'] == null) return null;
    if (map['image'] == null || '${map['image']}'.isEmpty) {
      map['image'] = fallbackImage;
    }
    map['user_id'] ??= AuthSessionStore.instance.userId ?? 0;
    map['is_show'] ??= 1;
    return map;
  }

  static int? _categoryId(Map<String, dynamic> category) {
    final id = category['id'] ?? category['category_id'];
    return id is int ? id : int.tryParse('$id');
  }

  static bool _isVisible(dynamic show) {
    if (show == null) return true;
    if (show == false) return false;
    return show != 0 && show != '0';
  }

  static List<Map<String, dynamic>> _parseList(
    dynamic data, {
    int? categoryId,
  }) {
    final list = _extractBackgroundNodes(data);
    if (list.isEmpty) return [];

    final result = <Map<String, dynamic>>[];
    for (final raw in list.whereType<Map>()) {
      _collectBackgrounds(
        Map<String, dynamic>.from(raw),
        result,
        categoryId: categoryId,
      );
    }
    return result;
  }

  static List<dynamic> _extractBackgroundNodes(dynamic data) {
    if (data is List) return data;
    if (data is! Map) return [];

    final list = data['list'] ?? data['backgrounds'] ?? data['items'];
    if (list is List) return list;
    return [];
  }

  static void _collectBackgrounds(
    Map<String, dynamic> map,
    List<Map<String, dynamic>> result, {
    int? categoryId,
  }) {
    final children = map['backgrounds'] ??
        map['items'] ??
        map['children'] ??
        map['background_list'] ??
        map['list'];

    if (children is List) {
      if (children.isEmpty) return;
      final groupCategoryId = map['category_id'] ?? map['id'];
      final categoryName = map['name'] ?? map['category_name'];
      for (final child in children.whereType<Map>()) {
        final item = Map<String, dynamic>.from(child);
        if (groupCategoryId != null) item['category_id'] = groupCategoryId;
        if (categoryName != null) item['category_name'] = categoryName;
        _addBackgroundItem(item, result, categoryId: categoryId);
      }
      return;
    }

    if (_looksLikeBackgroundItem(map)) {
      _addBackgroundItem(map, result, categoryId: categoryId);
    }
  }

  static bool _looksLikeBackgroundItem(Map<String, dynamic> map) {
    final image = map['image'] ?? map['img'] ?? map['url'];
    return image != null && '$image'.isNotEmpty;
  }

  static void _addBackgroundItem(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> result, {
    int? categoryId,
  }) {
    if (!_isVisible(item['is_show'])) return;

    if (categoryId != null) {
      final itemCategoryId = item['category_id'] ?? item['categoryId'];
      final parsed = itemCategoryId is int
          ? itemCategoryId
          : int.tryParse('$itemCategoryId');
      if (parsed != null && parsed != categoryId) return;
    }

    result.add(item);
  }

  static List<Map<String, dynamic>> _parseCategories(dynamic data) {
    final list = data is Map ? data['list'] : data;
    if (list is! List) return [];

    final result = <Map<String, dynamic>>[];
    for (final raw in list.whereType<Map>()) {
      final map = Map<String, dynamic>.from(raw);
      if (!_isVisible(map['is_show'])) continue;
      result.add(map);
    }
    result.sort((a, b) {
      final sortA = int.tryParse('${a['sort']}') ?? 0;
      final sortB = int.tryParse('${b['sort']}') ?? 0;
      return sortA.compareTo(sortB);
    });
    return result;
  }
}
