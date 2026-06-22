import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../l10n/tr.dart';
import '../../services/app_launch.dart';
import '../../services/network_service.dart';
import 'app_logo.dart';

/// 应用开屏：先获取网络状态，再执行启动初始化，完成后自动消失。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _logoRadius = 20.0;
  static const _logoSize = 96.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    // 1. 检测网络  2. 登录 + getConfig 等启动初始化  3. routeReady 后进入选宠/首页
    await NetworkService.instance.ensureReady();
    if (!mounted) return;
    await AppLaunch.instance.onLaunch();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgPrimary,
      child: Align(
        alignment: const Alignment(0, -0.22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(_logoRadius),
              child: const AppLogo(size: _logoSize),
            ),
            const SizedBox(height: 14),
            Text(
              tr('app.title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
