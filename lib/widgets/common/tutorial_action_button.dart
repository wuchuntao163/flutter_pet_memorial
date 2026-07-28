import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';

/// 详情页右上角「教程」按钮
class TutorialActionButton extends StatelessWidget {
  const TutorialActionButton({
    super.key,
    required this.onTap,
    this.height = 52,
  });

  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 10,
          right: 10,
          // 与「返回」、标题同一行对齐
          top: AppLayout.memorialDetailTopPadding,
        ),
        child: SizedBox(
          height: height,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.question_mark,
                    size: 14,
                    color: AppColors.accent,
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Text(
                      '教程',
                      style: TextStyle(
                        height: 1,
                        fontSize: 10,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
