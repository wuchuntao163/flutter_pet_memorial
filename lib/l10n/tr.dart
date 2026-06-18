import '../services/language_service.dart';

/// 文案：点分路径，如 `tr('profile.cloud_sync')`
String tr(String key, {String? fb}) => LanguageService.instance.tr(key, fb: fb);
