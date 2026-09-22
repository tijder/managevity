import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_provider.dart';
import '../screens/about_screen.dart';
import '../screens/busy_screen.dart';
import '../screens/favourites_screen.dart';
import '../screens/guests_screen.dart';
import '../screens/info_screen.dart';
import '../screens/invoices_screen.dart';
import '../screens/lesson_detail_screen.dart';
import '../screens/location_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/memberships_screen.dart';
import '../screens/more_screen.dart';
import '../screens/my_lessons_screen.dart';
import '../screens/news_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/sync_settings_screen.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  AppRouter(this._container);

  final ProviderContainer _container;

  @override
  List<AutoRoute> get routes {
    final guard = SessionGuard(_container);
    return [
      AutoRoute(path: '/login', page: LoginRoute.page),
      // Public: readable without an account, and the page search engines can index.
      AutoRoute(path: '/about', page: AboutRoute.page),
      AutoRoute(path: '/location', page: LocationRoute.page, guards: [guard]),
      AutoRoute(
        path: '/',
        page: MainRoute.page,
        guards: [guard],
        children: [
          AutoRoute(path: '', page: ScheduleRoute.page, initial: true),
          AutoRoute(path: 'mine', page: MyLessonsRoute.page),
          AutoRoute(path: 'busy', page: BusyRoute.page),
          AutoRoute(path: 'more', page: MoreRoute.page),
        ],
      ),
      AutoRoute(path: '/lesson/:id', page: LessonDetailRoute.page, guards: [guard]),
      AutoRoute(path: '/sync', page: SyncSettingsRoute.page, guards: [guard]),
      AutoRoute(path: '/favourites', page: FavouritesRoute.page, guards: [guard]),
      AutoRoute(path: '/news', page: NewsRoute.page, guards: [guard]),
      AutoRoute(path: '/info', page: InfoRoute.page, guards: [guard]),
      AutoRoute(path: '/profile', page: ProfileRoute.page, guards: [guard]),
      AutoRoute(path: '/memberships', page: MembershipsRoute.page, guards: [guard]),
      AutoRoute(path: '/invoices', page: InvoicesRoute.page, guards: [guard]),
      AutoRoute(path: '/guests', page: GuestsRoute.page, guards: [guard]),
    ];
  }
}

/// Not logged in → login; logged in without a location → location picker.
class SessionGuard extends AutoRouteGuard {
  SessionGuard(this._container);

  final ProviderContainer _container;

  @override
  Future<void> onNavigation(NavigationResolver resolver, StackRouter router) async {
    final session = await _container.read(sessionProvider.future);
    if (session.ready) return resolver.next();

    // Remember where the visitor was going. Every page has its own URL, so a link to a
    // lesson or to the invoices must still lead there after signing in (or after choosing a
    // location) instead of dumping everyone on the timetable.
    // A direct URL to a deep page arrives as a stack (main screen first, the page on top),
    // and the guard of the first one is what runs: the real destination is the last route
    // still waiting behind it.
    final destination = resolver.pendingRoutes.isEmpty
        ? resolver.route
        : resolver.pendingRoutes.last;
    final requested = _requestedPath(destination);
    // The stops along the way (sign in, choose a location) are never a destination.
    if (!const {'/', '/login', '/location'}.contains(requested)) {
      _container.read(pendingPathProvider.notifier).set(requested);
    }

    if (!session.loggedIn) {
      resolver.redirectUntil(const LoginRoute());
    } else if (resolver.routeName != LocationRoute.name) {
      resolver.redirectUntil(const LocationRoute());
    } else {
      resolver.next();
    }
  }

  String _requestedPath(RouteMatch route) {
    final query = route.queryParams.rawMap;
    final path = '/${route.fullPath}'.replaceAll(RegExp('/+'), '/');
    return query.isEmpty
        ? path
        : Uri(
            path: path,
            queryParameters: {for (final e in query.entries) e.key: '${e.value}'},
          ).toString();
  }
}

/// Moves on after signing in or choosing a location: to the location screen if there is no
/// location yet (keeping the requested URL for later), otherwise to the URL that was asked
/// for, or the timetable. Shared by the login screen, the location screen and the demo button.
Future<void> continueAfterSession(StackRouter router, WidgetRef ref) async {
  if (ref.read(sessionProvider).value?.ready != true) {
    // One location means there is nothing to choose: skip the screen. (Most members, and
    // the demo.) Any trouble fetching them, and the location screen shows it with a retry.
    try {
      final locations = await ref.read(locationsProvider.future);
      if (locations.length == 1) {
        await ref.read(sessionProvider.notifier).chooseLocation(locations.single);
      }
    } catch (_) {}
  }
  if (ref.read(sessionProvider).value?.ready != true) {
    await router.replaceAll([const LocationRoute()]);
    return;
  }
  final path = ref.read(pendingPathProvider.notifier).take();
  await router.replaceAll([const MainRoute()]);
  // With the prefix matches a deep page gets the main screen under it, so "back" works.
  if (path != null) await router.navigatePath(path, includePrefixMatches: true);
}
