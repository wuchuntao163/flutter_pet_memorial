import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/api.dart';
import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../data/pet_avatar_store.dart';
import '../../router/app_routes.dart';
import '../../services/app_launch.dart';
import '../../services/platform_pet_sync.dart';
import '../../services/user_service.dart';
import '../../l10n/tr.dart';
import '../../utils/center_tip_util.dart';
import '../../widgets/common/gradient_tap_button.dart';
import '../../widgets/common/pet_avatar_image.dart';

const _formWidth = 275.0;

class PetNamingScreen extends StatefulWidget {
  final String petType;

  const PetNamingScreen({super.key, required this.petType});

  @override
  State<PetNamingScreen> createState() => _PetNamingScreenState();
}

class _PetNamingScreenState extends State<PetNamingScreen> {
  final _nameController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  Map? get _pet {
    for (final item in AppCacheStore.instance.petList) {
      if (item is Map && item['type'] == widget.petType) return item;
    }
    return null;
  }

  String get _nameHint => switch (widget.petType) {
    'dog' => tr('pet_naming.hint_dog'),
    'cat' => tr('pet_naming.hint_cat'),
    _ => tr('pet_naming.hint_other'),
  };

  String get _defaultName => switch (widget.petType) {
    'dog' => tr('pet_naming.default_name_dog'),
    'cat' => tr('pet_naming.default_name_cat'),
    _ => tr('pet_naming.default_name_other'),
  };

  String get _petLabel => switch (widget.petType) {
    'dog' => tr('pet_naming.default_name_dog'),
    'cat' => tr('pet_naming.default_name_cat'),
    'custom' => tr('pet_naming.custom_pet_label'),
    _ => _pet?['name']?.toString() ?? tr('pet_naming.default_name_other'),
  };

  String? get _profileImage {
    if (widget.petType == 'custom') {
      return PetAvatarStore.customAvatarUrl;
    }
    return _pet?['image']?.toString();
  }

  Widget _buildAvatarPreview() {
    return PetAvatarImage(
      url: _profileImage,
      width: AppLayout.petNamingAvatarSize,
      height: AppLayout.petNamingAvatarSize,
      fit: BoxFit.contain,
    );
  }

  Future<void> _onConfirm() async {
    final name = _nameController.text.trim();
    final nickname = name.isNotEmpty ? name : _defaultName;

    final image = _profileImage ?? '';
    if (image.isEmpty) {
      showCenterTip(
        context,
        widget.petType == 'custom'
            ? tr('pet_naming.generate_ai_first')
            : tr('pet_naming.image_not_loaded'),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{
        'nickname': nickname,
        'image': image,
        'type': widget.petType == 'custom'
            ? 3
            : (_pet?['pet_type'] ?? (widget.petType == 'cat' ? 2 : 1)),
      };
      final description = PetAvatarStore.customAvatarDescription;
      if (widget.petType == 'custom' &&
          description != null &&
          description.isNotEmpty) {
        data['description'] = description;
      }

      final res = await Api.post(ApiPaths.createPetProfile, data: data);
      final responseData = res.data;
      final id = responseData is Map
          ? (responseData['pet_id'] ?? responseData['id'])
          : null;
      if (id != null) {
        await AppCacheStore.instance.setPetId(
          id is int ? id : int.tryParse('$id'),
        );
      }

      AppCacheStore.instance.setPetInfo({
        'nickname': nickname,
        'image': image,
        'type': widget.petType,
      });
      await PlatformPetSync.afterProfileUpdate();
      await UserService.refreshUserInfo();

      await AppLaunch.instance.markOnboardingDone();
      if (!mounted) return;
      context.go(AppRoutes.homeAdopted);

      if (id != null) {
        try {
          final createdImage = image;
          await AppLaunch.instance.fetchPetProfile(force: true);
          final profile = AppCacheStore.instance.petProfile;
          AppCacheStore.instance.setPetInfo({
            ...?profile,
            'nickname': nickname,
            'image': createdImage,
          });
          await PlatformPetSync.afterProfileUpdate();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[PetNaming] post-create sync failed: $e');
          }
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showCenterTip(context, e.message);
    } catch (e) {
      if (!mounted) return;
      showCenterTip(context, '${tr('pet_naming.create_failed')}$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    children: [
                      const SizedBox(
                        height: AppLayout.petOnboardingTitleTopInset,
                      ),
                      Text(
                        tr('pet_naming.title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('pet_naming.subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: AppLayout.petNamingAvatarSize,
                    height: AppLayout.petNamingAvatarSize,
                    child: _buildAvatarPreview(),
                  ),
                  Positioned(
                    bottom: 0,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _petLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF785C35),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: SizedBox(
                  width: _formWidth,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bgWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.avatarDescriptionBorder,
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _nameController,
                      maxLength: 10,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1,
                        color: Color(0xFF5C4033),
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        counterText: '',
                        hintText: _nameHint,
                        hintStyle: TextStyle(
                          fontSize: 15,
                          height: 1,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: SizedBox(
                  width: _formWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_nameController.text.length}/10',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr('pet_naming.name_tip'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: _formWidth,
                  child: Row(
                    children: [
                      Expanded(
                        child: GradientTapButton(
                          onTap: _submitting ? null : () => context.pop(),
                          color: AppColors.bgWhite,
                          height: 46,
                          border: Border.all(
                            color: AppColors.avatarDescriptionBorder,
                            width: 1.5,
                          ),
                          child: Text(
                            tr('pet_naming.back'),
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5C4033),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GradientTapButton(
                          onTap: _submitting ? null : _onConfirm,
                          gradient: AppColors.avatarGenerateGradient,
                          height: 46,
                          child: Text(
                            _submitting
                                ? tr('pet_naming.creating')
                                : tr('pet_naming.confirm'),
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              color: AppColors.avatarGenerateButtonText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
