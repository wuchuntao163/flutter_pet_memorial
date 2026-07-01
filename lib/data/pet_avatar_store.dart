import 'package:shared_preferences/shared_preferences.dart';

import '../services/widget_sync_trigger.dart';

/// 用户选定的 AI 宠物形象（按 petId 持久化，绑定手机号后仍可找回）
class PetAvatarStore {
  PetAvatarStore._();

  static const _keyCustomAvatarUrl = 'custom_avatar_url';
  static const _keyCustomAvatarDescription = 'custom_avatar_description';
  static const _keyByPetPrefix = 'custom_avatar_pet_';

  static String? customAvatarUrl;
  static String? customAvatarDescription;
  static final Map<int, String> _petUrlById = {};

  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyCustomAvatarUrl)?.trim();
    customAvatarUrl = (url != null && url.isNotEmpty) ? url : null;
    final description = prefs.getString(_keyCustomAvatarDescription)?.trim();
    customAvatarDescription =
        (description != null && description.isNotEmpty) ? description : null;

    _petUrlById.clear();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_keyByPetPrefix)) continue;
      final id = int.tryParse(key.substring(_keyByPetPrefix.length));
      final stored = prefs.getString(key)?.trim();
      if (id != null && stored != null && stored.isNotEmpty) {
        _petUrlById[id] = stored;
      }
    }
  }

  /// 内存读取（小组件/UI 同步路径用）
  static String? urlForPetSync(int? petId) {
    if (petId != null) {
      final stored = _petUrlById[petId]?.trim();
      if (stored != null && stored.isNotEmpty) return stored;
    }
    final global = customAvatarUrl?.trim();
    if (global != null && global.isNotEmpty) return global;
    return null;
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

  static Future<void> setAvatar({
    required String url,
    String? description,
    int? petId,
  }) async {
    customAvatarUrl = url.trim().isEmpty ? null : url.trim();
    customAvatarDescription = description?.trim();
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
    if (customAvatarDescription != null &&
        customAvatarDescription!.isNotEmpty) {
      await prefs.setString(
        _keyCustomAvatarDescription,
        customAvatarDescription!,
      );
    } else {
      await prefs.remove(_keyCustomAvatarDescription);
    }
    scheduleWidgetSync();
  }

  static Future<void> clear() async {
    customAvatarUrl = null;
    customAvatarDescription = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCustomAvatarUrl);
    await prefs.remove(_keyCustomAvatarDescription);
    scheduleWidgetSync();
  }
}
