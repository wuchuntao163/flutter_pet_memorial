import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_config.dart';

/// 语言包：先用本地 assets，服务器拉取成功则覆盖同 key；失败或超时继续用本地。
class LanguageService extends ChangeNotifier {
  LanguageService._();

  static final LanguageService instance = LanguageService._();
  static const _keyFontName = 'language_font_name';
  static const defaultFontName = 'ch';
  static const _remoteTimeout = Duration(seconds: 5);

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
    ),
  );

  String fontName = defaultFontName;
  Map<String, dynamic> strings = {};
  bool isReady = false;

  Future<void>? _initFuture;

  /// [runApp] 前调用：只读本地包，保证首屏不闪
  Future<void> init() => _initFuture ??= _loadLocal();

  /// 启动后后台拉服务器（慢/失败不影响当前文案）
  Future<void> refreshFromServer() => _applyRemote(fontName);

  Future<void> switchTo(String code) async {
    final name = code.trim();
    if (name.isEmpty) return;

    fontName = name;
    await _loadLocal(name);
    await _applyRemote(name);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontName, name);
    notifyListeners();
  }

  Future<void> _loadLocal([String? code]) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyFontName)?.trim();
    final lang = code ?? ((saved == null || saved.isEmpty) ? defaultFontName : saved);
    fontName = lang;

    strings = await _loadBundled(lang);
    isReady = strings.isNotEmpty;

    if (saved == null || saved.isEmpty) {
      await prefs.setString(_keyFontName, defaultFontName);
    }
    notifyListeners();
  }

  Future<void> _applyRemote(String code) async {
    final local = Map<String, dynamic>.from(strings);
    try {
      final remote = await _fetchRemotePack(code).timeout(_remoteTimeout);
      if (remote.isEmpty) return;
      strings = _deepMerge(local, remote);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LanguageService] remote skipped, use local: $e');
      }
    }
  }

  String tr(String key, {String? fb}) {
    if (!isReady) return fb ?? key;
    final v = _resolve(strings, key);
    if (v != null && v.isNotEmpty) return v;
    return fb ?? key;
  }

  static dynamic _resolve(Map<String, dynamic> map, String key) {
    dynamic cur = map;
    for (final part in key.split('.')) {
      if (cur is! Map) return null;
      cur = cur[part];
    }
    if (cur == null) return null;
    return cur is String ? cur : cur.toString();
  }

  Future<Map<String, dynamic>> _fetchRemotePack(String code) async {
    final url =
        '${ApiConfig.baseUrl}/language/zh_$code.json?t=${DateTime.now().millisecondsSinceEpoch}';
    final res = await _dio.get<dynamic>(
      url,
      options: Options(headers: {'Cache-Control': 'no-cache'}),
    );
    var data = res.data;
    if (data is String && data.trim().isNotEmpty) {
      data = jsonDecode(data);
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<Map<String, dynamic>> _loadBundled(String code) async {
    try {
      final raw = await rootBundle.loadString('assets/language/zh_$code.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LanguageService] bundled missing: $code');
      }
    }
    return {};
  }

  static Map<String, dynamic> _deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> over,
  ) {
    final out = Map<String, dynamic>.from(base);
    over.forEach((k, v) {
      if (v is Map && out[k] is Map) {
        out[k] = _deepMerge(
          Map<String, dynamic>.from(out[k] as Map),
          Map<String, dynamic>.from(v),
        );
      } else {
        out[k] = v;
      }
    });
    return out;
  }
}
