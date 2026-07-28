import 'package:flutter/material.dart';

import '../config/colors.dart';

/// 与宠物岛一致的「已上岛」居中成功弹窗（约 2 秒自动关闭）。
Future<void> showIslandSuccessDialog(BuildContext context) async {
  var dialogOpen = true;
  final navigator = Navigator.of(context, rootNavigator: true);
  Future.delayed(const Duration(seconds: 2), () {
    if (dialogOpen && navigator.mounted && navigator.canPop()) {
      navigator.pop();
    }
  });
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    requestFocus: false,
    barrierDismissible: false,
    barrierColor: Colors.black45,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: UnconstrainedBox(
        child: Container(
          width: 152,
          height: 152,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 原图 320×183，按比例显示；上下留白使弹窗呈正方形
              Image.asset(
                'assets/images/shimajima.png',
                width: 120,
                height: 69,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              const Text(
                '已上岛',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  dialogOpen = false;
}
