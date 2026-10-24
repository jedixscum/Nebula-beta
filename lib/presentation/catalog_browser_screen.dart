import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    _scroll.addListener(_onScroll);
    _search.addListener(_onSearchChanged);
    _load();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 500) {
      _load();
    }
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
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
      final fresh = got.where((item) => _seen.add(item.id)).toList();
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
    final query = _search.text.trim().toLowerCase();
    final result = _items.where((item) {
      if (query.isNotEmpty && !item.title.toLowerCase().contains(query)) return false;
      if (_genre != null && !item.genres.any((g) => g.toLowerCase() == _genre!.toLowerCase())) return false;
      if (_minYear > 0 && item.year < _minYear) return false;
      if (_minRating > 0 && item.rating < _minRating) return false;
      return true;
    }).toList();

    if (_sort == 'title') {
      result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sort == 'year') {
      result.sort((a, b) => b.year.compareTo(a.year));
    } else if (_sort == 'rating') {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return result;
  }

  List<String> get _genres {
    final values = <String>{};
    for (final item in _items) {
      for (final genre in item.genres) {
        if (genre.trim().isNotEmpty) values.add(genre.trim());
      }
    }
    final result = values.toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  bool get _hasFilters => _genre != null || _minYear > 0 || _minRating > 0 || _sort != 'default';

  Future<void> _showFilters() async {
    var genre = _genre ?? '';
    var minYear = _minYear;
    var rating = _minRating;
    var sort = _sort;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Filter catalog', style: Theme.of(context).textTheme.titleLarge)),
                        TextButton(
                          onPressed: () {
                            genre = '';
                            minYear = 0;
                            rating = 0;
                            sort = 'default';
                            setSheetState(() {});
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: genre,
                      decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('All genres')),
                        for (final value in _genres) DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (value) => setSheetState(() => genre = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: minYear,
                      decoration: const InputDecoration(labelText: 'Release year', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Any year')),
                        DropdownMenuItem(value: 2020, child: Text('2020 or newer')),
                        DropdownMenuItem(value: 2015, child: Text('2015 or newer')),
                        DropdownMenuItem(value: 2010, child: Text('2010 or newer')),
                        DropdownMenuItem(value: 2000, child: Text('2000 or newer')),
                        DropdownMenuItem(value: 1990, child: Text('1990 or newer')),
                      ],
                      onChanged: (value) => setSheetState(() => minYear = value ?? 0),
                    ),
                    const SizedBox(height: 12),
                    Text('Minimum rating: ${rating == 0 ? 'Any' : rating.toStringAsFixed(1)}'),
                    Slider(
                      value: rating,
                      min: 0,
                      max: 9,
                      divisions: 18,
                      label: rating == 0 ? 'Any' : rating.toStringAsFixed(1),
                      onChanged: (value) => setSheetState(() => rating = value),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: sort,
                      decoration: const InputDecoration(labelText: 'Sort by', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'default', child: Text('Catalog order')),
                        DropdownMenuItem(value: 'title', child: Text('Title A–Z')),
                        DropdownMenuItem(value: 'year', child: Text('Newest first')),
                        DropdownMenuItem(value: 'rating', child: Text('Highest rated')),
                      ],
                      onChanged: (value) => setSheetState(() => sort = value ?? 'default'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _genre = genre.isEmpty ? null : genre;
                          _minYear = minYear;
                          _minRating = rating;
                          _sort = sort;
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Apply filters'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: _showFilters,
            icon: Badge(isLabelVisible: _hasFilters, child: const Icon(Icons.tune)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search this catalog',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(icon: const Icon(Icons.clear), onPressed: _search.clear),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (_hasFilters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      if (_genre != null) InputChip(label: Text(_genre!), onDeleted: () => setState(() => _genre = null)),
                      if (_minYear > 0) InputChip(label: Text('From $_minYear'), onDeleted: () => setState(() => _minYear = 0)),
                      if (_minRating > 0) InputChip(label: Text('${_minRating.toStringAsFixed(1)}+ rating'), onDeleted: () => setState(() => _minRating = 0)),
                      if (_sort != 'default') InputChip(label: Text(_sort == 'title' ? 'A–Z' : _sort == 'year' ? 'Newest' : 'Top rated'), onDeleted: () => setState(() => _sort = 'default')),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: items.isEmpty && !_loading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_items.isEmpty ? 'This catalog has no titles.' : 'No titles match your filters.'),
                      ),
                    )
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
                      itemBuilder: (_, index) {
                        if (index < items.length) {
                          return PosterCard(item: items[index], width: double.infinity);
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: const ShimmerBox(),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
