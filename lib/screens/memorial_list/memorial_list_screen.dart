import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/api.dart';
import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../data/memorial_list_view_prefs.dart';
import '../../data/memorial_store.dart';
import '../../widgets/common/pet_avatar_image.dart';
import '../../models/memorial_day.dart';
import '../../router/app_routes.dart';
import '../../widgets/common/gradient_tap_button.dart';
import '../../widgets/common/memorial_card.dart';
import '../../widgets/common/memorial_grid_card.dart';
import '../../l10n/tr.dart';
import '../../utils/center_tip_util.dart';
import '../../services/pet_gif_service.dart';
import '../../utils/app_update_util.dart';
import '../../services/day_tick_service.dart';
import '../../services/language_service.dart';
import '../../services/platform_pet_sync.dart';
import '../../services/pet_image_cache.dart';
import '../../utils/pet_display_image.dart';
import '../../widgets/common/pet_gif_progress_hint.dart';
import '../main/main_shell_scope.dart';

class MemorialListScreen extends StatefulWidget {
  const MemorialListScreen({super.key});

  @override
  State<MemorialListScreen> createState() => _MemorialListScreenState();
}

class _MemorialListScreenState extends State<MemorialListScreen> {
  final _petCardKey = GlobalKey();
  bool _isGridView = false;
  bool _summonGifLoading = false;
  PetGifTaskResult? _gifProgress;

  late final Listenable _rebuildListenable = Listenable.merge([
    LanguageService.instance,
    MemorialStore.instance,
    DayTickService.instance,
  ]);

