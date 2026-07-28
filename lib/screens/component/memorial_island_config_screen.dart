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
import '../../widgets/common/add_memorial_chip.dart';
import '../../widgets/common/tutorial_action_button.dart';
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
  bool _showAllMemorials = false;
  bool _prefsLoaded = false;
  /// 仅本次进入后用户手动选过图标；离开页面不保留
  bool _userPickedIconThisSession = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyDefaultIconFromDetail();
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: Column(
              children: [
                Center(child: _buildCompactIsland()),
                const SizedBox(height: 12),
                Center(child: _buildExpandedIsland()),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widgetOptionEnabled(context, 'anniversary_select')) ...[
                      _buildAnniversarySelectHeader(),
                      if (_items.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        _buildMemorialList(),
                      ],
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
          ),
          ColoredBox(
            color: Colors.white,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(46, 12, 46, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
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
                  if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '系统限制灵动岛后台最多保持8-12小时\n消失后请重新开启',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.5,
                        fontSize: 11,
                        color: AppColors.textPlaceholder,
                      ),
                    ),
                  ],
                ],
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
              '纪念日岛',
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
        TutorialActionButton(
          onTap: () => IosDesktopPetGuideDialog.show(
            context,
            liveActivityEnabled: false,
          ),
          height: _headerContentHeight,
        ),
      ],
    );
  }

  Widget _buildCompactIsland() {
    return Container(
      width: kIslandCompactWidth,
      height: kIslandCompactHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _selectedIcon(22, circular: true),
          const Spacer(),
          Text(
            '${_days(_selected)}天',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
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
      padding: const EdgeInsets.fromLTRB(44, 0, 8, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8E4EB), Color(0xFFDCEAFF)],
        ),
        image: widgetDefaultBackgroundDecoration(context),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _selectedIcon(64),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_days(item)}天',
                  style: const TextStyle(
                    fontSize: 26,
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

  Widget _buildAnniversarySelectHeader() {
    final hasItems = _items.isNotEmpty;
    final title = Text(
      widgetOptionLabel(context, 'anniversary_select', '选择纪念日事项'),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
    final addButton = AddMemorialChip(
      size: hasItems ? 27 : 40,
      onTap: () => context.push(AppRoutes.memorialAdd),
    );
    if (hasItems) {
      return Row(
        children: [
          Expanded(child: title),
          addButton,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 10),
        addButton,
      ],
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
    final visibleItems = _showAllMemorials ? _items : _items.take(3).toList();
    return Column(
      children: [
        for (var index = 0; index < visibleItems.length; index++) ...[
          _buildMemorialRow(visibleItems[index]),
          if (index != visibleItems.length - 1) const SizedBox(height: 7),
        ],
        if (_items.length > 3) ...[
          const SizedBox(height: 7),
          GestureDetector(
            onTap: () => setState(() => _showAllMemorials = !_showAllMemorials),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                children: [
                  Text(
                    _showAllMemorials ? '收起' : '更多',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textPlaceholder,
                    ),
                  ),
                  Icon(
                    _showAllMemorials
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 15,
                    color: AppColors.textPlaceholder,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMemorialRow(MemorialDay item) {
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
  }

  Widget _selectedIcon(double size, {bool circular = false}) {
    if (_imagePath != null) {
      return islandCardSideImage(
        _imagePath,
        size: size,
        circular: circular,
        fit: BoxFit.contain,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          _icon,
          style: TextStyle(fontSize: size, height: 1),
          textAlign: TextAlign.center,
        ),
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
      setState(() {
        _imagePath = url;
        _userPickedIconThisSession = true;
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
      _userPickedIconThisSession = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_imageKey);
    await prefs.setString(_iconKey, value);
    await LiveActivityService.instance.clearAsset('icon');
    if (_enabled) {
      final selected = _selected;
      if (selected == null) return;
      final daysRaw = selected.formattedDayCount;
      final daysText = daysRaw.contains('天') ? daysRaw : '$daysRaw天';
      await LiveActivityService.instance.startOrUpdateIsland(
        template: 5,
        payload: {
          'petName': selected.title.trim().isEmpty ? '纪念日' : selected.title,
          'subtitle': selected.title,
          'memorialTitle': selected.title,
          'daysText': daysText,
          'compactLeadingEmoji': value,
          'backgroundColorARGB': const Color(0xFFF8E4EB).toARGB32(),
        },
        assetPaths: const {},
      );
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedId = prefs.getString(_selectedKey);
      _enabled = prefs.getBool(_enabledKey) ?? false;
      // 每次进入都用接口 default_icon，不恢复本地图标
      _icon = '❤️';
      _imagePath = null;
      _userPickedIconThisSession = false;
      _prefsLoaded = true;
    });
    _applyDefaultIconFromDetail();
  }

  /// 详情接口晚于首帧返回时补上 default_icon
  void _applyDefaultIconFromDetail() {
    if (!_prefsLoaded || _userPickedIconThisSession || !mounted) return;
    final defaultIcon =
        WidgetDetailScope.maybeOf(context)?.defaultIcon.trim() ?? '';
    if (defaultIcon.isEmpty) return;
    if (islandDefaultIconIsImage(defaultIcon)) {
      if (_imagePath == defaultIcon) return;
      setState(() {
        _imagePath = defaultIcon;
        _icon = '❤️';
      });
    } else {
      if (_icon == defaultIcon && _imagePath == null) return;
      setState(() {
        _icon = defaultIcon;
        _imagePath = null;
      });
    }
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
      _imagePath != null
          ? prefs.setString(_imageKey, _imagePath!)
          : prefs.remove(_imageKey),
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
