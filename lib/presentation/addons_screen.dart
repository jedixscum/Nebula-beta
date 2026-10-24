import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/addon_service.dart';
import '../data/providers.dart';
import '../domain/addon.dart';
import '../domain/media_item.dart';

class AddonsScreen extends ConsumerStatefulWidget {
  const AddonsScreen({super.key});
  @override
  ConsumerState<AddonsScreen> createState() => _AddonsScreenState();
}

class _AddonsScreenState extends ConsumerState<AddonsScreen> {
  String _filter = '';
  bool _busy = false;

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _install(String url) async {
    setState(() => _busy = true);
    try {
      final a = await ref.read(addonsProvider.notifier).installFromUrl(url);
      ref.invalidate(addonRowsProvider);
      _snack('Installed/refreshed ${a.name}');
    } catch (e) {
      _snack('Install failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _installDialog() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Install Stremio add-on'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'https://addon.example/manifest.json or stremio://…',
            helperText: 'Paste the add-on manifest URL. Your preferences stay on this device.',
          ),
        ),
        actions: [
          TextButton(onPressed: () async {
            final d = await Clipboard.getData('text/plain');
            ctrl.text = d?.text ?? '';
          }, child: const Text('Paste')),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Install')),
        ],
      ),
    );
    if (url != null && url.trim().isNotEmpty) await _install(url);
  }

  Future<void> _playLocal() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.video);
    final path = r?.files.single.path;
    if (path == null || !mounted) return;
    context.push('/player', extra: MediaItem(
      id: 'local-$path', title: r!.files.single.name, year: 0, type: MediaType.movie,
      synopsis: 'Local file', director: '-', runtimeMin: 0, rating: 0, cast: const [],
      genres: const [], streamUrl: 'file://$path'));
  }

  Widget _preference(Addon a, String title, String subtitle, bool value,
      ValueChanged<bool> onChanged, {bool enabled = true}) {
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 12, right: 8),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _addonCard(Addon a) {
    final active = a.enabled;
    return Card(
      key: ValueKey(a.id),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: CircleAvatar(
          backgroundColor: active ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(Icons.extension, color: active ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).disabledColor),
        ),
        title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          if (a.version.isNotEmpty) 'v${a.version}',
          if (a.remote) a.host else 'Built-in',
          if (a.resources.isNotEmpty) a.resources.keys.join(' · '),
          if (!active) 'Disabled',
        ].join('  •  '), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: a.builtIn ? const Icon(Icons.verified_outlined) : IconButton(
          tooltip: 'Remove add-on',
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            ref.read(addonsProvider.notifier).remove(a.id);
            ref.invalidate(addonRowsProvider);
            _snack('Removed ${a.name}');
          },
        ),
        children: [
          if (a.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(alignment: Alignment.centerLeft, child: Text(a.description)),
            ),
          _preference(a, 'Enable add-on', 'Master switch for this add-on', a.enabled,
            (v) => _set(a, enabled: v)),
          const Divider(height: 1),
          _preference(a, 'Show catalogs on Home', 'Display this add-on’s browse catalogs as Home rows', a.showInHome,
            (v) => _set(a, showInHome: v), enabled: active && a.resources.containsKey('catalog')),
          _preference(a, 'Include in Search', 'Use this add-on when searching titles', a.includeInSearch,
            (v) => _set(a, includeInSearch: v), enabled: active && a.resources.containsKey('catalog')),
          _preference(a, 'Find playable streams', 'Include stream results from this add-on', a.useForStreams,
            (v) => _set(a, useForStreams: v), enabled: active && a.resources.containsKey('stream')),
          _preference(a, 'Load metadata and episodes', 'Use details, cast, and episode data', a.useForMetadata,
            (v) => _set(a, useForMetadata: v), enabled: active && a.resources.containsKey('meta')),
          _preference(a, 'Load subtitles', 'Include subtitle tracks supplied by this add-on', a.useForSubtitles,
            (v) => _set(a, useForSubtitles: v), enabled: active && a.resources.containsKey('subtitles')),
          if (a.remote)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                Expanded(child: Text('Manifest: ${a.baseUrl}/manifest.json', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall)),
                IconButton(
                  tooltip: 'Refresh manifest',
                  onPressed: _busy ? null : () => _install('${a.baseUrl}/manifest.json'),
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Copy manifest URL',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '${a.baseUrl}/manifest.json'));
                    _snack('Manifest URL copied');
                  },
                  icon: const Icon(Icons.copy),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  void _set(Addon a, {
    bool? enabled, bool? showInHome, bool? includeInSearch, bool? useForStreams,
    bool? useForMetadata, bool? useForSubtitles,
  }) {
    ref.read(addonsProvider.notifier).updateSettings(a.id,
      enabled: enabled, showInHome: showInHome, includeInSearch: includeInSearch,
      useForStreams: useForStreams, useForMetadata: useForMetadata,
      useForSubtitles: useForSubtitles);
    ref.invalidate(addonRowsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(addonsProvider);
    final addons = all.where((a) => a.name.toLowerCase().contains(_filter.toLowerCase()) ||
      a.host.toLowerCase().contains(_filter.toLowerCase())).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: SearchBar(hintText: 'Filter add-ons by name or host', leading: const Icon(Icons.filter_list),
          onChanged: (v) => setState(() => _filter = v)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Expanded(child: Text('${all.where((a) => a.remote && a.enabled).length} active · ${all.length} installed',
            style: Theme.of(context).textTheme.labelLarge)),
          TextButton.icon(onPressed: _busy || !all.any((a) => a.remote) ? null : () async {
            setState(() => _busy = true);
            var ok = 0, failed = 0;
            for (final a in all.where((a) => a.remote)) {
              try { await ref.read(addonsProvider.notifier).installFromUrl('${a.baseUrl}/manifest.json'); ok++; }
              catch (_) { failed++; }
            }
            ref.invalidate(addonRowsProvider);
            if (mounted) { setState(() => _busy = false); _snack('Refresh complete: $ok updated, $failed failed'); }
          }, icon: const Icon(Icons.sync), label: const Text('Refresh all')),
        ]),
      ),
      if (_busy) const LinearProgressIndicator(),
      Expanded(
        child: addons.isEmpty
          ? const Center(child: Text('No matching add-ons. Install a Stremio manifest URL to get started.'))
          : ListView(padding: const EdgeInsets.only(bottom: 8), children: [for (final a in addons) _addonCard(a)]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
          FilledButton.icon(onPressed: _busy ? null : _installDialog, icon: const Icon(Icons.add_link), label: const Text('Install add-on')),
          OutlinedButton(onPressed: _busy ? null : () => _install('https://v3-cinemeta.strem.io/manifest.json'), child: const Text('Add Cinemeta')),
          OutlinedButton.icon(onPressed: _playLocal, icon: const Icon(Icons.folder_open), label: const Text('Play local file')),
        ]),
      ),
    ]);
  }
}
