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
    final content = Scaffold(
        body: SafeArea(child: pages[_i]),
        bottomNavigationBar: NavigationBar(
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
      );
    return Starfield(enabled: settings.starfieldEnabled, child: content);
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
          maxCrossAxisExtent: 160, childAspectRatio: 2 / 3, mainAxisSpacing: 12, crossAxisSpacing: 12),
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

