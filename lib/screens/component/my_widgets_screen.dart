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

  @override
  void initState() {
    super.initState();
    SavedWidgetStore.instance.load(force: true);
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
                    onPressed: () => TransparentWallpaperSetupScreen.open(context),
                    child: const Text(
                      '透明壁纸',
                      style: TextStyle(fontSize: 13, color: AppColors.accentDark),
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
        child: ListenableBuilder(
          listenable: SavedWidgetStore.instance,
          builder: (context, _) {
            final items = SavedWidgetStore.instance.items;
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  '还没有保存小组件',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPlaceholder,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) => _SavedWidgetTile(
                item: items[index],
                onDelete: () => _delete(items[index]),
              ),
            );
          },
        ),
      ),
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
  const _SavedWidgetTile({required this.item, required this.onDelete});

  final SavedWidget item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.image.isEmpty
                ? const Icon(Icons.widgets_outlined, color: AppColors.accent)
                : _SavedWidgetThumb(image: item.image),
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
