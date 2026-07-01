import '../data/app_cache_store.dart';
import '../data/pet_avatar_store.dart';
import '../services/pet_image_service.dart';

/// 首页 / 悬浮宠 / 小组件统一取图
class PetDisplayImage {
  PetDisplayImage._();

  static const widgetImageFileName = 'petWidgetImage.png';
  static const widgetDataFileName = 'petWidgetData.json';

  static bool isCustomPet(Map? profile) {
    final type =
        profile?['type']?.toString() ?? profile?['pet_type']?.toString() ?? '';
    return type == '3' || type == 'custom';
  }

  /// 同步读取（内存 + 按 petId 缓存）
  static String? resolveRawSync() {
    final profile = AppCacheStore.instance.petProfile;
    final petId = AppCacheStore.instance.petId;
    final storedCustom = PetAvatarStore.urlForPetSync(petId);
    final image = profile?['image']?.toString().trim();

    if (isCustomPet(profile) || storedCustom != null) {
      if (storedCustom != null && storedCustom.isNotEmpty) return storedCustom;
      if (image != null && image.isNotEmpty) return image;
    } else {
      if (image != null && image.isNotEmpty) return image;
      if (storedCustom != null && storedCustom.isNotEmpty) return storedCustom;
    }

    final animated = profile?['animated_image']?.toString().trim();
    if (animated != null && animated.isNotEmpty) return animated;

    return null;
  }

  /// 异步读取（含按 petId 持久化的 AI 图，绑定手机号后用）
  static Future<String?> resolveRaw() async {
    final profile = AppCacheStore.instance.petProfile;
    final storedCustom = await PetAvatarStore.urlForPet(
      AppCacheStore.instance.petId,
    );
    final image = profile?['image']?.toString().trim();

    if (isCustomPet(profile) || storedCustom != null) {
      if (storedCustom != null && storedCustom.isNotEmpty) return storedCustom;
      if (image != null && image.isNotEmpty) return image;
    } else {
      if (image != null && image.isNotEmpty) return image;
      if (storedCustom != null && storedCustom.isNotEmpty) return storedCustom;
    }

    final animated = profile?['animated_image']?.toString().trim();
    if (animated != null && animated.isNotEmpty) return animated;

    return null;
  }

  static Future<String> resolveUrl() async {
    final raw = await resolveRaw();
    if (raw == null || raw.isEmpty) return '';
    return PetImageService.resolveUrl(raw);
  }

  static Future<List<String>> downloadCandidates() async {
    final profile = AppCacheStore.instance.petProfile;
    final seen = <String>{};
    final out = <String>[];

    void addRaw(String? raw) {
      if (raw == null) return;
      final value = raw.trim();
      if (value.isEmpty) return;
      if (_isLocalPath(value)) {
        if (seen.add(value)) out.add(value);
        return;
      }
      final resolved = PetImageService.resolveUrl(value);
      for (final candidate in [resolved, value]) {
        if (candidate.isEmpty || seen.contains(candidate)) continue;
        seen.add(candidate);
        out.add(candidate);
      }
    }

    final primary = await resolveRaw();
    addRaw(primary);
    addRaw(await PetAvatarStore.urlForPet(AppCacheStore.instance.petId));
    addRaw(profile?['image']?.toString());
    addRaw(PetAvatarStore.localPathForPetSync(AppCacheStore.instance.petId));
    addRaw(PetAvatarStore.customAvatarUrl);
    addRaw(profile?['animated_image']?.toString());

    return out;
  }

  static bool _isLocalPath(String value) {
    if (value.startsWith('file://')) return true;
    if (value.startsWith('/')) return true;
    return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);
  }
}
