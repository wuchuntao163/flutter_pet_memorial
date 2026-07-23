import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../services/live_activity_service.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/island_image_util.dart';
import '../../utils/island_success_dialog.dart';
import '../../widgets/dialogs/ios_desktop_pet_guide_dialog.dart';
import '../../widgets/common/widget_detail_scope.dart';
import 'pet_widget_config_screen.dart' show showComponentColorPicker;

class PhotoIslandConfigScreen extends StatefulWidget {
  const PhotoIslandConfigScreen({super.key});

  @override
  State<PhotoIslandConfigScreen> createState() =>
      _PhotoIslandConfigScreenState();
}

class _PhotoIslandConfigScreenState extends State<PhotoIslandConfigScreen> {
  static const _headerHeight = 52.0;
  static const _contentKey = 'photo_island_content';
  static const _imageKey = 'photo_island_image';
  static const _colorKey = 'photo_island_color';
  static const _sizeKey = 'photo_island_font_size';
  static const _enabledKey = 'photo_island_enabled';
  static const _colors = [
    Colors.white,
    Color(0xFF111111),
    Color(0xFFFFA49D),
    Color(0xFFFF956E),
    Color(0xFFFFC85D),
    Color(0xFFB6F36C),
    Color(0xFF83E7B5),
    Color(0xFF62D8F4),
    Color(0xFF6695F5),
    Color(0xFFB36EF3),
    Color(0xFFFF6271),
  ];

