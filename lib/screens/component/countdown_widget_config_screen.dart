import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/background_store.dart';
import '../../data/font_style_store.dart';
import '../../data/memorial_store.dart';
import '../../data/saved_widget_store.dart';
import '../../models/font_style_config.dart';
import '../../models/memorial_day.dart';
import '../../router/app_routes.dart';
import '../../services/live_activity_service.dart';
import '../../services/pet_image_service.dart';
import '../../utils/app_permission_util.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/pet_image_picker.dart';
import '../../utils/saving_overlay.dart';
import '../../widgets/common/day_number_display.dart';
import '../../widgets/common/memorial_type_info.dart';
import '../../widgets/dialogs/ios_desktop_pet_guide_dialog.dart';
import '../../widgets/common/widget_detail_scope.dart';
import 'pet_widget_config_screen.dart' show showComponentColorPicker;
import 'transparent_wallpaper_setup_screen.dart';

enum CountdownWidgetVariant {
  photo,
  simple,
  medium,
  multiSmall,
  multiMedium,
  calendar,
}

class CountdownWidgetConfigScreen extends StatefulWidget {
  final CountdownWidgetVariant variant;

  const CountdownWidgetConfigScreen({super.key, required this.variant});

  @override
  State<CountdownWidgetConfigScreen> createState() =>
      _CountdownWidgetConfigScreenState();
}

