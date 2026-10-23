import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/addon_service.dart';
import '../data/providers.dart';
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
      _snack('Installed ${a.name}');
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
        title: const Text('Addon manifest URL'),
        content: TextField(controller: ctrl, maxLines: 3,
            decoration: const InputDecoration(hintText: 'https://…/manifest.json')),
        actions: [
          TextButton(onPressed: () async {
            final d = await Clipboard.getData('text/plain');
            ctrl.text = d?.text ?? '';
          }, child: const Text('Paste')),
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

  @override
  Widget build(BuildContext context) {
    final addons = ref.watch(addonsProvider)
        .where((a) => a.name.toLowerCase().contains(_filter.toLowerCase())).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: SearchBar(hintText: 'Filter addons', leading: const Icon(Icons.filter_list),
            onChanged: (v) => setState(() => _filter = v)),
      ),
      if (_busy) const LinearProgressIndicator(),
      Expanded(
        child: ListView(children: [
          for (final a in addons)
            ListTile(
              leading: const Icon(Icons.extension),
              title: Text('${a.name}  v${a.version}'),
              subtitle: Text([
                if (a.description.isNotEmpty) a.description,
                if (a.remote) '${a.host} · ${a.resources.keys.join(', ')}',
              ].join('\n')),
              isThreeLine: true,
              trailing: a.builtIn ? null : IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () { ref.read(addonsProvider.notifier).remove(a.id); ref.invalidate(addonRowsProvider); }),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 12, children: [
          FilledButton.icon(onPressed: _installDialog, icon: const Icon(Icons.add_link), label: const Text('Install from URL')),
          OutlinedButton(onPressed: () => _install('https://v3-cinemeta.strem.io/manifest.json'), child: const Text('Add Cinemeta (catalogs)')),
          OutlinedButton.icon(onPressed: _playLocal, icon: const Icon(Icons.folder_open), label: const Text('Play local file')),
        ]),
      ),
    ]);
  }
}
