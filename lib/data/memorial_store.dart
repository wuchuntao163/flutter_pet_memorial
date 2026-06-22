import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../l10n/tr.dart';
import '../models/memorial_day.dart';
import '../services/reminder_service.dart';
import '../services/platform_pet_sync.dart';
import '../utils/language_id_util.dart';
import '../utils/type_title_util.dart';
import 'app_cache_store.dart';

/// 纪念日数据（接口 getAnniversaryList / addAnniversary）
class MemorialStore extends ChangeNotifier {
  MemorialStore._();

  static final MemorialStore instance = MemorialStore._();

  final List<MemorialDay> _items = [];
  List<Map<String, dynamic>> typeList = [];
  List<Map<String, dynamic>> typeIconList = [];
  bool isLoadingList = false;
  bool listLoaded = false;
  bool typeIconsLoading = false;
  Future<void>? _fetchListFuture;
  Future<void>? _ensureMemorialsFuture;
  int? _loadedPetId;

  List<MemorialDay> get items {
    final sorted = List<MemorialDay>.from(_items);
    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return a.date.compareTo(b.date);
    });
    return List.unmodifiable(sorted);
  }

  void markListPending() {
    isLoadingList = true;
    listLoaded = false;
    notifyListeners();
  }

  Future<void> fetchList({bool silent = false}) {
    if (_fetchListFuture != null) return _fetchListFuture!;
    final future = _fetchList(silent: silent);
    _fetchListFuture = future;
    return future.whenComplete(() => _fetchListFuture = null);
  }

  /// 拉取纪念日类型 + 列表；同一宠物只请求一次，并发调用会合并。
  /// [force] 为 true 时强制刷新（如绑定手机号后云同步）。
  Future<void> ensureMemorialsLoaded({bool force = false}) {
    final petId = AppCacheStore.instance.petId;
    if (petId == null) {
      _loadedPetId = null;
      return Future.value();
    }

    if (force) {
      _loadedPetId = null;
    } else if (_loadedPetId == petId && listLoaded) {
      return Future.value();
    }

    if (_ensureMemorialsFuture != null) {
      return _ensureMemorialsFuture!;
    }

    final future = _ensureMemorialsForPet(petId);
    _ensureMemorialsFuture = future;
    return future.whenComplete(() {
      if (identical(_ensureMemorialsFuture, future)) {
        _ensureMemorialsFuture = null;
      }
    });
  }

  Future<void> _ensureMemorialsForPet(int petId) async {
    if (AppCacheStore.instance.petId != petId) return;
    await fetchTypes();
    if (AppCacheStore.instance.petId != petId) return;
    await fetchList();
    if (AppCacheStore.instance.petId == petId) {
      _loadedPetId = petId;
    }
  }

  Future<void> _fetchList({bool silent = false}) async {
    final petId = AppCacheStore.instance.petId;
    if (petId == null) {
      _items.clear();
      isLoadingList = false;
      listLoaded = true;
      notifyListeners();
      return;
    }
    if (!silent) {
      isLoadingList = true;
      notifyListeners();
    }
    try {
      final res = await Api.get(
        ApiPaths.getAnniversaryList,
        query: {'pet_id': petId},
      );
      final data = res.data;
      final list = data is Map ? data['list'] : data;
      final previous = {for (final d in _items) d.id: d};
      final parsed = <MemorialDay>[];
      for (final raw in (list is List ? list : [])) {
        if (raw is! Map) continue;
        if (raw['is_show'] == 0) continue;
        try {
          parsed.add(
            MemorialDay.fromApi(
              Map<String, dynamic>.from(raw),
              types: typeList,
            ),
          );
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('[MemorialStore] skip invalid item: $e\n$st');
          }
        }
      }
      if (kDebugMode) {
        debugPrint('[MemorialStore] getAnniversaryList parsed: ${parsed.length}');
      }
      _items
        ..clear()
        ..addAll(parsed);
      for (var i = 0; i < _items.length; i++) {
        final old = previous[_items[i].id];
        if (old != null) {
          _items[i] = _mergeLocalOnly(_items[i], old);
        }
      }
      if (kDebugMode) {
        // debugPrint('[MemorialStore] getAnniversaryList ok: $data');
      }
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[MemorialStore] fetchList failed: $e');
    } finally {
      isLoadingList = false;
      listLoaded = true;
      notifyListeners();
      await _syncReminders();
      await PlatformPetSync.afterDataUpdate();
    }
  }

  Future<void> _syncReminders() async {
    try {
      await ReminderService.instance.syncMemorials(_items);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MemorialStore] syncReminders failed: $e');
      }
    }
  }

  MemorialDay _mergeLocalOnly(MemorialDay api, MemorialDay local) {
    return api.copyWith(
      fontStyleId: local.fontStyleId,
      backgroundStyleId: local.backgroundStyleId,
      backgroundTab: local.backgroundTab,
      dayCountDisplayMode: local.dayCountDisplayMode,
      isLunarLeapMonth: local.isLunarLeapMonth,
    );
  }

  Map<String, dynamic>? typeById(int? typeId) {
    if (typeId == null) return null;
    for (final t in typeList) {
      if (_asInt(t['id']) == typeId) return t;
    }
    return null;
  }

  static String localizedTypeTitle(Map<String, dynamic> type) =>
      TypeTitleUtil.resolve(type);

  String typeTitleFor(int? typeId) {
    final type = typeById(typeId);
    if (type == null) return '';
    return localizedTypeTitle(type);
  }

  static bool isCustomType(Map<String, dynamic> type) {
    if (isOtherType(type)) return false;
    return type['is_system'] == 0;
  }

  static bool isOtherType(Map<String, dynamic> type) {
    final title = type['title']?.toString().trim() ?? '';
    // 接口固定文案，不参与多语言
    return title == '自定义';
  }

  Map<String, dynamic>? get otherType {
    for (final type in typeList) {
      if (isOtherType(type)) return type;
    }
    return null;
  }

  /// 添加纪念日类型选择：系统类型 → 用户自定义类型 → 「自定义」入口
  List<Map<String, dynamic>> get pickerTypeList {
    final system = <Map<String, dynamic>>[];
    final custom = <Map<String, dynamic>>[];
    Map<String, dynamic>? other;
    for (final type in typeList) {
      if (isOtherType(type)) {
        other = type;
      } else if (isCustomType(type)) {
        custom.add(type);
      } else {
        system.add(type);
      }
    }
    custom.sort((a, b) {
      final idA = _asInt(a['id']) ?? 0;
      final idB = _asInt(b['id']) ?? 0;
      return idA.compareTo(idB);
    });
    return [
      ...system,
      ...custom,
      ?other,
    ];
  }

  MemorialDay _applyTypeInfo(MemorialDay day) {
    final typeMap = typeById(day.typeId);
    if (typeMap == null) return day;

    final title = localizedTypeTitle(typeMap);
    final bg = typeMap['bg_color']?.toString();
    return day.copyWith(
      customTypeName: title.isNotEmpty ? title : day.customTypeName,
      typeBgColorHex: bg ?? day.typeBgColorHex,
      type: title.isNotEmpty
          ? MemorialDay.typeFromTitle(title)
          : day.type,
    );
  }

  Future<void> fetchTypes() async {
    final petId = AppCacheStore.instance.petId;
    if (petId == null) {
      typeList = [];
      notifyListeners();
      return;
    }
    try {
      final res = await Api.get(
        ApiPaths.getTypes,
        query: LanguageIdUtil.apply({'pet_id': petId}),
      );
      final data = res.data;
      final list = data is Map ? data['list'] : data;
      typeList = (list is List ? list : [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['is_show'] != 0)
          .toList();
      if (_items.isNotEmpty) {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _applyTypeInfo(_items[i]);
        }
      }
      notifyListeners();
      if (kDebugMode) {
        
      }
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[MemorialStore] fetchTypes failed: $e');
    }
  }

  Future<void> fetchTypeIcons() async {
    if (typeIconsLoading) return;
    typeIconsLoading = true;
    notifyListeners();
    try {
      final res = await Api.get(
        ApiPaths.getAnniversaryTypeIcons,
        query: LanguageIdUtil.apply({}),
      );
      final data = res.data;
      final list = data is Map ? data['list'] : data;
      final icons = (list is List ? list : [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['is_show'] != 0)
          .toList();
      icons.sort((a, b) {
        final sortA = _asInt(a['sort']) ?? 0;
        final sortB = _asInt(b['sort']) ?? 0;
        if (sortA != sortB) return sortA.compareTo(sortB);
        return (_asInt(a['id']) ?? 0).compareTo(_asInt(b['id']) ?? 0);
      });
      typeIconList = icons;
      notifyListeners();
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[MemorialStore] fetchTypeIcons failed: $e');
    } finally {
      typeIconsLoading = false;
      notifyListeners();
    }
  }

  Future<({String msg, int typeId})> addCustomType({
    required String title,
    String bgColor = '#FF6B6B',
    String? icon,
  }) async {
    final petId = AppCacheStore.instance.petId;
    if (petId == null) {
      throw ApiException.business(0, tr('memorial.create_pet_first'));
    }

    final res = await Api.post(
      ApiPaths.addCustomType,
      data: {
        'pet_id': petId,
        'title': title,
        'bg_color': bgColor,
        if (icon != null && icon.trim().isNotEmpty) 'icon': icon.trim(),
      },
    );
    final data = res.data;
    final typeId = _asInt(data is Map ? data['type_id'] : null) ?? 0;
    await fetchTypes();
    return (
      msg: res.msg.isNotEmpty ? res.msg : tr('memorial.add_success'),
      typeId: typeId,
    );
  }

  Future<String> editCustomType({
    required int typeId,
    required String title,
    String? bgColor,
    String? icon,
  }) async {
    final petId = AppCacheStore.instance.petId;
    if (petId == null) {
      throw ApiException.business(0, tr('memorial.create_pet_first'));
    }

    final data = <String, dynamic>{
      'type_id': typeId,
      'pet_id': petId,
      'title': title,
      'bg_color': ?bgColor,
      if (icon != null && icon.trim().isNotEmpty) 'icon': icon.trim(),
    };
    if (kDebugMode) {
      // debugPrint('[MemorialStore] editCustomType req: $data');
    }
    try {
      final res = await Api.post(
        ApiPaths.editCustomType,
        data: data,
      );
      if (kDebugMode) {
        // debugPrint(
        //   '[MemorialStore] editCustomType ok: code=${res.code} msg=${res.msg} data=${res.data}',
        // );
      }
      await fetchTypes();
      return res.msg.isNotEmpty ? res.msg : tr('memorial.edit_success');
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[MemorialStore] editCustomType failed: code=${e.code} msg=${e.message} req=$data',
        );
      }
      rethrow;
    }
  }

  Future<String> deleteCustomType(int typeId) async {
    final petId = AppCacheStore.instance.petId;
    if (petId == null) {
      throw ApiException.business(0, tr('memorial.create_pet_first'));
    }

    final data = {
      'type_id': typeId,
      'pet_id': petId,
    };
    if (kDebugMode) {
      // debugPrint('[MemorialStore] deleteCustomType req: $data');
    }
    try {
      final res = await Api.post(
        ApiPaths.deleteCustomType,
        data: data,
      );
      if (kDebugMode) {
        // debugPrint(
        //   '[MemorialStore] deleteCustomType ok: code=${res.code} msg=${res.msg} data=${res.data}',
        // );
      }
      await fetchTypes();
      return res.msg.isNotEmpty ? res.msg : tr('memorial.delete_success');
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[MemorialStore] deleteCustomType failed: code=${e.code} msg=${e.message} req=$data',
        );
      }
      rethrow;
    }
  }

  Future<String> addAnniversary({
    required String name,
    required DateTime date,
    int typeId = 0,
    int dateType = 1,
    int repeatFrequency = 1,
    int isTop = 0,
    int isRemind = 0,
    bool isLunarLeapMonth = false,
  }) async {
    final petId = AppCacheStore.instance.petId;
    if (petId == null) {
      throw ApiException.business(0, tr('memorial.create_pet_first'));
    }

    final res = await Api.post(
      ApiPaths.addAnniversary,
      data: {
        'pet_id': petId,
        'name': name,
        'date': _formatDate(date),
        'type_id': typeId,
        'date_type': dateType,
        'repeat_frequency': repeatFrequency,
        'is_top': isTop,
        'is_remind': isRemind,
      },
    );
    await fetchList(silent: true);
    if (dateType == 2) {
      final newId = res.data is Map ? '${(res.data as Map)['id']}' : null;
      if (newId != null && newId != 'null') {
        _patchLunarLeap(newId, isLunarLeapMonth);
        await _syncReminders();
      }
    }
    return res.msg.isNotEmpty ? res.msg : tr('memorial.add_success');
  }

  Future<String> editAnniversary({
    required String anniversaryId,
    required String name,
    required DateTime date,
    required int typeId,
    required int dateType,
    required int repeatFrequency,
    required int isTop,
    required int isRemind,
    bool isLunarLeapMonth = false,
  }) async {
    final petId = AppCacheStore.instance.petId;
    final data = {
      'anniversary_id': _asInt(anniversaryId) ?? anniversaryId,
      'pet_id': petId,
      'name': name,
      'date': _formatDate(date),
      'type_id': typeId,
      'date_type': dateType,
      'repeat_frequency': repeatFrequency,
      'is_top': isTop,
      'is_remind': isRemind,
    };
    final res = await Api.post(
      ApiPaths.editAnniversary,
      data: data,
    );
    if (kDebugMode) {
      // debugPrint('[MemorialStore] editAnniversary ok: code=${res.code} msg=${res.msg} data=${res.data}');
    }
    await fetchList(silent: true);
    if (dateType == 2) {
      _patchLunarLeap(anniversaryId, isLunarLeapMonth);
      await _syncReminders();
    }
    return res.msg.isNotEmpty ? res.msg : tr('memorial.edit_success');
  }

  void _patchLunarLeap(String id, bool isLunarLeapMonth) {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(isLunarLeapMonth: isLunarLeapMonth);
    notifyListeners();
  }

  Future<String> deleteAnniversary(
    String anniversaryId, {
    bool updateLocal = true,
  }) async {
    final res = await Api.post(
      ApiPaths.deleteAnniversary,
      data: {
        'anniversary_id': _asInt(anniversaryId) ?? anniversaryId,
      },
    );
    try {
      await ReminderService.instance.cancelMemorial(anniversaryId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MemorialStore] cancelMemorial failed: $e');
      }
    }
    if (updateLocal) {
      await applyDeleteLocally(anniversaryId);
    }
    return res.msg.isNotEmpty ? res.msg : tr('memorial.delete_success');
  }

  Future<void> applyDeleteLocally(String anniversaryId) async {
    remove(anniversaryId);
    await fetchList(silent: true);
  }

  void update(MemorialDay day) {
    final index = _items.indexWhere((e) => e.id == day.id);
    if (index == -1) return;
    _items[index] = day;
    notifyListeners();
  }

  void remove(String id) {
    final normalized = id.trim();
    _items.removeWhere((e) => e.id.trim() == normalized);
    notifyListeners();
  }

  void clearAll() {
    _items.clear();
    typeList = [];
    isLoadingList = false;
    listLoaded = false;
    _loadedPetId = null;
    _ensureMemorialsFuture = null;
    notifyListeners();
  }

  MemorialDay? findById(String id) {
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v');
  }
}
