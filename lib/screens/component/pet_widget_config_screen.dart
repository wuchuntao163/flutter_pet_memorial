import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../data/background_store.dart';
import '../../services/live_activity_service.dart';
import '../../services/pet_image_service.dart';
import '../../services/widget_service.dart';
import '../../utils/app_permission_util.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/pet_display_image.dart';
import '../../utils/pet_image_picker.dart';
import '../../utils/saving_overlay.dart';
import '../../widgets/dialogs/ios_desktop_pet_guide_dialog.dart';
import '../../widgets/common/widget_detail_scope.dart';

Future<Color?> showComponentColorPicker(
  BuildContext context, {
  required Color initialColor,
  String title = '选择背景颜色',
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) =>
        _ColorPickerDialog(initialColor: initialColor, title: title),
  );
}

class PetWidgetConfigScreen extends StatefulWidget {
  const PetWidgetConfigScreen({super.key});

  @override
  State<PetWidgetConfigScreen> createState() => _PetWidgetConfigScreenState();
}

class _PetWidgetConfigScreenState extends State<PetWidgetConfigScreen> {
  static const _headerContentHeight = 52.0;
  static const _petKey = 'component_pet_widget_pet';
  static const _backgroundImageKey = 'component_pet_widget_background_image';
  static const _backgroundModeKey = 'component_pet_widget_background_mode';
  static const _customColorKey = 'component_pet_widget_custom_color';

  int _selectedPet = 1;
  Color _customColor = const Color(0xFF98CBF2);
  String? _selectedBackgroundImage;
  /// 相册上传后的网络地址（保存用）；预览优先本地路径避免闪色
  String? _selectedBackgroundRemoteUrl;
  bool _backgroundPrefsLoaded = false;
  bool _backgroundSelectionInitialized = false;
  bool _apiDetailMode = false;
  final List<String> _petImages = [];
  final GlobalKey _previewBoundaryKey = GlobalKey();

