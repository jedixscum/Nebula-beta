import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/starfield.dart';
import '../data/addon_client.dart';
import '../data/addon_service.dart';
import '../data/catalog.dart';
import '../data/history_store.dart';
import '../data/home_layout.dart';
import '../data/providers.dart';
import '../data/theme_settings.dart';
import '../data/sync_service.dart';
import '../domain/addon.dart';
import '../domain/media_item.dart';
import '../l10n/app_localizations.dart';
import 'widgets.dart';
import 'catalog_browser_screen.dart';

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final settings = ref.watch(themeSettingsProvider);
    final pages = <Widget>[
      const HomePage(),
      const CatalogGrid(key: ValueKey('movies-catalog'), type: MediaType.movie),
      const CatalogGrid(key: ValueKey('shows-catalog'), type: MediaType.show),
      const LibraryPage(),
      const ProfilePage(),
    ];
    final tvLayout = MediaQuery.sizeOf(context).width >= 800;
    return Starfield(
      enabled: settings.starfieldEnabled,
      child: Scaffold(
        body: SafeArea(
          child: tvLayout
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _i,
                      onDestinationSelected: (v) => setState(() => _i = v),
                      labelType: NavigationRailLabelType.all,
                      groupAlignment: -0.8,
                      destinations: [
                        NavigationRailDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: Text(t.home)),
                        NavigationRailDestination(icon: const Icon(Icons.movie_outlined), selectedIcon: const Icon(Icons.movie), label: Text(t.movies)),
                        NavigationRailDestination(icon: const Icon(Icons.tv_outlined), selectedIcon: const Icon(Icons.tv), label: Text(t.tvShows)),
                        NavigationRailDestination(icon: const Icon(Icons.bookmarks_outlined), selectedIcon: const Icon(Icons.bookmarks), label: Text(t.library)),
                        const NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('Profile')),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: pages[_i]),
                  ],
                )
              : pages[_i],
        ),
        bottomNavigationBar: tvLayout
            ? null
            : NavigationBar(
                selectedIndex: _i,
                onDestinationSelected: (v) => setState(() => _i = v),
                destinations: [
                  NavigationDestination(icon: const Icon(Icons.home_outlined), label: t.home),
                  NavigationDestination(icon: const Icon(Icons.movie_outlined), label: t.movies),
                  NavigationDestination(icon: const Icon(Icons.tv), label: t.tvShows),
                  NavigationDestination(icon: const Icon(Icons.bookmarks_outlined), label: t.library),
                  const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
                ],
              ),
      ),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final query = ref.watch(queryProvider).trim();
    final results = ref.watch(searchResultsProvider);
    final addonRows = ref.watch(addonRowsProvider);
    final addons = ref.watch(addonsProvider);
    final library = ref.watch(libraryItemsProvider);
    final favorites = ref.watch(favoritesItemsProvider);
    final layout = ref.watch(homeLayoutProvider);
    final collections = ref.watch(catalogProvider);
    final history = HistoryStore().all();
    final continueWatching = history
        .where((e) => e.durMs > 0 && e.posMs < e.durMs * 0.92)
        .map((e) => resolveItem(e.id))
        .whereType<MediaItem>()
        .toList();

    Widget empty(String message) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
      child: Center(child: Text(message, textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70))),
    );

    List<Widget> personalSections() {
      final out = <Widget>[];
      for (final section in layout.where((s) => s.visible)) {
        final items = switch (section.key) {
          'library' => library,
          'continue' => continueWatching,
          'favorites' => favorites,
          _ => const <MediaItem>[],
        };
        if (items.isNotEmpty) {
          out.add(CosmicRow(title: homeSectionTitles[section.key]!, items: items));
        }
      }
      for (final collection in collections) {
        final items = [for (final id in collection.itemIds) if (resolveItem(id) != null) resolveItem(id)!];
        if (items.isNotEmpty) out.add(CosmicRow(title: collection.name, items: items));
      }
      return out;
    }

    return ListView(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: SearchBar(
          controller: _ctrl,
          hintText: t.search,
          leading: const Icon(Icons.search),
          onChanged: (value) => ref.read(queryProvider.notifier).state = value,
        ),
      ),
      if (query.isNotEmpty)
        results.when(
          loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          error: (error, _) => empty('Search failed: $error'),
          data: (items) => items.isEmpty
              ? empty('No results from your installed add-ons. Make sure an add-on supports catalog search.')
              : Column(children: [CosmicRow(title: 'Search results', items: items)]),
        )
      else ...[
        ...personalSections(),
        addonRows.when(
          loading: () => addons.any((a) => a.remote && a.enabled && a.showInHome && a.resources.containsKey('catalog'))
              ? const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
              : empty('Your Home is ready for add-ons. Open Profile → Addons and install an add-on with movie or series catalogs.'),
          error: (error, _) => empty('Could not load add-on catalogs: $error'),
          data: (rows) => rows.isEmpty
              ? empty(addons.any((a) => a.remote && a.resources.containsKey('catalog'))
                  ? 'Your installed add-ons did not return any catalog titles.'
                  : 'Install an add-on with movie or series catalogs in Profile → Addons to populate Home.')
              : Column(children: [
                  for (final row in rows)
                    CosmicRow(
                      title: row.title,
                      items: row.items,
                      onSeeAll: () => context.push('/catalog-browser', extra: CatalogBrowserArgs(row.addon, row.catalog)),
                    ),
                ]),
        ),
      ],
    ]);
  }
}

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider);
    if (items.isEmpty) return const Center(child: Text('Your library is empty. Add titles from a detail page.'));
    return _PosterGrid(items: items);
  }
}

