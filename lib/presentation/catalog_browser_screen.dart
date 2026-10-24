import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/addon_client.dart';
import '../data/addon_service.dart';
import '../domain/addon.dart';
import '../domain/media_item.dart';
import 'widgets.dart';

class CatalogBrowserArgs {
  final Addon addon;
  final AddonCatalog catalog;
  const CatalogBrowserArgs(this.addon, this.catalog);
}

class CatalogBrowserScreen extends ConsumerStatefulWidget {
  final CatalogBrowserArgs args;
  const CatalogBrowserScreen({super.key, required this.args});

  @override
  ConsumerState<CatalogBrowserScreen> createState() => _CatalogBrowserScreenState();
}

class _CatalogBrowserScreenState extends ConsumerState<CatalogBrowserScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _items = <MediaItem>[];
  final _seen = <String>{};
  bool _loading = false;
  bool _done = false;
  int _skip = 0;
  String? _genre;
  int _minYear = 0;
  double _minRating = 0;
  String _sort = 'default';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 500) {
        _load();
      }
    });
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final got = await ref.read(addonClientProvider).catalog(
            widget.args.addon,
            widget.args.catalog.type,
            widget.args.catalog.id,
            skip: _skip,
          );
      final fresh = got.where((m) => _seen.add(m.id)).toList();
      if (fresh.isEmpty || got.isEmpty) {
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

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _seen.clear();
      _skip = 0;
      _done = false;
    });
    await _load();
  }

  List<MediaItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final result = _items.where((item) {
      if (q.isNotEmpty && !item.title.toLowerCase().contains(q)) return false;
      if (_genre != null && !item.genres.any((g) => g.toLowerCase() == _genre!.toLowerCase())) return false;
      if (_minYear > 0 && item.year < _minYear) return false;
      if (_minRating > 0 && item.rating < _minRating) return false;
      return true;
    }).toList();

    switch (_sort) {
      case 'title':
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'year':
        result.sort((a, b) => b.year.compareTo(a.year));
        break;
      case 'rating':
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }
    return result;
  }

  List<String> get _genres {
    final values = <String>{};
    for (final item in _items) {
      values.addAll(item.genres.where((g) => g.trim().isNotEmpty));
    }
    final result = values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  Future<void> _showFilters() async {
    var genre = _genre;
    var minYear = _minYear;
    var rating = _minRating;
    var sort = _sort;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Filter catalog', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      genre = null;
                      minYear = 0;
                      rating = 0;
                      sort = 'default';
                      setSheetState(() {});
                    },
                    child: const Text('Reset'),
                  ),
                ]),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: genre,
                  decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All genres')),
                    for (final g in _genres) DropdownMenuItem<String?>(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => setSheetState(() => genre = v),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: minYear,
                  decoration: const InputDecoration(labelText: 'Release year', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Any year')),
                    DropdownMenuItem(value: 2020, child: Text('2020 or newer')),
                    DropdownMenuItem(value: 2015, child: Text('2015 or newer')),
                    DropdownMenuItem(value: 2010, child: Text('2010 or newer')),
                    DropdownMenuItem(value: 2000, child: Text('2000 or newer')),
                    DropdownMenuItem(value: 1990, child: Text('1990 or newer')),
                  ],
                  onChanged: (v) => setSheetState(() => minYear = v ?? 0),
                ),
                const SizedBox(height: 8),
                Text('Minimum rating: ${rating == 0 ? 'Any' : rating.toStringAsFixed(1)}'),
                Slider(
                  value: rating,
                  min: 0,
                  max: 9,
                  divisions: 18,
                  label: rating == 0 ? 'Any' : rating.toStringAsFixed(1),
                  onChanged: (v) => setSheetState(() => rating = v),
                ),
                DropdownButtonFormField<String>(
                  value: sort,
                  decoration: const InputDecoration(labelText: 'Sort by', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('Catalog order')),
                    DropdownMenuItem(value: 'title', child: Text('Title A–Z')),
                    DropdownMenuItem(value: 'year', child: Text('Newest first')),
                    DropdownMenuItem(value: 'rating', child: Text('Highest rated')),
                  ],
                  onChanged: (v) => setSheetState(() => sort = v ?? 'default'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Apply filters'),
                    onPressed: () {
                      setState(() {
                        _genre = genre;
                        _minYear = minYear;
                        _minRating = rating;
                        _sort = sort;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.catalog.name),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Filters', onPressed: _showFilters, icon: Badge(isLabelVisible: _genre != null || _minYear > 0 || _minRating > 0 || _sort != 'default', child: const Icon(Icons.tune))),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search this catalog',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: _search.clear),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (_genre != null || _minYear > 0 || _minRating > 0 || _sort != 'default')
            SizedBox(
              height: 42,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                if (_genre != null) InputChip(label: Text(_genre!), onDeleted: () => setState(() => _genre = null)),
                if (_minYear > 0) InputChip(label: Text('From $_minYear'), onDeleted: () => setState(() => _minYear = 0)),
                if (_minRating > 0) InputChip(label: Text('${_minRating.toStringAsFixed(1)}+ rating'), onDeleted: () => setState(() => _minRating = 0)),
                if (_sort != 'default') InputChip(label: Text(_sort == 'title' ? 'A–Z' : _sort == 'year' ? 'Newest' : 'Top rated'), onDeleted: () => setState(() => _sort = 'default')),
              ],
            ),
          Expanded(
            child: items.isEmpty && !_loading
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_items.isEmpty ? 'This catalog has no titles.' : 'No titles match your filters.')))
                : GridView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: wide ? 210 : 165,
                      childAspectRatio: 2 / 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: items.length + (_loading ? 6 : 0),
                    itemBuilder: (_, i) => i < items.length
                        ? PosterCard(item: items[i], width: double.infinity)
                        : ClipRRect(borderRadius: BorderRadius.circular(14), child: const ShimmerBox()),
                  ),
          ),
        ]),
      ),
    );
  }
}
