import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../data/pet_avatar_store.dart';
import '../services/pet_image_service.dart';

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
    if (prev != null) {
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
    notifyListeners();
  }

  /// 写入档案，并用返回的 id 覆盖本地 petId
  Future<void> applyPetProfileResponse(dynamic data) async {
    setPetInfo(data);
    final id = _parsePetId(petProfile?['id'] ?? petProfile?['pet_id']);
    if (id != null) {
      await setPetId(id);
    }
  }

  static Map<String, dynamic>? _extractPetProfileMap(dynamic data) {
    if (data is! Map) return null;
    final info = data['info'];
    if (info is Map) {
      return Map<String, dynamic>.from(info);
    }
    if (info is List) {
      for (final item in info) {
        if (item is Map &&
            (item['is_default'] == 1 || item['is_default'] == true)) {
          return Map<String, dynamic>.from(item);
        }
      }
      if (info.isNotEmpty && info.first is Map) {
        return Map<String, dynamic>.from(info.first as Map);
      }
    }
    return null;
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
