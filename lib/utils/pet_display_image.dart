import '../data/app_cache_store.dart';
import '../data/pet_avatar_store.dart';
import '../services/pet_image_service.dart';

/// 与「我的」页头像一致：档案 image → AI 生成图 customAvatarUrl
class PetDisplayImage {
  PetDisplayImage._();

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

  /// 下载候选（去重）：与 resolveRaw 一致，附带解析前后两种写法
  static List<String> downloadCandidates() {
    final raw = resolveRaw();
    if (raw == null || raw.isEmpty) return [];

    final resolved = PetImageService.resolveUrl(raw);
    final seen = <String>{};
    final out = <String>[];
    for (final value in [resolved, raw]) {
      if (value.isEmpty || seen.contains(value)) continue;
      seen.add(value);
      out.add(value);
    }
    return out;
  }
}
