import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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

class CustomIslandConfigScreen extends StatefulWidget {
  const CustomIslandConfigScreen({super.key});

  @override
  State<CustomIslandConfigScreen> createState() =>
      _CustomIslandConfigScreenState();
}

class _CustomIslandConfigScreenState extends State<CustomIslandConfigScreen> {
  static const _headerHeight = 52.0;
  static const _prefix = 'custom_island';
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
    Color(0xFFE76BF3),
    Color(0xFFFF6271),
  ];

  final _controller = TextEditingController(text: '每天都要开心');
  String? _panelImagePath;
  String? _leftIconImagePath;
  String? _rightIconImagePath;
  String _leftIcon = '🌈';
  String _rightIcon = '🔔';
  Color _textColor = Colors.white;
  bool _editingRightIcon = false;
  Offset _textPosition = const Offset(.58, .72);
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
                  Center(child: _panelPreview()),
                  const SizedBox(height: 26),
                  if (widgetOptionEnabled(context, 'upload_image')) ...[
                    _title(
                      widgetOptionLabel(context, 'upload_image', '编辑灵动面板'),
                    ),
                    const SizedBox(height: 10),
                    _albumButton(_pickPanelImage),
                  ],
                  if (widgetOptionEnabled(context, 'custom_text')) ...[
                    const SizedBox(height: 18),
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
                  ],
                  if (widgetOptionEnabled(context, 'text_color')) ...[
                    const SizedBox(height: 18),
                    _title(widgetOptionLabel(context, 'text_color', '文字颜色')),
                    const SizedBox(height: 10),
                    _colorPicker(),
                  ],
                  if (widgetOptionEnabled(context, 'icon') ||
                      widgetOptionEnabled(context, 'icon_position')) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _title(
                            widgetOptionLabel(context, 'icon', '编辑图标'),
                          ),
                        ),
                        if (widgetOptionEnabled(context, 'icon_position'))
                          _positionControl(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _albumButton(_pickIconImage),
                        const SizedBox(width: 12),
                        _iconButton(
                          selected: _activeIconImagePath == null,
                          onTap: _showEmojiPicker,
                          child: Text(
                            _activeIcon,
                            style: const TextStyle(fontSize: 23),
                          ),
                        ),
                      ],
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
              '自定义',
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

  Widget _compactPreview() {
    return Container(
      width: 150,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _selectedIcon(24, right: false),
          const Spacer(),
          _selectedIcon(24, right: true),
        ],
      ),
    );
  }

  Widget _panelPreview() {
    return SizedBox(
      width: kIslandPreviewCardWidth,
      height: kIslandPreviewCardHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final left = _textPosition.dx * (constraints.maxWidth - 100);
            final top = _textPosition.dy * (constraints.maxHeight - 28);
            return Stack(
              fit: StackFit.expand,
              children: [
                _panelImage(),
                Positioned(
                  left: left,
                  top: top,
                  right: 0,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _textPosition = Offset(
                          (_textPosition.dx +
                                  details.delta.dx /
                                      (constraints.maxWidth - 100))
                              .clamp(0, 1),
                          (_textPosition.dy +
                                  details.delta.dy /
                                      (constraints.maxHeight - 28))
                              .clamp(0, 1),
                        );
                      });
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 3,
                        ),
                        child: Text(
                          _controller.text.trim().isEmpty
                              ? '请输入文字'
                              : _controller.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _panelImage() {
    if (_panelImagePath != null) {
      return islandImage(
        _panelImagePath,
        width: kIslandPreviewCardWidth,
        height: kIslandPreviewCardHeight,
        fit: BoxFit.cover,
        placeholder: Image.asset(
          'assets/images/image_87.png',
          fit: BoxFit.cover,
        ),
      );
    }
    final defaultBackground = WidgetDetailScope.maybeOf(
      context,
    )?.defaultBackground.trim();
    if (defaultBackground != null && defaultBackground.isNotEmpty) {
      return islandImage(
        defaultBackground,
        width: kIslandPreviewCardWidth,
        height: kIslandPreviewCardHeight,
        fit: BoxFit.cover,
        placeholder: Image.asset(
          'assets/images/image_87.png',
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset('assets/images/image_87.png', fit: BoxFit.cover);
  }

  String? get _activeIconImagePath =>
      _editingRightIcon ? _rightIconImagePath : _leftIconImagePath;

  String get _activeIcon => _editingRightIcon ? _rightIcon : _leftIcon;

  Widget _selectedIcon(double size, {required bool right}) {
    final imagePath = right ? _rightIconImagePath : _leftIconImagePath;
    final icon = right ? _rightIcon : _leftIcon;
    if (imagePath != null) {
      return ClipOval(
        child: islandImage(imagePath, width: size, height: size),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          icon,
          style: TextStyle(fontSize: size * .72, height: 1),
        ),
      ),
    );
  }

  Widget _title(String value) => Text(
    value,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );

  Widget _albumButton(VoidCallback onTap) => _iconButton(
    onTap: onTap,
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo_outlined, size: 20),
        SizedBox(height: 2),
        Text('相册', style: TextStyle(fontSize: 9)),
      ],
    ),
  );

  Widget _iconButton({
    required VoidCallback onTap,
    required Widget child,
    bool selected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F4),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _positionControl() {
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [_positionButton('左侧', false), _positionButton('右侧', true)],
      ),
    );
  }

  Widget _positionButton(String label, bool right) {
    final selected = _editingRightIcon == right;
    return InkWell(
      onTap: () => setState(() => _editingRightIcon = right),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? AppColors.textPrimary : AppColors.textPlaceholder,
          ),
        ),
      ),
    );
  }

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
          onTap: () => setState(() => _textColor = color),
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

  Future<void> _pickCustomColor() async {
    final color = await showComponentColorPicker(
      context,
      initialColor: _textColor,
    );
    if (color != null && mounted) setState(() => _textColor = color);
  }

  Future<void> _pickPanelImage() async {
    final url = await pickAndUploadIslandImage(context);
    if (url != null && url.isNotEmpty && mounted) {
      setState(() => _panelImagePath = url);
    }
  }

  Future<void> _pickIconImage() async {
    final url = await pickAndUploadIslandImage(context);
    if (url != null && url.isNotEmpty && mounted) {
      setState(() {
        if (_editingRightIcon) {
          _rightIconImagePath = url;
        } else {
          _leftIconImagePath = url;
        }
      });
    }
  }

  Future<void> _showEmojiPicker() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 370,
          child: EmojiPicker(
            onEmojiSelected: (_, emoji) =>
                Navigator.of(context).pop(emoji.emoji),
            config: const Config(
              height: 370,
              emojiViewConfig: EmojiViewConfig(
                columns: 8,
                emojiSizeMax: 28,
                backgroundColor: Colors.white,
              ),
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: Colors.white,
                indicatorColor: AppColors.accent,
                iconColorSelected: AppColors.accent,
                showBackspaceButton: false,
              ),
              bottomActionBarConfig: BottomActionBarConfig(
                enabled: false,
                showBackspaceButton: false,
                showSearchViewButton: false,
              ),
            ),
          ),
        ),
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (_editingRightIcon) {
        _rightIcon = value;
        _rightIconImagePath = null;
      } else {
        _leftIcon = value;
        _leftIconImagePath = null;
      }
    });
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _controller.text = prefs.getString('${_prefix}_content') ?? '每天都要开心';
      _panelImagePath = prefs.getString('${_prefix}_panel_image');
      _leftIconImagePath =
          prefs.getString('${_prefix}_left_icon_image') ??
          prefs.getString('${_prefix}_icon_image');
      _rightIconImagePath = prefs.getString('${_prefix}_right_icon_image');
      _leftIcon =
          prefs.getString('${_prefix}_left_icon') ??
          prefs.getString('${_prefix}_icon') ??
          '🌈';
      _rightIcon = prefs.getString('${_prefix}_right_icon') ?? '🔔';
      _textColor = Color(
        prefs.getInt('${_prefix}_text_color') ?? Colors.white.toARGB32(),
      );
      _editingRightIcon = false;
      _textPosition = Offset(
        prefs.getDouble('${_prefix}_text_x') ?? .58,
        prefs.getDouble('${_prefix}_text_y') ?? .72,
      );
      _enabled = prefs.getBool('${_prefix}_enabled') ?? false;
    });
  }

  Future<void> _toggle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    final next = !_enabled;
    final prefs = await SharedPreferences.getInstance();
    final content = _controller.text.trim();
    await Future.wait([
      prefs.setString('${_prefix}_content', content),
      if (_panelImagePath != null)
        prefs.setString('${_prefix}_panel_image', _panelImagePath!),
      _leftIconImagePath != null
          ? prefs.setString('${_prefix}_left_icon_image', _leftIconImagePath!)
          : prefs.remove('${_prefix}_left_icon_image'),
      _rightIconImagePath != null
          ? prefs.setString('${_prefix}_right_icon_image', _rightIconImagePath!)
          : prefs.remove('${_prefix}_right_icon_image'),
      prefs.setString('${_prefix}_left_icon', _leftIcon),
      prefs.setString('${_prefix}_right_icon', _rightIcon),
      prefs.setInt('${_prefix}_text_color', _textColor.toARGB32()),
      prefs.setDouble('${_prefix}_text_x', _textPosition.dx),
      prefs.setDouble('${_prefix}_text_y', _textPosition.dy),
    ]);

    if (next) {
      final ok = await LiveActivityService.instance.startOrUpdateIsland(
        template: 6,
        payload: {
          'petName': content.isEmpty ? '自定义' : content,
          'subtitle': content.isEmpty ? '每天都要开心' : content,
          'memorialTitle': '',
          'textColorARGB': _textColor.toARGB32(),
          'textNormX': _textPosition.dx,
          'textNormY': _textPosition.dy,
          'compactLeadingEmoji': _leftIcon,
          'compactTrailingEmoji': _rightIcon,
        },
        assetPaths: {
          if (_panelImagePath != null) 'panel': _panelImagePath,
          if (_leftIconImagePath != null) 'leftIcon': _leftIconImagePath,
          if (_rightIconImagePath != null) 'rightIcon': _rightIconImagePath,
        },
      );
      if (!mounted) return;
      if (!ok) {
        setState(() => _busy = false);
        await showCenterTip(context, '上岛失败，请在系统设置中开启实时活动');
        return;
      }
      await prefs.setBool('${_prefix}_enabled', true);
      setState(() {
        _enabled = true;
        _busy = false;
      });
      if (!mounted) return;
      await showIslandSuccessDialog(context);
      return;
    }

    await LiveActivityService.instance.disableIsland(6);
    await prefs.setBool('${_prefix}_enabled', false);
    if (!mounted) return;
    setState(() {
      _enabled = false;
      _busy = false;
    });
  }
}
