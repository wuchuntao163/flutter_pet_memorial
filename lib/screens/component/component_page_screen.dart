import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../data/banner_store.dart';
import '../../data/widget_store.dart';
import '../../models/widget_definition.dart';
import '../../router/app_routes.dart';
import '../../widgets/common/profile_banner.dart';

class ComponentPageScreen extends StatefulWidget {
  const ComponentPageScreen({super.key});

  @override
  State<ComponentPageScreen> createState() => _ComponentPageScreenState();
}

class _ComponentPageScreenState extends State<ComponentPageScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    final store = BannerStore.instance;
    if (!store.listLoaded && !store.isLoading) {
      store.fetchList();
    }
    WidgetStore.instance.fetchList(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            AppCacheStore.instance,
            BannerStore.instance,
            WidgetStore.instance,
          ]),
          builder: (context, _) {
            final cache = AppCacheStore.instance;
            return Stack(
              children: [
                Positioned(
                  right: -5,
                  top: -6,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/catspaw1.png',
                      width: 46,
                      height: 46,
                    ),
                  ),
                ),
                Positioned(
                  left: -6,
                  bottom: AppLayout.bottomNavBarInset + 54,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/catspaw2.png',
                      width: 54,
                      height: 54,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: _buildHeader(
                          cache.liveActivityCatImageUrl,
                          cache.liveActivityDogImageUrl,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: _buildBanner(),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: _buildTabs(),
                      ),
                      Expanded(child: _buildCategoryContent()),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(String? catUrl, String? dogUrl) {
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RemotePetIcon(url: catUrl),
            const SizedBox(width: 0),
            _RemotePetIcon(url: dogUrl),
          ],
        ),
        const Spacer(),
        Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Text(
            '我的组件',
            style: TextStyle(
              color: AppColors.textPlaceholder,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    final store = BannerStore.instance;
    if (store.isLoading && store.items.isEmpty) {
      return const SizedBox(
        height: 102,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    if (store.items.isEmpty) return const SizedBox.shrink();
    return ProfileBanner(items: store.items, height: 102);
  }

  Widget _buildTabs() {
    return Row(
      children: [_tab('小组件', 0), const SizedBox(width: 28), _tab('灵动岛', 1)],
    );
  }

  Widget _buildCategoryContent() {
    if (_selectedTab == 1) return _buildDynamicIslandContent();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        22,
        18,
        22,
        AppLayout.bottomNavBarInset + 40,
      ),
      children: [
        _buildApiWidgetGrid(1),
        const SizedBox(height: 28),
        const Text(
          '更多小组件敬请期待',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textPlaceholder),
        ),
      ],
    );
  }

  Widget _buildDynamicIslandContent() {
    final store = WidgetStore.instance;
    if (store.isLoading(2) && store.items(2).isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (store.items(2).isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          22,
          18,
          22,
          AppLayout.bottomNavBarInset + 40,
        ),
        children: [
          _SpannedWidgetGrid(
            items: store.items(2),
            columns: 2,
            previewAspectRatio: 1.55,
          ),
          const SizedBox(height: 30),
          const Text(
            '系统限制灵动岛后台最多保持8-12小时\n消失后请重新开启',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.5,
              fontSize: 12,
              color: AppColors.textPlaceholder,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildApiWidgetGrid(int type) {
    final store = WidgetStore.instance;
    final items = store.items(type);
    if (store.isLoading(type) && items.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return _SpannedWidgetGrid(items: items);
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
    if (_selectedTab != index) setState(() => _selectedTab = index);
    final type = index + 1;
    final store = WidgetStore.instance;
    if (store.items(type).isEmpty && !store.isLoading(type)) {
      store.fetchList(type, forceRefresh: true);
    }
  }
}

class _RemotePetIcon extends StatelessWidget {
  const _RemotePetIcon({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    return SizedBox(
      width: 30,
      height: 30,
      child: value.isEmpty
          ? const Icon(Icons.pets, size: 16, color: AppColors.accentDark)
          : Image.network(
              value,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.pets, size: 16, color: AppColors.accentDark),
            ),
    );
  }
}

class _SpannedWidgetGrid extends StatelessWidget {
  const _SpannedWidgetGrid({
    required this.items,
    this.columns = 3,
    this.previewAspectRatio = 1,
  });

  final List<WidgetDefinition> items;
  final int columns;
  final double previewAspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalGap = 12.0;
        const verticalGap = 20.0;
        const labelHeight = 28.0;
        final cellWidth =
            (constraints.maxWidth - horizontalGap * (columns - 1)) / columns;
        final cellHeight = cellWidth / previewAspectRatio + labelHeight;
        final occupied = <List<bool>>[];
        final placements = <_WidgetPlacement>[];

        void ensureRows(int count) {
          while (occupied.length < count) {
            occupied.add(List<bool>.filled(columns, false));
          }
        }

        for (final item in items) {
          final columnSpan = item.columnSpan.clamp(1, columns);
          final rowSpan = item.rowSpan.clamp(1, 20);
          var placed = false;
          for (var row = 0; !placed; row++) {
            ensureRows(row + rowSpan);
            for (var column = 0; column <= columns - columnSpan; column++) {
              var fits = true;
              for (var y = row; y < row + rowSpan && fits; y++) {
                for (var x = column; x < column + columnSpan; x++) {
                  if (occupied[y][x]) {
                    fits = false;
                    break;
                  }
                }
              }
              if (!fits) continue;
              for (var y = row; y < row + rowSpan; y++) {
                for (var x = column; x < column + columnSpan; x++) {
                  occupied[y][x] = true;
                }
              }
              placements.add(
                _WidgetPlacement(
                  item: item,
                  row: row,
                  column: column,
                  rowSpan: rowSpan,
                  columnSpan: columnSpan,
                ),
              );
              placed = true;
              break;
            }
          }
        }

        final rowCount = placements.fold<int>(
          0,
          (value, item) =>
              value > item.row + item.rowSpan ? value : item.row + item.rowSpan,
        );
        final height = rowCount == 0
            ? 0.0
            : rowCount * cellHeight + (rowCount - 1) * verticalGap;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              for (final placement in placements)
                Positioned(
                  left: placement.column * (cellWidth + horizontalGap),
                  top: placement.row * (cellHeight + verticalGap),
                  width:
                      cellWidth * placement.columnSpan +
                      horizontalGap * (placement.columnSpan - 1),
                  height:
                      cellHeight * placement.rowSpan +
                      verticalGap * (placement.rowSpan - 1),
                  child: _ApiWidgetTile(item: placement.item),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WidgetPlacement {
  const _WidgetPlacement({
    required this.item,
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.columnSpan,
  });

  final WidgetDefinition item;
  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;
}

class _ApiWidgetTile extends StatelessWidget {
  const _ApiWidgetTile({required this.item});

  final WidgetDefinition item;

  @override
  Widget build(BuildContext context) {
    final radius = item.columnSpan > 1 ? 16.0 : 14.0;
    return InkWell(
      onTap: () =>
          context.push(AppRoutes.componentConfig(item.id), extra: item),
      borderRadius: BorderRadius.circular(radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: item.isIsland ? Colors.white : const Color(0xFFF0F1F4),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: item.image.isEmpty
                  ? const Icon(Icons.widgets_outlined, color: AppColors.accent)
                  : Image.network(
                      item.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.widgets_outlined,
                        color: AppColors.accent,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
