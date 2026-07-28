import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api.dart';
import '../data/app_cache_store.dart';
import '../data/memorial_store.dart';
import '../data/pet_avatar_store.dart';
import '../l10n/tr.dart';
import '../router/app_routes.dart';
import '../services/app_launch.dart';
import '../services/desktop_pet_overlay_service.dart';
import '../services/live_activity_service.dart';
import '../services/platform_pet_sync.dart';
import '../widgets/dialogs/reselect_pet_confirm_dialog.dart';
import 'center_tip_util.dart';

/// 重新选择宠物：确认清除数据后进入最初选宠页（与个人中心「重新选择宠物」一致）
class ReselectPetUtil {
  ReselectPetUtil._();

  /// 返回是否已确认并完成清理、跳转选宠页
  /// [forAddCustomPet] 为 true 时使用「添加自家宠物」文案（组件页加号）
  static Future<bool> run(
    BuildContext context, {
    bool forAddCustomPet = false,
  }) async {
    final confirmed = await ReselectPetConfirmDialog.show(
      context,
      titleKey: forAddCustomPet
          ? 'reselect.add_custom_title'
          : 'reselect.title',
      messageKey: forAddCustomPet
          ? 'reselect.add_custom_message'
          : 'reselect.message',
    );
    if (confirmed != true || !context.mounted) return false;

    final petId = AppCacheStore.instance.petId;
    if (petId != null) {
      try {
        final res = await Api.post(
          ApiPaths.reselectPet,
          data: {'pet_id': petId},
        );
        await AppCacheStore.instance.setPetId(null);
        if (!context.mounted) return false;
        showCenterTip(
          context,
          res.msg.isNotEmpty ? res.msg : tr('language.switch_success'),
        );
      } on ApiException catch (e) {
        if (!context.mounted) return false;
        showCenterTip(context, e.message);
        return false;
      }
    }

    MemorialStore.instance.clearAll();
    await PetAvatarStore.clear();
    await PlatformPetSync.afterProfileUpdate();
    await DesktopPetOverlayService.setEnabled(false);
    await LiveActivityService.instance.setEnabled(false);
    await AppLaunch.instance.clearOnboarding();

    if (!context.mounted) return false;
    context.go(AppRoutes.petType);
    return true;
  }
}
