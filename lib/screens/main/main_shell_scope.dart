import 'package:flutter/material.dart';

/// 主壳层：供子页面控制悬浮宠物
class MainShellScope extends InheritedWidget {
  final bool isPetVisible;
  final void Function(Offset initialGlobalPosition, {String? animatedImage})
      summonPet;
  final VoidCallback recallPet;

  const MainShellScope({
    super.key,
    required this.isPetVisible,
    required this.summonPet,
    required this.recallPet,
    required super.child,
  });

  static MainShellScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MainShellScope>();
    assert(scope != null, 'MainShellScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(MainShellScope oldWidget) {
    return isPetVisible != oldWidget.isPetVisible;
  }
}
