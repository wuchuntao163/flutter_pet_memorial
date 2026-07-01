import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/pet_image_service.dart';
import '../services/widget_sync_trigger.dart';

/// 用户选定的 AI 宠物形象（按 petId 持久化，绑定手机号后仍可找回）
class PetAvatarStore {
  PetAvatarStore._();

  static const _keyCustomAvatarUrl = 'custom_avatar_url';
  static const _keyCustomAvatarDescription = 'custom_avatar_description';
  static const _keyCustomAvatarLocalPath = 'custom_avatar_local_path';
  static const _keyByPetPrefix = 'custom_avatar_pet_';
  static const _keyLocalByPetPrefix = 'custom_avatar_local_pet_';

  static String? customAvatarUrl;
  static String? customAvatarDescription;
  static String? customAvatarLocalPath;
  static final Map<int, String> _petUrlById = {};
  static final Map<int, String> _petLocalPathById = {};

  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyCustomAvatarUrl)?.trim();
    customAvatarUrl = (url != null && url.isNotEmpty) ? url : null;
    final description = prefs.getString(_keyCustomAvatarDescription)?.trim();
    customAvatarDescription = (description != null && description.isNotEmpty)
        ? description
        : null;
    final local = prefs.getString(_keyCustomAvatarLocalPath)?.trim();
    customAvatarLocalPath = (local != null && local.isNotEmpty) ? local : null;

    _petUrlById.clear();
    _petLocalPathById.clear();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_keyByPetPrefix)) {
        final id = int.tryParse(key.substring(_keyByPetPrefix.length));
        final stored = prefs.getString(key)?.trim();
        if (id != null && stored != null && stored.isNotEmpty) {
          _petUrlById[id] = stored;
        }
      }
      if (key.startsWith(_keyLocalByPetPrefix)) {
        final id = int.tryParse(key.substring(_keyLocalByPetPrefix.length));
        final stored = prefs.getString(key)?.trim();
        if (id != null && stored != null && stored.isNotEmpty) {
          _petLocalPathById[id] = stored;
        }
      }
    }
  }

  /// 内存读取（小组件/UI 同步路径用）
  static String? urlForPetSync(int? petId) {
    if (petId != null) {
      final stored = exactUrlForPetSync(petId);
      if (stored != null) return stored;
    }
    final global = customAvatarUrl?.trim();
    if (global != null && global.isNotEmpty) return global;
    return null;
  }

  static String? exactUrlForPetSync(int? petId) {
    if (petId == null) return null;
    final stored = _petUrlById[petId]?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return null;
  }

  static String? localPathForPetSync(int? petId) {
    String? pick(String? path) {
      final value = path?.trim();
      if (value == null || value.isEmpty) return null;
      if (File(value).existsSync()) return value;
      return null;
    }

    if (petId != null) {
      final stored = pick(_petLocalPathById[petId]);
      if (stored != null) return stored;
    }
    return pick(customAvatarLocalPath);
  }

  static String? exactLocalPathForPetSync(int? petId) {
    if (petId == null) return null;
    final value = _petLocalPathById[petId]?.trim();
    if (value == null || value.isEmpty) return null;
    if (File(value).existsSync()) return value;
    return null;
  }

  static Future<void> bindCurrentAvatarToPet(
    int? petId, {
    bool scheduleSync = false,
  }) async {
    if (petId == null) return;
    final url = customAvatarUrl?.trim();
    if (url == null || url.isEmpty) return;
    await setAvatar(
      url: url,
      description: customAvatarDescription,
      petId: petId,
      localPath: localPathForPetSync(null) ?? exactLocalPathForPetSync(petId),
      scheduleSync: scheduleSync,
    );
  }

  /// 当前宠物可用的 AI 图（优先读该 petId 的持久化 URL）
  static Future<String?> urlForPet(int? petId) async {
    final sync = urlForPetSync(petId);
    if (sync != null && sync.isNotEmpty) return sync;

    if (petId != null) {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('$_keyByPetPrefix$petId')?.trim();
      if (stored != null && stored.isNotEmpty) {
        _petUrlById[petId] = stored;
        return stored;
      }
    }
    return null;
  }

  /// 确保 AI 图在本地 Documents 有副本，供小组件同步（高版本 iOS 必须走本地 PNG）
  static Future<String?> ensureLocalCacheForWidget({int? petId}) async {
    final existing = localPathForPetSync(petId);
    if (existing != null) return existing;

    final url = urlForPetSync(petId) ?? customAvatarUrl;
    if (url == null || url.trim().isEmpty) return null;

    try {
      final path = await PetImageService.downloadToDocuments(
        url,
        filename: petId != null
            ? 'pet_widget_avatar_$petId.png'
            : 'pet_widget_avatar.png',
      );
      await setAvatar(
        url: url,
        description: customAvatarDescription,
        petId: petId,
        localPath: path,
        scheduleSync: false,
      );
      return path;
    } catch (e) {
      return null;
    }
  }

  static Future<void> setAvatar({
    required String url,
    String? description,
    int? petId,
    String? localPath,
    bool scheduleSync = true,
  }) async {
    customAvatarUrl = url.trim().isEmpty ? null : url.trim();
    customAvatarDescription = description?.trim();
    if (localPath != null && localPath.trim().isNotEmpty) {
      customAvatarLocalPath = localPath.trim();
    }
    final prefs = await SharedPreferences.getInstance();
    if (customAvatarUrl != null) {
      await prefs.setString(_keyCustomAvatarUrl, customAvatarUrl!);
      if (petId != null) {
        await prefs.setString('$_keyByPetPrefix$petId', customAvatarUrl!);
        _petUrlById[petId] = customAvatarUrl!;
      }
    } else {
      await prefs.remove(_keyCustomAvatarUrl);
    }
    if (customAvatarLocalPath != null && customAvatarLocalPath!.isNotEmpty) {
      await prefs.setString(_keyCustomAvatarLocalPath, customAvatarLocalPath!);
      if (petId != null) {
        await prefs.setString(
          '$_keyLocalByPetPrefix$petId',
          customAvatarLocalPath!,
        );
        _petLocalPathById[petId] = customAvatarLocalPath!;
      }
    }
    if (customAvatarDescription != null &&
        customAvatarDescription!.isNotEmpty) {
      await prefs.setString(
        _keyCustomAvatarDescription,
        customAvatarDescription!,
      );
    } else {
      await prefs.remove(_keyCustomAvatarDescription);
    }
    if (scheduleSync) {
      scheduleWidgetSync();
    }
  }

  static Future<void> clear() async {
    customAvatarUrl = null;
    customAvatarDescription = null;
    customAvatarLocalPath = null;
    _petUrlById.clear();
    _petLocalPathById.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCustomAvatarUrl);
    await prefs.remove(_keyCustomAvatarDescription);
    await prefs.remove(_keyCustomAvatarLocalPath);
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_keyByPetPrefix) ||
          key.startsWith(_keyLocalByPetPrefix)) {
        await prefs.remove(key);
      }
    }
    scheduleWidgetSync();
  }
}
