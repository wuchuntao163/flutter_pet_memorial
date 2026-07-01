import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../l10n/tr.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/pet_display_image.dart';
import '../../router/app_routes.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../../widgets/floating_pet/draggable_floating_pet.dart';
import 'main_shell_scope.dart';

/// 主 Tab 容器：底部切换不压栈；悬浮宠物覆盖在当前 Tab 之上
class MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final bool showAdoptionSuccess;

  const MainShell({
    super.key,
    required this.navigationShell,
    this.showAdoptionSuccess = false,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _petVisible = false;
  Offset? _petPosition;
  int _petAnimationEpoch = 0;
  GlobalKey _floatingPetKey = GlobalKey();

  /// [anchor] dy=卡片顶边全局 y
  void _summonPet(Offset anchor) {
    final petSize = AppLayout.homePetAvatarSize;
    final media = MediaQuery.of(context);
    final padding = media.padding;
    final bottomNavHeight = 56 + padding.bottom;

    // 初始在最右侧，GIF 底边踩在卡片顶边上
    final x = media.size.width - petSize - padding.right;
    final y = (anchor.dy - petSize).clamp(
      padding.top,
      media.size.height - petSize - bottomNavHeight,
    );

    setState(() {
      _floatingPetKey = GlobalKey();
      _petAnimationEpoch++;
      _petVisible = true;
      _petPosition = Offset(x, y);
    });
  }

  void _recallPet() {
    setState(() {
      _floatingPetKey = GlobalKey();
      _petAnimationEpoch++;
      _petVisible = false;
      _petPosition = null;
    });
  }

  void _onPetPositionChanged(Offset pos) {
    _petPosition = pos;
  }

  /// 主 Tab 根页按一次返回直接退出
  void _onRootBack(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final onMainTab =
        path == AppRoutes.home || path == AppRoutes.profile;

    if (!onMainTab) {
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
        return;
      }
    }
    SystemNavigator.pop();
  }

  @override
  void initState() {
    super.initState();
    if (widget.showAdoptionSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showCenterTip(context, tr('app.adoption_success'));
        // 去掉 ?adopted=1，避免第一次返回只清 query、第二次才退出
        if (GoRouterState.of(context).uri.queryParameters.containsKey('adopted')) {
          context.go(AppRoutes.home);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onRootBack(context);
      },
      child: MainShellScope(
        isPetVisible: _petVisible,
        summonPet: _summonPet,
        recallPet: _recallPet,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: widget.navigationShell,
              ),
              if (_petVisible && _petPosition != null)
                ListenableBuilder(
                  listenable: AppCacheStore.instance,
                  builder: (context, _) {
                    final profile = AppCacheStore.instance.petProfile;
                    final gif = profile?['animated_image']?.toString();
                    final avatar = PetDisplayImage.resolveRaw();
                    return DraggableFloatingPet(
                      key: _floatingPetKey,
                      position: _petPosition!,
                      animationEpoch: _petAnimationEpoch,
                      animatedImage: gif,
                      fallbackImage: avatar,
                      size: AppLayout.homePetAvatarSize,
                      bottomInset: 56 + MediaQuery.paddingOf(context).bottom,
                      onPositionChanged: _onPetPositionChanged,
                    );
                  },
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: BottomNavBar(
                  navigationShell: widget.navigationShell,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
