import 'dart:async';
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
  static const _keyCachedPetProfile = 'cached_pet_profile';

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
    _restoreCachedPetProfile();
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
      await _prefs!.remove(_keyCachedPetProfile);
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
    _persistPetProfile();
    notifyListeners();
  }

  /// AI 宠：若档案 image 为空或与本地 AI 图不一致，用本地 AI 图补全
  void repairLocalPetImage() {
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
    final previousId = petId;

    setPetInfo(data);
    repairLocalPetImage();

    final id = _parsePetId(petProfile?['id'] ?? petProfile?['pet_id']) ??
        previousId;
    if (id != null) {
      await setPetId(id);
      final custom = PetAvatarStore.urlForPetSync(id)?.trim();
      final profileImage = petProfile?['image']?.toString().trim();
      final avatarUrl = (custom != null && custom.isNotEmpty)
          ? custom
          : profileImage;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        await PetAvatarStore.setAvatar(
          url: avatarUrl,
          description: PetAvatarStore.customAvatarDescription,
          petId: id,
          localPath: PetAvatarStore.localPathForPetSync(id) ??
              PetAvatarStore.localPathForPetSync(previousId),
          scheduleSync: false,
        );
        repairLocalPetImage();
      }
    }
    _persistPetProfile();
    scheduleWidgetSync();
  }

  Map<String, dynamic>? _extractPetProfileMap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final info = map['info'];
    if (info is Map) {
      return _resolveIncomingProfile(Map<String, dynamic>.from(info));
    }
    if (info is List) {
      return _pickPetProfileFromList(info);
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

  /// 绑定手机号后接口可能返回多宠列表，优先保留本地已建立的宠物档案
  Map<String, dynamic>? _pickPetProfileFromList(List info) {
    final items = info
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (items.isEmpty) return null;

    final local = _localEstablishedProfile();

    final currentId = petId ?? _parsePetId(local?['id'] ?? local?['pet_id']);
    if (currentId != null) {
      for (final item in items) {
        final id = _parsePetId(item['id'] ?? item['pet_id']);
        if (id == currentId) return item;
      }
    }

    if (local != null) {
      final localImage = local['image']?.toString().trim();
      if (localImage != null && localImage.isNotEmpty) {
        for (final item in items) {
          if (_imageMatches(item['image'], localImage)) return item;
        }
      }

      for (final item in items) {
        if (_profileIdentityMatches(item, local)) return item;
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

      // 云端列表无匹配项：保留绑定前的本地宠物档案，避免退回默认猫狗
      return Map<String, dynamic>.from(local);
    }

    for (final item in items) {
      if (item['is_default'] == 1 || item['is_default'] == true) return item;
    }
    return items.first;
  }

  /// 单条档案返回时，若与本地已建立档案不一致则保留本地
  Map<String, dynamic> _resolveIncomingProfile(Map<String, dynamic> incoming) {
    final local = _localEstablishedProfile();
    if (local == null) return incoming;

    final incomingId = _parsePetId(incoming['id'] ?? incoming['pet_id']);
    final localId = _parsePetId(local['id'] ?? local['pet_id']);
    if (incomingId != null && localId != null && incomingId == localId) {
      return incoming;
    }
    if (_imageMatches(incoming['image'], local['image'])) return incoming;
    if (_profileIdentityMatches(incoming, local)) return incoming;

    return Map<String, dynamic>.from(local);
  }

  Map<String, dynamic>? _localEstablishedProfile() {
    final current = petProfile;
    if (current != null && _hasEstablishedPet(current)) {
      return Map<String, dynamic>.from(current);
    }
    return _loadCachedPetProfile();
  }

  static bool _hasEstablishedPet(Map profile) {
    final image = profile['image']?.toString().trim();
    if (image != null && image.isNotEmpty) return true;
    final nickname = profile['nickname']?.toString().trim();
    return nickname != null && nickname.isNotEmpty;
  }

  static bool _profileIdentityMatches(Map a, Map b) {
    final nickA = a['nickname']?.toString().trim() ?? '';
    final nickB = b['nickname']?.toString().trim() ?? '';
    if (nickA.isEmpty || nickB.isEmpty || nickA != nickB) return false;
    final typeA = _normalizePetType(a);
    final typeB = _normalizePetType(b);
    return typeA != null && typeA == typeB;
  }

  static int? _normalizePetType(Map profile) {
    final raw = profile['pet_type'] ?? profile['type'];
    if (raw == null) return null;
    final value = raw.toString().trim().toLowerCase();
    if (value == 'cat' || value == '2') return 2;
    if (value == 'dog' || value == '1') return 1;
    if (value == 'custom' || value == '3') return 3;
    return int.tryParse(value);
  }

  void _restoreCachedPetProfile() {
    final cached = _loadCachedPetProfile();
    if (cached == null) return;
    petInfo = cached;
    repairLocalPetImage();
  }

  Map<String, dynamic>? _loadCachedPetProfile() {
    final raw = _prefs?.getString(_keyCachedPetProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final profile = Map<String, dynamic>.from(decoded);
        if (_hasEstablishedPet(profile)) return profile;
      }
    } catch (_) {}
    return null;
  }

  void _persistPetProfile() {
    final profile = petProfile;
    if (profile == null || !_hasEstablishedPet(profile)) return;

    final prefs = _prefs;
    if (prefs == null) return;

    final payload = Map<String, dynamic>.from(profile);
    if (petId != null) {
      payload['id'] ??= petId;
      payload['pet_id'] ??= petId;
    }
    unawaited(prefs.setString(_keyCachedPetProfile, jsonEncode(payload)));
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
    _prefs?.remove(_keyCachedPetProfile);
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
