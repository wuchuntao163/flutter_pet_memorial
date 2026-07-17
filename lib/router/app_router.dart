import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';
import '../services/app_launch.dart';
import '../data/memorial_store.dart';
import '../screens/add_memorial/add_memorial_screen.dart';
import '../screens/bind_phone/bind_phone_screen.dart';
import '../screens/birthday_overview/birthday_overview_screen.dart';
import '../screens/main/main_shell.dart';
import '../screens/memorial_list/memorial_list_screen.dart';
import '../screens/pet_birthday_detail/pet_birthday_detail_screen.dart';
import '../screens/pet_naming/pet_naming_screen.dart';
import '../screens/avatar_style_selection/avatar_style_selection_screen.dart';
import '../screens/pet_type_selection/pet_type_selection_screen.dart';
import '../screens/privacy_policy/privacy_policy_screen.dart';
import '../screens/feedback/feedback_screen.dart';
import '../screens/component/component_page_screen.dart';
import '../screens/component/pet_widget_config_screen.dart';
import '../screens/component/countdown_widget_config_screen.dart';
import '../screens/component/pet_island_config_screen.dart';
import '../screens/component/timer_island_config_screen.dart';
import '../screens/component/memorial_island_config_screen.dart';
import '../screens/component/photo_island_config_screen.dart';
import '../screens/component/custom_island_config_screen.dart';
import '../screens/component/api_widget_config_screen.dart';
import '../models/widget_definition.dart';
import '../screens/profile/profile_screen.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.home,
  refreshListenable: AppLaunch.instance,
  redirect: (context, state) => AppLaunch.instance.redirect(state.uri.path),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        final adopted = state.uri.queryParameters['adopted'] == '1';
        return MainShell(
          navigationShell: navigationShell,
          showAdoptionSuccess: adopted,
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, _) => const MemorialListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, _) => const ProfileScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.component,
              builder: (_, _) => const ComponentPageScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentPet,
      builder: (_, _) => const PetWidgetConfigScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentPhotoCountdown,
      builder: (_, _) => const CountdownWidgetConfigScreen(
        variant: CountdownWidgetVariant.photo,
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentSimpleCountdown,
      builder: (_, _) => const CountdownWidgetConfigScreen(
        variant: CountdownWidgetVariant.simple,
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentMediumCountdown,
      builder: (_, _) => const CountdownWidgetConfigScreen(
        variant: CountdownWidgetVariant.medium,
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentMultiMemorial,
      builder: (_, _) => const CountdownWidgetConfigScreen(
        variant: CountdownWidgetVariant.multiSmall,
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentBirthdayCountdown,
      builder: (_, _) => const CountdownWidgetConfigScreen(
        variant: CountdownWidgetVariant.multiMedium,
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentCalendar,
      builder: (_, _) => const CountdownWidgetConfigScreen(
        variant: CountdownWidgetVariant.calendar,
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentPetIsland,
      builder: (_, _) => const PetIslandConfigScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentCountUpIsland,
      builder: (_, _) =>
          const TimerIslandConfigScreen(mode: TimerIslandMode.countUp),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentCountDownIsland,
      builder: (_, _) =>
          const TimerIslandConfigScreen(mode: TimerIslandMode.countDown),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentMemorialIsland,
      builder: (_, _) => const MemorialIslandConfigScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentPhotoIsland,
      builder: (_, _) => const PhotoIslandConfigScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.componentCustomIsland,
      builder: (_, _) => const CustomIslandConfigScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/component/config/:id',
      builder: (_, state) => ApiWidgetConfigScreen(
        widgetId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        initial: state.extra is WidgetDefinition
            ? state.extra! as WidgetDefinition
            : null,
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.bindPhone,
      builder: (_, _) => const BindPhoneScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.privacyPolicy,
      builder: (_, _) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.feedback,
      builder: (_, _) => const FeedbackScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.petType,
      builder: (_, _) => const PetTypeSelectionScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.avatarStyle,
      builder: (_, _) => const AvatarStyleSelectionScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/pet-naming/:petType',
      builder: (context, state) =>
          PetNamingScreen(petType: state.pathParameters['petType'] ?? 'cat'),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.memorialAdd,
      builder: (_, _) => const AddMemorialScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/memorial/:id',
      builder: (context, state) {
        final day = MemorialStore.instance.findById(
          state.pathParameters['id']!,
        );
        if (day == null) {
          return Scaffold(body: Center(child: Text(tr('router.not_found'))));
        }
        return MemorialDayDetailScreen(memorialDay: day);
      },
      routes: [
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: 'edit',
          builder: (context, state) {
            final day = MemorialStore.instance.findById(
              state.pathParameters['id']!,
            );
            if (day == null) {
              return Scaffold(
                body: Center(child: Text(tr('router.not_found'))),
              );
            }
            return AddMemorialScreen(editingDay: day);
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: 'overview',
          builder: (context, state) {
            final day = MemorialStore.instance.findById(
              state.pathParameters['id']!,
            );
            if (day == null) {
              return Scaffold(
                body: Center(child: Text(tr('router.not_found'))),
              );
            }
            return BirthdayOverviewScreen(memorialDay: day);
          },
        ),
      ],
    ),
  ],
);
