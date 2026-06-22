import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/phone_util.dart';

/// 登录态：设备 UUID + loginByUuid 返回的 data
class AuthSessionStore extends ChangeNotifier {
  AuthSessionStore._();

  static final AuthSessionStore instance = AuthSessionStore._();

  static const _keyData = 'api_user_data';
  static const _keyUuid = 'device_uuid';
  static const _keyCloudSync = 'cloud_sync';

  SharedPreferences? _prefs;
  dynamic _data;
  bool _loaded = false;
  bool _cloudSync = false;

  dynamic get data => _data;

  String? get token =>
      _data is Map ? _data['token']?.toString() : null;

  int? get userId {
    if (_data is! Map) return null;
    final id = _data['id'];
    return id is int ? id : int.tryParse('$id');
  }

  String? get phone {
    if (_data is! Map) return null;
    final value = _data['phone']?.toString();
    if (value == null || value.isEmpty) return null;
    return isFullPhone(value) ? maskPhone(value) : value;
  }

  bool get hasPhone => phone != null;

  bool get cloudSync => _cloudSync;

  Future<void> setCloudSync(bool value) async {
    await init();
    _cloudSync = value;
    await _prefs?.setBool(_keyCloudSync, value);
    notifyListeners();
  }

  Future<void> updatePhone(String phone) async {
    if (_data is! Map) return;
    final map = Map<String, dynamic>.from(_data as Map);
    map['phone'] = maskPhone(phone);
    await saveData(map);
  }

  /// 绑定手机号成功后写入返回的 user_id（无则忽略）
  Future<void> applyBindPhoneResult({
    required String phone,
    dynamic data,
  }) async {
    await init();
    final map = _data is Map
        ? Map<String, dynamic>.from(_data as Map)
        : <String, dynamic>{};
    map['phone'] = maskPhone(phone);

    final userId = _parseUserId(data is Map ? data['user_id'] ?? data['id'] : null);
    if (userId != null) {
      map['id'] = userId;
    }

    await saveData(map);
  }

  static int? _parseUserId(dynamic raw) {
    if (raw == null) return null;
    final parsed = raw is int ? raw : int.tryParse('$raw');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  /// 合并用户信息字段（保留 token 等已有数据）
  Future<void> mergeUserInfo(Map<String, dynamic> info) async {
    await init();
    if (_data is Map) {
      final merged = Map<String, dynamic>.from(_data as Map);
      info.forEach((key, value) {
        if (value == null) return;
        final text = value.toString();
        if (text.isEmpty) return;
        merged[key.toString()] = value;
      });
      await saveData(merged);
      return;
    }
    await saveData(Map<String, dynamic>.from(info));
  }

  Future<void> init() async {
    if (_loaded) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_keyData);
      if (raw != null) {
        _data = jsonDecode(raw);
        if (_data is Map) {
          final phone = (_data as Map)['phone']?.toString();
          if (isFullPhone(phone)) {
            final map = Map<String, dynamic>.from(_data as Map);
            map['phone'] = maskPhone(phone!);
            _data = map;
            await _prefs!.setString(_keyData, jsonEncode(map));
          }
        }
      }
      if (_prefs!.containsKey(_keyCloudSync)) {
        _cloudSync = _prefs!.getBool(_keyCloudSync) ?? false;
      } else {
        _cloudSync = hasPhone;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthSessionStore] init failed: $e');
    } finally {
      _loaded = true;
    }
  }

  Future<String> getOrCreateUuid() async {
    await init();
    final cached = _prefs?.getString(_keyUuid);
    if (cached != null && cached.isNotEmpty) return cached;

    final uuid = _createUuid();
    await _prefs?.setString(_keyUuid, uuid);
    return uuid;
  }

  /// 本地是否已有设备 UUID（有则无需再次 loginByUuid）
  Future<bool> hasStoredUuid() async {
    await init();
    final cached = _prefs?.getString(_keyUuid);
    return cached != null && cached.isNotEmpty;
  }

  Future<void> saveData(dynamic data, {bool notify = true}) async {
    await init();
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final phone = map['phone']?.toString();
      if (isFullPhone(phone)) {
        map['phone'] = maskPhone(phone!);
      }
      _data = map;
      if (_prefs != null) {
        await _prefs!.setString(_keyData, jsonEncode(map));
      }
      if (notify) notifyListeners();
      return;
    }
    _data = data;
    if (_prefs != null && data != null) {
      await _prefs!.setString(_keyData, jsonEncode(data));
    }
    if (notify) notifyListeners();
  }

  Future<void> clear() async {
    await init();
    _data = null;
    await _prefs?.remove(_keyData);
  }

  static String _createUuid() {
    final randomStr =
        '${_randomString(22)}${DateTime.now().millisecondsSinceEpoch}';
    return md5.convert(utf8.encode(randomStr)).toString();
  }

  static String _randomString(int length) {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final rand = Random();
    var result = '';
    for (var i = length; i > 0; i--) {
      result += chars[rand.nextInt(chars.length)];
    }
    return md5.convert(utf8.encode(result)).toString().substring(0, 22);
  }
}
