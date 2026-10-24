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

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _install(String url) async {
    setState(() => _busy = true);
    try {
      final addon = await ref.read(addonsProvider.notifier).installFromUrl(url);
      ref.invalidate(addonRowsProvider);
      _snack('Installed/refreshed ${addon.name}');
    } catch (e) {
      _snack('Install failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _installDialog() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Install Stremio add-on'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'https://addon.example/manifest.json or stremio://…',
            helperText: 'Paste the add-on manifest URL. Preferences stay on this device.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              controller.text = data?.text ?? '';
            },
            child: const Text('Paste'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Install'),
          ),
        ],
      ),
    );
    if (url != null && url.trim().isNotEmpty) await _install(url);
  }

  Future<void> _playLocal() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    context.push(
      '/player',
      extra: MediaItem(
        id: 'local-$path',
        title: result!.files.single.name,
        year: 0,
        type: MediaType.movie,
        synopsis: 'Local file',
        director: '-',
        runtimeMin: 0,
        rating: 0,
        cast: const [],
        genres: const [],
        streamUrl: 'file://$path',
      ),
    );
  }

  Widget _preference(
    Addon addon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool enabled = true,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 12, right: 8),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }

  void _catalogDialog(Addon addon) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${addon.name} · Home catalogs',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Hide catalogs you do not want and drag them to choose their Home order.',
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    itemCount: addon.catalogs.where((c) => !c.requiresExtra).length,
                    itemBuilder: (context, index) {
                      final catalogs = addon.catalogs
                          .where((c) => !c.requiresExtra)
                          .toList();
                      final catalog = catalogs[index];
                      return ListTile(
                        key: ValueKey(catalog.id),
                        leading: Switch(
                          value: catalog.showInHome,
                          onChanged: (value) {
                            ref.read(addonsProvider.notifier).updateCatalogSettings(
                              addon.id,
                              catalog.id,
                              showInHome: value,
                            );
                            ref.invalidate(addonRowsProvider);
                            Navigator.pop(sheetContext);
                            _catalogDialog(addon);
                          },
                        ),
                        title: Text(catalog.name),
                        subtitle: Text(
                          '${catalog.type} · ${catalog.id}${catalog.supportsSearch ? ' · Search' : ''}',
                        ),
                        trailing: const Icon(Icons.drag_handle),
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      final catalogs = addon.catalogs
                          .where((c) => !c.requiresExtra)
                          .toList();
                      if (newIndex > oldIndex) newIndex--;
                      final moved = catalogs.removeAt(oldIndex);
                      catalogs.insert(newIndex, moved);
                      for (var i = 0; i < catalogs.length; i++) {
                        ref.read(addonsProvider.notifier).updateCatalogSettings(
                          addon.id,
                          catalogs[i].id,
                          order: i,
                        );
                      }
                      ref.invalidate(addonRowsProvider);
                      Navigator.pop(sheetContext);
                      _catalogDialog(addon);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _addonCard(Addon addon) {
    final active = addon.enabled;
    final homeCatalogs = addon.catalogs.where((c) => !c.requiresExtra).toList();

    return Card(
      key: ValueKey(addon.id),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: CircleAvatar(
          backgroundColor: active
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.extension,
            color: active
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).disabledColor,
          ),
        ),
        title: Text(addon.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (addon.version.isNotEmpty) 'v${addon.version}',
            if (addon.remote) addon.host else 'Built-in',
            if (addon.resources.isNotEmpty) addon.resources.keys.join(' · '),
            if (!active) 'Disabled',
          ].join('  •  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: addon.builtIn
            ? const Icon(Icons.verified_outlined)
            : IconButton(
                tooltip: 'Remove add-on',
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  ref.read(addonsProvider.notifier).remove(addon.id);
                  ref.invalidate(addonRowsProvider);
                  _snack('Removed ${addon.name}');
                },
              ),
        children: [
          if (addon.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(addon.description),
              ),
            ),
          _preference(
            addon,
            'Enable add-on',
            'Master switch for this add-on',
            addon.enabled,
            (value) => _set(addon, enabled: value),
          ),
          const Divider(height: 1),
          _preference(
            addon,
            'Show catalogs on Home',
            'Master switch for this add-on’s Home catalogs',
            addon.showInHome,
            (value) => _set(addon, showInHome: value),
            enabled: active && homeCatalogs.isNotEmpty,
          ),
          if (active && homeCatalogs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: OutlinedButton.icon(
                onPressed: () => _catalogDialog(addon),
                icon: const Icon(Icons.tune),
                label: Text(
                  'Customize ${homeCatalogs.length} Home catalog${homeCatalogs.length == 1 ? '' : 's'}',
                ),
              ),
            ),
          _preference(
            addon,
            'Include in Search',
            'Use this add-on when searching titles',
            addon.includeInSearch,
            (value) => _set(addon, includeInSearch: value),
            enabled: active && addon.resources.containsKey('catalog'),
          ),
          _preference(
            addon,
            'Find playable streams',
            'Include stream results from this add-on',
            addon.useForStreams,
            (value) => _set(addon, useForStreams: value),
            enabled: active && addon.resources.containsKey('stream'),
          ),
          _preference(
            addon,
            'Load metadata and episodes',
            'Use details, cast, and episode data',
            addon.useForMetadata,
            (value) => _set(addon, useForMetadata: value),
            enabled: active && addon.resources.containsKey('meta'),
          ),
          _preference(
            addon,
            'Load subtitles',
            'Include subtitle tracks supplied by this add-on',
            addon.useForSubtitles,
            (value) => _set(addon, useForSubtitles: value),
            enabled: active && addon.resources.containsKey('subtitles'),
          ),
          if (addon.remote)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Manifest: ${addon.baseUrl}/manifest.json',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh manifest',
                    onPressed: _busy
                        ? null
                        : () => _install('${addon.baseUrl}/manifest.json'),
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Copy manifest URL',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: '${addon.baseUrl}/manifest.json'),
                      );
                      _snack('Manifest URL copied');
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _set(
    Addon addon, {
    bool? enabled,
    bool? showInHome,
    bool? includeInSearch,
    bool? useForStreams,
    bool? useForMetadata,
    bool? useForSubtitles,
  }) {
    ref.read(addonsProvider.notifier).updateSettings(
      addon.id,
      enabled: enabled,
      showInHome: showInHome,
      includeInSearch: includeInSearch,
      useForStreams: useForStreams,
      useForMetadata: useForMetadata,
      useForSubtitles: useForSubtitles,
    );
    ref.invalidate(addonRowsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(addonsProvider);
    final filter = _filter.toLowerCase();
    final addons = all
        .where(
          (addon) =>
              addon.name.toLowerCase().contains(filter) ||
              addon.host.toLowerCase().contains(filter),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SearchBar(
            hintText: 'Filter add-ons by name or host',
            leading: const Icon(Icons.filter_list),
            onChanged: (value) => setState(() => _filter = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${all.where((a) => a.remote && a.enabled).length} active · ${all.length} installed',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              TextButton.icon(
                onPressed: _busy || !all.any((a) => a.remote)
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        var updated = 0;
                        var failed = 0;
                        for (final addon in all.where((a) => a.remote)) {
                          try {
                            await ref
                                .read(addonsProvider.notifier)
                                .installFromUrl('${addon.baseUrl}/manifest.json');
                            updated++;
                          } catch (_) {
                            failed++;
                          }
                        }
                        ref.invalidate(addonRowsProvider);
                        if (mounted) {
                          setState(() => _busy = false);
                          _snack('Refresh complete: $updated updated, $failed failed');
                        }
                      },
                icon: const Icon(Icons.sync),
                label: const Text('Refresh all'),
              ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: addons.isEmpty
              ? const Center(
                  child: Text(
                    'No matching add-ons. Install a Stremio manifest URL to get started.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [for (final addon in addons) _addonCard(addon)],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _installDialog,
                icon: const Icon(Icons.add_link),
                label: const Text('Install add-on'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _install('https://v3-cinemeta.strem.io/manifest.json'),
                child: const Text('Add Cinemeta'),
              ),
              OutlinedButton.icon(
                onPressed: _playLocal,
                icon: const Icon(Icons.folder_open),
                label: const Text('Play local file'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
