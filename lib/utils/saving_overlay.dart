import 'package:flutter/material.dart';

import '../config/colors.dart';

/// 保存等异步操作时显示全屏转圈，结束后自动关闭
Future<T?> withSavingOverlay<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black26,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.accent,
          ),
        ),
      ),
    ),
  );
  try {
    return await action();
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
