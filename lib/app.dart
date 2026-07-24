import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'config/theme.dart';
import 'data/memorial_store.dart';
import 'models/font_style_config.dart';
import 'models/memorial_day.dart';
import 'router/app_router.dart';
import 'services/app_launch.dart';
import 'services/day_tick_service.dart';
import 'services/language_service.dart';
import 'l10n/tr.dart';
import 'services/app_launcher_channel.dart';
import 'services/platform_pet_sync.dart';
import 'widgets/common/splash_screen.dart';
import 'widgets/dialogs/number_style_dialog.dart';

class PetMemorialApp extends StatefulWidget {
  const PetMemorialApp({super.key});

  @override
  State<PetMemorialApp> createState() => _PetMemorialAppState();
}

class _PetMemorialAppState extends State<PetMemorialApp>
    with WidgetsBindingObserver {
  static const _navChannel = MethodChannel(
    'com.jnr.flutter_pet_memorial/navigation',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DayTickService.instance.start();
    _setupAndroidChannels();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DayTickService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 含灵动岛：按 active template 刷新天数 / 计时目标
      PlatformPetSync.afterProfileUpdate();
      MemorialStore.instance.resyncReminders();
    }
  }

  void _setupAndroidChannels() {
    if (!Platform.isAndroid) return;

    _navChannel.setMethodCallHandler((call) async {
      if (call.method == 'navigate') {
        final route = call.arguments?.toString();
        if (route != null && route.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            appRouter.go(route);
          });
        }
      }
      return null;
    });

    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == 'open_main') {
        AppLauncherChannel.launchMainApp();
      }
    });

    _consumePendingLaunchRoute();
  }

  Future<void> _consumePendingLaunchRoute() async {
    try {
      final route = await _navChannel.invokeMethod<String>('getPendingRoute');
      if (route != null && route.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appRouter.go(route);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([lang, AppLaunch.instance]),
      builder: (context, _) {
        return MaterialApp.router(
          title: tr('app.title'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: appRouter,
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ?child,
                if (!AppLaunch.instance.isRouteReady) const SplashScreen(),
              ],
            );
          },
          locale: lang.fontName == 'en'
              ? const Locale('en', 'US')
              : const Locale('zh', 'CN'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        );
      },
    );
  }
}

void showNumberStyleDialog(
  BuildContext context, {
  required MemorialDay memorialDay,
  String initialStyleId = FontStyleConfig.normalStyleId,
  ValueChanged<String>? onConfirm,
}) {
  showDialog(
    context: context,
    builder: (_) => NumberStyleDialog(
      memorialDay: memorialDay,
      initialStyleId: initialStyleId,
      onConfirm: onConfirm,
    ),
  );
}
