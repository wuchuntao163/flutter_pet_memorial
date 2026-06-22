import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/colors.dart';
import '../../data/app_cache_store.dart';
import '../../data/pet_avatar_store.dart';
import '../../config/layout.dart';
import '../../l10n/tr.dart';
import '../../widgets/common/gradient_tap_button.dart';
import '../../router/app_routes.dart';
import '../../widgets/common/pet_avatar_image.dart';

class PetTypeSelectionScreen extends StatefulWidget {
  const PetTypeSelectionScreen({super.key});

  @override
  State<PetTypeSelectionScreen> createState() => _PetTypeSelectionScreenState();
}

class _PetTypeSelectionScreenState extends State<PetTypeSelectionScreen> {
  late bool _hasGeneratedAvatar;

  @override
  void initState() {
    super.initState();
    _hasGeneratedAvatar = _avatarExists;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!AppCacheStore.instance.configLoaded) {
        AppCacheStore.instance.fetchConfig();
      }
    });
  }

  bool get _avatarExists => PetAvatarStore.customAvatarUrl?.isNotEmpty == true;

  void _onGenerateAvatarTap() {
    context.push(AppRoutes.avatarStyle);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: AppCacheStore.instance,
            builder: (context, _) {
              final pets = AppCacheStore.instance.petList;

              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(
                              height: AppLayout.petOnboardingTitleTopInset,
                            ),
                            Text(
                              tr('pet_type.title'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('pet_type.subtitle'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                            for (final pet in pets) ...[
                              _buildPetCard(context, pet),
                              const SizedBox(height: 14),
                            ],
                            const SizedBox(height: 13),
                            _buildGenerateButton(),
                            const SizedBox(height: 100),
                            Text(
                              tr('pet_type.hint'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return GradientTapButton(
      onTap: _onGenerateAvatarTap,
      color: AppColors.petTypeAiButton,
      borderRadius: 999,
      height: 44,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/magic.png', width: 26, height: 26),
          const SizedBox(width: 8),
          Text(
            _hasGeneratedAvatar
                ? tr('pet_type.regenerate_ai')
                : tr('pet_type.generate_ai'),
            style: const TextStyle(
              fontSize: 15,
              height: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(BuildContext context, dynamic pet) {
    if (pet is! Map) return const SizedBox.shrink();
    final cache = AppCacheStore.instance;
    final map = Map<String, dynamic>.from(pet);
    final type = map['type']?.toString() ?? '';
    final image = map['image']?.toString() ?? '';
    final apiName = map['name']?.toString().trim() ?? '';
    final describe = map['describe']?.toString().trim() ?? '';
    final fallbackName = type == 'cat'
        ? tr('pet_naming.default_name_cat')
        : type == 'dog'
        ? tr('pet_naming.default_name_dog')
        : '';
    final waitingConfig = cache.configLoading;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.petNaming(type)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentDark.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: AppLayout.petTypeSelectionAvatarSize,
              height: AppLayout.petTypeSelectionAvatarSize,
              child: _buildPetImage(image, waitingConfig),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (waitingConfig)
                    _buildTextLoading()
                  else
                    Text(
                      apiName.isNotEmpty ? apiName : fallbackName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  if (waitingConfig)
                    const SizedBox(height: 6)
                  else if (describe.isNotEmpty)
                    Text(
                      describe,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetImage(String image, bool waitingConfig) {
    if (waitingConfig) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (image.isEmpty) {
      return const SizedBox.shrink();
    }
    return PetAvatarImage(
      url: image,
      width: AppLayout.petTypeSelectionAvatarSize,
      height: AppLayout.petTypeSelectionAvatarSize,
      fit: BoxFit.contain,
    );
  }

  Widget _buildTextLoading() {
    return const SizedBox(
      height: 32,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
