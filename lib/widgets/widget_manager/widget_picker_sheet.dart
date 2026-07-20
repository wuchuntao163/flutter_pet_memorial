import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/saved_widget_store.dart';
import '../../l10n/tr.dart';
import '../../models/saved_widget.dart';
import '../common/app_logo.dart';
import 'widget_desktop_preview.dart';

/// 图一：小组件尺寸选择底部弹层
class WidgetPickerSheet extends StatefulWidget {
  const WidgetPickerSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await SavedWidgetStore.instance.load();
    if (!context.mounted) return;
    final family = await showModalBottomSheet<WidgetPickerFamily>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const WidgetPickerSheet(),
    );
    if (family == null || !context.mounted) return;
    await WidgetDesktopPreviewPage.open(context, family: family);
  }

  @override
  State<WidgetPickerSheet> createState() => _WidgetPickerSheetState();
}

class _WidgetPickerSheetState extends State<WidgetPickerSheet> {
  static const _iosBlue = Color(0xFF007AFF);
  static const _families = WidgetPickerFamily.values;

  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.78);
    SavedWidgetStore.instance.load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  WidgetPickerFamily get _family => _families[_index];

  List<SavedWidget> get _thumbs {
    final items = SavedWidgetStore.instance.items;
    if (items.isEmpty) return const [];
    return items.take(2).toList(growable: false);
  }

  Future<void> _onAdd() async {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(_family);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.82;
    final appName = tr('promotion.app_name', fb: '哈基米纪念日');

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 0),
              child: Row(
                children: [
                  const AppLogo(size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x14787880),
                      foregroundColor: const Color(0xFF3C3C43),
                    ),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                tr(_family.titleKey, fb: _family.titleFb),
                key: ValueKey(_family),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                tr(
                  'widget_manager.picker_subtitle',
                  fb: '选择你要添加的组件尺寸添加到桌面',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8E8E93),
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListenableBuilder(
                listenable: SavedWidgetStore.instance,
                builder: (context, _) {
                  return PageView.builder(
                    controller: _pageController,
                    itemCount: _families.length,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _index = i);
                    },
                    itemBuilder: (context, i) {
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          var scale = 1.0;
                          if (_pageController.position.haveDimensions) {
                            final page = _pageController.page ?? _index.toDouble();
                            scale = (1 - (page - i).abs() * 0.08).clamp(0.88, 1.0);
                          } else if (i != _index) {
                            scale = 0.92;
                          }
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: _PreviewCard(
                          family: _families[i],
                          appName: appName,
                          thumbs: _thumbs,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_families.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 8 : 7,
                  height: active ? 8 : 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? const Color(0xFF3C3C43)
                        : const Color(0xFFC7C7CC),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottom),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: _iosBlue,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.6),
                        ),
                        child: const Icon(Icons.add, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tr('widget_manager.add_widget', fb: '添加小组件'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.family,
    required this.appName,
    required this.thumbs,
  });

  final WidgetPickerFamily family;
  final String appName;
  final List<SavedWidget> thumbs;

  @override
  Widget build(BuildContext context) {
    final isSmall = family == WidgetPickerFamily.small;
    final isMedium = family == WidgetPickerFamily.medium;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: isSmall ? 220 : 320,
          maxHeight: isMedium ? 210 : 280,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const AppLogo(size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 2),
              Text(
                tr('widget_manager.tap_below', fb: '点击下方'),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8E8E93),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr('widget_manager.add_widget', fb: '添加小组件'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'widget_manager.add_to_desktop',
                  fb: '将组件添加到桌面',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8E8E93),
                ),
              ),
              const Spacer(),
              if (thumbs.isNotEmpty) _MyWidgetThumbs(items: thumbs),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyWidgetThumbs extends StatelessWidget {
  const _MyWidgetThumbs({required this.items});

  final List<SavedWidget> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length && i < 2; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          _Thumb(item: items[i]),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item});

  final SavedWidget item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: item.image.isEmpty
          ? const Icon(Icons.widgets_outlined, size: 22, color: Colors.grey)
          : Image.network(
              item.image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.widgets_outlined, size: 22),
            ),
    );
  }
}
