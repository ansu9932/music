import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/aura_theme.dart';
import 'presentation/discover/discover_view.dart';
import 'presentation/lifecycle/app_lifecycle_observer.dart';
import 'presentation/now_playing/now_playing_canvas.dart';
import 'presentation/transitions/morph_page_route.dart';
import 'presentation/widgets/aura_toast.dart';

/// The two-route GoRouter. Only Discover (`/`) and Now Playing
/// (`/now-playing`) exist — no other top-level destinations.
final _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const DiscoverView(),
      routes: <RouteBase>[
        GoRoute(
          path: 'now-playing',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            transitionDuration: morphDuration(context),
            reverseTransitionDuration: morphDuration(context),
            child: const NowPlayingCanvas(),
            transitionsBuilder: buildMorphTransition,
          ),
        ),
      ],
    ),
  ],
);

/// Route name constant used by the Discover view to open the canvas.
const String nowPlayingRoute = '/now-playing';

class AuraApp extends ConsumerWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppLifecycleObserver(
      child: MaterialApp.router(
        title: 'Aura Player',
        debugShowCheckedModeBanner: false,
        theme: AuraTheme.dark(),
        routerConfig: _router,
        builder: (context, child) =>
            AuraToastScope(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
