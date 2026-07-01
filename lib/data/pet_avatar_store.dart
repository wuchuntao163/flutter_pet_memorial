import 'package:shared_preferences/shared_preferences.dart';

import '../services/widget_sync_trigger.dart';

/// 用户选定的 AI 宠物形象
class PetAvatarStore {
  PetAvatarStore._();

  static const _keyCustomAvatarUrl = 'custom_avatar_url';
  static const _keyCustomAvatarDescription = 'custom_avatar_description';

  static String? customAvatarUrl;
  static String? customAvatarDescription;

  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyCustomAvatarUrl)?.trim();
    customAvatarUrl = (url != null && url.isNotEmpty) ? url : null;
    final description = prefs.getString(_keyCustomAvatarDescription)?.trim();
    customAvatarDescription =
        (description != null && description.isNotEmpty) ? description : null;
  }

  static Future<void> setAvatar({required String url, String? description}) async {
    customAvatarUrl = url.trim().isEmpty ? null : url.trim();
    customAvatarDescription = description?.trim();
    final prefs = await SharedPreferences.getInstance();
    if (customAvatarUrl != null) {
      await prefs.setString(_keyCustomAvatarUrl, customAvatarUrl!);
    } else {
      await prefs.remove(_keyCustomAvatarUrl);
    }
    if (customAvatarDescription != null && customAvatarDescription!.isNotEmpty) {
      await prefs.setString(_keyCustomAvatarDescription, customAvatarDescription!);
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
  }
}