class _CountdownWidgetConfigScreenState
    extends State<CountdownWidgetConfigScreen> {
  static const _headerContentHeight = 52.0;

  String? _selectedMemorialId;
  final Set<String> _selectedMemorialIds = {};
  String _selectedFontStyleId = FontStyleConfig.normalStyleId;
  Color _textColor = Colors.white;
  Color _multiTitleTextColor = Colors.black;
  Color _backgroundColor = const Color(0xFF98CBF2);
  String? _backgroundImage;
  /// 相册上传后的网络地址（与预览同源；保存优先用它）
  String? _backgroundRemoteUrl;
  /// 用户点了背景色盘后为 true，避免仍被接口 defaultBackground 盖住
  bool _useSolidBackground = false;
  bool _backgroundReady = false;
  bool _showAllMemorials = false;
  bool _fontSelectionInitialized = false;
  bool _apiDetailMode = false;
  bool _hasSelectedTextColor = false;
  final GlobalKey _previewBoundaryKey = GlobalKey();
  final GlobalKey _previewBackgroundKey = GlobalKey();

  void _applyOverallTextColor(Color color) {
    _textColor = color;
    // 多纪念日名称保持黑色，不随整体文字色变化
    if (!_isMulti) {
      _multiTitleTextColor = color;
    }
    _hasSelectedTextColor = true;
  }

  /// 默认勾选纪念列表前 N 条（最多 3 条）
  void _syncDefaultMultiSelection() {
    if (!_isMulti || !MemorialStore.instance.listLoaded) return;
    final days = MemorialStore.instance.items;
    final validIds = days.map((item) => item.id).toSet();
    _selectedMemorialIds.removeWhere((id) => !validIds.contains(id));
    if (_selectedMemorialIds.isEmpty && days.isNotEmpty) {
      _selectedMemorialIds.addAll(days.take(3).map((item) => item.id));
    }
  }

  String? get _effectiveBackgroundImage {
    if (_useSolidBackground) return null;
    if (_backgroundImage != null) return _backgroundImage;
    final value = WidgetDetailScope.maybeOf(context)?.defaultBackground.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// 写入设置/偏好的背景图：优先网络地址
  String? get _backgroundImageForPersist {
    if (_useSolidBackground) return null;
    final remote = _backgroundRemoteUrl?.trim();
    if (remote != null && remote.isNotEmpty) return remote;
    final current = _backgroundImage?.trim();
    if (current == null || current.isEmpty) return null;
    // 本地临时路径不写入偏好，避免失效
    final isLocal =
        current.startsWith('/') ||
        current.startsWith('file://') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(current);
    if (isLocal) return null;
    return current;
  }

  String get _prefsPrefix => switch (widget.variant) {
    CountdownWidgetVariant.photo => 'photo_widget',
    CountdownWidgetVariant.simple => 'simple_widget',
    CountdownWidgetVariant.medium => 'medium_widget',
    CountdownWidgetVariant.multiSmall => 'multi_memorial_widget',
    CountdownWidgetVariant.multiMedium => 'birthday_countdown_widget',
    CountdownWidgetVariant.calendar => 'calendar_widget',
  };

  String get _title => switch (widget.variant) {
    CountdownWidgetVariant.photo => '图文纪念日',
    CountdownWidgetVariant.simple => '简约',
    CountdownWidgetVariant.medium => '中号',
    CountdownWidgetVariant.multiSmall => '多纪念日',
    CountdownWidgetVariant.multiMedium => '生日倒计时',
    CountdownWidgetVariant.calendar => '波点日历',
  };

  bool get _isMulti =>
      widget.variant == CountdownWidgetVariant.multiSmall ||
      widget.variant == CountdownWidgetVariant.multiMedium;

  bool get _isMedium =>
      widget.variant == CountdownWidgetVariant.medium ||
      widget.variant == CountdownWidgetVariant.multiMedium;

  bool get _isSingleMedium => widget.variant == CountdownWidgetVariant.medium;

  bool get _isCalendar => widget.variant == CountdownWidgetVariant.calendar;

  @override
  void initState() {
    super.initState();
    if (widget.variant == CountdownWidgetVariant.simple || _isCalendar) {
      _textColor = Colors.black;
    }
    MemorialStore.instance.addListener(_rebuild);
    FontStyleStore.instance.addListener(_rebuild);
    BackgroundStore.instance.addListener(_onBackgroundChanged);
    MemorialStore.instance.ensureMemorialsLoaded();
    if (FontStyleStore.instance.items.isEmpty) {
      FontStyleStore.instance.fetchList();
    }
    BackgroundStore.instance.fetchWidgetList(type: 1);
    _restore();
  }

  @override
  void dispose() {
    MemorialStore.instance.removeListener(_rebuild);
    FontStyleStore.instance.removeListener(_rebuild);
    BackgroundStore.instance.removeListener(_onBackgroundChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_apiDetailMode && WidgetDetailScope.maybeOf(context) != null) {
      _apiDetailMode = true;
      _backgroundReady = true;
    }
  }

  void _rebuild() {
    if (!mounted) return;
    if (_isCalendar) {
      setState(() {});
      return;
    }
    final days = MemorialStore.instance.items;
    if (_isMulti) {
      _syncDefaultMultiSelection();
      setState(() {});
      return;
    }
    final hasSelectedMemorial = days.any(
      (item) => item.id == _selectedMemorialId,
    );
    if (!hasSelectedMemorial && days.isNotEmpty) {
      _selectedMemorialId = days.first.id;
    }
    if (_fontSelectionInitialized &&
        !FontStyleConfig.isNormalStyle(_selectedFontStyleId) &&
        !FontStyleStore.instance.isLoading &&
        FontStyleStore.instance.findById(_selectedFontStyleId) == null) {
      _selectedFontStyleId = FontStyleConfig.normalStyleId;
    }
    _syncInitialFontStyle();
    setState(() {});
  }

  void _syncInitialFontStyle() {
    if (_fontSelectionInitialized) return;
    final memorial = _selectedMemorial;
    if (memorial == null) return;
    final styleId = memorial.fontStyleId;
    if (FontStyleConfig.isNormalStyle(styleId) ||
        FontStyleStore.instance.findById(styleId) != null) {
      _selectedFontStyleId = styleId;
      _fontSelectionInitialized = true;
    }
  }

  void _onBackgroundChanged() {
    if (!mounted) return;
    // 避免 notifyListeners 落在 build 中触发 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = BackgroundStore.instance;
      final items = store.widgetItems(1);
      final loading = store.widgetListLoading(1);
      if (!_apiDetailMode && !_backgroundReady && !loading) {
        if (items.isNotEmpty && _backgroundImage == null) {
          _backgroundImage = _backgroundUrl(items.first);
        }
        _backgroundReady = true;
      }
      setState(() {});
    });
  }

  MemorialDay? get _selectedMemorial {
    final items = MemorialStore.instance.items;
    for (final item in items) {
      if (item.id == _selectedMemorialId) return item;
    }
    return items.isEmpty ? null : items.first;
  }

  int get _days {
    final memorial = _selectedMemorial;
    if (memorial == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(
      memorial.date.year,
      memorial.date.month,
      memorial.date.day,
    );
    return date.difference(today).inDays.abs();
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: RepaintBoundary(
                      key: _previewBoundaryKey,
                      child: _buildPreview(),
                    ),
                  ),
                  if (!_isCalendar &&
                      widgetOptionEnabled(context, 'anniversary_select')) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
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
                        const Spacer(),
                        InkWell(
                          onTap: () => context.push(AppRoutes.memorialAdd),
                          borderRadius: BorderRadius.circular(7),
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.bgInput,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 17,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildMemorialPicker(),
                  ],
                  if (!_apiDetailMode && !_isMulti) ...[
                    const SizedBox(height: 18),
                    const Text(
                      '文字样式',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFontPicker(),
                  ],
                  if (_apiDetailMode &&
                      (widgetOptionEnabled(
                            context,
                            'text_style',
                            fallback: false,
                          ) ||
                          widgetOptionEnabled(
                            context,
                            'text_color',
                            fallback: false,
                          ))) ...[
                    const SizedBox(height: 18),
                    Text(
                      widgetOptionLabel(
                        context,
                        widgetOptionEnabled(
                              context,
                              'text_style',
                              fallback: false,
                            )
                            ? 'text_style'
                            : 'text_color',
                        widgetOptionEnabled(
                              context,
                              'text_style',
                              fallback: false,
                            )
                            ? '文字样式'
                            : '选择文字颜色',
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTextStylePicker(),
                  ],
                  if (_apiDetailMode &&
                      widgetOptionEnabled(
                        context,
                        'number_style',
                        fallback: false,
                      )) ...[
                    const SizedBox(height: 18),
                    Text(
                      widgetOptionLabel(context, 'number_style', '数字样式'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFontPicker(includeColorPalette: false),
                  ],
                  if (widgetOptionEnabled(context, 'background')) ...[
                    const SizedBox(height: 18),
                    Text(
                      widgetOptionLabel(context, 'background', '背景'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
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
        child: Padding(
          padding: const EdgeInsets.only(
            left: 12,
            top: AppLayout.memorialDetailTopPadding,
          ),
          child: SizedBox(
            height: _headerContentHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
      title: Padding(
        padding: const EdgeInsets.only(top: AppLayout.memorialDetailTopPadding),
        child: SizedBox(
          height: _headerContentHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                _title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Positioned(
                top: 39,
                child: Text(
                  _isMedium ? '中号' : '小号',
                  style: const TextStyle(
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

  Widget _buildPreview() {
    if (_isCalendar) return _buildCalendarPreview();
    if (_isMulti) return _buildMultiPreview();
    if (_isSingleMedium) return _buildMediumPreview();
    final simple = widget.variant == CountdownWidgetVariant.simple;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 132,
        height: 132,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _previewBackgroundLayer(width: 132, height: 132),
            if (simple) _buildSimplePreview() else _buildPhotoPreview(),
          ],
        ),
      ),
    );
  }

  /// 仅底色/背景图，供保存时写入桌面实时背景（不含文字，保证倒计时仍实时）
  Widget _previewBackgroundLayer({
    required double width,
    required double height,
    Widget? fallback,
  }) {
    return RepaintBoundary(
      key: _previewBackgroundKey,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: _backgroundColor),
            if (_effectiveBackgroundImage != null)
              _sourceImage(_effectiveBackgroundImage!, fit: BoxFit.cover)
            else if (fallback != null)
              fallback,
          ],
        ),
      ),
    );
  }

  Widget _buildMediumPreview() {
    final memorial = _selectedMemorial;
    final date = memorial?.listDisplayDate ?? DateTime.now();
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 280,
        height: 124,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _previewBackgroundLayer(width: 280, height: 124),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekdays[date.weekday - 1],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Transform.translate(
                    offset: const Offset(0, 6),
                    child: Text(
                      memorial?.title ?? '考研倒计时',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildMediumDayNumber(),
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 5),
                        child: Text(
                          '天',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${date.year}.${date.month}.${date.day}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _textColor.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediumDayNumber() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140, maxHeight: 48),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomLeft,
        child: DayNumberDisplay(
          value: _days,
          fontStyleId: _selectedFontStyleId,
          digitHeight: 48,
          textStyle: TextStyle(
            fontSize: 50,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarPreview() {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 132,
        height: 132,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _previewBackgroundLayer(
              width: 132,
              height: 132,
              fallback: CustomPaint(
                painter: _DotPatternPainter(
                  color: _textColor.withValues(alpha: 0.12),
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(
                  height: 29,
                  child: Center(
                    child: Text(
                      months[now.month - 1],
                      style: TextStyle(
                        fontSize: 13,
                        // 未选文字样式时白色；选中后与文字色同步
                        color: _hasSelectedTextColor
                            ? _textColor
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCalendarDay(now.day),
                      const SizedBox(height: 2),
                      Text(
                        weekdays[now.weekday - 1],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarDay(int day) {
    return SizedBox(
      width: 90,
      height: 53,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: DayNumberDisplay(
          value: day,
          fontStyleId: _selectedFontStyleId,
          digitHeight: 50,
          textStyle: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMultiPreview() {
    final items = MemorialStore.instance.items
        .where((item) => _selectedMemorialIds.contains(item.id))
        .take(3)
        .toList();
    final width = _isMedium ? 280.0 : 132.0;
    final height = _isMedium ? 124.0 : 132.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _previewBackgroundLayer(width: width, height: height),
            Padding(
              padding: EdgeInsets.all(_isMedium ? 16 : 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _buildMultiPreviewRow(items[index]),
                    if (index != items.length - 1)
                      SizedBox(height: _isMedium ? 5 : 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiPreviewRow(MemorialDay item) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(item.date.year, item.date.month, item.date.day);
    final days = target.difference(today).inDays.abs();
    final badgeColor = MemorialTypeInfo.daysBackground(item);
    final badgeText = MemorialTypeInfo.daysText(item);
    final typeLabel = MemorialTypeInfo.label(item);
    return Container(
      height: _isMedium ? 29 : 32,
      padding: const EdgeInsets.only(right: 7),
      decoration: BoxDecoration(
        // 名称区域：不透明白底
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: _isMedium ? 54 : 47,
            height: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
              ),
            ),
            child: Text(
              '$days天',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: badgeText,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _isMedium ? 12 : 11,
                fontWeight: FontWeight.w600,
                color: _multiTitleTextColor,
              ),
            ),
          ),
          if (_isMedium) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(fontSize: 8, color: badgeText),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
        child: Column(
          children: [
            _buildPhotoHeader(),
            const Spacer(),
            // 与简约小号天数同级字号
            _buildDayNumber(width: 96, height: 43, digitHeight: 40),
            const Spacer(),
            Text(
              _photoDateLabel(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _textColor.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimplePreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildDayNumber(
                  width: 96,
                  height: 43,
                  digitHeight: 40,
                  alignment: Alignment.centerRight,
                ),
                Text(
                  'Days',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _textColor.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            _selectedMemorial?.title ?? '纪念日还有',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _simpleDateLabel(),
            style: TextStyle(
              fontSize: 11,
              color: _textColor.withValues(alpha: 0.42),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayNumber({
    required double width,
    required double height,
    required double digitHeight,
    Alignment alignment = Alignment.center,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: DayNumberDisplay(
          value: _days,
          fontStyleId: _selectedFontStyleId,
          digitHeight: digitHeight,
          textStyle: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoHeader() {
    final memorial = _selectedMemorial;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            memorial?.title ?? '纪念日',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ),
        if (memorial != null) ...[
          const SizedBox(width: 3),
          MemorialTypeInfo.icon(memorial, size: 14, color: _textColor),
        ],
      ],
    );
  }

  String _photoDateLabel() {
    final date = _selectedMemorial?.date;
    if (date == null) return '';
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day  周${weekdays[date.weekday - 1]}';
  }

  String _memorialIconUrl(MemorialDay? memorial) {
    if (memorial == null) return '';
    final type = MemorialStore.instance.typeById(memorial.typeId);
    return type?['icon']?.toString().trim() ?? '';
  }

  String _simpleDateLabel() {
    final date = _selectedMemorial?.date;
    if (date == null) return '';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Widget _buildMemorialPicker() {
    final items = MemorialStore.instance.items;
    final visibleItems = _showAllMemorials ? items : items.take(3).toList();
    return Column(
      children: [
        for (var index = 0; index < visibleItems.length; index++) ...[
          _buildMemorialRow(visibleItems[index]),
          if (index != visibleItems.length - 1) const SizedBox(height: 7),
        ],
        if (items.length > 3) ...[
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
                    style: TextStyle(
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
    final selected = _isMulti
        ? _selectedMemorialIds.contains(item.id)
        : item.id == _selectedMemorialId;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(item.date.year, item.date.month, item.date.day);
    final days = date.difference(today).inDays.abs();
    return GestureDetector(
      onTap: () => _toggleMemorial(item.id),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF0F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '$days天',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMemorial(String id) {
    if (!_isMulti) {
      setState(() => _selectedMemorialId = id);
      return;
    }
    if (_selectedMemorialIds.contains(id)) {
      setState(() => _selectedMemorialIds.remove(id));
      return;
    }
    if (_selectedMemorialIds.length >= 3) {
      showCenterTip(context, '最多选择3条纪念日');
      return;
    }
    setState(() => _selectedMemorialIds.add(id));
  }

  Widget _buildFontPicker({bool includeColorPalette = true}) {
    final items = FontStyleConfig.displayItems();
    final offset = includeColorPalette ? 1 : 0;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length + offset,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (includeColorPalette && index == 0) {
            return _fontRoundOption(
              selected: false,
              child: const _PaletteCircle(size: 48),
              onTap: _pickTextColor,
            );
          }
          final item = items[index - offset];
          final id = '${item['id']}';
          final selected = id == _selectedFontStyleId;
          final preview = FontStyleConfig.previewImageUrl(id);
          return _fontRoundOption(
            selected: selected,
            onTap: () => setState(() {
              _selectedFontStyleId = id;
              _fontSelectionInitialized = true;
            }),
            child: preview == null
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '0',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                : ClipOval(
                    child: ColoredBox(
                      color: Colors.white,
                      child: Padding(
                        // 略缩进，避免圆形裁切吃掉数字描边
                        padding: const EdgeInsets.all(5),
                        child: Image.network(
                          preview,
                          width: 38,
                          height: 38,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildTextStylePicker() {
    const colors = [
      Colors.white,
      Colors.black,
      Color(0xFFFF9E99),
      Color(0xFFFF956E),
      Color(0xFFFFC85D),
      Color(0xFFB6F36C),
      Color(0xFF83E7B5),
      Color(0xFF6695F5),
      Color(0xFFB36EF3),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _fontRoundOption(
              selected: false,
              child: const _PaletteCircle(size: 48),
              onTap: _pickTextColor,
            );
          }
          final color = colors[index - 1];
          return _fontRoundOption(
            selected: color.toARGB32() == _textColor.toARGB32(),
            onTap: () => setState(() => _applyOverallTextColor(color)),
            child: SizedBox(
              width: 48,
              height: 48,
              child: ColoredBox(color: color),
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
    if (!_backgroundReady && loading && items.isEmpty) {
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
            return _roundOption(
              selected: false,
              onTap: _pickBackground,
              fill: true,
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
                    Text('相册', style: TextStyle(fontSize: 9, height: 1)),
                  ],
                ),
              ),
            );
          }
          if (index == 1) {
            return _roundOption(
              selected: _useSolidBackground,
              onTap: _pickBackgroundColor,
              fill: true,
              child: const _PaletteCircle(size: 48),
            );
          }
          final url = _backgroundUrl(items[index - 2]);
          return _roundOption(
            selected:
                !_useSolidBackground &&
                url.isNotEmpty &&
                url == _backgroundImage,
            onTap: () => setState(() {
              _useSolidBackground = false;
              _backgroundRemoteUrl = url;
              _backgroundImage = url;
            }),
            fill: true,
            child: ClipOval(
              child: Image.network(
                url,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AppColors.bgInput),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _roundOption({
    required bool selected,
    required Widget child,
    required VoidCallback onTap,
    bool fill = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: fill ? Alignment.center : null,
        padding: fill ? EdgeInsets.zero : const EdgeInsets.all(3),
        clipBehavior: fill ? Clip.antiAlias : Clip.none,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: fill
              ? null
              : Border.all(
                  color: selected ? AppColors.accent : AppColors.borderMedium,
                  width: selected ? 2 : 1,
                ),
        ),
        foregroundDecoration: fill
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.borderMedium,
                  width: selected ? 2 : 1,
                ),
              )
            : null,
        child: fill ? child : ClipOval(child: Center(child: child)),
      ),
    );
  }

  Widget _fontRoundOption({
    required bool selected,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.borderMedium,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }

  Future<void> _pickTextColor() async {
    final color = await _pickColor(
      _textColor,
      title: '选择文字颜色',
    );
    if (color != null && mounted) {
      setState(() => _applyOverallTextColor(color));
    }
  }

  Future<void> _pickBackgroundColor() async {
    final color = await _pickColor(
      _backgroundColor,
      title: '选择背景颜色',
    );
    if (color != null && mounted) {
      setState(() {
        _backgroundColor = color;
        _backgroundImage = null;
        _backgroundRemoteUrl = null;
        _useSolidBackground = true;
      });
    }
  }

  Future<Color?> _pickColor(Color initial, {required String title}) {
    return showComponentColorPicker(
      context,
      initialColor: initial,
      title: title,
    );
  }

  Future<void> _pickBackground() async {
    try {
      final path = await PetImagePicker.pickFromGallery(context);
      if (path == null || path.isEmpty || !mounted) return;
      await withSavingOverlay(context, () async {
        final definition = WidgetDetailScope.maybeOf(context);
        // 倒计时类桌面走实时渲染：先把本地图写入 App Group
        if (definition != null && definition.id > 0) {
          await SavedWidgetStore.instance.syncBackgroundImage(
            widgetId: definition.id,
            imageRef: path,
          );
        } else {
          debugPrint(
            '[CountdownWidget] no widget definition, skip App Group sync',
          );
        }

        // 登记背景库，拿到网络地址
        final created = await BackgroundStore.instance.uploadCustomBackground(
          localPath: path,
          name: '组件背景',
        );
        if (!mounted) return;
        final url = created == null
            ? ''
            : PetImageService.resolveUrl(
                '${created['image'] ?? created['img'] ?? created['url'] ?? ''}',
              );
        if (url.isEmpty) {
          throw Exception('empty upload url');
        }
        debugPrint('[CountdownWidget] upload background url=$url');
        // 预览只用网络图：转圈期间先缓存好，结束时直接显示，避免闪底色；
        // 也保证此时已有可保存的网络链接，不会出现「图没加载完就保存」
        await precacheImage(NetworkImage(url), context);
        if (!mounted) return;
        setState(() {
          _useSolidBackground = false;
          _backgroundImage = url;
          _backgroundRemoteUrl = url;
        });
        await WidgetsBinding.instance.endOfFrame;
      });
    } on AppPermissionDeniedException catch (error) {
      if (!mounted) return;
      await AppPermissionUtil.showDeniedDialog(context, error);
    } catch (error) {
      if (!mounted) return;
      showCenterTip(context, '背景上传失败');
      debugPrint('[CountdownWidget] upload background failed: $error');
    }
  }

  Widget _sourceImage(String source, {BoxFit fit = BoxFit.contain}) {
    final local =
        source.startsWith('/') ||
        source.startsWith('file://') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(source);
    if (local) {
      final path = source.startsWith('file://')
          ? Uri.parse(source).toFilePath()
          : source;
      return Image.file(File(path), fit: fit);
    }
    return Image.network(source, fit: fit);
  }

  String _backgroundUrl(Map<String, dynamic> item) {
    final raw = item['image'] ?? item['img'] ?? item['url'];
    return PetImageService.resolveUrl(raw?.toString() ?? '');
  }

  Future<void> _showTutorial() async {
    final enabled = await LiveActivityService.instance.isEnabled();
    if (!mounted) return;
    await IosDesktopPetGuideDialog.show(context, liveActivityEnabled: enabled);
    if (!mounted) return;
    // 全版本均用壁纸裁切实现桌面假透明
    if (Platform.isIOS) {
      await TransparentWallpaperSetupScreen.open(context);
    }
  }

  Future<void> _save() async {
    final definition = WidgetDetailScope.maybeOf(context);
    final memorial = _selectedMemorial;
    try {
      await withSavingOverlay(context, () async {
        final prefs = await SharedPreferences.getInstance();
        final persistBg = _backgroundImageForPersist;
        // 列表/相册网络图：截图前确保已解码，避免保存时预览还是底色
        if (persistBg != null &&
            (persistBg.startsWith('http://') ||
                persistBg.startsWith('https://'))) {
          await precacheImage(NetworkImage(persistBg), context);
          if (!mounted) return;
          await WidgetsBinding.instance.endOfFrame;
        }
        await Future.wait([
          if (_isMulti)
            prefs.setStringList(
              '${_prefsPrefix}_memorials',
              _selectedMemorialIds.toList(),
            )
          else if (_selectedMemorialId == null)
            prefs.remove('${_prefsPrefix}_memorial')
          else
            prefs.setString('${_prefsPrefix}_memorial', _selectedMemorialId!),
          prefs.setString('${_prefsPrefix}_font', _selectedFontStyleId),
          prefs.setInt('${_prefsPrefix}_text_color', _textColor.toARGB32()),
          prefs.setInt(
            '${_prefsPrefix}_background_color',
            _backgroundColor.toARGB32(),
          ),
          prefs.setString(
            '${_prefsPrefix}_background_mode',
            _useSolidBackground ? 'palette' : 'image',
          ),
          if (_useSolidBackground || _backgroundImageForPersist == null)
            prefs.remove('${_prefsPrefix}_background_image')
          else
            prefs.setString(
              '${_prefsPrefix}_background_image',
              _backgroundImageForPersist!,
            ),
        ]);
        await saveWidgetToLibrary(
          definition,
          settings: {
            'memorial_id': _selectedMemorialId ?? '',
            'memorial_ids': _selectedMemorialIds.toList(),
            'memorial_items': jsonEncode(
              _selectedMemorialIds.isEmpty
                  ? <Map<String, dynamic>>[]
                  : MemorialStore.instance.items
                        .where((item) => _selectedMemorialIds.contains(item.id))
                        .take(3)
                        .map(
                          (item) => {
                            'id': item.id,
                            'title': item.title,
                            'date': item.date.toIso8601String(),
                            'days': '${item.displayDayCount}',
                            'badge_bg': MemorialTypeInfo.daysBackground(
                              item,
                            ).toARGB32(),
                            'badge_text': MemorialTypeInfo.daysText(
                              item,
                            ).toARGB32(),
                            'type_label': MemorialTypeInfo.label(item),
                          },
                        )
                        .toList(),
            ),
            'memorial_title': memorial?.title ?? '',
            'memorial_days': memorial?.displayDayCount ?? 0,
            'memorial_date': memorial?.date.toIso8601String() ?? '',
            'icon_url': _memorialIconUrl(memorial),
            'font_style': _selectedFontStyleId,
            'text_color': _textColor.toARGB32(),
            'text_color_selected': _hasSelectedTextColor ? '1' : '0',
            'background_color': _backgroundColor.toARGB32(),
            'background_image': _backgroundImageForPersist ?? '',
          },
          previewBoundaryKey: _previewBoundaryKey,
          backgroundBoundaryKey: _previewBackgroundKey,
        );
      });
      if (!mounted) return;
      await showCenterTip(context, '已保存到我的组件');
      if (mounted) context.pop();
    } catch (error) {
      debugPrint('[CountdownWidgetConfig] save failed: $error');
      if (mounted) await showCenterTip(context, '保存失败，请检查网络后重试');
    }
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final memorial = prefs.getString('${_prefsPrefix}_memorial');
    final savedMemorials = prefs.getStringList('${_prefsPrefix}_memorials');
    final font = prefs.getString('${_prefsPrefix}_font');
    final textColor = prefs.getInt('${_prefsPrefix}_text_color');
    final backgroundColor = prefs.getInt('${_prefsPrefix}_background_color');
    final backgroundImage = prefs.getString('${_prefsPrefix}_background_image');
    final backgroundMode = prefs.getString('${_prefsPrefix}_background_mode');
    if (!mounted) return;
    final memorials = MemorialStore.instance.items;
    final restoredMemorialExists = memorials.any((item) => item.id == memorial);
    final effectiveMemorialId = restoredMemorialExists
        ? memorial
        : (memorials.isEmpty ? memorial : memorials.first.id);
    setState(() {
      if (_isMulti) {
        _selectedMemorialIds
          ..clear()
          ..addAll(savedMemorials ?? const []);
        _multiTitleTextColor = Colors.black;
        _syncDefaultMultiSelection();
      } else {
        _selectedMemorialId = effectiveMemorialId;
      }
      // 波点日历：特效页不恢复上次文字/背景样式，重进月份仍为白色
      if (_isCalendar) {
        _textColor = Colors.black;
        _hasSelectedTextColor = false;
        _selectedFontStyleId = FontStyleConfig.normalStyleId;
        _fontSelectionInitialized = false;
        _backgroundColor = const Color(0xFF98CBF2);
        if (_apiDetailMode) {
          _backgroundImage = null;
          _backgroundRemoteUrl = null;
          _useSolidBackground = false;
          _backgroundReady = true;
        } else if (!BackgroundStore.instance.widgetListLoading(1)) {
          final bgItems = BackgroundStore.instance.widgetItems(1);
          if (bgItems.isNotEmpty) {
            _backgroundImage = _backgroundUrl(bgItems.first);
            _backgroundRemoteUrl = _backgroundImage;
          }
          _useSolidBackground = false;
          _backgroundReady = true;
        }
        return;
      }
      if (font != null && font.isNotEmpty) {
        _selectedFontStyleId = font;
        _fontSelectionInitialized = true;
      }
      if (textColor != null) {
        if (_isMulti) {
          // 多纪念日：整体色只影响其它文案，名称保持黑色
          _textColor = Color(textColor);
          _hasSelectedTextColor = true;
        } else {
          _applyOverallTextColor(Color(textColor));
        }
      }
      if (backgroundColor != null) _backgroundColor = Color(backgroundColor);
      if (_apiDetailMode) {
        _backgroundImage = null;
        _backgroundRemoteUrl = null;
        _useSolidBackground = false;
        _backgroundReady = true;
      } else {
        if (backgroundMode == 'palette') {
          _backgroundImage = null;
          _backgroundRemoteUrl = null;
          _useSolidBackground = true;
          _backgroundReady = true;
        } else if (backgroundImage != null && backgroundImage.isNotEmpty) {
          _backgroundImage = backgroundImage;
          _backgroundRemoteUrl = backgroundImage;
          _useSolidBackground = false;
          _backgroundReady = true;
        } else if (!BackgroundStore.instance.widgetListLoading(1)) {
          final bgItems = BackgroundStore.instance.widgetItems(1);
          if (bgItems.isNotEmpty) {
            _backgroundImage = _backgroundUrl(bgItems.first);
            _backgroundRemoteUrl = _backgroundImage;
          }
          _useSolidBackground = false;
          _backgroundReady = true;
        }
      }
      if (!_isMulti && !_isCalendar) _syncInitialFontStyle();
    });
  }
}

class _DotPatternPainter extends CustomPainter {
  final Color color;

  const _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const gap = 13.0;
    for (var y = 7.0; y < size.height; y += gap) {
      for (var x = 7.0; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PaletteCircle extends StatelessWidget {
  const _PaletteCircle({this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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
