import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../data/pet_avatar_store.dart';
import '../services/pet_image_service.dart';
import '../services/widget_sync_trigger.dart';
import '../utils/pet_display_image.dart';

/// 启动接口数据缓存
class AppCacheStore extends ChangeNotifier {
  AppCacheStore._();

  static final AppCacheStore instance = AppCacheStore._();
  static const _keyPetId = 'pet_id';
  static const _keyCachedConfig = 'cached_get_config';

  SharedPreferences? _prefs;
  dynamic _config;
  dynamic _info;
  List<dynamic> navList = [];
  List<dynamic> languageList = [];
  List<dynamic> navLangList = [];
  List<dynamic> petList = [];
  int? petId;
  dynamic petInfo;

  bool configLoading = false;
  bool configLoaded = false;

  dynamic get config => _config;
  dynamic get info => _info;

  /// getPetProfileInfo 的 info，兼容 Map / List
  Map? get petProfile {
    final raw = petInfo;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  /// 添加纪念日页右上角装饰图
  String? get petProfileOne => _petProfileUrl('one');

  /// 背景/数字样式弹窗右上角装饰图
  String? get petProfileTwo => _petProfileUrl('two');

  String? _petProfileUrl(String key) {
    final value = petProfile?[key]?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// 根据 created_at 计算已陪伴天数
  int get accompanyDays {
    final created = _parseCreatedAt(petProfile?['created_at']);
    if (created == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(created.year, created.month, created.day);
    return today.difference(start).inDays.clamp(0, 999999);
  }

  static DateTime? _parseCreatedAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      return raw > 9999999999
          ? DateTime.fromMillisecondsSinceEpoch(raw)
          : DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    if (raw is num) {
      final v = raw.toInt();
      return v > 9999999999
          ? DateTime.fromMillisecondsSinceEpoch(v)
          : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    return DateTime.tryParse(raw.toString());
  }

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    petId = _prefs!.getInt(_keyPetId);
    await PetAvatarStore.loadFromPrefs();
    _loadLocalPetList();
    final cached = _prefs!.getString(_keyCachedConfig);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        await setConfig(decoded, persist: false, markLoaded: false);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AppCacheStore] cached config parse failed: $e');
        }
      }
    }
  }

  /// 本地默认猫/狗，接口 getConfig 返回后覆盖
  void _loadLocalPetList() {
    petList = _defaultPetList();
    notifyListeners();
  }

  static List<Map<String, dynamic>> _defaultPetList() => [
        {
          'type': 'cat',
          'pet_type': 2,
          'image': '',
          'name': '',
          'describe': '',
        },
        {
          'type': 'dog',
          'pet_type': 1,
          'image': '',
          'name': '',
          'describe': '',
        },
      ];

  Future<void>? _configFuture;

  /// 拉取 getConfig，选宠页与启动流程共用；[force] 为 true 时忽略已加载状态重新请求
  Future<void> fetchConfig({bool force = false}) {
    if (force) {
      _configFuture = null;
      if (!configLoading) configLoaded = false;
    }
    if (configLoaded && !force) return Future.value();
    return _configFuture ??= _fetchConfig();
  }

  Future<void> _fetchConfig() async {
    configLoading = true;
    notifyListeners();
    try {
      final res = await Api.get(ApiPaths.getConfig);
      await setConfig(res.data);
      if (kDebugMode) {
        debugPrint('[AppCacheStore] getConfig ok');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[AppCacheStore] getConfig failed: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppCacheStore] getConfig error: $e');
      }
    } finally {
      configLoading = false;
      // 网络失败时仍可使用本地缓存
      if (!configLoaded && _config != null) {
        configLoaded = true;
      }
      notifyListeners();
      _configFuture = null;
    }
  }

  Future<void> setPetId(int? id) async {
    _prefs ??= await SharedPreferences.getInstance();
    petId = id;
    if (id == null) petInfo = null;
    if (id != null) {
      await _prefs!.setInt(_keyPetId, id);
    } else {
      await _prefs!.remove(_keyPetId);
    }
    notifyListeners();
  }

  void setPetInfo(dynamic data) {
    final next = _extractPetProfileMap(data);
    if (next == null) return;

    final prev = petProfile;
    final prevId = _parsePetId(prev?['id'] ?? prev?['pet_id']);
    final nextId = _parsePetId(next['id'] ?? next['pet_id']);
    // 换宠 / 绑定后 petId 变化时，禁止把上一只宠（如默认猫狗）的 image 合并过来
    final samePet = prevId != null && nextId != null && prevId == nextId;

    if (prev != null && samePet) {
      for (final entry in prev.entries) {
        final incoming = next[entry.key];
        final empty = incoming == null ||
            (incoming is String && incoming.trim().isEmpty);
        if (empty && entry.value != null) {
          final keep = entry.value;
          if (keep is String && keep.trim().isNotEmpty) {
            next[entry.key] = keep;
          } else if (keep is! String) {
            next[entry.key] = keep;
          }
        }
      }
    }

    petInfo = next;
    repairLocalPetImage();
    notifyListeners();
  }

  /// AI 宠：未开启云同步时，用本地 AI 图补全档案（云同步以手机号账号档案为准）
  void repairLocalPetImage() {
    if (AuthSessionStore.instance.cloudSync) return;

    final map = petProfile;
    if (map == null) return;

    final custom = PetAvatarStore.urlForPetSync(petId)?.trim();
    if (custom == null || custom.isEmpty) return;

    final image = map['image']?.toString().trim() ?? '';
    if (image == custom) return;

    final patched = Map<String, dynamic>.from(map);
    patched['image'] = custom;
    if (!PetDisplayImage.isCustomPet(map)) {
      patched['type'] = 'custom';
      patched['pet_type'] = 3;
    }
    petInfo = patched;
  }

  /// 写入档案，并用返回的 id 覆盖本地 petId
  Future<void> applyPetProfileResponse(dynamic data) async {
    setPetInfo(data);
    repairLocalPetImage();
    final id = _parsePetId(petProfile?['id'] ?? petProfile?['pet_id']);
    if (id != null) {
      await setPetId(id);
      final custom = PetAvatarStore.urlForPetSync(id)?.trim();
      final profileImage = petProfile?['image']?.toString().trim();
      final cloudSync = AuthSessionStore.instance.cloudSync;
      // 绑定手机号后：以云端档案 image 为准，供首页与桌面组件同步
      final avatarUrl = cloudSync
          ? ((profileImage != null && profileImage.isNotEmpty)
              ? profileImage
              : custom)
          : ((custom != null && custom.isNotEmpty) ? custom : profileImage);
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        await PetAvatarStore.setAvatar(
          url: avatarUrl,
          description: PetAvatarStore.customAvatarDescription,
          petId: id,
          scheduleSync: false,
        );
        repairLocalPetImage();
      }
    }
    scheduleWidgetSync();
  }

  Map<String, dynamic>? _extractPetProfileMap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final info = map['info'];
    if (info is Map) {
      return Map<String, dynamic>.from(info);
    }
    if (info is List) {
      return _pickPetProfileFromList(info, cloudSync: AuthSessionStore.instance.cloudSync);
    }
    // 本地直接写入（取名页等）
    if (map.containsKey('nickname') ||
        map.containsKey('image') ||
        map.containsKey('pet_type') ||
        map.containsKey('type')) {
      return map;
    }
    return null;
  }

  /// 多宠列表选取：云同步走手机号账号档案；未绑定时优先本地 petId / AI 图
  Map<String, dynamic>? _pickPetProfileFromList(
    List info, {
    required bool cloudSync,
  }) {
    final items = info
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (items.isEmpty) return null;

    if (cloudSync) {
      return _pickCloudPetProfileFromList(items);
    }
    return _pickLocalPetProfileFromList(items);
  }

  /// 绑定手机号后：以 getPetProfileInfo 云端列表为准
  Map<String, dynamic> _pickCloudPetProfileFromList(
    List<Map<String, dynamic>> items,
  ) {
    final currentId = petId;
    if (currentId != null) {
      for (final item in items) {
        final id = _parsePetId(item['id'] ?? item['pet_id']);
        if (id == currentId) return item;
      }
    }

    for (final item in items) {
      if (PetDisplayImage.isCustomPet(item)) return item;
    }
    for (final item in items) {
      if (item['is_default'] == 1 || item['is_default'] == true) return item;
    }
    return items.first;
  }

  /// 未云同步：优先本地 petId / AI 图，避免小组件误用默认猫狗
  Map<String, dynamic>? _pickLocalPetProfileFromList(
    List<Map<String, dynamic>> items,
  ) {
    final currentId = petId;
    if (currentId != null) {
      for (final item in items) {
        final id = _parsePetId(item['id'] ?? item['pet_id']);
        if (id == currentId) return item;
      }
    }

    final storedCustom = PetAvatarStore.customAvatarUrl?.trim();
    if (storedCustom != null && storedCustom.isNotEmpty) {
      for (final item in items) {
        if (_imageMatches(item['image'], storedCustom)) return item;
      }
      for (final item in items) {
        if (PetDisplayImage.isCustomPet(item)) return item;
      }
    }

    for (final item in items) {
      if (item['is_default'] == 1 || item['is_default'] == true) return item;
    }
    return items.first;
  }

  static bool _imageMatches(dynamic raw, String target) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return false;
    final resolvedValue = PetImageService.resolveUrl(value);
    final resolvedTarget = PetImageService.resolveUrl(target);
    return value == target ||
        value == resolvedTarget ||
        resolvedValue == target ||
        resolvedValue == resolvedTarget;
  }

  static int? _parsePetId(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw > 0 ? raw : null;
    return int.tryParse('$raw');
  }

  Future<void> setConfig(
    dynamic data, {
    bool persist = true,
    bool markLoaded = true,
  }) async {
    final parsed = _extractConfig(data);
    if (parsed == null) {
      if (kDebugMode) {
        debugPrint('[AppCacheStore] setConfig: unrecognized shape $data');
      }
      return;
    }
    _config = parsed;
    final list = _buildPetList(_config);
    if (list.isNotEmpty) {
      petList = list;
      if (markLoaded) configLoaded = true;
      if (persist && data != null) {
        _prefs ??= await SharedPreferences.getInstance();
        try {
          await _prefs!.setString(_keyCachedConfig, jsonEncode(data));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AppCacheStore] cache config failed: $e');
          }
        }
      }
    }
    notifyListeners();
  }

  static Map<String, dynamic>? _extractConfig(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['config'] is Map) {
      return Map<String, dynamic>.from(map['config'] as Map);
    }
    if (map.containsKey('defaultp_cat') || map.containsKey('defaultp_dog')) {
      return map;
    }
    return null;
  }

  void setAppInfo(dynamic data) {
    _info = data is Map ? data['info'] : null;
  }

  void setNavList(dynamic data) {
    navList = data is List ? data : [];
    notifyListeners();
  }

  void setLanguage(dynamic data) {
    if (data is Map) {
      languageList = data['list'] is List ? data['list'] : [];
      navLangList = data['nav_lang'] is List ? data['nav_lang'] : [];
    } else {
      languageList = [];
      navLangList = [];
    }
    notifyListeners();
  }

  void clear() {
    _config = null;
    _info = null;
    navList = [];
    languageList = [];
    navLangList = [];
    petList = [];
    petId = null;
    petInfo = null;
    configLoading = false;
    configLoaded = false;
    _configFuture = null;
    _prefs?.remove(_keyPetId);
    _prefs?.remove(_keyCachedConfig);
    notifyListeners();
  }

  List<dynamic> _buildPetList(dynamic config) {
    if (config is! Map) return [];

    var texts = config['defaultp_text'];
    if (texts is String) {
      try {
        texts = jsonDecode(texts);
      } catch (_) {
        texts = [];
      }
    }
    if (texts is! List) texts = [];

    return [
      _petItem('cat', config['defaultp_cat'], texts, 0),
      _petItem('dog', config['defaultp_dog'], texts, 1),
    ];
  }

  Map<String, dynamic> _petItem(
    String type,
    dynamic image,
    List texts,
    int index,
  ) {
    final t = index < texts.length && texts[index] is Map
        ? Map<String, dynamic>.from(texts[index] as Map)
        : <String, dynamic>{};
    return {
      'type': type,
      'pet_type': type == 'cat' ? 2 : 1,
      'image': _normalizeImageUrl(image),
      'name': t['value']?.toString() ?? '',
      'describe': t['describe']?.toString() ?? '',
    };
  }

  static String _normalizeImageUrl(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return '';
    return PetImageService.resolveUrl(value);
  }
}