  final _controller = TextEditingController(text: '笨猫真可爱 >.<');
  String? _imagePath;
  Color _textColor = Colors.white;
  double _fontSize = 16;
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: _appBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _compactPreview()),
                  const SizedBox(height: 14),
                  Center(child: _expandedPreview()),
                  const SizedBox(height: 28),
                  if (widgetOptionEnabled(context, 'upload_image')) ...[
                    _title(widgetOptionLabel(context, 'upload_image', '上传图片')),
                    const SizedBox(height: 10),
                    _albumButton(),
                    const SizedBox(height: 18),
                  ],
                  if (widgetOptionEnabled(context, 'custom_text')) ...[
                    _title(widgetOptionLabel(context, 'custom_text', '编辑内容')),
                    const SizedBox(height: 9),
                    TextField(
                      controller: _controller,
                      maxLength: 18,
                      maxLines: 1,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(fontSize: 13),
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
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
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (widgetOptionEnabled(context, 'text_color')) ...[
                    _title(widgetOptionLabel(context, 'text_color', '选择文字颜色')),
                    const SizedBox(height: 10),
                    _colorPicker(),
                    const SizedBox(height: 20),
                  ],
                  if (widgetOptionEnabled(context, 'text_size')) ...[
                    _title(widgetOptionLabel(context, 'text_size', '文字大小')),
                    const SizedBox(height: 4),
                    _fontSizeSlider(),
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
                    onTap: _busy ? null : _toggle,
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

  PreferredSizeWidget _appBar() {
    return AppBar(
      toolbarHeight: _headerHeight + AppLayout.memorialDetailTopPadding,
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
            height: _headerHeight,
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
          height: _headerHeight,
          child: Center(
            child: Text(
              '图文岛',
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
          onTap: () => IosDesktopPetGuideDialog.show(
            context,
            liveActivityEnabled: false,
          ),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 10,
              top: AppLayout.memorialDetailTopPadding,
            ),
            child: SizedBox(
              height: _headerHeight,
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

  Widget _compactPreview() => Container(
    width: 150,
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 3),
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(16),
    ),
    alignment: Alignment.centerLeft,
    // 仅相册上传图在灵动岛预览里圆形
    child: _image(26, circular: _imagePath != null),
  );

  Widget _expandedPreview() => Container(
    width: kIslandPreviewCardWidth,
    height: kIslandPreviewCardHeight,
    padding: const EdgeInsets.fromLTRB(18, 0, 12, 0),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFC7B9), Color(0xFFFFD29B)],
      ),
      image: widgetDefaultBackgroundDecoration(context),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        _image(44, circular: false),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _controller.text.trim().isEmpty ? '请输入内容' : _controller.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _image(double size, {bool circular = false}) {
    return islandCardSideImage(_imagePath, size: size, circular: circular);
  }

  Widget _title(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );

  Widget _albumButton() => InkWell(
    onTap: _pickImage,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F1F4),
        shape: BoxShape.circle,
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_outlined, size: 20),
          SizedBox(height: 2),
          Text('相册', style: TextStyle(fontSize: 9)),
        ],
      ),
    ),
  );

  Widget _colorPicker() => SizedBox(
    height: 34,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _colors.length + 1,
      separatorBuilder: (_, _) => const SizedBox(width: 7),
      itemBuilder: (context, index) {
        if (index == 0) {
          return InkWell(
            onTap: _pickCustomColor,
            child: Container(
              width: 34,
              height: 34,
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
            ),
          );
        }
        final color = _colors[index - 1];
        final selected = color.toARGB32() == _textColor.toARGB32();
        return InkWell(
          onTap: () async {
            setState(() => _textColor = color);
            await _syncLiveIfEnabled();
          },
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.borderLight,
                width: selected ? 2 : 1,
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _fontSizeSlider() {
    const labelStyle = TextStyle(
      fontSize: 13,
      color: AppColors.textPlaceholder,
    );
    return Row(
      children: [
        const Text('小', style: labelStyle),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 36,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final progress = (_fontSize - 12) / 12;
                const sideInset = 12.0;
                const iconSize = 18.0;
                final trackWidth = constraints.maxWidth - sideInset * 2;
                final iconLeft =
                    sideInset + trackWidth * progress - iconSize / 2;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor: AppColors.borderLight,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 0,
                        ),
                        trackHeight: 2,
                      ),
                      child: Slider(
                        value: _fontSize,
                        min: 12,
                        max: 24,
                        onChanged: (value) => setState(() => _fontSize = value),
                        onChangeEnd: (_) => _syncLiveIfEnabled(),
                      ),
                    ),
                    Positioned(
                      left: iconLeft,
                      top: 7,
                      child: IgnorePointer(
                        child: Image.asset(
                          'assets/images/image_18.png',
                          width: iconSize,
                          height: iconSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text('大', style: labelStyle),
      ],
    );
  }

  Future<void> _pickCustomColor() async {
    final color = await showComponentColorPicker(
      context,
      initialColor: _textColor,
    );
    if (color != null && mounted) {
      setState(() => _textColor = color);
      await _syncLiveIfEnabled();
    }
  }

  Future<void> _syncLiveIfEnabled() async {
    if (!_enabled) return;
    final bannerBg =
        WidgetDetailScope.maybeOf(context)?.defaultBackground.trim() ?? '';
    final content = _controller.text.trim();
    final bgColor = const Color(0xFFFFC7B9).toARGB32();
    await LiveActivityService.instance.startOrUpdateIsland(
      template: 2,
      payload: {
        'petName': content.isEmpty ? '图文岛' : content,
        'subtitle': content.isEmpty ? '笨猫真可爱 >.<' : content,
        'memorialTitle': '',
        'textColorARGB': _textColor.toARGB32(),
        'textFontSize': _fontSize,
        'backgroundColorARGB': bgColor,
      },
      assetPaths: {
        'photo': _effectivePhotoPath,
        if (bannerBg.isNotEmpty) 'bannerBg': bannerBg,
      },
    );
  }

  /// 与预览一致：有相册用相册，否则用默认图
  String get _effectivePhotoPath {
    final path = _imagePath?.trim() ?? '';
    return path.isNotEmpty ? path : kPhotoIslandDefaultImage;
  }

  Future<void> _pickImage() async {
    final url = await pickAndUploadIslandImage(context);
    if (url != null && url.isNotEmpty && mounted) {
      setState(() => _imagePath = url);
    } else if (mounted && url == null) {
      // 用户取消不提示；上传失败时 util 已打日志
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _controller.text = prefs.getString(_contentKey) ?? '笨猫真可爱 >.<';
      _imagePath = prefs.getString(_imageKey);
      _textColor = Color(prefs.getInt(_colorKey) ?? Colors.white.toARGB32());
      _fontSize = prefs.getDouble(_sizeKey) ?? 16;
      _enabled = prefs.getBool(_enabledKey) ?? false;
    });
  }

  Future<void> _toggle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    final next = !_enabled;
    final bannerBg =
        WidgetDetailScope.maybeOf(context)?.defaultBackground.trim() ?? '';
    final prefs = await SharedPreferences.getInstance();
    final content = _controller.text.trim();
    await Future.wait([
      prefs.setString(_contentKey, content),
      if (_imagePath != null) prefs.setString(_imageKey, _imagePath!),
      prefs.setInt(_colorKey, _textColor.toARGB32()),
      prefs.setDouble(_sizeKey, _fontSize),
    ]);

    if (next) {
      const bgColor = Color(0xFFFFC7B9);
      await prefs.setInt('photo_island_bg_color', bgColor.toARGB32());
      if (bannerBg.isNotEmpty) {
        await prefs.setString('photo_island_banner_bg', bannerBg);
      } else {
        await prefs.remove('photo_island_banner_bg');
      }
      final ok = await LiveActivityService.instance.startOrUpdateIsland(
        template: 2,
        payload: {
          'petName': content.isEmpty ? '图文岛' : content,
          'subtitle': content.isEmpty ? '笨猫真可爱 >.<' : content,
          'memorialTitle': '',
          'textColorARGB': _textColor.toARGB32(),
          'textFontSize': _fontSize,
          'backgroundColorARGB': bgColor.toARGB32(),
        },
        assetPaths: {
          'photo': _effectivePhotoPath,
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

    await LiveActivityService.instance.disableIsland(2);
    await prefs.setBool(_enabledKey, false);
    if (!mounted) return;
    setState(() {
      _enabled = false;
      _busy = false;
    });
  }
}
