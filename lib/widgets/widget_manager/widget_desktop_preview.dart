import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/tr.dart';
import 'instructional_widget_card.dart';

enum WidgetDesktopMenuAction { editWidget, editHomeScreen, removeWidget }

/// 图三：桌面预览上的长按编辑菜单
class WidgetDesktopEditMenu {
  WidgetDesktopEditMenu._();

  static Future<WidgetDesktopMenuAction?> show(
    BuildContext context, {
    required Offset widgetBottomLeft,
    required double menuWidth,
  }) {
    return showGeneralDialog<WidgetDesktopMenuAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim, _) {
        final safe = MediaQuery.paddingOf(ctx);
        final size = MediaQuery.sizeOf(ctx);
        var left = widgetBottomLeft.dx;
        var top = widgetBottomLeft.dy + 10;
        left = left.clamp(12.0, size.width - menuWidth - 12);
        top = top.clamp(safe.top + 8, size.height - 180 - safe.bottom);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                behavior: HitTestBehavior.opaque,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.0).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  ),
                  alignment: Alignment.topCenter,
                  child: _MenuCard(
                    onSelect: (action) => Navigator.pop(ctx, action),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.onSelect});

  final ValueChanged<WidgetDesktopMenuAction> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE6F2F2F7),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _item(
                label: tr('widget_manager.menu_edit_widget', fb: '编辑小组件'),
                icon: Icons.info_outline,
                onTap: () => onSelect(WidgetDesktopMenuAction.editWidget),
              ),
              const Divider(height: 1, thickness: 0.5, color: Color(0x4D3C3C43)),
              _item(
                label: tr('widget_manager.menu_edit_home', fb: '编辑主屏幕'),
                icon: Icons.grid_view_rounded,
                onTap: () => onSelect(WidgetDesktopMenuAction.editHomeScreen),
              ),
              const Divider(height: 1, thickness: 0.5, color: Color(0x4D3C3C43)),
              _item(
                label: tr('widget_manager.menu_remove', fb: '移除小组件'),
                icon: Icons.remove_circle_outline,
                destructive: true,
                onTap: () => onSelect(WidgetDesktopMenuAction.removeWidget),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? const Color(0xFFFF3B30) : Colors.black;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: color,
                    ),
                  ),
                ),
                Icon(icon, size: 22, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 图二→图三：添加后的桌面预览页（可长按编辑）
class WidgetDesktopPreviewPage extends StatefulWidget {
  const WidgetDesktopPreviewPage({
    super.key,
    required this.family,
  });

  final WidgetPickerFamily family;

  static Future<void> open(
    BuildContext context, {
    required WidgetPickerFamily family,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, animation, _) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: WidgetDesktopPreviewPage(family: family),
          );
        },
      ),
    );
  }

  @override
  State<WidgetDesktopPreviewPage> createState() =>
      _WidgetDesktopPreviewPageState();
}

enum WidgetPickerFamily { small, medium, large }

extension WidgetPickerFamilyX on WidgetPickerFamily {
  String get titleKey => switch (this) {
        WidgetPickerFamily.small => 'widget_manager.size_small',
        WidgetPickerFamily.medium => 'widget_manager.size_medium',
        WidgetPickerFamily.large => 'widget_manager.size_large',
      };

  String get titleFb => switch (this) {
        WidgetPickerFamily.small => '小号',
        WidgetPickerFamily.medium => '中号',
        WidgetPickerFamily.large => '大号',
      };

  String get widgetTitleFb => switch (this) {
        WidgetPickerFamily.small => '小号组件',
        WidgetPickerFamily.medium => '中号组件',
        WidgetPickerFamily.large => '大号组件',
      };
}

class _WidgetDesktopPreviewPageState extends State<WidgetDesktopPreviewPage>
    with SingleTickerProviderStateMixin {
  final _widgetKey = GlobalKey();
  late final AnimationController _popIn;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _popIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _popIn.dispose();
    super.dispose();
  }

  double get _widgetSize {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.42).clamp(158.0, 176.0);
  }

  Future<void> _onLongPress() async {
    if (_menuOpen) return;
    HapticFeedback.heavyImpact();
    final box = _widgetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final origin = box.localToGlobal(Offset.zero);
    final bottomLeft = Offset(origin.dx, origin.dy + box.size.height);

    setState(() => _menuOpen = true);
    final action = await WidgetDesktopEditMenu.show(
      context,
      widgetBottomLeft: bottomLeft,
      menuWidth: box.size.width.clamp(200.0, 280.0),
    );
    if (!mounted) return;
    setState(() => _menuOpen = false);

    switch (action) {
      case WidgetDesktopMenuAction.editWidget:
        await _showEditHint();
      case WidgetDesktopMenuAction.editHomeScreen:
        await _showHomeEditHint();
      case WidgetDesktopMenuAction.removeWidget:
        if (mounted) Navigator.of(context).pop();
      case null:
        break;
    }
  }

  Future<void> _showEditHint() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('widget_manager.menu_edit_widget', fb: '编辑小组件')),
        content: Text(
          tr(
            'widget_manager.edit_widget_hint',
            fb: '请在桌面长按小组件，选择「编辑小组件」，再挑选「我的组件」中已保存的样式。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common.confirm', fb: '确定')),
          ),
        ],
      ),
    );
  }

  Future<void> _showHomeEditHint() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('widget_manager.menu_edit_home', fb: '编辑主屏幕')),
        content: Text(
          tr(
            'widget_manager.edit_home_hint',
            fb: '此操作为系统主屏幕编辑。请在手机桌面空白处长按，进入编辑模式后可调整位置或移除。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common.confirm', fb: '确定')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appName = tr('promotion.app_name', fb: '哈基米纪念日');
    final title = tr(
      'widget_manager.${widget.family == WidgetPickerFamily.small ? 'small_widget_title' : widget.family == WidgetPickerFamily.medium ? 'medium_widget_title' : 'large_widget_title'}',
      fb: widget.family.widgetTitleFb,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 模拟桌面壁纸
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _menuOpen ? 14 : 6,
              sigmaY: _menuOpen ? 14 : 6,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF8EC5FC).withValues(alpha: 0.95),
                    const Color(0xFFE0C3FC).withValues(alpha: 0.95),
                    const Color(0xFFF9D1D1),
                  ],
                ),
              ),
              child: CustomPaint(painter: _FakeHomeIconsPainter()),
            ),
          ),
          if (_menuOpen)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.28),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                const Spacer(flex: 2),
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _popIn,
                    curve: Curves.easeOutBack,
                  ),
                  child: FadeTransition(
                    opacity: _popIn,
                    child: Column(
                      children: [
                        KeyedSubtree(
                          key: _widgetKey,
                          child: InstructionalWidgetCard(
                            size: _widgetSize,
                            title: title,
                            onLongPress: _onLongPress,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          appName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.92),
                            shadows: const [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Text(
                    tr(
                      'widget_manager.preview_tip',
                      fb: '长按上方小组件可编辑或移除',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeHomeIconsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    const cols = 4;
    const rows = 6;
    final cellW = size.width / (cols + 1);
    final cellH = size.height / (rows + 2);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cellW * (c + 1), cellH * (r + 1.2)),
            width: cellW * 0.42,
            height: cellW * 0.42,
          ),
          const Radius.circular(12),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
