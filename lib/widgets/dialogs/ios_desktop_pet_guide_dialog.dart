import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../l10n/tr.dart';
import '../../services/live_activity_service.dart';
import '../../utils/center_tip_util.dart';
import '../../widgets/common/settings_item.dart';

/// iOS「桌面悬浮宠物」引导：萌宠组件 + 灵动岛 双 Tab
class IosDesktopPetGuideDialog extends StatefulWidget {
  final bool liveActivityEnabled;
  final Future<void> Function(bool enabled)? onLiveActivityChanged;

  const IosDesktopPetGuideDialog({
    super.key,
    required this.liveActivityEnabled,
    this.onLiveActivityChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required bool liveActivityEnabled,
    Future<void> Function(bool enabled)? onLiveActivityChanged,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => IosDesktopPetGuideDialog(
        liveActivityEnabled: liveActivityEnabled,
        onLiveActivityChanged: onLiveActivityChanged,
      ),
    );
  }

  static const _widgetSlides = [
    _GuideSlide(
      imageAsset: 'assets/images/desktopcomponent1.jpg',
      titleKey: 'ios_desktop_guide.widget_step1_title',
      bodyKey: 'ios_desktop_guide.widget_step1_body',
    ),
    _GuideSlide(
      imageAsset: 'assets/images/desktopcomponent2.jpg',
      titleKey: 'ios_desktop_guide.widget_step2_title',
      bodyKey: 'ios_desktop_guide.widget_step2_body',
    ),
  ];

  static const _islandSlides = [
    _GuideSlide(
      titleKey: 'ios_desktop_guide.island_step1_title',
      bodyKey: 'ios_desktop_guide.island_step1_body',
    ),
    _GuideSlide(
      titleKey: 'ios_desktop_guide.island_step2_title',
      bodyKey: 'ios_desktop_guide.island_step2_body',
    ),
  ];

  @override
  State<IosDesktopPetGuideDialog> createState() =>
      _IosDesktopPetGuideDialogState();
}

class _GuideSlide {
  final String? imageAsset;
  final String titleKey;
  final String bodyKey;

  const _GuideSlide({
    this.imageAsset,
    required this.titleKey,
    required this.bodyKey,
  });
}

class _IosDesktopPetGuideDialogState extends State<IosDesktopPetGuideDialog> {
  static const _tabWidget = 0;
  static const _tabIsland = 1;
  static const _hintTextColor = AppColors.accentDarker;
  static const _bookmarkColor = Color(0xFFF8A59A);
  static const _bookmarkAsset = 'assets/images/image_43.png';
  static const _leftCatPawTop = 309.0;

  int _tabIndex = _tabWidget;
  int _pageIndex = 0;
  late bool _liveActivityEnabled;
  late PageController _pageController;

  List<_GuideSlide> get _slides => _tabIndex == _tabWidget
      ? IosDesktopPetGuideDialog._widgetSlides
      : IosDesktopPetGuideDialog._islandSlides;

  @override
  void initState() {
    super.initState();
    _liveActivityEnabled = widget.liveActivityEnabled;
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_tabIndex == index) return;
    setState(() {
      _tabIndex = index;
      _pageIndex = 0;
    });
    _pageController.jumpToPage(0);
  }

  Future<void> _onLiveActivityToggle(bool enabled) async {
    if (!await LiveActivityService.instance.isSupported()) {
      if (!mounted) return;
      showCenterTip(context, tr('live_activity.unsupported'));
      return;
    }

    if (enabled) {
      final systemEnabled =
          await LiveActivityService.instance.areActivitiesEnabled();
      if (!systemEnabled) {
        if (!mounted) return;
        showCenterTip(context, tr('live_activity.system_disabled'));
        return;
      }
    }

    final ok = await LiveActivityService.instance.setEnabled(enabled);
    if (!mounted) return;
    if (!ok && enabled) {
      showCenterTip(context, tr('live_activity.enable_failed'));
      return;
    }

    setState(() => _liveActivityEnabled = enabled);
    await widget.onLiveActivityChanged?.call(enabled);
    if (enabled && mounted) {
      showCenterTip(context, tr('live_activity.enabled_tip'));
    }
  }

  void _previewImage(String assetPath) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.asset(assetPath, fit: BoxFit.contain),
            ),
            IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  bool get _showLiveActivitySwitch =>
      _tabIndex == _tabIsland && _pageIndex == 0;

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_pageIndex.clamp(0, _slides.length - 1)];

    return Dialog(
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.none,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTabs(),
                    const SizedBox(height: 10),
                    _buildCarouselCard(),
                    const SizedBox(height: 12),
                    _buildInstructionCard(slide),
                    if (_showLiveActivitySwitch) ...[
                      const SizedBox(height: 10),
                      _buildLiveActivitySwitch(),
                    ],
                  ],
                ),
                Positioned(
                  left: -12,
                  top: _leftCatPawTop,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/catspaw2.png',
                      width: 46,
                      height: 46,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 172,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/catspaw1.png',
                width: 42,
                height: 42,
                fit: BoxFit.contain,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
          Positioned(
            top: -20,
            right: 16,
            child: _buildBookmark(),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmark() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 30,
        height: 60,
        padding: const EdgeInsets.only(top: 35),
        alignment: Alignment.topCenter,
        decoration: BoxDecoration(
          color: _bookmarkColor.withValues(alpha: 0.88),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Image.asset(
          _bookmarkAsset,
          width: 15,
          height: 15,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildTabs() {
    Widget tab(String label, int index) {
      final selected = _tabIndex == index;
      return GestureDetector(
        onTap: () => _selectTab(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.petTypeAiButton : AppColors.bgWhite,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color:
                  selected ? AppColors.petTypeAiButton : AppColors.borderMedium,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.accentDarker : AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tab(tr('ios_desktop_guide.tab_widget'), _tabWidget),
          const SizedBox(width: 12),
          tab(tr('ios_desktop_guide.tab_dynamic_island'), _tabIsland),
        ],
      ),
    );
  }

  Widget _buildCarouselCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
      child: Column(
        children: [
          SizedBox(
            height: 320,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (index) => setState(() => _pageIndex = index),
              itemBuilder: (context, index) {
                final slide = _slides[index];
                if (slide.imageAsset == null) {
                  return _buildIslandPlaceholder(index);
                }
                return GestureDetector(
                  onTap: () => _previewImage(slide.imageAsset!),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Image.asset(
                      slide.imageAsset!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          _buildPageDots(),
        ],
      ),
    );
  }

  Widget _buildIslandPlaceholder(int index) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              index == 0 ? Icons.sensors : Icons.settings_outlined,
              size: 44,
              color: AppColors.accent.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 10),
            Text(
              tr(_slides[index].titleKey),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _hintTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (index) {
        final active = index == _pageIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 7 : 5,
          height: active ? 7 : 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.accent : AppColors.borderMedium,
          ),
        );
      }),
    );
  }

  Widget _buildInstructionCard(_GuideSlide slide) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(slide.titleKey),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _hintTextColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(slide.bodyKey),
            style: const TextStyle(
              fontSize: 13,
              color: _hintTextColor,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveActivitySwitch() {
    return SwitchSettingsItem(
      icon: Icons.sensors,
      title: tr('profile.dynamic_island'),
      value: _liveActivityEnabled,
      onChanged: _onLiveActivityToggle,
    );
  }
}
