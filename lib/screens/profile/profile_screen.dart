import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/api.dart';
import '../../config/app_info.dart';
import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/banner_store.dart';
import '../../data/app_cache_store.dart';
import '../../data/memorial_store.dart';
import '../../data/pet_avatar_store.dart';
import '../../router/app_routes.dart';
import '../../services/app_launch.dart';
import '../../services/desktop_pet_overlay_service.dart';
import '../../services/live_activity_service.dart';
import '../../utils/app_promotion_util.dart';
import '../../utils/app_update_util.dart';
import '../../utils/center_tip_util.dart';
import '../../widgets/common/action_button.dart';
import '../../widgets/common/profile_banner.dart';
import '../../widgets/common/settings_item.dart';
import '../../widgets/common/pet_avatar_image.dart';
import '../../widgets/dialogs/ios_desktop_pet_guide_dialog.dart';
import '../../widgets/dialogs/reselect_pet_confirm_dialog.dart';
import '../../widgets/dialogs/logout_confirm_dialog.dart';
import '../../widgets/dialogs/language_picker_dialog.dart';
import '../../l10n/tr.dart';
import '../../services/language_service.dart';
import '../../services/pet_image_cache.dart';
import '../../services/platform_pet_sync.dart';
import '../../services/user_service.dart';
import '../../utils/pet_display_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _iconDesktopPet = 'assets/images/image_81.png';
  static const _iconLanguage = 'assets/images/image_82.png';
  static const _iconCloudSync = 'assets/images/image_83.png';
  static const _iconShare = 'assets/images/image_84.png';
  static const _iconRate = 'assets/images/image_85.png';
  static const _iconContactService = 'assets/images/image_86.png';
  static const _iconFeedback = 'assets/images/feedback.png';
  static const _iconPrivacy = 'assets/images/privacy.png';
  static const _iconVersion = 'assets/images/update.png';

  bool _showFloatingPet = false;
  bool _showLiveActivity = false;
  String _appVersion = AppInfo.version;
  GoRouter? _router;
  VoidCallback? _routeListener;
  String? _lastRoutePath;

  @override
  void initState() {
    super.initState();
    AuthSessionStore.instance.addListener(_onSessionChanged);
    BannerStore.instance.addListener(_onBannerChanged);
    final store = BannerStore.instance;
    if (!store.listLoaded && !store.isLoading) {
      store.fetchList();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watchRoute();
      unawaited(_precachePetAvatar());
      PlatformPetSync.afterProfileUpdate();
    });
    _loadDesktopPetSetting();
    if (Platform.isIOS) {
      _loadLiveActivitySetting();
    }
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final version = await AppUpdateUtil.currentVersion();
    if (mounted) setState(() => _appVersion = version);
  }

  Future<void> _precachePetAvatar() async {
    if (!mounted) return;
    final url = await PetDisplayImage.resolveRaw();
    if (!mounted) return;
    PetImageCache.instance.precache(context, url);
  }

  Future<void> _loadDesktopPetSetting() async {
    final enabled = await DesktopPetOverlayService.isEnabled();
    if (mounted) setState(() => _showFloatingPet = enabled);
  }

  Future<void> _loadLiveActivitySetting() async {
    final enabled = await LiveActivityService.instance.isEnabled();
    if (mounted) setState(() => _showLiveActivity = enabled);
  }

  Future<void> _openDesktopPetGuide() async {
    await IosDesktopPetGuideDialog.show(
      context,
      liveActivityEnabled: _showLiveActivity,
      onLiveActivityChanged: (enabled) async {
        if (mounted) setState(() => _showLiveActivity = enabled);
      },
    );
  }

  Future<void> _onDesktopPetChanged(bool enabled) async {
    if (!DesktopPetOverlayService.isSupported) {
      if (!mounted) return;
      showCenterTip(context, tr('desktop_pet.android_only'));
      return;
    }

    if (enabled) {
      final granted = await DesktopPetOverlayService.ensurePermission();
      if (!granted) {
        if (!mounted) return;
        showCenterTip(context, tr('desktop_pet.permission_required'));
        return;
      }
    }

    final ok = await DesktopPetOverlayService.setEnabled(enabled);
    if (!mounted) return;
    if (!ok && enabled) {
      showCenterTip(context, tr('desktop_pet.enable_failed'));
      return;
    }
    setState(() => _showFloatingPet = enabled);
    if (enabled) {
      showCenterTip(context, tr('desktop_pet.enabled_tip'));
    }
  }

  void _watchRoute() {
    if (!mounted) return;
    _router = GoRouter.of(context);
    _lastRoutePath = _router!.routerDelegate.currentConfiguration.uri.path;

    _routeListener = () {
      if (!mounted) return;
      final path = _router!.routerDelegate.currentConfiguration.uri.path;
      if (path == AppRoutes.profile && _lastRoutePath != AppRoutes.profile) {
        unawaited(PlatformPetSync.afterProfileUpdate());
        final image =
            AppCacheStore.instance.petProfile?['image']?.toString() ?? '';
        if (image.isEmpty) {
          AppLaunch.instance.fetchPetProfile(force: true).then((_) {
            PlatformPetSync.afterProfileUpdate();
          });
        }
      }
      _lastRoutePath = path;
    };
    _router!.routerDelegate.addListener(_routeListener!);

    if (_lastRoutePath == AppRoutes.profile) {
      final image =
          AppCacheStore.instance.petProfile?['image']?.toString() ?? '';
      if (image.isEmpty) {
        AppLaunch.instance.fetchPetProfile(force: true);
      }
    }
  }

  @override
  void dispose() {
    if (_routeListener != null) {
      _router?.routerDelegate.removeListener(_routeListener!);
    }
    AuthSessionStore.instance.removeListener(_onSessionChanged);
    BannerStore.instance.removeListener(_onBannerChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  void _onBannerChanged() {
    if (mounted) setState(() {});
  }

  String? _petAvatarUrl() => PetDisplayImage.resolveRawSync();

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionStore.instance;
    final cloudSync = session.cloudSync;

    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              AppLayout.homeTopPadding,
              16,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListenableBuilder(
                  listenable: AppCacheStore.instance,
                  builder: (context, _) => _buildProfileCard(),
                ),
                const SizedBox(height: 10),
                ActionButton(
                  text: tr('profile.reselect_pet'),
                  icon: const Icon(
                    Icons.pets,
                    size: 16,
                    color: AppColors.accentDarker,
                  ),
                  textColor: AppColors.accentDarker,
                  borderRadius: 12,
                  onTap: () => _onReselectPetTap(context),
                ),
                const SizedBox(height: 10),
                _buildBannerSection(),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(
                      bottom: 12 + AppLayout.bottomNavBarInset,
                    ),
                    children: [
                      if (Platform.isIOS)
                        SettingsItem(
                          iconAsset: _iconDesktopPet,
                          title: tr('profile.desktop_pet'),
                          showArrow: true,
                          onTap: _openDesktopPetGuide,
                        )
                      else
                        SwitchSettingsItem(
                          iconAsset: _iconDesktopPet,
                          title: tr('profile.desktop_pet'),
                          value: _showFloatingPet,
                          onChanged: _onDesktopPetChanged,
                        ),
                      const SizedBox(height: 8),
                      SwitchSettingsItem(
                        iconAsset: _iconCloudSync,
                        title: tr('profile.cloud_sync'),
                        value: cloudSync,
                        onChanged: _onCloudSyncChanged,
                      ),
                      const SizedBox(height: 8),
                      SettingsItem(
                        iconAsset: _iconLanguage,
                        title: tr('profile.switch_language'),
                        showArrow: true,
                        onTap: () => LanguagePickerDialog.show(context),
                      ),
                      const SizedBox(height: 8),
                      SettingsItem(
                        iconAsset: _iconContactService,
                        title: tr('profile.contact_service'),
                        showArrow: true,
                        onTap: () => _onContactService(context),
                      ),
                      const SizedBox(height: 8),
                      SettingsItem(
                        iconAsset: _iconFeedback,
                        title: tr('profile.feedback'),
                        showArrow: true,
                        onTap: () => context.push(AppRoutes.feedback),
                      ),
                      const SizedBox(height: 8),
                      SettingsItem(
                        iconAsset: _iconShare,
                        title: tr('profile.share_app'),
                        showArrow: true,
                        onTap: () => _onShareRecommend(context),
                      ),
                      const SizedBox(height: 8),
                      SettingsItem(
                        iconAsset: _iconRate,
                        title: tr('profile.rate_us'),
                        showArrow: true,
                        onTap: () => _onRateApp(context),
                      ),
                      const SizedBox(height: 8),
                      SettingsItem(
                        iconAsset: _iconPrivacy,
                        title: tr('profile.privacy_policy'),
                        showArrow: true,
                        onTap: () => context.push(AppRoutes.privacyPolicy),
                      ),
                      const SizedBox(height: 8),
                      SettingsItem(
                        iconAsset: _iconVersion,
                        title: tr('profile.version'),
                        trailing: Text(
                          'v$_appVersion',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        showArrow: true,
                        onTap: () => AppUpdateUtil.checkOnVersionTap(context),
                      ),
                      if (cloudSync) ...[
                        const SizedBox(height: 8),
                        SettingsItem(
                          icon: Icons.logout,
                          title: tr('profile.logout'),
                          showArrow: true,
                          onTap: _onLogoutTap,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onShareRecommend(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      await AppPromotionUtil.shareRecommend(sharePositionOrigin: origin);
    } catch (e) {
      if (!context.mounted) return;
      showCenterTip(context, '${tr('profile.share_failed')}$e');
    }
  }

  Future<void> _onContactService(BuildContext context) async {
    try {
      final ok = await AppPromotionUtil.openCustomerService();
      if (!context.mounted) return;
      if (!ok) {
        showCenterTip(context, tr('profile.contact_service_unavailable'));
      }
    } catch (e) {
      if (!context.mounted) return;
      showCenterTip(context, '${tr('profile.open_failed')}$e');
    }
  }

  Future<void> _onRateApp(BuildContext context) async {
    try {
      final ok = await AppPromotionUtil.openAppStoreRating();
      if (!context.mounted) return;
      if (!ok) {
        showCenterTip(context, tr('profile.cannot_open_store'));
      }
    } catch (e) {
      if (!context.mounted) return;
      showCenterTip(context, '${tr('profile.open_failed')}$e');
    }
  }

  Future<void> _onReselectPetTap(BuildContext context) async {
    final confirmed = await ReselectPetConfirmDialog.show(context);
    if (confirmed != true || !context.mounted) return;

    final petId = AppCacheStore.instance.petId;
    if (petId != null) {
      try {
        final res = await Api.post(
          ApiPaths.reselectPet,
          data: {'pet_id': petId},
        );
        await AppCacheStore.instance.setPetId(null);
        if (!context.mounted) return;
        showCenterTip(
          context,
          res.msg.isNotEmpty ? res.msg : tr('language.switch_success'),
        );
      } on ApiException catch (e) {
        if (!context.mounted) return;
        showCenterTip(context, e.message);
        return;
      }
    }

    MemorialStore.instance.clearAll();
    await PetAvatarStore.clear();
    await PlatformPetSync.afterProfileUpdate();
    await DesktopPetOverlayService.setEnabled(false);
    await LiveActivityService.instance.setEnabled(false);
    if (mounted) {
      setState(() {
        _showFloatingPet = false;
        _showLiveActivity = false;
      });
    }
    await AppLaunch.instance.clearOnboarding();

    if (!context.mounted) return;
    context.go(AppRoutes.petType);
  }

  Future<void> _syncCloudMemorialData() async {
    await UserService.refreshUserInfo();
    await AppLaunch.instance.fetchPetProfile(force: true);
    await MemorialStore.instance.ensureMemorialsLoaded(force: true);
    await PlatformPetSync.afterProfileUpdate();
  }

  Future<void> _openBindPhone() async {
    final ok = await context.push<bool>(AppRoutes.bindPhone);
    if (ok == true && mounted) {
      await AuthSessionStore.instance.setCloudSync(true);
      await _syncCloudMemorialData();
      if (mounted) setState(() {});
    }
  }

  Future<void> _onLogoutTap() async {
    if (!AuthSessionStore.instance.cloudSync) return;
    await _confirmLogout();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await LogoutConfirmDialog.show(context);
    if (confirmed != true || !mounted) return;
    await AuthSessionStore.instance.setCloudSync(false);
    setState(() {});
  }

  void _onCloudSyncChanged(bool value) {
    if (value) {
      if (!AuthSessionStore.instance.hasPhone) {
        _openBindPhone();
        return;
      }
      AuthSessionStore.instance.setCloudSync(true).then((_) async {
        await _syncCloudMemorialData();
        if (mounted) setState(() {});
      });
      return;
    }
    _confirmLogout();
  }

  Future<void> _onProfileCardTap() async {
    final session = AuthSessionStore.instance;
    if (session.cloudSync && session.hasPhone) return;
    await _openBindPhone();
  }

  Widget _buildBannerSection() {
    final store = BannerStore.instance;
    if (store.isLoading && store.items.isEmpty) {
      return const SizedBox(
        height: 72,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    if (store.items.isEmpty) return const SizedBox.shrink();
    return ProfileBanner(items: store.items);
  }

  Widget _buildProfileAvatar() {
    final url = _petAvatarUrl();
    final size = AppLayout.petAvatarSize;
    return SizedBox(
      width: size,
      height: size,
      child: PetAvatarImage(
        key: ValueKey('profile-pet-avatar-$url'),
        url: url,
        width: size,
        height: size,
      ),
    );
  }

  Widget _buildProfileCard() {
    final session = AuthSessionStore.instance;
    final userId = session.userId;
    final phone = session.phone;
    final showPhone = session.cloudSync && phone != null;

    return GestureDetector(
      onTap: showPhone ? null : _onProfileCardTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: AppLayout.petCardPadding,
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(AppLayout.petCardBorderRadius),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentDark.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildProfileAvatar(),
            const SizedBox(width: AppLayout.petCardAvatarGap),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID:${userId ?? '--'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppLayout.petCardTextGap),
                Text(
                  showPhone ? phone : tr('profile.bind_phone'),
                  style: TextStyle(
                    fontSize: 12,
                    color: showPhone
                        ? AppColors.textSecondary
                        : AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
