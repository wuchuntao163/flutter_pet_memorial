import '../data/app_cache_store.dart';
import '../data/pet_avatar_store.dart';
import '../services/pet_image_service.dart';

/// 与「我的」页头像一致：档案 image → AI 生成图 customAvatarUrl
class PetDisplayImage {
  PetDisplayImage._();

  static const widgetImageFileName = 'petWidgetImage.png';

  static String? resolveRaw() {
    final profile = AppCacheStore.instance.petProfile;
    final fromProfile = profile?['image']?.toString().trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;

    final custom = PetAvatarStore.customAvatarUrl?.trim();
    if (custom != null && custom.isNotEmpty) return custom;

    return null;
  }

  static String resolveUrl() {
    final raw = resolveRaw();
    if (raw == null || raw.isEmpty) return '';
    return PetImageService.resolveUrl(raw);
  }

  /// 下载时依次尝试：档案图、AI 图（两者可能不同，都试）
  static List<String> downloadCandidates() {
    final profile = AppCacheStore.instance.petProfile;
    final seen = <String>{};
    final out = <String>[];

    void addRaw(String? raw) {
      if (raw == null) return;
      final value = raw.trim();
      if (value.isEmpty) return;
      final resolved = PetImageService.resolveUrl(value);
      for (final candidate in [resolved, value]) {
        if (candidate.isEmpty || seen.contains(candidate)) continue;
        seen.add(candidate);
        out.add(candidate);
      }
    }

    addRaw(profile?['image']?.toString());
    addRaw(PetAvatarStore.customAvatarUrl);

    return out;
  }
}
