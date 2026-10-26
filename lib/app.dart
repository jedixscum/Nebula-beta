import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'data/theme_settings.dart';
import 'data/providers.dart';
import 'presentation/appearance_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/media_item.dart';
import 'l10n/app_localizations.dart';
import 'presentation/shell.dart';
import 'presentation/tv_shell.dart';
import 'presentation/detail_screen.dart';
import 'presentation/player_screen.dart';
import 'presentation/addons_screen.dart';
import 'presentation/library_tools.dart';
import 'presentation/widgets.dart';
import 'presentation/catalog_browser_screen.dart';
import 'presentation/launch_screen.dart';
import 'presentation/update_screen.dart';

final _router = GoRouter(
  initialLocation: '/launch',
  routes: [
    GoRoute(path: '/', builder: (context, __) => MediaQuery.sizeOf(context).width >= 800 ? const TvShell() : const Shell()),
    GoRoute(path: '/launch', builder: (_, __) => const LaunchScreen()),
    GoRoute(path: '/detail', builder: (_, s) => DetailScreen(item: s.extra as MediaItem)),
    GoRoute(path: '/player', builder: (_, s) => PlayerScreen(item: s.extra as MediaItem)),
    GoRoute(path: '/addons', builder: (_, __) => const SubPage(title: 'Addons', child: AddonsScreen())),
    GoRoute(path: '/downloads', builder: (_, __) => const SubPage(title: 'Downloads', child: DownloadsScreen())),
    GoRoute(path: '/catalog', builder: (_, __) => const SubPage(title: 'Catalog builder', child: CatalogScreen())),
    GoRoute(path: '/layout', builder: (_, __) => const SubPage(title: 'Home layout', child: HomeLayoutScreen())),
    GoRoute(path: '/appearance', builder: (_, __) => const SubPage(title: 'Appearance & themes', child: AppearanceScreen())),
    GoRoute(path: '/favorites', builder: (_, __) => const SubPage(title: 'Favorites', child: FavoritesScreen())),
    GoRoute(path: '/updates', builder: (_, __) => const SubPage(title: 'Nebula Updates', child: UpdateScreen())),
    GoRoute(path: '/catalog-browser', builder: (_, s) => CatalogBrowserScreen(args: s.extra as CatalogBrowserArgs)),
  ],
);

class FavoritesScreen extends ConsumerWidget {
 const FavoritesScreen({super.key});
 @override Widget build(BuildContext context,WidgetRef ref){final items=ref.watch(favoritesItemsProvider);if(items.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('No favorites yet. Open a title and tap Add to favorites.')));return GridView.builder(padding:const EdgeInsets.all(16),gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:170,childAspectRatio:2/3,mainAxisSpacing:12,crossAxisSpacing:12),itemCount:items.length,itemBuilder:(_,i)=>PosterCard(item:items[i],width:double.infinity));}
}
class NebulaApp extends ConsumerWidget {
  const NebulaApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Nebula',
        theme: nebulaTheme(ref.watch(themeSettingsProvider)),
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
