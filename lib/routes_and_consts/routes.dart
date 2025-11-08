import 'package:Bloomee/screens/widgets/global_footer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:Bloomee/routes_and_consts/global_str_consts.dart';
import 'package:Bloomee/screens/screen/common_views/add_to_playlist_screen.dart';
import 'package:Bloomee/screens/screen/player_screen.dart';
import 'package:Bloomee/screens/screen/explore_screen.dart';
import 'package:Bloomee/screens/screen/library_screen.dart';
import 'package:Bloomee/screens/screen/library_views/import_media_view.dart';
import 'package:Bloomee/screens/screen/library_views/playlist_screen.dart';
import 'package:Bloomee/screens/screen/offline_screen.dart';
import 'package:Bloomee/screens/screen/search_screen.dart';
import 'package:Bloomee/screens/screen/chart/chart_view.dart';
import 'package:Bloomee/screens/screen/auth_screen.dart';
import 'package:Bloomee/screens/screen/profile_setup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Bloomee/screens/screen/social/friends_page.dart';
import 'package:Bloomee/screens/screen/social/notifications_page.dart';
import 'dart:async';

class GlobalRoutes {
  static final globalRouterKey = GlobalKey<NavigatorState>();

  // Notifier to refresh GoRouter redirects on auth changes
  static final _authRefresh = _GoRouterRefreshStream(
      Supabase.instance.client.auth.onAuthStateChange);

  static Future<bool> _userHasProfile() async {
    final supa = Supabase.instance.client;
    final user = supa.auth.currentUser;
    if (user == null) return false;
    try {
      final res = await supa
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  static final globalRouter = GoRouter(
    initialLocation: '/Explore',
    navigatorKey: globalRouterKey,
    refreshListenable: _authRefresh,
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final loggedIn = session != null;
      final goingToAuth = state.matchedLocation == '/Auth' || state.uri.path == '/Auth';
      final goingToProfileSetup = state.matchedLocation == '/ProfileSetup' || state.uri.path == '/ProfileSetup';

      if (!loggedIn) {
        return goingToAuth ? null : '/Auth';
      }

      // If logged in, prevent going back to Auth
      if (goingToAuth) {
        return '/Explore';
      }

      // Enforce first-time Profile Setup: if no profile row exists, force /ProfileSetup
      final hasProfile = await _userHasProfile();
      if (!hasProfile && !goingToProfileSetup) {
        return '/ProfileSetup';
      }
      return null;
    },
    routes: [
      GoRoute(
        name: GlobalStrConsts.playerScreen,
        path: "/MusicPlayer",
        parentNavigatorKey: globalRouterKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            child: const AudioPlayerView(),
            transitionDuration: const Duration(milliseconds: 400),
            reverseTransitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              final tween = Tween(begin: begin, end: end);
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                reverseCurve: Curves.easeIn,
                curve: Curves.easeInOut,
              );
              final offsetAnimation = curvedAnimation.drive(tween);
              return SlideTransition(
                position: offsetAnimation,
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        name: GlobalStrConsts.notificationsScreen,
        path: '/Notifications',
        parentNavigatorKey: globalRouterKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        name: GlobalStrConsts.authScreen,
        path: '/Auth',
        parentNavigatorKey: globalRouterKey,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        name: GlobalStrConsts.profileSetupScreen,
        path: '/ProfileSetup',
        parentNavigatorKey: globalRouterKey,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/AddToPlaylist',
        parentNavigatorKey: globalRouterKey,
        name: GlobalStrConsts.addToPlaylistScreen,
        builder: (context, state) => const AddToPlaylistScreen(),
      ),
      StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              GlobalFooter(navigationShell: navigationShell),
          branches: [
            // StatefulShellBranch(routes: [
            //   GoRoute(
            //     name: GlobalStrConsts.testScreen,
            //     path: '/Test',
            //     builder: (context, state) => TestView(),
            //   ),
            // ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  name: GlobalStrConsts.exploreScreen,
                  path: '/Explore',
                  builder: (context, state) => const ExploreScreen(),
                  routes: [
                    GoRoute(
                        name: GlobalStrConsts.ChartScreen,
                        path: 'ChartScreen:chartName',
                        builder: (context, state) => ChartScreen(
                            chartName:
                                state.pathParameters['chartName'] ?? "none")),
                  ])
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                name: GlobalStrConsts.searchScreen,
                path: '/Search',
                builder: (context, state) {
                  if (state.uri.queryParameters['query'] != null) {
                    return SearchScreen(
                      searchQuery:
                          state.uri.queryParameters['query']!.toString(),
                    );
                  } else {
                    return const SearchScreen();
                  }
                },
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                name: GlobalStrConsts.offlineScreen,
                path: '/Offline',
                builder: (context, state) => const OfflineScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                name: GlobalStrConsts.friendsScreen,
                path: '/Friends',
                builder: (context, state) => const FriendsPage(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  name: GlobalStrConsts.libraryScreen,
                  path: '/Library',
                  builder: (context, state) => const LibraryScreen(),
                  routes: [
                    GoRoute(
                      path: GlobalStrConsts.ImportMediaFromPlatforms,
                      name: GlobalStrConsts.ImportMediaFromPlatforms,
                      builder: (context, state) =>
                          const ImportMediaFromPlatformsView(),
                    ),
                    GoRoute(
                      name: GlobalStrConsts.playlistView,
                      path: GlobalStrConsts.playlistView,
                      builder: (context, state) {
                        return const PlaylistView();
                      },
                    ),
                  ]),
            ]),
          ])
    ],
  );
}

class _GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription _sub;
  _GoRouterRefreshStream(Stream<AuthState> stream) {
    _sub = stream.listen((event) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