/// Movies / TV grid: infinite-scrolling addon catalog (skip paging) with shimmer.
class CatalogGrid extends ConsumerStatefulWidget {
  final MediaType type;
  const CatalogGrid({super.key, required this.type});
  @override
  ConsumerState<CatalogGrid> createState() => _CatalogGridState();
}

class _CatalogGridState extends ConsumerState<CatalogGrid> {
  final _sc = ScrollController();
  final _items = <MediaItem>[];
  final _seen = <String>{};
  (Addon, AddonCatalog)? _src;
  bool _loading = false, _done = false;
  int _skip = 0;

  String get _typeStr => widget.type == MediaType.movie ? 'movie' : 'series';

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      if (_sc.hasClients && _sc.position.pixels > _sc.position.maxScrollExtent - 400) _load();
    });
    ref.listenManual(addonsProvider, (_, __) => _reset(), fireImmediately: true);
  }

  @override
  void didUpdateWidget(covariant CatalogGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _reset();
    }
  }

  @override
  void dispose() { _sc.dispose(); super.dispose(); }

  void _reset() {
    _src = null;
    for (final a in ref.read(addonsProvider).where((a) => a.remote && a.enabled && a.showInHome && a.resources.containsKey('catalog'))) {
      for (final c in a.browseCatalogs) {
        if (c.type == _typeStr && _src == null) _src = (a, c);
      }
    }
    _items.clear();
    _seen.clear();
    _skip = 0;
    _done = false;
    _loading = false;
    if (mounted) setState(() {});
    _load();
  }

  Future<void> _load() async {
    final src = _src;
    if (src == null || _loading || _done) return;
    setState(() => _loading = true);
    try {
      final got = await ref.read(addonClientProvider).catalog(src.$1, src.$2.type, src.$2.id, skip: _skip);
      final fresh = got.where((m) => _seen.add(m.id)).toList();
      if (fresh.isEmpty) {
        _done = true;
      } else {
        _items.addAll(fresh);
        _skip += got.length;
      }
    } catch (_) {
      _done = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_src == null) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No catalog available. Install an add-on that provides movie or series catalogs.')));
    final extra = _loading ? 6 : 0;
    return GridView.builder(
      controller: _sc,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: MediaQuery.sizeOf(context).width >= 800 ? 220 : 160, childAspectRatio: 2 / 3, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: _items.length + extra,
      itemBuilder: (_, i) => i < _items.length
          ? PosterCard(item: _items[i], width: double.infinity)
          : ClipRRect(borderRadius: BorderRadius.circular(14), child: const ShimmerBox()),
    );
  }
}

