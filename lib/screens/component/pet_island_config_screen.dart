import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../services/live_activity_service.dart';
import '../../services/pet_image_service.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/island_image_util.dart';
import '../../utils/island_success_dialog.dart';
import '../../utils/pet_display_image.dart';
import '../../widgets/dialogs/ios_desktop_pet_guide_dialog.dart';
import '../../widgets/common/widget_detail_scope.dart';

class PetIslandConfigScreen extends StatefulWidget {
  const PetIslandConfigScreen({super.key});

  @override
  State<PetIslandConfigScreen> createState() => _PetIslandConfigScreenState();
}

class _PetIslandConfigScreenState extends State<PetIslandConfigScreen> {
  static const _headerContentHeight = 52.0;
  static const _petKey = 'pet_island_selected_pet';
  static const _contentKey = 'pet_island_content';
  static const _enabledKey = 'pet_island_enabled';

  final _contentController = TextEditingController(text: '记录每个值得纪念的日子');
  final List<String> _petImages = [];
  String? _cloverImage;
  int _selectedPet = 0;
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildCompactIsland()),
                  const SizedBox(height: 14),
                  Center(child: _buildExpandedIsland()),
                  const SizedBox(height: 28),
                  if (widgetOptionEnabled(context, 'pet_select')) ...[
                    Text(
                      widgetOptionLabel(context, 'pet_select', '选择显示宠物'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPetPicker(),
                  ],
                  if (widgetOptionEnabled(context, 'custom_text')) ...[
                    const SizedBox(height: 20),
                    Text(
                      widgetOptionLabel(context, 'custom_text', '编辑内容'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _contentController,
                      maxLength: 24,
                      maxLines: 1,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.borderLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Text(
            '系统限制灵动岛后台最多保持8-12小时\n消失后请重新开启',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.5,
              fontSize: 11,
              color: AppColors.textPlaceholder,
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(46, 12, 46, 18),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.avatarGenerateGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _busy ? null : _toggleIsland,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : Text(
                              _enabled ? '关闭灵动岛' : '开启灵动岛',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentDarker,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: _headerContentHeight + AppLayout.memorialDetailTopPadding,
      backgroundColor: const Color(0xFFF7F8FB),
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 72,
      leading: GestureDetector(
        onTap: () => context.pop(),
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.only(
            left: 12,
            top: AppLayout.memorialDetailTopPadding,
          ),
          child: SizedBox(
            height: _headerContentHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios_new,
                  size: 14,
                  color: AppColors.accentDark,
                ),
                SizedBox(width: 4),
                Text(
                  '返回',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      centerTitle: true,
      title: const Padding(
        padding: EdgeInsets.only(top: AppLayout.memorialDetailTopPadding),
        child: SizedBox(
          height: _headerContentHeight,
          child: Center(
            child: Text(
              '宠物岛',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: _showTutorial,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 10,
              top: AppLayout.memorialDetailTopPadding,
            ),
            child: SizedBox(
              height: _headerContentHeight,
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0EC),
                    shape: BoxShape.circle,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.question_mark,
                        size: 13,
                        color: AppColors.accent,
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Text(
                          '教程',
                          style: TextStyle(
                            height: 1,
                            fontSize: 8,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactIsland() {
    return Container(
      width: 150,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _selectedPetImage(size: 20),
          const Spacer(),
          if (_cloverImage != null && _cloverImage!.isNotEmpty)
            Image.network(
              _cloverImage!,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedIsland() {
    return Container(
      width: kIslandPreviewCardWidth,
      height: kIslandPreviewCardHeight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC5D6E2), Color(0xFFAFBDF1)],
        ),
        image: widgetDefaultBackgroundDecoration(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _selectedPetImage(size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _contentController.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetPicker() {
    if (_petImages.isEmpty) {
      return const SizedBox(
        height: 66,
        child: Align(
          alignment: Alignment.centerLeft,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    }
    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _petImages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final selected = index == _selectedPet;
          return GestureDetector(
            onTap: () => setState(() => _selectedPet = index),
            child: Container(
              width: 66,
              height: 66,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: _petImage(_petImages[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _selectedPetImage({required double size}) {
    if (_petImages.isEmpty) {
      return Icon(Icons.pets, size: size * 0.7, color: AppColors.accentDark);
    }
    return SizedBox(
      width: size,
      height: size,
      child: _petImage(_petImages[_selectedPet]),
    );
  }

  Widget _petImage(String source) {
    return Image.network(
      source,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.pets, color: AppColors.accentDark),
    );
  }

  Future<void> _prepare() async {
    final cache = AppCacheStore.instance;
    await cache.fetchConfig();
    final prefs = await SharedPreferences.getInstance();
    final images = <String>[];
    void add(String? value) {
      final image = value?.trim() ?? '';
      if (image.isNotEmpty && !images.contains(image)) images.add(image);
    }

    add(cache.liveActivityDogImageUrl);
    add(cache.liveActivityCatImageUrl);
    if (PetDisplayImage.isCustomPet(cache.petProfile)) {
      final profile = await PetDisplayImage.resolveUrl();
      add(profile);
    }
    final selected = prefs.getInt(_petKey) ?? 0;
    final content = prefs.getString(_contentKey);
    final enabled = prefs.getBool(_enabledKey) ?? false;
    if (!mounted) return;
    setState(() {
      _petImages
        ..clear()
        ..addAll(images.map(PetImageService.resolveUrl));
      _cloverImage = cache.fourCloverImageUrl;
      _selectedPet = selected.clamp(
        0,
        _petImages.isEmpty ? 0 : _petImages.length - 1,
      );
      if (content != null && content.isNotEmpty) {
        _contentController.text = content;
      }
      _enabled = enabled;
    });
  }

  Future<void> _toggleIsland() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    final prefs = await SharedPreferences.getInstance();
    final nextEnabled = !_enabled;
    final content = _contentController.text.trim();
    await Future.wait([
      prefs.setInt(_petKey, _selectedPet),
      prefs.setString(_contentKey, content),
    ]);

    if (nextEnabled) {
      final petUrl = _petImages.isEmpty ? '' : _petImages[_selectedPet];
      final bannerBg =
          WidgetDetailScope.maybeOf(context)?.defaultBackground.trim() ?? '';
      const bgColor = Color(0xFFC5D6E2);
      if (bannerBg.isNotEmpty) {
        await prefs.setString('pet_island_banner_bg', bannerBg);
      } else {
        await prefs.remove('pet_island_banner_bg');
      }
      await prefs.setInt('pet_island_bg_color', bgColor.toARGB32());
      final ok = await LiveActivityService.instance.startOrUpdateIsland(
        template: 1,
        payload: {
          'petName': AppCacheStore.instance.petProfile?['nickname']
                  ?.toString()
                  .trim() ??
              AppCacheStore.instance.petProfile?['name']?.toString().trim() ??
              '宠物',
          'subtitle': content.isEmpty ? '记录每个值得纪念的日子' : content,
          'memorialTitle': '',
          'backgroundColorARGB': bgColor.toARGB32(),
        },
        assetPaths: {
          'petUrl': petUrl,
          'cloverUrl': _cloverImage,
          if (bannerBg.isNotEmpty) 'bannerBg': bannerBg,
        },
      );
      if (!mounted) return;
      if (!ok) {
        setState(() => _busy = false);
        await showCenterTip(context, '上岛失败，请在系统设置中开启实时活动');
        return;
      }
      await prefs.setBool(_enabledKey, true);
      setState(() {
        _enabled = true;
        _busy = false;
      });
      if (!mounted) return;
      await showIslandSuccessDialog(context);
      return;
    }

    await LiveActivityService.instance.disableIsland(1);
    await prefs.setBool(_enabledKey, false);
    if (!mounted) return;
    setState(() {
      _enabled = false;
      _busy = false;
    });
  }

  Future<void> _showTutorial() async {
    await IosDesktopPetGuideDialog.show(context, liveActivityEnabled: false);
  }
}
