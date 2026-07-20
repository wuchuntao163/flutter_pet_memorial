import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../common/app_logo.dart';

/// 图二：小号组件占位引导卡（三步说明）
class InstructionalWidgetCard extends StatelessWidget {
  const InstructionalWidgetCard({
    super.key,
    this.size = 168,
    this.title,
    this.onLongPress,
  });

  final double size;
  final String? title;
  final VoidCallback? onLongPress;

  static const _stepYellow = Color(0xFFFFD60A);
  static const _stepText = Color(0xFF3C3C43);
  static const _line = Color(0xFFD1D1D6);

  @override
  Widget build(BuildContext context) {
    final steps = [
      tr('widget_manager.step1', fb: '长按进入编辑模式'),
      tr('widget_manager.step2', fb: '点击编辑小组件'),
      tr('widget_manager.step3', fb: '选择所需的小组件'),
    ];

    final card = Container(
      width: size,
      height: size,
      padding: EdgeInsets.fromLTRB(size * 0.09, size * 0.08, size * 0.09, size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: const AppLogo(size: 18),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title ?? tr('widget_manager.small_widget_title', fb: '小号组件'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: size * 0.085,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: size * 0.07),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stepH = constraints.maxHeight / steps.length;
                return Stack(
                  children: [
                    Positioned(
                      left: size * 0.055,
                      top: stepH * 0.28,
                      bottom: stepH * 0.28,
                      child: Container(width: 1.5, color: _line),
                    ),
                    Column(
                      children: [
                        for (var i = 0; i < steps.length; i++)
                          SizedBox(
                            height: stepH,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: size * 0.12,
                                  height: size * 0.12,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: _stepYellow,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: size * 0.07,
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                SizedBox(width: size * 0.045),
                                Expanded(
                                  child: Text(
                                    steps[i],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: size * 0.068,
                                      fontWeight: FontWeight.w500,
                                      color: _stepText,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );

    if (onLongPress == null) return card;
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}