class _PosterGrid extends StatelessWidget {
  final List<MediaItem> items;
  const _PosterGrid({required this.items});
  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160, childAspectRatio: 2 / 3, mainAxisSpacing: 12, crossAxisSpacing: 12),
        itemCount: items.length,
        itemBuilder: (_, i) => PosterCard(item: items[i], width: double.infinity),
      );
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<String?> _paste(BuildContext c) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: c,
      builder: (d) => AlertDialog(
        title: const Text('Paste sync JSON'),
        content: TextField(controller: ctrl, maxLines: 6),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, ctrl.text), child: const Text('Import')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hist = HistoryStore().all();
    final lib = ref.watch(libraryProvider);
    final minutes = hist.fold<int>(0, (a, e) => a + e.posMs ~/ 60000);
    final genreCount = <String, int>{};
    for (final e in hist) {
      for (final g in e.genres) { genreCount[g] = (genreCount[g] ?? 0) + 1; }
    }
    final top = genreCount.entries.isEmpty
        ? '-'
        : (genreCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    void snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Continuum', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        Chip(label: Text('${hist.length} titles started')),
        Chip(label: Text('$minutes min watched')),
        Chip(label: Text('${lib.length} in library')),
        Chip(label: Text('Top genre: $top')),
      ]),
      TextButton.icon(
        icon: const Icon(Icons.share),
        label: const Text('Share to space (copy)'),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: 'I watched $minutes minutes across ${hist.length} titles in Nebula. Top genre: $top.'));
          snack('Copied');
        },
      ),
      const Divider(),
      ListTile(leading: const Icon(Icons.extension), title: const Text('Addons'), onTap: () => context.push('/addons')),
      ListTile(leading: const Icon(Icons.download), title: const Text('Downloads'), onTap: () => context.push('/downloads')),
      ListTile(leading: const Icon(Icons.library_add), title: const Text('Catalog builder'), onTap: () => context.push('/catalog')),
      ListTile(leading: const Icon(Icons.dashboard_customize), title: const Text('Home layout'), onTap: () => context.push('/layout')),
      ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('Appearance & themes'), subtitle: const Text('30 palettes, custom colors and effects'), onTap: () => context.push('/appearance')),
      ListTile(leading: const Icon(Icons.favorite_outline), title: const Text('Favorites'), subtitle: const Text('Your saved favorite titles'), onTap: () => context.push('/favorites')),
      ListTile(
        leading: const Icon(Icons.upload),
        title: const Text('Export sync data'),
        subtitle: const Text('Copies JSON for another device'),
        onTap: () { Clipboard.setData(ClipboardData(text: exportAll())); snack('Sync data copied'); },
      ),
      ListTile(
        leading: const Icon(Icons.download_for_offline),
        title: const Text('Import sync data'),
        subtitle: const Text('Replaces library, history, catalog, layout'),
        onTap: () async {
          final json = await _paste(context);
          if (json == null || json.trim().isEmpty) return;
          try {
            await importAll(json);
            ref.invalidate(libraryProvider);
            ref.invalidate(catalogProvider);
            ref.invalidate(homeLayoutProvider);
            snack('Imported');
          } catch (e) {
            snack('Import failed: $e');
          }
        },
      ),
      const Divider(),
      Text('Continuum Watch History', style: Theme.of(context).textTheme.titleMedium),
      if (hist.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Nothing watched yet.')),
      for (final e in hist)
        ListTile(
          title: Text(e.title),
          subtitle: LinearProgressIndicator(value: e.durMs > 0 ? (e.posMs / e.durMs).clamp(0, 1).toDouble() : 0),
          onTap: () {
            MediaItem? it = resolveItem(e.id);
            if (it == null) {
              for (final favorite in ref.read(favoritesItemsProvider)) {
                if (favorite.id == e.id) { it = favorite; break; }
              }
            }
            if (it != null) {
              context.push('/player', extra: it);
            } else {
              snack('Open it from its detail page to pick a stream again');
            }
          },
        ),
    ]);
  }
}
