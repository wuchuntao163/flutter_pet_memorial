import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';

import '../data/app_cache_store.dart';
import '../data/banner_store.dart';
import '../data/background_store.dart';
import '../data/font_style_store.dart';
import '../data/memorial_store.dart';
import '../services/reminder_service.dart';
import '../services/platform_pet_sync.dart';
import '../services/language_service.dart';

import '../router/app_routes.dart';

/// App 启动后执行（须在 runApp 之后）

class AppLaunch extends ChangeNotifier {
  AppLaunch._();

  static final AppLaunch instance = AppLaunch._();

  static const _keyIsFirstOpen = 'isFirstOpen';

  final _cache = AppCacheStore.instance;

  DateTime? _lastPetProfileFetchAt;
  Future<void>? _petProfileFuture;

  bool _routeReady = false;

  bool _guideOnce = false;

  /// 由 [PetMemorialApp] 首帧回调触发，勿在 main 里 await

  Future<void> onLaunch() async {
    await Api.init();
    await ReminderService.instance.init();
    await _cache.init();

    // 先请求通知权限，避免网络权限弹窗阻塞
    await ReminderService.instance.requestPermission();

    await Future.wait([_cache.fetchConfig(), _loginByUuid()]);

    await _checkFirstOpen();

    if (_cache.petId != null) {
      MemorialStore.instance.markListPending();
      await fetchPetProfile();
      await MemorialStore.instance.fetchTypes();
      await MemorialStore.instance.fetchList();
      await PlatformPetSync.afterProfileUpdate();
    }

    await _fetchNav();

    await _fetchAppInfo();

    await _fetchLanguage();
    unawaited(LanguageService.instance.refreshFromServer());

    await BackgroundStore.instance.fetchCategories();
    await BackgroundStore.instance.selectFirstCategory();
    await FontStyleStore.instance.fetchList();
    await BannerStore.instance.fetchList();
  }

  Future<void> _checkFirstOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded =
        prefs.getInt(_keyIsFirstOpen) == 1 && _cache.petId != null;
    if (!onboarded) {
      _guideOnce = true;
    }
    _routeReady = true;
    notifyListeners();
  }

  /// 取名页确定后标记已完成引导
  Future<void> markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyIsFirstOpen, 1);
    _guideOnce = false;
    notifyListeners();
  }

  /// 重新选择宠物时清除引导标记
  Future<void> clearOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsFirstOpen);
    _guideOnce = true;
    notifyListeners();
  }

  String? redirect(String location) {
    if (!_routeReady) return null;

    if (location.startsWith('/pet-naming')) {
      return null;
    }

    if (location == AppRoutes.petType) {
      _guideOnce = false;
      return null;
    }

    if (!_guideOnce || _cache.petId != null) {
      return null;
    }

    _guideOnce = false;
    return AppRoutes.petType;
  }

  Future<void> _loginByUuid() async {
    try {
      final uuid = await AuthSessionStore.instance.getOrCreateUuid();

      final res = await Api.post(ApiPaths.loginByUuid, data: {'uuid': uuid});

      final data = res.data;

      if (data != null) {
        await AuthSessionStore.instance.saveData(data);
      }

      if (kDebugMode) {
        // debugPrint('[onLaunch] data ok, $data');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[onLaunch] data failed: $e');
      }
    }
  }

  Future<void> fetchPetProfile({bool force = false}) async {
    final petId = _cache.petId;
    if (petId == null) return;

    if (!force) {
      final last = _lastPetProfileFetchAt;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(seconds: 30)) {
        return;
      }
      if (_petProfileFuture != null) {
        return _petProfileFuture;
      }
    }

    _petProfileFuture = _doFetchPetProfile();
    try {
      await _petProfileFuture;
    } finally {
      _petProfileFuture = null;
    }
  }

  Future<void> _doFetchPetProfile() async {
    final petId = _cache.petId;
    if (petId == null) return;
    _lastPetProfileFetchAt = DateTime.now();
    try {
      final res = await Api.get(
        ApiPaths.getPetProfileInfo,
        query: {'pet_id': petId},
      );
      _cache.setPetInfo(res.data);
      await PlatformPetSync.afterProfileUpdate();
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[onLaunch] getPetProfileInfo failed: $e');
      }
    }
  }

  Future<void> _fetchNav() async {
    try {
      final res = await Api.get(ApiPaths.nav, query: {'type': 2});

      _cache.setNavList(res.data);

      if (kDebugMode) {
        // debugPrint('[onLaunch] getNav(type:2) ok: ${res.data}');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[onLaunch] getNav failed: $e');
      }
    }
  }

  Future<void> _fetchAppInfo() async {
    try {
      final res = await Api.get(ApiPaths.getAppInfo);

      _cache.setAppInfo(res.data);
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[onLaunch] getAppInfo failed: $e');
      }
    }
  }

  Future<void> _fetchLanguage() async {
    try {
      final res = await Api.get(ApiPaths.getLanguage);

      _cache.setLanguage(res.data);
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[onLaunch] getLanguage failed: $e');
      }
    }
  }
}
