import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/saved_widget_store.dart';
import '../../models/saved_widget.dart';
import 'transparent_wallpaper_setup_screen.dart';

class MyWidgetsScreen extends StatefulWidget {
  const MyWidgetsScreen({super.key});

  @override
  State<MyWidgetsScreen> createState() => _MyWidgetsScreenState();
}

class _MyWidgetsScreenState extends State<MyWidgetsScreen> {
  static const _headerContentHeight = 52.0;

  late final PageController _pageController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    SavedWidgetStore.instance.load(force: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        toolbarHeight:
            _headerContentHeight + AppLayout.memorialDetailTopPadding,
        backgroundColor: AppColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
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
            child: const SizedBox(
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
        actions: [
          if (Platform.isIOS)
            Padding(
              padding: const EdgeInsets.only(
                right: 8,
                top: AppLayout.memorialDetailTopPadding,
              ),
              child: SizedBox(
                height: _headerContentHeight,
                child: Center(
                  child: TextButton(
                    onPressed: () =>
                        TransparentWallpaperSetupScreen.open(context),
                    child: const Text(
                      '透明壁纸',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.accentDark,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 72),
        ],
        centerTitle: true,
        title: const Padding(
          padding: EdgeInsets.only(top: AppLayout.memorialDetailTopPadding),
          child: SizedBox(
            height: _headerContentHeight,
            child: Center(
              child: Text(
                '我的组件',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
              child: Row(
                children: [
                  _tab('小号', 0),
                  const SizedBox(width: 28),
                  _tab('中号', 1),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: SavedWidgetStore.instance,
                builder: (context, _) {
                  final all = SavedWidgetStore.instance.items;
                  final small = all.where((e) => !e.isMediumSize).toList();
                  final medium = all.where((e) => e.isMediumSize).toList();
                  return PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      if (_selectedTab != index) {
                        setState(() => _selectedTab = index);
                      }
                    },
                    children: [
                      _buildList(small, isMedium: false),
                      _buildList(medium, isMedium: true),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, int index) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () => _selectTab(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.accentDark : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 24 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildList(List<SavedWidget> items, {required bool isMedium}) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          isMedium ? '还没有保存中号组件' : '还没有保存小号组件',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPlaceholder,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF0F1F4),
                    indent: 12,
                    endIndent: 12,
                  ),
                _SavedWidgetTile(
                  item: items[i],
                  isMedium: isMedium,
                  onDelete: () => _delete(items[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _delete(SavedWidget item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除组件'),
        content: Text('确定删除“${item.title}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SavedWidgetStore.instance.remove(item.widgetId);
    }
  }
}

class _SavedWidgetTile extends StatelessWidget {
  const _SavedWidgetTile({
    required this.item,
    required this.isMedium,
    required this.onDelete,
  });

  final SavedWidget item;
  final bool isMedium;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // 小号正方形；中号同高度，宽度按约 2.1:1 比例随高度变化
    const side = 80.0;
    final thumbH = side;
    final thumbW = isMedium ? side * 2.1 : side;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: thumbW,
            height: thumbH,
            child: item.image.isEmpty
                ? const Icon(Icons.widgets_outlined, color: AppColors.accent)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _SavedWidgetThumb(image: item.image),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              item.title.isEmpty ? '小组件' : item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: '删除',
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.textPlaceholder,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedWidgetThumb extends StatelessWidget {
  const _SavedWidgetThumb({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.widgets_outlined, color: AppColors.accent);
    final src = image.trim();
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    final path = src.startsWith('file://')
        ? Uri.parse(src).toFilePath()
        : src;
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
