import '../data/app_cache_store.dart';
import '../data/pet_avatar_store.dart';
import '../services/pet_image_service.dart';

/// 首页 / 悬浮宠 / 小组件统一取图
class PetDisplayImage {
  PetDisplayImage._();

  static const widgetImageFileName = 'petWidgetImage.png';

  static bool _isCustomPet(Map? profile) {
    final type =
        profile?['type']?.toString() ?? profile?['pet_type']?.toString() ?? '';
    return type == '3' || type == 'custom';
  }

  /// 与首页宠物卡片、悬浮宠一致
  static String? resolveRaw() {
    final profile = AppCacheStore.instance.petProfile;
    final image = profile?['image']?.toString().trim();
    final custom = PetAvatarStore.customAvatarUrl?.trim();

    // AI 宠：优先 AI 图，避免档案里残留上一只默认宠的 image
    if (_isCustomPet(profile)) {
      if (custom != null && custom.isNotEmpty) return custom;
      if (image != null && image.isNotEmpty) return image;
    } else {
      if (image != null && image.isNotEmpty) return image;
      if (custom != null && custom.isNotEmpty) return custom;
    }

    final animated = profile?['animated_image']?.toString().trim();
    if (animated != null && animated.isNotEmpty) return animated;

    return null;
  }

  static String resolveUrl() {
    final raw = resolveRaw();
    if (raw == null || raw.isEmpty) return '';
    return PetImageService.resolveUrl(raw);
  }

  /// 下载候选：主图 + 其余来源（切换宠物时逐个尝试）
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

    addRaw(resolveRaw());
    if (_isCustomPet(profile)) {
      addRaw(PetAvatarStore.customAvatarUrl);
      addRaw(profile?['image']?.toString());
    } else {
      addRaw(profile?['image']?.toString());
      addRaw(PetAvatarStore.customAvatarUrl);
    }
    addRaw(profile?['animated_image']?.toString());

    return out;
  }
}