  @override
  void initState() {
    super.initState();
    AppCacheStore.instance.addListener(_onPetChanged);
    unawaited(_loadViewMode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onPetChanged();
      AppUpdateUtil.checkOnHomeLaunch(context);
      if (mounted) {
        PetImageCache.instance.precache(context, PetDisplayImage.resolveRawSync());
      }
    });
  }

  @override
  void dispose() {
    AppCacheStore.instance.removeListener(_onPetChanged);
    super.dispose();
  }

  Future<void> _loadViewMode() async {
    final isGrid = await MemorialListViewPrefs.loadIsGrid();
    if (mounted) setState(() => _isGridView = isGrid);
  }

  void _toggleViewMode() {
    final next = !_isGridView;
    setState(() => _isGridView = next);
    unawaited(MemorialListViewPrefs.saveIsGrid(next));
  }

  void _onPetChanged() {
    if (!mounted) return;
    MemorialStore.instance.ensureMemorialsLoaded();
    PlatformPetSync.afterProfileUpdate();
  }

  void _openDayDetail(MemorialDay day) {
    context.push(AppRoutes.memorialDetail(day.id));
  }

  Future<void> _openEditor(MemorialDay day) async {
    await context.push(AppRoutes.memorialEdit(day.id));
  }

  Future<void> _confirmDelete(MemorialDay day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('memorial.delete_title')),
        content: Text(
          '${tr('memorial.delete_prefix')}${day.title}${tr('memorial.delete_suffix')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr('common.delete'),
              style: const TextStyle(color: AppColors.delete),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final store = MemorialStore.instance;
        final msg = await store.deleteAnniversary(
          day.id,
          updateLocal: false,
        );
        if (!mounted) return;
        await showCenterTip(
          context,
          msg,
          onVisible: () {
            store.applyDeleteLocally(day.id);
          },
        );
      } on ApiException catch (e) {
        if (!mounted) return;
        showCenterTip(context, e.message);
      }
    }
  }

  Future<void> _onSummonOrRecallTap() async {
    if (_summonGifLoading) return;

    final shell = MainShellScope.of(context);
    if (shell.isPetVisible) {
      shell.recallPet();
      return;
    }

    final box = _petCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final cardTop = box.localToGlobal(Offset.zero).dy;
    final anchor = Offset(0, cardTop);

    final existingGif = PetGifService.existingAnimatedImageUrl();
    if (existingGif != null && existingGif.isNotEmpty) {
      shell.summonPet(anchor, animatedImage: existingGif);
      return;
    }

    setState(() {
      _summonGifLoading = true;
      _gifProgress = const PetGifTaskResult(status: 0);
    });

    String? gifUrl;
    try {
      gifUrl = await PetGifService.resolveAnimatedImage(
        onProgress: (result) {
          if (!mounted) return;
          setState(() => _gifProgress = result);
        },
      );
    } on ApiException catch (e) {
      if (mounted) {
        showCenterTip(
          context,
          e.message.isNotEmpty ? e.message : tr('summon.failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _summonGifLoading = false;
          _gifProgress = null;
        });
      }
    }

    if (!mounted) return;

    if (gifUrl != null && gifUrl.isNotEmpty) {
      AppCacheStore.instance.setAnimatedImage(gifUrl);
      shell.summonPet(anchor, animatedImage: gifUrl);
      return;
    }

    shell.summonPet(anchor);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _rebuildListenable,
      builder: (context, _) {
        final isPetVisible = MainShellScope.of(context).isPetVisible;
        final store = MemorialStore.instance;
        final memorialDays = store.items;
        final isLoading =
            store.isLoadingList && memorialDays.isEmpty;

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                AppLayout.homeTopPadding,
                16,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListenableBuilder(
                    listenable: AppCacheStore.instance,
                    builder: (context, _) => _buildPetCard(
                      isPetVisible,
                      summonGifLoading: _summonGifLoading,
                      gifProgress: _gifProgress,
                    ),
                  ),
                  const SizedBox(height: 17),
                  _buildSectionHeader(context),
                  SizedBox(
                    height: _isGridView
                        ? AppLayout.memorialSectionListGap
                        : 12,
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        _buildMemorialList(
                          memorialDays,
                          isLoading,
                          _isGridView,
                        ),
                        if (!isLoading)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 8 + AppLayout.bottomNavBarInset,
                            child: Center(child: _buildAddButton(context)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemorialList(
    List<MemorialDay> memorialDays,
    bool isLoading,
    bool isGridView,
  ) {
    if (isLoading) {
      return const Positioned.fill(
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    }

    if (memorialDays.isEmpty) {
      return Positioned.fill(
        child: Padding(
          padding: EdgeInsets.only(bottom: AppLayout.memorialListBottomInset),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  tr('memorial.empty_list'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final listBottomPadding = isLoading
        ? 8.0
        : AppLayout.memorialListBottomInset;

    if (isGridView) {
      return Positioned.fill(
        child: GridView.builder(
          padding: EdgeInsets.fromLTRB(
            AppLayout.memorialGridListHorizontalInset,
            AppLayout.memorialGridPinTopInset,
            AppLayout.memorialGridListHorizontalInset,
            listBottomPadding,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppLayout.memorialGridMainAxisSpacing,
            crossAxisSpacing: AppLayout.memorialGridCrossAxisSpacing,
            childAspectRatio: AppLayout.memorialGridChildAspectRatio,
          ),
          itemCount: memorialDays.length,
          itemBuilder: (context, index) {
            final day = memorialDays[index];
            return MemorialGridCard(
              key: ValueKey('grid-${day.id}'),
              memorialDay: day,
              onTap: () => _openDayDetail(day),
            );
          },
        ),
      );
    }

    return Positioned.fill(
      child: ListView.separated(
        padding: EdgeInsets.only(bottom: listBottomPadding),
        itemCount: memorialDays.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final day = memorialDays[index];
          return MemorialCard(
            key: ValueKey(day.id),
            memorialDay: day,
            onTap: () => _openDayDetail(day),
            onEdit: () => _openEditor(day),
            onDelete: () => _confirmDelete(day),
          );
        },
      ),
    );
  }

  Widget _buildPetCard(
    bool isPetVisible, {
    required bool summonGifLoading,
    PetGifTaskResult? gifProgress,
  }) {
    final pet = AppCacheStore.instance.petProfile;
    final nickname = pet?['nickname']?.toString() ?? '';
    final image = PetDisplayImage.resolveRawSync() ?? '';
    final days = AppCacheStore.instance.accompanyDays;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          key: _petCardKey,
          padding: AppLayout.petCardPadding,
          decoration: BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.circular(AppLayout.petCardBorderRadius),
            border: Border.all(
              color: AppColors.borderPlaceholder.withValues(alpha: 0.2),
            ),
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
              SizedBox(
                width: AppLayout.petAvatarSize,
                height: AppLayout.petAvatarSize,
                child: PetAvatarImage(
                  key: ValueKey('home-pet-avatar-$image'),
                  url: image,
                  width: AppLayout.petAvatarSize,
                  height: AppLayout.petAvatarSize,
                ),
              ),
              const SizedBox(width: AppLayout.petCardAvatarGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentDark,
                      ),
                    ),
                    const SizedBox(height: AppLayout.petCardTextGap),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.favorite,
                            size: 14,
                            color: AppColors.accent.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: tr('memorial.days_prefix'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                                TextSpan(
                                  text: '$days',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentDark,
                                  ),
                                ),
                                TextSpan(
                                  text: tr('memorial.days_suffix'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GradientTapButton(
                onTap: summonGifLoading ? null : _onSummonOrRecallTap,
                gradient: AppColors.avatarGenerateGradient,
                borderRadius: 999,
                width: AppLayout.petSummonButtonMaxWidth,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  isPetVisible
                      ? tr('memorial.recall_pet')
                      : summonGifLoading
                          ? tr('summon.preparing_short')
                          : tr('memorial.summon_pet'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.avatarGenerateButtonText,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (gifProgress != null)
          Positioned(
            top: -52,
            right: 8,
            child: PetGifProgressHint(
              progress: gifProgress,
              petImageUrl: image,
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppLayout.memorialSectionTitleInset,
        right: 4,
      ),
      child: Row(
        children: [
          Text(
            tr('memorial.section_title'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF765933),
            ),
          ),
          ...List.generate(
            3,
            (index) => Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 8 : 2,
                top: 4,
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 12,
                color: AppColors.accent.withValues(alpha: 0.85),
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _toggleViewMode,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              _isGridView
                  ? 'assets/images/image_88.png'
                  : 'assets/images/image_87.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.memorialAdd),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/addvalentine.png',
            width: 72,
            height: 72,
            fit: BoxFit.contain,
          ),
          Text(
            tr('memorial.add_new'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.accentDark,
            ),
          ),
        ],
      ),
    );
  }
}
