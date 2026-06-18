import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/api.dart';
import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../data/memorial_store.dart';
import '../../widgets/common/pet_avatar_image.dart';
import '../../models/memorial_day.dart';
import '../../router/app_routes.dart';
import '../../widgets/common/gradient_tap_button.dart';
import '../../widgets/common/memorial_card.dart';
import '../../widgets/common/memorial_grid_card.dart';
import '../../l10n/tr.dart';
import '../../utils/center_tip_util.dart';
import '../../services/day_tick_service.dart';
import '../../services/language_service.dart';
import '../../services/pet_image_cache.dart';
import '../main/main_shell_scope.dart';

class MemorialListScreen extends StatefulWidget {
  const MemorialListScreen({super.key});

  @override
  State<MemorialListScreen> createState() => _MemorialListScreenState();
}

class _MemorialListScreenState extends State<MemorialListScreen> {
  final _petCardKey = GlobalKey();
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    MemorialStore.instance.addListener(_onStoreChanged);
    DayTickService.instance.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final petId = AppCacheStore.instance.petId;
      final store = MemorialStore.instance;
      if (petId != null && !store.listLoaded && !store.isLoadingList) {
        store.fetchList();
      }
      if (mounted) {
        final image = AppCacheStore.instance.petProfile?['image']?.toString();
        PetImageCache.instance.precache(context, image);
      }
    });
  }

  @override
  void dispose() {
    MemorialStore.instance.removeListener(_onStoreChanged);
    DayTickService.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
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
        final msg = await MemorialStore.instance.deleteAnniversary(day.id);
        if (!mounted) return;
        showCenterTip(context, msg);
      } on ApiException catch (e) {
        if (!mounted) return;
        showCenterTip(context, e.message);
      }
    }
  }

  void _onSummonOrRecallTap() {
    final shell = MainShellScope.of(context);
    if (shell.isPetVisible) {
      shell.recallPet();
      return;
    }

    final box = _petCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final cardTop = box.localToGlobal(Offset.zero).dy;

    // dy=卡片顶边，召唤后出现在屏幕最右侧并踩在顶边上
    shell.summonPet(Offset(0, cardTop));
  }

  @override
  Widget build(BuildContext context) {
    final isPetVisible = MainShellScope.of(context).isPetVisible;
    final store = MemorialStore.instance;
    final memorialDays = store.items;
    final petId = AppCacheStore.instance.petId;
    final isLoading =
        store.isLoadingList || (petId != null && !store.listLoaded);

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
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListenableBuilder(
                  listenable: AppCacheStore.instance,
                  builder: (context, _) => _buildPetCard(isPetVisible),
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
      ),
    );
  }

  Widget _buildMemorialList(
    List<MemorialDay> memorialDays,
    bool isLoading,
    bool isGridView,
  ) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accent,
        ),
      );
    }

    if (memorialDays.isEmpty) {
      return Center(
        child: Text(
          tr('memorial.empty_list'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
        ),
      );
    }

    final listBottomPadding = isLoading
        ? 8.0
        : AppLayout.memorialListBottomInset;

    if (isGridView) {
      return GridView.builder(
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
      );
    }

    return ListView.separated(
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
    );
  }

  Widget _buildPetCard(bool isPetVisible) {
    final pet = AppCacheStore.instance.petProfile;
    final nickname = pet?['nickname']?.toString() ?? '';
    final image = pet?['image']?.toString() ?? '';
    final days = AppCacheStore.instance.accompanyDays;

    return Container(
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
            onTap: _onSummonOrRecallTap,
            gradient: AppColors.avatarGenerateGradient,
            borderRadius: 999,
            width: AppLayout.petSummonButtonMaxWidth,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              isPetVisible
                  ? tr('memorial.recall_pet')
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
            onTap: () => setState(() => _isGridView = !_isGridView),
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
