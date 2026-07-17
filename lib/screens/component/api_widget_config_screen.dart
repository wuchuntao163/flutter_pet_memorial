import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../data/background_store.dart';
import '../../data/font_style_store.dart';
import '../../data/memorial_store.dart';
import '../../data/widget_store.dart';
import '../../models/font_style_config.dart';
import '../../models/memorial_day.dart';
import '../../models/widget_definition.dart';
import '../../services/pet_image_service.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/pet_display_image.dart';
import '../../utils/pet_image_picker.dart';
import '../../widgets/common/day_number_display.dart';
import '../../widgets/common/widget_detail_scope.dart';
import 'pet_widget_config_screen.dart';
import 'countdown_widget_config_screen.dart';
import 'pet_island_config_screen.dart';
import 'timer_island_config_screen.dart';
import 'memorial_island_config_screen.dart';
import 'photo_island_config_screen.dart';
import 'custom_island_config_screen.dart';

class ApiWidgetConfigScreen extends StatefulWidget {
  const ApiWidgetConfigScreen({
    super.key,
    required this.widgetId,
    this.initial,
  });

  final int widgetId;
  final WidgetDefinition? initial;

  @override
  State<ApiWidgetConfigScreen> createState() => _ApiWidgetConfigScreenState();
}

class _ApiWidgetConfigScreenState extends State<ApiWidgetConfigScreen> {
  static const _headerHeight = 52.0;

  WidgetDefinition? _detail;
  final _petImages = <String>[];
  int _selectedPet = 0;
  String? _selectedMemorialId;
  String _fontStyleId = FontStyleConfig.normalStyleId;
  Color _textColor = Colors.white;
  String? _selectedBackground;
  Color _backgroundColor = const Color(0xFF98CBF2);
  String? _uploadedImage;
  String? _iconImage;
  String _icon = '🔔';
  double _textSize = 16;
  bool _iconOnRight = false;
  final _textController = TextEditingController(text: '每天都要开心');

  String get _prefsPrefix => 'api_widget_${widget.widgetId}';

  @override
  void initState() {
    super.initState();
    WidgetStore.instance.addListener(_rebuild);
    BackgroundStore.instance.addListener(_rebuild);
    MemorialStore.instance.addListener(_rebuild);
    FontStyleStore.instance.addListener(_rebuild);
    MemorialStore.instance.ensureMemorialsLoaded();
    FontStyleStore.instance.fetchList();
    _load();
    _preparePets();
    _fetchDetail();
  }

