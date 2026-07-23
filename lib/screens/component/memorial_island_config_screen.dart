import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/memorial_store.dart';
import '../../models/memorial_day.dart';
import '../../router/app_routes.dart';
import '../../services/live_activity_service.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/island_image_util.dart';
import '../../utils/island_success_dialog.dart';
import '../../widgets/dialogs/ios_desktop_pet_guide_dialog.dart';
import '../../widgets/common/widget_detail_scope.dart';

class MemorialIslandConfigScreen extends StatefulWidget {
  const MemorialIslandConfigScreen({super.key});

  @override
  State<MemorialIslandConfigScreen> createState() =>
      _MemorialIslandConfigScreenState();
}

class _MemorialIslandConfigScreenState
    extends State<MemorialIslandConfigScreen> {
  static const _selectedKey = 'memorial_island_selected_id';
  static const _iconKey = 'memorial_island_icon';
  static const _imageKey = 'memorial_island_image';
  static const _enabledKey = 'memorial_island_enabled';
  static const _headerContentHeight = 52.0;

  String? _selectedId;
  String _icon = '❤️';
  String? _imagePath;
  bool _enabled = false;
  bool _busy = false;

  List<MemorialDay> get _items => MemorialStore.instance.items;

  MemorialDay? get _selected {
    for (final item in _items) {
      if (item.id == _selectedId) return item;
    }
    return _items.isEmpty ? null : _items.first;
  }

  @override
  void initState() {
    super.initState();
    MemorialStore.instance.addListener(_onMemorialsChanged);
    MemorialStore.instance.ensureMemorialsLoaded();
    _load();
  }

  @override
  void dispose() {
    MemorialStore.instance.removeListener(_onMemorialsChanged);
    super.dispose();
  }

  void _onMemorialsChanged() {
    if (!mounted) return;
    final selectedExists = _items.any((item) => item.id == _selectedId);
    if (!selectedExists && _items.isNotEmpty) {
      _selectedId = _items.first.id;
    }
    setState(() {});
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
                  if (widgetOptionEnabled(context, 'anniversary_select')) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widgetOptionLabel(
                              context,
                              'anniversary_select',
                              '选择纪念日事项',
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => context.push(AppRoutes.memorialAdd),
                          borderRadius: BorderRadius.circular(7),
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F1F4),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(Icons.add, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    _buildMemorialList(),
                  ],
                  if (widgetOptionEnabled(context, 'icon')) ...[
                    const SizedBox(height: 20),
                    Text(
                      widgetOptionLabel(context, 'icon', '图标'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
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
                    onTap: _busy || _selected == null ? null : _toggle,
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
              '纪念日',
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
            '${_days(_selected)}天',
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
    final item = _selected;
    return Container(
      width: kIslandPreviewCardWidth,
      height: kIslandPreviewCardHeight,
      padding: const EdgeInsets.fromLTRB(32, 0, 4, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8E4EB), Color(0xFFDCEAFF)],
        ),
        image: widgetDefaultBackgroundDecoration(context),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _selectedIcon(42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item?.title ?? '请选择纪念日事项',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_days(item)}天',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemorialList() {
    if (MemorialStore.instance.isLoadingList && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accent,
        ),
      );
    }
    if (_items.isEmpty) {
      return Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '暂无纪念日事项',
          style: TextStyle(fontSize: 13, color: AppColors.textPlaceholder),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 7),
      itemBuilder: (context, index) {
        final item = _items[index];
        final selected = item.id == _selected?.id;
        return InkWell(
          onTap: () => _select(item.id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_days(item)}天',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _selectedIcon(double size) {
    if (_imagePath != null) {
      return ClipOval(
        child: islandImage(_imagePath, width: size, height: size),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(_icon, style: TextStyle(fontSize: size * .75, height: 1)),
      ),
    );
  }

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

  int _days(MemorialDay? item) {
    if (item == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(item.listDisplayDate).inDays.abs();
  }

  Future<void> _select(String id) async {
    setState(() => _selectedId = id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, id);
  }

  Future<void> _pickImage() async {
    final url = await pickAndUploadIslandImage(context);
    if (url != null && url.isNotEmpty && mounted) {
      setState(() => _imagePath = url);
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
                gridPadding: EdgeInsets.symmetric(horizontal: 8),
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
      _icon = value;
      _imagePath = null;
    });
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedId = prefs.getString(_selectedKey);
      _icon = prefs.getString(_iconKey) ?? '❤️';
      _imagePath = prefs.getString(_imageKey);
      _enabled = prefs.getBool(_enabledKey) ?? false;
    });
  }

  Future<void> _toggle() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() => _busy = true);
    final next = !_enabled;
    final bannerBg =
        WidgetDetailScope.maybeOf(context)?.defaultBackground.trim() ?? '';
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_selectedKey, selected.id),
      prefs.setString(_iconKey, _icon),
      if (_imagePath != null) prefs.setString(_imageKey, _imagePath!),
    ]);

    final daysRaw = selected.formattedDayCount;
    final daysText = daysRaw.contains('天') ? daysRaw : '$daysRaw天';
    if (next) {
      final ok = await LiveActivityService.instance.startOrUpdateIsland(
        template: 5,
        payload: {
          'petName': selected.title.trim().isEmpty ? '纪念日' : selected.title,
          'subtitle': selected.title,
          'memorialTitle': selected.title,
          'daysText': daysText,
          'compactLeadingEmoji': _icon,
          'backgroundColorARGB': const Color(0xFFF8E4EB).toARGB32(),
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
      await prefs.setBool(_enabledKey, true);
      setState(() {
        _enabled = true;
        _busy = false;
      });
      if (!mounted) return;
      await showIslandSuccessDialog(context);
      return;
    }

    await LiveActivityService.instance.disableIsland(5);
    await prefs.setBool(_enabledKey, false);
    if (!mounted) return;
    setState(() {
      _enabled = false;
      _busy = false;
    });
  }
}
