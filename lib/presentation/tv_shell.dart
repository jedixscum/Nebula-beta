import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/starfield.dart';
import '../data/addon_service.dart' as addon_service;
import '../data/history_store.dart';
import '../data/providers.dart';
import '../data/theme_settings.dart';
import '../domain/media_item.dart';
import '../l10n/app_localizations.dart';
import '../core/theme.dart';
import 'widgets.dart';
import 'shell.dart';
import 'catalog_browser_screen.dart';

/// Dedicated Android TV shell. All primary controls are focusable and D-pad friendly.
class TvShell extends ConsumerStatefulWidget {
  const TvShell({super.key});
  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

class _TvShellState extends ConsumerState<TvShell> {
  int _index = 0;
  final _searchFocus = FocusNode();
  final _navFocus = List.generate(5, (_) => FocusNode());
  @override void dispose() { _searchFocus.dispose(); for (final node in _navFocus) { node.dispose(); } super.dispose(); }
  List<Widget> _pages() => const [TvHomePage(), CatalogGrid(key: ValueKey('tv-movies'), type: MediaType.movie), CatalogGrid(key: ValueKey('tv-shows'), type: MediaType.show), LibraryPage(), ProfilePage()];
  void _select(int index) { setState(() => _index = index); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) FocusScope.of(context).requestFocus(_navFocus[index]); }); }
  @override Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!; final settings = ref.watch(themeSettingsProvider); final pages = _pages();
    return Starfield(enabled: settings.starfieldEnabled, child: Scaffold(backgroundColor: settings.background, body: SafeArea(child: FocusTraversalGroup(policy: ReadingOrderTraversalPolicy(), child: Row(children: [
      _TvSidebar(selected: _index, focusNodes: _navFocus, onSelected: _select, labels: [t.home, t.movies, t.tvShows, t.library, 'Profile']),
      Expanded(child: Column(children: [
        _TvTopBar(title: ['Home', 'Movies', 'TV Shows', 'Library', 'Profile'][_index], searchFocus: _searchFocus, onSearch: () => _select(0)),
        Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]))),
      ])),
    ])))));
  }
}