  @override
  void dispose() {
    WidgetStore.instance.removeListener(_rebuild);
    BackgroundStore.instance.removeListener(_rebuild);
    MemorialStore.instance.removeListener(_rebuild);
    FontStyleStore.instance.removeListener(_rebuild);
    _textController.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchDetail() async {
    final detail = await WidgetStore.instance.fetchDetail(
      widget.widgetId,
      fallback: widget.initial,
    );
    if (!mounted || detail == null) return;
    _detail = detail;
    await BackgroundStore.instance.fetchWidgetList(type: detail.type);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = _detail;
    if (item == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F8FB),
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return _buildFixedTemplate(item);
  }

  Widget _buildFixedTemplate(WidgetDefinition item) {
    final child = _fixedTemplateChild(item);
    return WidgetDetailScope(definition: item, child: child);
  }

  Widget _fixedTemplateChild(WidgetDefinition item) {
    if (item.type == 1) {
      return switch (item.template) {
        1 => const PetWidgetConfigScreen(),
        2 => const CountdownWidgetConfigScreen(
          variant: CountdownWidgetVariant.photo,
        ),
        3 => const CountdownWidgetConfigScreen(
          variant: CountdownWidgetVariant.simple,
        ),
        4 => const CountdownWidgetConfigScreen(
          variant: CountdownWidgetVariant.multiSmall,
        ),
        5 => const CountdownWidgetConfigScreen(
          variant: CountdownWidgetVariant.multiMedium,
        ),
        6 => const CountdownWidgetConfigScreen(
          variant: CountdownWidgetVariant.calendar,
        ),
        7 => const CountdownWidgetConfigScreen(
          variant: CountdownWidgetVariant.medium,
        ),
        _ => _buildGenericDetail(item),
      };
    }
    return switch (item.template) {
      1 => const PetIslandConfigScreen(),
      2 => const PhotoIslandConfigScreen(),
      3 => const TimerIslandConfigScreen(mode: TimerIslandMode.countUp),
      4 => const TimerIslandConfigScreen(mode: TimerIslandMode.countDown),
      5 => const MemorialIslandConfigScreen(),
      6 => const CustomIslandConfigScreen(),
      _ => _buildGenericDetail(item),
    };
  }

  Widget _buildGenericDetail(WidgetDefinition item) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: _appBar(item.title),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildTemplatePreview(item)),
                  const SizedBox(height: 26),
                  for (final key in item.config) ...[
                    _buildOption(item, key),
                    const SizedBox(height: 18),
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
                    child: Center(
                      child: Text(
                        item.isIsland ? '开启灵动岛' : '保存到我的组件',
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

  PreferredSizeWidget _appBar(String title) {
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
      title: Padding(
        padding: const EdgeInsets.only(top: AppLayout.memorialDetailTopPadding),
        child: SizedBox(
          height: _headerHeight,
          child: Center(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(WidgetDefinition item, String key) {
    final label = item.optionLabel(key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        switch (key) {
          'pet_select' => _petPicker(),
          'anniversary_select' => _memorialPicker(),
          'text_style' || 'text_color' => _colorPicker(),
          'number_style' => _fontPicker(),
          'background' => _backgroundPicker(item.type),
          'icon' => _iconPicker(),
          'upload_image' => _albumButton(_pickUploadImage),
          'text_size' => _textSizeSlider(),
          'custom_text' => _customTextField(),
          'icon_position' => _iconPositionPicker(),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }

  Widget _buildTemplatePreview(WidgetDefinition item) {
    final wide =
        item.columnSpan > 1 || item.rowSpan == 1 && item.columnSpan == 3;
    final width = wide ? 280.0 : 138.0;
    final height = wide ? 124.0 : 138.0;
    if (item.isIsland) {
      return Column(
        children: [
          Container(
            width: 150,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _selectedIcon(22),
                const Spacer(),
                if (_iconOnRight) _selectedIcon(22),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _previewSurface(item, 245, 88),
        ],
      );
    }
    return _previewSurface(item, width, height);
  }

  Widget _previewSurface(WidgetDefinition item, double width, double height) {
    final background = _selectedBackground ?? item.defaultBackground;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(item.isIsland ? 18 : 20),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (background.isNotEmpty) _sourceImage(background),
          if (_uploadedImage != null) _sourceImage(_uploadedImage!),
          _templateContent(item),
        ],
      ),
    );
  }

  Widget _templateContent(WidgetDefinition item) {
    if (item.template < 1 || item.template > 6) {
      return item.image.isEmpty
          ? const SizedBox.shrink()
          : _sourceImage(item.image);
    }
    if (item.isIsland) return _islandTemplateContent(item.template);
    return switch (item.template) {
      1 =>
        _petImages.isEmpty
            ? const SizedBox.shrink()
            : Center(
                child: _sourceImage(
                  _petImages[_selectedPet],
                  fit: BoxFit.contain,
                ),
              ),
      2 =>
        _uploadedImage == null && item.image.isNotEmpty
            ? _sourceImage(item.image)
            : _textOverlay(),
      3 => _countdownContent(),
      4 || 5 => _multiMemorialContent(),
      6 => _calendarContent(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _islandTemplateContent(int template) {
    if (template == 1 && _petImages.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: _sourceImage(
                _petImages[_selectedPet],
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _textOverlay()),
          ],
        ),
      );
    }
    if (template == 2) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _uploadedImage == null
                ? const SizedBox.shrink()
                : _sourceImage(_uploadedImage!),
          ),
          Expanded(flex: 3, child: _textOverlay()),
        ],
      );
    }
    final value = switch (template) {
      3 => '05 : 11',
      4 => '03 : 04 : 06',
      5 => '$_selectedDays天',
      _ => '',
    };
    if (template == 6) return _textOverlay();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                  _selectedMemorial?.title ?? _textController.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textOverlay() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          _textController.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: _textSize,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
    );
  }

  Widget _countdownContent() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedMemorial?.title ?? '纪念日',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DayNumberDisplay(
                value: _selectedDays,
                fontStyleId: _fontStyleId,
                digitHeight: 46,
                textStyle: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              const SizedBox(width: 3),
              Text('天', style: TextStyle(fontSize: 13, color: _textColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _multiMemorialContent() {
    final items = MemorialStore.instance.items.take(3).toList();
    return Padding(
      padding: const EdgeInsets.all(9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final item in items)
            Container(
              height: 28,
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  Text(
                    '${item.listDisplayDate.difference(DateTime.now()).inDays.abs()}天',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _calendarContent() {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${now.year} / ${now.month}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const Spacer(),
          Center(
            child: Text(
              '${now.day}',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: _textColor,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  MemorialDay? get _selectedMemorial {
    final items = MemorialStore.instance.items;
    for (final item in items) {
      if (item.id == _selectedMemorialId) return item;
    }
    return items.isEmpty ? null : items.first;
  }

  int get _selectedDays {
    final item = _selectedMemorial;
    if (item == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return item.listDisplayDate.difference(today).inDays.abs();
  }

  Widget _petPicker() => SizedBox(
    height: 66,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _petImages.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) => GestureDetector(
        onTap: () => setState(() => _selectedPet = index),
        child: Container(
          width: 66,
          height: 66,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1F4),
            shape: BoxShape.circle,
            border: Border.all(
              color: index == _selectedPet
                  ? AppColors.accent
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipOval(
            child: _sourceImage(_petImages[index], fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );

  Widget _memorialPicker() {
    final items = MemorialStore.instance.items;
    return Column(
      children: [
        for (final item in items.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: InkWell(
              onTap: () => setState(() => _selectedMemorialId = item.id),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1F4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.id == _selectedMemorial?.id
                        ? AppColors.accent
                        : Colors.transparent,
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
                    Text(
                      '${item.listDisplayDate.difference(DateTime.now()).inDays.abs()}天',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fontPicker() {
    final items = FontStyleConfig.displayItems();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final id = '${items[index]['id']}';
          final preview = FontStyleConfig.previewImageUrl(id);
          return GestureDetector(
            onTap: () => setState(() => _fontStyleId = id),
            child: Container(
              width: 48,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: id == _fontStyleId
                      ? AppColors.accent
                      : AppColors.borderMedium,
                  width: id == _fontStyleId ? 2 : 1,
                ),
              ),
              child: preview == null
                  ? const Center(
                      child: Text('0', style: TextStyle(fontSize: 18)),
                    )
                  : Image.network(preview, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }

  Widget _colorPicker() => Row(
    children: [
      for (final color in const [
        Colors.white,
        Colors.black,
        Color(0xFFFF9E99),
        Color(0xFFFFC85D),
        Color(0xFF83E7B5),
        Color(0xFF6695F5),
        Color(0xFFB36EF3),
      ])
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () => setState(() => _textColor = color),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color == _textColor
                      ? AppColors.accent
                      : AppColors.borderLight,
                  width: color == _textColor ? 2 : 1,
                ),
              ),
            ),
          ),
        ),
      InkWell(
        onTap: _pickTextColor,
        child: const Icon(
          Icons.palette_outlined,
          size: 30,
          color: AppColors.accent,
        ),
      ),
    ],
  );

  Widget _backgroundPicker(int type) {
    final items = BackgroundStore.instance.widgetItems(type);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          if (index == 0) {
            return InkWell(
              onTap: _pickBackgroundColor,
              child: Container(
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
              ),
            );
          }
          final source =
              '${items[index - 1]['image'] ?? items[index - 1]['url'] ?? ''}';
          final selected = _selectedBackground == source;
          return InkWell(
            onTap: () => setState(() => _selectedBackground = source),
            child: Container(
              width: 48,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.borderMedium,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Image.network(
                PetImageService.resolveUrl(source),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _iconPicker() => Row(
    children: [
      _albumButton(_pickIconImage),
      const SizedBox(width: 12),
      InkWell(
        onTap: _showEmojiPicker,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F1F4),
            shape: BoxShape.circle,
          ),
          child: Text(_icon, style: const TextStyle(fontSize: 24)),
        ),
      ),
    ],
  );

  Widget _albumButton(VoidCallback onTap) => InkWell(
    onTap: onTap,
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

  Widget _textSizeSlider() => Row(
    children: [
      const Text('小'),
      Expanded(
        child: Slider(
          value: _textSize,
          min: 12,
          max: 24,
          activeColor: AppColors.accent,
          onChanged: (value) => setState(() => _textSize = value),
        ),
      ),
      const Text('大'),
    ],
  );

  Widget _customTextField() => TextField(
    controller: _textController,
    maxLines: 1,
    maxLength: 24,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    ),
  );

  Widget _iconPositionPicker() => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(value: false, label: Text('左侧')),
      ButtonSegment(value: true, label: Text('右侧')),
    ],
    selected: {_iconOnRight},
    onSelectionChanged: (value) => setState(() => _iconOnRight = value.first),
  );

  Widget _selectedIcon(double size) {
    if (_iconImage != null) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: _sourceImage(_iconImage!, fit: BoxFit.cover)),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(_icon, style: TextStyle(fontSize: size * .7)),
      ),
    );
  }

  Widget _sourceImage(String source, {BoxFit fit = BoxFit.cover}) {
    final resolved = PetImageService.resolveUrl(source);
    final local =
        resolved.startsWith('/') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(resolved);
    if (local) return Image.file(File(resolved), fit: fit);
    return Image.network(
      resolved,
      fit: fit,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _preparePets() async {
    final cache = AppCacheStore.instance;
    await cache.fetchConfig();
    final images = <String>[];
    void add(String? value) {
      final image = value?.trim() ?? '';
      if (image.isNotEmpty && !images.contains(image)) images.add(image);
    }

    add(cache.defaultPetCatImageUrl);
    add(cache.defaultPetDogImageUrl);
    if (PetDisplayImage.isCustomPet(cache.petProfile)) {
      final raw = PetDisplayImage.resolveRawSync();
      add(raw == null ? null : PetImageService.resolveUrl(raw));
    }
    if (!mounted) return;
    setState(() {
      _petImages.addAll(images);
      if (_selectedPet >= _petImages.length) _selectedPet = 0;
    });
  }

  Future<void> _pickTextColor() async {
    final value = await showComponentColorPicker(
      context,
      initialColor: _textColor,
    );
    if (value != null && mounted) setState(() => _textColor = value);
  }

  Future<void> _pickBackgroundColor() async {
    final value = await showComponentColorPicker(
      context,
      initialColor: _backgroundColor,
    );
    if (value != null && mounted) {
      setState(() {
        _backgroundColor = value;
        _selectedBackground = '';
      });
    }
  }

  Future<void> _pickUploadImage() async {
    final value = await PetImagePicker.pickFromGallery(context);
    if (value != null && value.isNotEmpty && mounted) {
      setState(() => _uploadedImage = value);
    }
  }

  Future<void> _pickIconImage() async {
    final value = await PetImagePicker.pickFromGallery(context);
    if (value != null && value.isNotEmpty && mounted) {
      setState(() => _iconImage = value);
    }
  }

  Future<void> _showEmojiPicker() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 370,
          child: EmojiPicker(
            onEmojiSelected: (_, emoji) => Navigator.pop(context, emoji.emoji),
            config: const Config(
              height: 370,
              bottomActionBarConfig: BottomActionBarConfig(enabled: false),
            ),
          ),
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        _icon = value;
        _iconImage = null;
      });
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedPet = prefs.getInt('${_prefsPrefix}_pet') ?? 0;
      _selectedMemorialId = prefs.getString('${_prefsPrefix}_memorial');
      _fontStyleId =
          prefs.getString('${_prefsPrefix}_font') ??
          FontStyleConfig.normalStyleId;
      _textColor = Color(
        prefs.getInt('${_prefsPrefix}_text_color') ?? Colors.white.toARGB32(),
      );
      _backgroundColor = Color(
        prefs.getInt('${_prefsPrefix}_background_color') ??
            const Color(0xFF98CBF2).toARGB32(),
      );
      _selectedBackground = prefs.getString('${_prefsPrefix}_background');
      _uploadedImage = prefs.getString('${_prefsPrefix}_upload');
      _iconImage = prefs.getString('${_prefsPrefix}_icon_image');
      _icon = prefs.getString('${_prefsPrefix}_icon') ?? '🔔';
      _textSize = prefs.getDouble('${_prefsPrefix}_text_size') ?? 16;
      _textController.text =
          prefs.getString('${_prefsPrefix}_text') ?? '每天都要开心';
      _iconOnRight = prefs.getBool('${_prefsPrefix}_icon_right') ?? false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt('${_prefsPrefix}_pet', _selectedPet),
      if (_selectedMemorialId != null)
        prefs.setString('${_prefsPrefix}_memorial', _selectedMemorialId!),
      prefs.setString('${_prefsPrefix}_font', _fontStyleId),
      prefs.setInt('${_prefsPrefix}_text_color', _textColor.toARGB32()),
      prefs.setInt(
        '${_prefsPrefix}_background_color',
        _backgroundColor.toARGB32(),
      ),
      if (_selectedBackground != null)
        prefs.setString('${_prefsPrefix}_background', _selectedBackground!),
      if (_uploadedImage != null)
        prefs.setString('${_prefsPrefix}_upload', _uploadedImage!),
      if (_iconImage != null)
        prefs.setString('${_prefsPrefix}_icon_image', _iconImage!),
      prefs.setString('${_prefsPrefix}_icon', _icon),
      prefs.setDouble('${_prefsPrefix}_text_size', _textSize),
      prefs.setString('${_prefsPrefix}_text', _textController.text.trim()),
      prefs.setBool('${_prefsPrefix}_icon_right', _iconOnRight),
    ]);
    if (mounted) await showCenterTip(context, '已保存');
  }
}
