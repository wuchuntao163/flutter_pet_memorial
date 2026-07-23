import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../services/live_activity_service.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/island_success_dialog.dart';
import '../../utils/pet_image_picker.dart';
import '../../widgets/dialogs/ios_desktop_pet_guide_dialog.dart';
import '../../widgets/common/widget_detail_scope.dart';

enum TimerIslandMode { countUp, countDown }

class TimerIslandConfigScreen extends StatefulWidget {
  const TimerIslandConfigScreen({super.key, required this.mode});

  final TimerIslandMode mode;

  @override
  State<TimerIslandConfigScreen> createState() =>
      _TimerIslandConfigScreenState();
}

class _TimerIslandConfigScreenState extends State<TimerIslandConfigScreen> {
  static const _headerContentHeight = 52.0;

  late final TextEditingController _titleController;
  TimeOfDay _targetTime = const TimeOfDay(hour: 18, minute: 30);
  String _icon = '🔔';
  String? _imagePath;
  bool _enabled = false;
  bool _busy = false;
  late DateTime _previewNow;
  Timer? _previewTicker;

  bool get _isCountUp => widget.mode == TimerIslandMode.countUp;
  String get _pageTitle => _isCountUp ? '正计时' : '倒计时';
  String get _storagePrefix =>
      _isCountUp ? 'count_up_island' : 'count_down_island';
  String get _defaultTitle => _isCountUp ? '学英语1小时已经' : '距离下班还有';
  String get _timerText {
    final now = _previewNow;
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      _targetTime.hour,
      _targetTime.minute,
    );
    late final Duration duration;
    if (_isCountUp) {
      if (target.isAfter(now)) {
        target = target.subtract(const Duration(days: 1));
      }
      duration = now.difference(target);
    } else {
      if (!target.isAfter(now)) {
        target = target.add(const Duration(days: 1));
      }
      duration = target.difference(now);
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours == 0) {
      return '${minutes.toString().padLeft(2, '0')} : ${seconds.toString().padLeft(2, '0')}';
    }
    return '${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')} : ${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _previewNow = DateTime.now();
    _titleController = TextEditingController(text: _defaultTitle);
    _previewTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _previewNow = DateTime.now());
    });
    _load();
  }

  @override
  void dispose() {
    _previewTicker?.cancel();
    _titleController.dispose();
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
                  const SizedBox(height: 12),
                  Center(child: _buildExpandedIsland()),
                  const SizedBox(height: 28),
                  if (widgetOptionEnabled(context, 'custom_text')) ...[
                    _sectionTitle(
                      widgetOptionLabel(context, 'custom_text', '编辑内容'),
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      controller: _titleController,
                      maxLength: 18,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 13),
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecoration('请输入目标名称'),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _sectionTitle('目标时间'),
                  const SizedBox(height: 9),
                  InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatTime(_targetTime),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (widgetOptionEnabled(context, 'icon')) ...[
                    _sectionTitle(widgetOptionLabel(context, 'icon', '图标')),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _iconButton(
                          onTap: _pickImage,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_outlined, size: 20),
                              SizedBox(height: 2),
                              Text('相册', style: TextStyle(fontSize: 9)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _iconButton(
                          selected: _imagePath == null,
                          onTap: _showEmojiPicker,
                          child: Text(
                            _icon,
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
      title: Padding(
        padding: const EdgeInsets.only(top: AppLayout.memorialDetailTopPadding),
        child: SizedBox(
          height: _headerContentHeight,
          child: Center(
            child: Text(
              _pageTitle,
              style: const TextStyle(
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
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _selectedIcon(19),
          const Spacer(),
          Text(
            _timerText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedIsland() {
    return Container(
      width: 245,
      height: 82,
      padding: const EdgeInsets.fromLTRB(28, 0, 8, 0),
      decoration: BoxDecoration(
        color: _isCountUp ? Colors.black : const Color(0xFFE4F0FF),
        image: widgetDefaultBackgroundDecoration(context),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _selectedIcon(34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleController.text.trim().isEmpty
                      ? _defaultTitle
                      : _titleController.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isCountUp ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _timerText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _isCountUp ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedIcon(double size) {
    if (_imagePath != null) {
      return ClipOval(
        child: Image.file(
          File(_imagePath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          _icon,
          style: TextStyle(fontSize: size * .75, height: 1),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    counterText: '',
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.accent),
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

  Future<void> _pickTime() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final value = await showDialog<TimeOfDay>(
      context: context,
      builder: (_) => _TimerWheelPickerDialog(initial: _targetTime),
    );
    if (value != null && mounted) {
      setState(() => _targetTime = value);
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setInt('${_storagePrefix}_hour', value.hour),
        prefs.setInt('${_storagePrefix}_minute', value.minute),
      ]);
    }
  }

  Future<void> _pickImage() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final path = await PetImagePicker.pickFromGallery(context);
    if (path != null && path.isNotEmpty && mounted) {
      setState(() => _imagePath = path);
    }
  }

  Future<void> _showEmojiPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
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
                gridPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: Colors.white,
                indicatorColor: AppColors.accent,
                iconColorSelected: AppColors.accent,
                backspaceColor: AppColors.accent,
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
    if (value != null && mounted) {
      setState(() {
        _icon = value;
        _imagePath = null;
      });
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _titleController.text =
          prefs.getString('${_storagePrefix}_title') ?? _defaultTitle;
      _targetTime = TimeOfDay(
        hour: prefs.getInt('${_storagePrefix}_hour') ?? 18,
        minute: prefs.getInt('${_storagePrefix}_minute') ?? 30,
      );
      _icon = prefs.getString('${_storagePrefix}_icon') ?? '🔔';
      _imagePath = prefs.getString('${_storagePrefix}_image');
      _enabled = prefs.getBool('${_storagePrefix}_enabled') ?? false;
    });
  }

  Future<void> _toggle() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    final next = !_enabled;
    final bannerBg =
        WidgetDetailScope.maybeOf(context)?.defaultBackground.trim() ?? '';
    final prefs = await SharedPreferences.getInstance();
    final title = _titleController.text.trim();
    await Future.wait([
      prefs.setString('${_storagePrefix}_title', title),
      prefs.setInt('${_storagePrefix}_hour', _targetTime.hour),
      prefs.setInt('${_storagePrefix}_minute', _targetTime.minute),
      prefs.setString('${_storagePrefix}_icon', _icon),
      if (_imagePath != null)
        prefs.setString('${_storagePrefix}_image', _imagePath!),
    ]);

    final template = _isCountUp ? 3 : 4;
    if (next) {
      final now = DateTime.now();
      var target = DateTime(
        now.year,
        now.month,
        now.day,
        _targetTime.hour,
        _targetTime.minute,
      );
      if (_isCountUp) {
        if (target.isAfter(now)) {
          target = target.subtract(const Duration(days: 1));
        }
      } else if (!target.isAfter(now)) {
        target = target.add(const Duration(days: 1));
      }
      final bgColor = (_isCountUp ? Colors.black : const Color(0xFFE4F0FF))
          .toARGB32();
      final ok = await LiveActivityService.instance.startOrUpdateIsland(
        template: template,
        payload: {
          'petName': title.isEmpty ? _pageTitle : title,
          'subtitle': title.isEmpty ? _defaultTitle : title,
          'memorialTitle': title.isEmpty ? _defaultTitle : title,
          'timerTargetEpoch': target.millisecondsSinceEpoch / 1000.0,
          'compactLeadingEmoji': _icon,
          'backgroundColorARGB': bgColor,
        },
        assetPaths: {
          if (_imagePath != null) 'icon': _imagePath,
          if (bannerBg.isNotEmpty) 'bannerBg': bannerBg,
        },
      );
      if (!mounted) return;
      if (!ok) {
        setState(() => _busy = false);
        await showCenterTip(context, '上岛失败，请在系统设置中开启实时活动');
        return;
      }
      await prefs.setBool('${_storagePrefix}_enabled', true);
      setState(() {
        _enabled = true;
        _busy = false;
      });
      if (!mounted) return;
      await showIslandSuccessDialog(context);
      return;
    }

    await LiveActivityService.instance.disableIsland(template);
    await prefs.setBool('${_storagePrefix}_enabled', false);
    if (!mounted) return;
    setState(() {
      _enabled = false;
      _busy = false;
    });
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _TimerWheelPickerDialog extends StatefulWidget {
  const _TimerWheelPickerDialog({required this.initial});

  final TimeOfDay initial;

  @override
  State<_TimerWheelPickerDialog> createState() =>
      _TimerWheelPickerDialogState();
}

class _TimerWheelPickerDialogState extends State<_TimerWheelPickerDialog> {
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Widget _label(int value, String unit) {
    return Center(
      child: Text(
        '${value.toString().padLeft(2, '0')}$unit',
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '选择时间',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 180,
        child: Row(
          children: [
            Expanded(
              child: CupertinoPicker(
                scrollController: _hourController,
                itemExtent: 36,
                onSelectedItemChanged: (value) => _hour = value,
                children: [
                  for (var value = 0; value < 24; value++) _label(value, '时'),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: _minuteController,
                itemExtent: 36,
                onSelectedItemChanged: (value) => _minute = value,
                children: [
                  for (var value = 0; value < 60; value++) _label(value, '分'),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(TimeOfDay(hour: _hour, minute: _minute)),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