class _TvSidebar extends StatelessWidget {
  final int selected; final List<FocusNode> focusNodes; final ValueChanged<int> onSelected; final List<String> labels;
  const _TvSidebar({required this.selected, required this.focusNodes, required this.onSelected, required this.labels});
  static const _icons = [Icons.home_rounded, Icons.movie_rounded, Icons.live_tv_rounded, Icons.bookmark_rounded, Icons.person_rounded];
  @override Widget build(BuildContext context) => Container(width: 220, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withOpacity(.94), border: Border(right: BorderSide(color: nebulaViolet.withOpacity(.18)))), child: Column(children: [
    const SizedBox(height: 30), const _BrandBlock(), const SizedBox(height: 28),
    Expanded(child: ListView.separated(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), itemCount: labels.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) => _TvNavItem(index: i, label: labels[i], icon: _icons[i], selected: selected == i, focusNode: focusNodes[i], onTap: () => onSelected(i)))),
    const Padding(padding: EdgeInsets.all(18), child: Text('D-PAD • OK • BACK', style: TextStyle(color: Colors.white38, letterSpacing: 1.2, fontSize: 11))),
  ]));
}
class _BrandBlock extends StatelessWidget {
  const _BrandBlock();
  @override Widget build(BuildContext context) => Column(children: [
    Container(width: 64, height: 64, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [nebulaViolet, nebulaCyan]), boxShadow: const [BoxShadow(color: nebulaViolet, blurRadius: 20)]), child: const Icon(Icons.auto_awesome_rounded, color: spaceBlack, size: 34)),
    const SizedBox(height: 12), Text('NEBULA', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 3)), const SizedBox(height: 3), Text('ANDROID TV', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: nebulaCyan, letterSpacing: 1.8)),
  ]);
}
class _TvNavItem extends StatefulWidget {
  final int index; final String label; final IconData icon; final bool selected; final FocusNode focusNode; final VoidCallback onTap;
  const _TvNavItem({required this.index, required this.label, required this.icon, required this.selected, required this.focusNode, required this.onTap});
  @override State<_TvNavItem> createState() => _TvNavItemState();
}
class _TvNavItemState extends State<_TvNavItem> {
  bool _focused = false;
  @override Widget build(BuildContext context) { final active = widget.selected || _focused; return FocusableActionDetector(focusNode: widget.focusNode, autofocus: widget.index == 0, onFocusChange: (v) => setState(() => _focused = v), shortcuts: const {SingleActivator(LogicalKeyboardKey.select): ActivateIntent()}, actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { widget.onTap(); return null; })}, child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(16), child: AnimatedContainer(duration: const Duration(milliseconds: 120), height: 66, padding: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: widget.selected ? nebulaViolet.withOpacity(.24) : (_focused ? nebulaCyan.withOpacity(.16) : Colors.transparent), border: Border.all(color: _focused ? nebulaCyan : (widget.selected ? nebulaViolet.withOpacity(.7) : Colors.transparent), width: _focused ? 3 : 1), boxShadow: _focused ? [BoxShadow(color: nebulaCyan.withOpacity(.22), blurRadius: 18)] : null), child: Row(children: [Icon(widget.icon, size: 30, color: active ? nebulaCyan : Colors.white60), const SizedBox(width: 16), Expanded(child: Text(widget.label, style: TextStyle(fontSize: 17, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? Colors.white : Colors.white70))), if (widget.selected) const Icon(Icons.chevron_right_rounded, color: nebulaCyan, size: 25)])))); }
}
class _TvTopBar extends StatelessWidget {
  final String title; final FocusNode searchFocus; final VoidCallback onSearch;
  const _TvTopBar({required this.title, required this.searchFocus, required this.onSearch});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(34, 24, 38, 12), child: Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))), _TvHeaderButton(icon: Icons.search_rounded, label: 'Search', focusNode: searchFocus, onTap: onSearch), const SizedBox(width: 12), _TvHeaderButton(icon: Icons.settings_rounded, label: 'Settings', onTap: () => context.push('/appearance'))]));
}
class _TvHeaderButton extends StatefulWidget {
  final IconData icon; final String label; final FocusNode? focusNode; final VoidCallback onTap;
  const _TvHeaderButton({required this.icon, required this.label, this.focusNode, required this.onTap});
  @override State<_TvHeaderButton> createState() => _TvHeaderButtonState();
}
class _TvHeaderButtonState extends State<_TvHeaderButton> { bool focused = false; @override Widget build(BuildContext context) => FocusableActionDetector(focusNode: widget.focusNode, onFocusChange: (v) => setState(() => focused = v), child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(14), child: AnimatedContainer(duration: const Duration(milliseconds: 120), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), decoration: BoxDecoration(color: focused ? nebulaCyan.withOpacity(.18) : Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: focused ? nebulaCyan : Colors.white12, width: focused ? 2 : 1)), child: Row(children: [Icon(widget.icon, size: 23, color: focused ? nebulaCyan : Colors.white70), const SizedBox(width: 9), Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700))])))); }
}
class TvHomePage extends ConsumerStatefulWidget { const TvHomePage({super.key}); @override ConsumerState<TvHomePage> createState() => _TvHomePageState(); }
class _TvHomePageState extends ConsumerState<TvHomePage> {
  final _search = TextEditingController(); final _searchFocus = FocusNode();
  @override void dispose() { _search.dispose(); _searchFocus.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final query = ref.watch(queryProvider).trim(); final results = ref.watch(addon_service.searchResultsProvider); final addons = ref.watch(addonsProvider); final rows = ref.watch(addon_service.addonRowsProvider); final history = HistoryStore().all();
    final continueItems = history.where((e) => e.durMs > 0 && e.posMs < e.durMs * .92).map((e) => resolveItem(e.id)).whereType<MediaItem>().toList(); final library = ref.watch(libraryItemsProvider); final favorites = ref.watch(favoritesItemsProvider);
    Widget searchBox() => Padding(padding: const EdgeInsets.fromLTRB(34, 8, 34, 18), child: FocusableActionDetector(focusNode: _searchFocus, child: SearchBar(controller: _search, hintText: 'Search movies, shows, people and more', leading: const Icon(Icons.search_rounded, size: 28), trailing: [if (query.isNotEmpty) IconButton(onPressed: () { _search.clear(); ref.read(queryProvider.notifier).state = ''; }, icon: const Icon(Icons.clear))], textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)), onChanged: (v) => ref.read(queryProvider.notifier).state = v)));
    if (query.isNotEmpty) return Column(children: [searchBox(), Expanded(child: results.when(loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => _TvEmpty(message: 'Search failed: $e'), data: (items) => items.isEmpty ? const _TvEmpty(message: 'No results found.') : ListView(children: [CosmicRow(title: 'Search results', items: items)]))) ]);
    return ListView(children: [searchBox(), if (continueItems.isNotEmpty) CosmicRow(title: 'Continue Watching', items: continueItems), if (library.isNotEmpty) CosmicRow(title: 'Your Library', items: library), if (favorites.isNotEmpty) CosmicRow(title: 'Favorites', items: favorites), rows.when(loading: () => addons.any((a) => a.remote && a.enabled && a.showInHome && a.resources.containsKey('catalog')) ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())) : const _TvEmpty(message: 'Install a catalog add-on to populate your home screen.'), error: (e, _) => _TvEmpty(message: 'Could not load catalogs: $e'), data: (catalogRows) => catalogRows.isEmpty ? const _TvEmpty(message: 'No catalog titles are available yet.') : Column(children: [for (final row in catalogRows) CosmicRow(title: row.title, items: row.items, onSeeAll: () => context.push('/catalog-browser', extra: CatalogBrowserArgs(row.addon, row.catalog)))])), const SizedBox(height: 40)]);
  }
}
class _TvEmpty extends StatelessWidget { final String message; const _TvEmpty({required this.message}); @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(60), child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white54, fontSize: 18)))); }