  String? get _effectiveBackgroundImage {
    if (_selectedBackgroundImage != null) return _selectedBackgroundImage;
    final value = WidgetDetailScope.maybeOf(context)?.defaultBackground.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get _backgroundImageForPersist {
    final remote = _selectedBackgroundRemoteUrl?.trim();
    if (remote != null && remote.isNotEmpty) return remote;
    final current = _selectedBackgroundImage?.trim();
    if (current == null || current.isEmpty) return null;
    final isLocal =
        current.startsWith('/') ||
        current.startsWith('file://') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(current);
    if (isLocal) return null;
    return current;
  }

  @override
  void initState() {
    super.initState();
    BackgroundStore.instance.addListener(_onBackgroundsChanged);
    BackgroundStore.instance.fetchWidgetList(type: 1);
    _restoreBackgroundSelection();
    _preparePetChoices();
  }

  @override
  void dispose() {
    BackgroundStore.instance.removeListener(_onBackgroundsChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_apiDetailMode && WidgetDetailScope.maybeOf(context) != null) {
      _apiDetailMode = true;
      _backgroundSelectionInitialized = true;
    }
  }

  void _onBackgroundsChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = BackgroundStore.instance;
      final items = store.widgetItems(1);
      final loading = store.widgetListLoading(1);
      if (!_apiDetailMode &&
          _backgroundPrefsLoaded &&
          !_backgroundSelectionInitialized &&
          !loading) {
        if (items.isNotEmpty) {
          _selectedBackgroundImage = _backgroundImageFor(items.first);
        }
        _backgroundSelectionInitialized = true;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        toolbarHeight:
            _headerContentHeight + AppLayout.memorialDetailTopPadding,
        backgroundColor: const Color(0xFFF7F8FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 72,
        leading: GestureDetector(
          onTap: () => context.pop(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 12,
              top: AppLayout.memorialDetailTopPadding,
            ),
            child: SizedBox(
              height: _headerContentHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
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
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '我的宠物',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Positioned(
                  top: 39,
                  child: Text(
                    '小号',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
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
                    alignment: Alignment.center,
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
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildPreview()),
                  const SizedBox(height: 22),
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
                  if (widgetOptionEnabled(context, 'background')) ...[
                    const SizedBox(height: 20),
                    Text(
                      widgetOptionLabel(context, 'background', '背景'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBackgroundPicker(),
                  ],
                ],
              ),
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
                    onTap: _save,
                    borderRadius: BorderRadius.circular(12),
                    child: const Center(
                      child: Text(
                        '保存到我的组件',
                        style: TextStyle(
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

  Widget _buildPreview() {
    return RepaintBoundary(
      key: _previewBoundaryKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            color: _customColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_effectiveBackgroundImage != null)
                _backgroundPreviewImage(_effectiveBackgroundImage!),
              Padding(
                padding: const EdgeInsets.all(18),
                child: _petImages.isEmpty
                    ? const Icon(
                        Icons.pets,
                        size: 52,
                        color: AppColors.accentDark,
                      )
                    : _petImage(_petImages[_selectedPet]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetPicker() {
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
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

  Widget _buildBackgroundPicker() {
    final store = BackgroundStore.instance;
    final items = store.widgetItems(1);
    final loading = store.widgetListLoading(1);
    // 仅在首屏且无缓存时转圈；请求结束（哪怕为空）也展示相册/色盘，避免卡死
    if (!_backgroundPrefsLoaded ||
        (!_backgroundSelectionInitialized && loading && items.isEmpty)) {
      return const SizedBox(
        height: 48,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length + 2,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _backgroundOption(
              selected: false,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F1F4),
                  shape: BoxShape.circle,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_outlined, size: 20),
                    SizedBox(height: 2),
                    Text(
                      '相册',
                      style: TextStyle(
                        height: 1,
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: _pickBackgroundImage,
            );
          }
          if (index == 1) {
            return _backgroundOption(
              selected: !_apiDetailMode && _selectedBackgroundImage == null,
              child: const _ColorPaletteSwatch(),
              onTap: _selectCustomColor,
            );
          }
          final item = items[index - 2];
          final image = _backgroundImageFor(item);
          return _backgroundOption(
            selected: image.isNotEmpty && image == _selectedBackgroundImage,
            child: ClipOval(
              child: Image.network(
                image,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AppColors.bgInput),
              ),
            ),
            onTap: image.isEmpty
                ? null
                : () => setState(() {
                    _selectedBackgroundImage = image;
                    _selectedBackgroundRemoteUrl = image;
                    _backgroundSelectionInitialized = true;
                  }),
          );
        },
      ),
    );
  }

  Widget _backgroundPreviewImage(String source) {
    final isLocal =
        source.startsWith('/') ||
        source.startsWith('file://') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(source);
    if (isLocal) {
      final path = source.startsWith('file://')
          ? Uri.parse(source).toFilePath()
          : source;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  Widget _backgroundOption({
    required bool selected,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 48,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.borderMedium,
            width: selected ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );
  }

  String _backgroundImageFor(Map<String, dynamic> item) {
    final raw = item['image'] ?? item['img'] ?? item['url'];
    return PetImageService.resolveUrl(raw?.toString() ?? '');
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final path = await PetImagePicker.pickFromGallery(context);
      if (path == null || path.isEmpty || !mounted) return;
      await withSavingOverlay(context, () async {
        final created = await BackgroundStore.instance.uploadCustomBackground(
          localPath: path,
          name: '组件背景',
        );
        if (!mounted || created == null) return;
        final image = _backgroundImageFor(created);
        if (image.isEmpty) return;
        // 转圈期间缓存网络图，结束后直接显示；保存时已有稳定 URL
        await precacheImage(NetworkImage(image), context);
        if (!mounted) return;
        setState(() {
          _selectedBackgroundImage = image;
          _selectedBackgroundRemoteUrl = image;
          _backgroundSelectionInitialized = true;
        });
        await WidgetsBinding.instance.endOfFrame;
      });
    } on AppPermissionDeniedException catch (error) {
      if (!mounted) return;
      await AppPermissionUtil.showDeniedDialog(context, error);
    } catch (error) {
      if (!mounted) return;
      debugPrint('[PetWidgetConfig] upload background failed: $error');
      await showCenterTip(context, '背景上传失败');
    }
  }

  Future<void> _selectCustomColor() async {
    final selected = await showComponentColorPicker(
      context,
      initialColor: _customColor,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _customColor = selected;
      _selectedBackgroundImage = null;
      _selectedBackgroundRemoteUrl = null;
      _backgroundSelectionInitialized = true;
    });
  }

  Future<void> _showTutorial() async {
    final enabled = await LiveActivityService.instance.isEnabled();
    if (!mounted) return;
    await IosDesktopPetGuideDialog.show(context, liveActivityEnabled: enabled);
  }

  Widget _petImage(String source) {
    final isLocal =
        source.startsWith('file://') ||
        source.startsWith('/') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(source);
    final error = const Center(
      child: Icon(Icons.pets, size: 28, color: AppColors.accentDark),
    );
    if (isLocal) {
      final path = source.startsWith('file://')
          ? Uri.parse(source).toFilePath()
          : source;
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => error,
      );
    }
    return Image.network(
      source,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => error,
    );
  }

  Future<void> _save() async {
    final definition = WidgetDetailScope.maybeOf(context);
    try {
      await withSavingOverlay(context, () async {
        final prefs = await SharedPreferences.getInstance();
        final persistBg = _backgroundImageForPersist;
        if (persistBg != null &&
            (persistBg.startsWith('http://') ||
                persistBg.startsWith('https://'))) {
          await precacheImage(NetworkImage(persistBg), context);
          if (!mounted) return;
          await WidgetsBinding.instance.endOfFrame;
        }
        await Future.wait([
          prefs.setInt(_petKey, _selectedPet),
          prefs.setInt(_customColorKey, _customColor.toARGB32()),
          prefs.setString(
            _backgroundModeKey,
            _selectedBackgroundImage == null ? 'palette' : 'image',
          ),
          if (_backgroundImageForPersist == null)
            prefs.remove(_backgroundImageKey)
          else
            prefs.setString(_backgroundImageKey, _backgroundImageForPersist!),
        ]);
        await saveWidgetToLibrary(
          definition,
          settings: {
            'pet_index': _selectedPet,
            'pet_image': _petImages.isNotEmpty
                ? _petImages[_selectedPet.clamp(0, _petImages.length - 1)]
                : '',
            'background_color': _customColor.toARGB32(),
            'background_image': _backgroundImageForPersist ?? '',
          },
          previewBoundaryKey: _previewBoundaryKey,
        );
        await WidgetService.instance.updateWidget();
      });
      if (!mounted) return;
      await showCenterTip(context, '已保存到我的组件');
      if (mounted) context.pop();
    } catch (error) {
      debugPrint('[PetWidgetConfig] save failed: $error');
      if (mounted) await showCenterTip(context, '保存失败，请检查网络后重试');
    }
  }

  Future<void> _preparePetChoices() async {
    final cache = AppCacheStore.instance;
    await cache.fetchConfig();
    final prefs = await SharedPreferences.getInstance();
    final pet = prefs.getInt(_petKey);

    final images = <String>[];
    void addImage(String? image) {
      final value = image?.trim() ?? '';
      if (value.isNotEmpty && !images.contains(value)) images.add(value);
    }

    addImage(cache.defaultPetCatImageUrl);
    addImage(cache.defaultPetDogImageUrl);
    if (PetDisplayImage.isCustomPet(cache.petProfile)) {
      final profileImage = PetDisplayImage.resolveRawSync();
      addImage(
        profileImage == null ? null : PetImageService.resolveUrl(profileImage),
      );
    }
    if (!mounted) return;
    setState(() {
      _petImages
        ..clear()
        ..addAll(images);
      _selectedPet = _petImages.length > 1 ? 1 : 0;
      if (pet != null && pet >= 0 && pet < _petImages.length) {
        _selectedPet = pet;
      }
    });
  }

  Future<void> _restoreBackgroundSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final backgroundImage = prefs.getString(_backgroundImageKey);
    final backgroundMode = prefs.getString(_backgroundModeKey);
    final customColor = prefs.getInt(_customColorKey);
    if (!mounted) return;
    setState(() {
      if (customColor != null) _customColor = Color(customColor);
      _backgroundPrefsLoaded = true;
      if (_apiDetailMode) {
        _selectedBackgroundImage = null;
        _selectedBackgroundRemoteUrl = null;
        _backgroundSelectionInitialized = true;
      } else if (backgroundMode == 'palette') {
        _selectedBackgroundImage = null;
        _selectedBackgroundRemoteUrl = null;
        _backgroundSelectionInitialized = true;
      } else if (backgroundImage != null && backgroundImage.isNotEmpty) {
        _selectedBackgroundImage = backgroundImage;
        _selectedBackgroundRemoteUrl = backgroundImage;
        _backgroundSelectionInitialized = true;
      } else {
        final store = BackgroundStore.instance;
        final items = store.widgetItems(1);
        if (!store.widgetListLoading(1) && items.isNotEmpty) {
          _selectedBackgroundImage = _backgroundImageFor(items.first);
          _selectedBackgroundRemoteUrl = _selectedBackgroundImage;
          _backgroundSelectionInitialized = true;
        }
      }
    });
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;

  const _ColorPickerDialog({
    required this.initialColor,
    this.title = '选择背景颜色',
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  static const _presets = [
    Colors.black,
    Colors.white,
    Color(0xFF98CBF2),
    Color(0xFF80CBC4),
    Color(0xFFFFD166),
    Color(0xFFFF766F),
  ];

  late HSVColor _hsv;

  Color get _color => _hsv.toColor();

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            _buildSaturationValuePanel(),
            const SizedBox(height: 14),
            _buildHueSlider(),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderMedium),
                  ),
                ),
                const SizedBox(width: 10),
                for (final color in _presets) ...[
                  GestureDetector(
                    onTap: () =>
                        setState(() => _hsv = HSVColor.fromColor(color)),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderMedium),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_color),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentDarker,
                  ),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaturationValuePanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const height = 190.0;
        final width = constraints.maxWidth;
        return GestureDetector(
          onTapDown: (details) => _updateSaturationValue(
            details.localPosition,
            Size(width, height),
          ),
          onPanUpdate: (details) => _updateSaturationValue(
            details.localPosition,
            Size(width, height),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SaturationValuePainter(hue: _hsv.hue),
                    ),
                  ),
                  Positioned(
                    left: (_hsv.saturation * width - 7).clamp(0, width - 14),
                    top: ((1 - _hsv.value) * height - 7).clamp(0, height - 14),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 2),
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
    );
  }

  Widget _buildHueSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const height = 18.0;
        final width = constraints.maxWidth;
        return GestureDetector(
          onTapDown: (details) => _updateHue(details.localPosition.dx, width),
          onPanUpdate: (details) => _updateHue(details.localPosition.dx, width),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: const CustomPaint(painter: _HuePainter()),
                  ),
                ),
                Positioned(
                  left: ((_hsv.hue / 360) * width - 6).clamp(0, width - 12),
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 22,
                    decoration: BoxDecoration(
                      color: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateSaturationValue(Offset position, Size size) {
    setState(() {
      _hsv = _hsv
          .withSaturation((position.dx / size.width).clamp(0, 1))
          .withValue((1 - position.dy / size.height).clamp(0, 1));
    });
  }

  void _updateHue(double x, double width) {
    setState(() {
      _hsv = _hsv.withHue((x / width).clamp(0, 1) * 360);
    });
  }
}

class _SaturationValuePainter extends CustomPainter {
  final double hue;

  const _SaturationValuePainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) =>
      oldDelegate.hue != hue;
}

class _HuePainter extends CustomPainter {
  const _HuePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Colors.red,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.blue,
            Colors.purple,
            Colors.red,
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ColorPaletteSwatch extends StatelessWidget {
  const _ColorPaletteSwatch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Colors.red,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.blue,
            Colors.purple,
            Colors.red,
          ],
        ),
      ),
    );
  }
}
