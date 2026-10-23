import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'domain/media_item.dart';
import 'l10n/app_localizations.dart';
import 'presentation/shell.dart';
import 'presentation/detail_screen.dart';
import 'presentation/player_screen.dart';
import 'presentation/addons_screen.dart';
import 'presentation/library_tools.dart';
import 'presentation/widgets.dart';

final _router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const Shell()),
  GoRoute(path: '/detail', builder: (_, s) => DetailScreen(item: s.extra as MediaItem)),
  GoRoute(path: '/player', builder: (_, s) => PlayerScreen(item: s.extra as MediaItem)),
  GoRoute(path: '/addons', builder: (_, __) => const SubPage(title: 'Addons', child: AddonsScreen())),
  GoRoute(path: '/downloads', builder: (_, __) => const SubPage(title: 'Downloads', child: DownloadsScreen())),
  GoRoute(path: '/catalog', builder: (_, __) => const SubPage(title: 'Catalog builder', child: CatalogScreen())),
  GoRoute(path: '/layout', builder: (_, __) => const SubPage(title: 'Home layout', child: HomeLayoutScreen())),
]);

class NebulaApp extends StatelessWidget {
  const NebulaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Nebula',
        theme: nebulaTheme(),
        routerConfig: _router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      );
}
