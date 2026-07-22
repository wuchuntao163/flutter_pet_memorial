import 'package:flutter/material.dart';

import '../config/colors.dart';

/// 保存等异步操作时显示全屏转圈，结束后自动关闭。
/// 使用 [DialogRoute] + [removeRoute]，避免误 pop 掉业务页面导致黑屏。
Future<T?> withSavingOverlay<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
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
  navigator.push(route);
  try {
    return await action();
  } finally {
    if (route.isActive) {
      navigator.removeRoute(route);
    }
  }
}
