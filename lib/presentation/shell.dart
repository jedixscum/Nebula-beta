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
import '../data/recommender.dart';
import '../data/sample_data.dart';
import '../data/theme_settings.dart';
import '../data/sync_service.dart';
import '../domain/addon.dart';
import '../domain/media_item.dart';
import '../l10n/app_localizations.dart';
import 'widgets.dart';

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
      const CatalogGrid(type: MediaType.movie),
      const CatalogGrid(type: MediaType.show),
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
  static const _genres = ['Animation', 'Comedy', 'Sci-Fi', 'Fantasy'];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final q0 = ref.watch(queryProvider);
    final results = ref.watch(searchResultsProvider);
    final lib = ref.watch(libraryProvider);
    final libItems = ref.watch(libraryItemsProvider);
    final rows = q0.isEmpty ? ref.watch(addonRowsProvider).valueOrNull ?? const <AddonRow>[] : const <AddonRow>[];
    final layout = ref.watch(homeLayoutProvider);
    final collections = ref.watch(catalogProvider);
    final q = q0;
    final genre = ref.watch(genreFilterProvider);
    final minRating = ref.watch(minRatingProvider);
    final fromYear = ref.watch(fromYearProvider);
    final suggestions = q.isEmpty
        ? <MediaItem>[]
        : sampleItems.where((m) => m.type != MediaType.live && m.title.toLowerCase().contains(q.toLowerCase())).take(4).toList();

    return ListView(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: SearchBar(
          controller: _ctrl,
          hintText: t.search,
          leading: const Icon(Icons.search),
          onChanged: (v) => ref.read(queryProvider.notifier).state = v,
        ),
      ),
      if (suggestions.isNotEmpty && !suggestions.any((s) => s.title.toLowerCase() == q.toLowerCase()))
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(s.title),
                  onPressed: () {
                    _ctrl.text = s.title;
                    ref.read(queryProvider.notifier).state = s.title;
                  },
                ),
              ),
          ]),
        ),
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          for (final g in _genres)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(g),
                selected: genre == g,
                onSelected: (s) => ref.read(genreFilterProvider.notifier).state = s ? g : null,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('7+ rating'),
              selected: minRating >= 7,
              onSelected: (s) => ref.read(minRatingProvider.notifier).state = s ? 7 : 0,
            ),
          ),
          FilterChip(
            label: const Text('Since 2010'),
            selected: fromYear >= 2010,
            onSelected: (s) => ref.read(fromYearProvider.notifier).state = s ? 2010 : 0,
          ),
        ]),
      ),
      results.when(
        loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Search failed: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No titles match these filters.')));
          }
          List<MediaItem> rowFor(String key) {
            switch (key) {
              case 'rec': return recommend(lib, items).take(8).toList();
              case 'popular': return items.reversed.toList();
              case 'new': return ([...items]..sort((a, b) => b.year.compareTo(a.year)));
              case 'top': return ([...items]..sort((a, b) => b.rating.compareTo(a.rating)));
              case 'library': return libItems;
              case 'continue': return HistoryStore().all().where((e) => e.durMs > 0 && e.posMs < e.durMs * 0.92).map((e) => resolveItem(e.id)).whereType<MediaItem>().toList();
              case 'favorites': return ref.watch(favoritesItemsProvider);
              default: return items;
            }
          }
          return Column(children: [
            for (final s in layout)
              if (s.visible) CosmicRow(title: homeSectionTitles[s.key]!, items: rowFor(s.key)),
            for (final r in rows) CosmicRow(title: r.title, items: r.items),
            for (final c in collections)
              CosmicRow(title: c.name, items: [for (final id in c.itemIds) if (resolveItem(id) != null) resolveItem(id)!]),
          ]);
        },
      ),
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

/// Movies / TV grid: infinite-scrolling addon catalog (skip paging) with shimmer,
/// falling back to the built-in sample titles when no catalog addon is installed.
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
  void dispose() { _sc.dispose(); super.dispose(); }

  void _reset() {
    _src = null;
    for (final a in ref.read(addonsProvider).where((a) => a.remote && a.resources.containsKey('catalog'))) {
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
    if (_src == null) return _PosterGrid(items: sampleItems.where((m) => m.type == widget.type).toList());
    final extra = _loading ? 6 : 0;
    return GridView.builder(
      controller: _sc,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
            final it = findItem(e.id);
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
