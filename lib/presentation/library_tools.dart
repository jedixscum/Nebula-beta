import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/catalog.dart';
import '../data/download_manager.dart';
import '../data/home_layout.dart';
import '../data/providers.dart';
import '../data/sample_data.dart';
import '../domain/media_item.dart';

Future<String?> _prompt(BuildContext c, String title, {String initial = '', String? hint, int lines = 1}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, maxLines: lines, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, ctrl.text), child: const Text('OK')),
      ],
    ),
  );
}

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadsProvider).values.toList();
    final mgr = ref.read(downloadsProvider.notifier);
    if (tasks.isEmpty) return const Center(child: Text('No downloads yet. Use the download button on a detail page.'));
    return ListView(children: [
      for (final t in tasks)
        ListTile(
          title: Text(t.title),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            LinearProgressIndicator(value: t.status == DlStatus.done ? 1 : t.progress),
            const SizedBox(height: 4),
            Text('${t.status.name}  ${(t.received / 1048576).toStringAsFixed(1)} MB'),
          ]),
          onTap: t.status == DlStatus.done
              ? () {
                  final base = resolveItem(t.id);
                  final item = (base ??
                          MediaItem(id: t.id, title: t.title, year: 0, type: MediaType.movie, synopsis: '',
                              director: '-', runtimeMin: 0, rating: 0, cast: const [], genres: const []))
                      .copyWith(streamUrl: 'file://${t.path}');
                  context.push('/player', extra: item);
                }
              : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (t.status == DlStatus.running)
              IconButton(icon: const Icon(Icons.pause), onPressed: () => mgr.pause(t.id))
            else if (t.status != DlStatus.done)
              IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => mgr.start(MediaItem(id: t.id, title: t.title, year: 0, type: MediaType.movie,
                      synopsis: '', director: '-', runtimeMin: 0, rating: 0, cast: const [], genres: const [],
                      streamUrl: t.url))),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => mgr.delete(t.id)),
          ]),
        ),
    ]);
  }
}

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cols = ref.watch(catalogProvider);
    final n = ref.read(catalogProvider.notifier);
    return ListView(padding: const EdgeInsets.all(12), children: [
      Wrap(spacing: 8, children: [
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('New collection'),
          onPressed: () async {
            final name = await _prompt(context, 'Collection name');
            if (name != null && name.trim().isNotEmpty) n.add(name.trim());
          },
        ),
        OutlinedButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: n.exportJson()));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catalog JSON copied')));
          },
          child: const Text('Export JSON'),
        ),
        OutlinedButton(
          onPressed: () async {
            final json = await _prompt(context, 'Paste catalog JSON', lines: 6);
            if (json == null || json.trim().isEmpty) return;
            try {
              n.importJson(json);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid catalog: $e')));
              }
            }
          },
          child: const Text('Import JSON'),
        ),
      ]),
      for (final c in cols)
        Card(
          color: Colors.black38,
          child: ExpansionTile(
            title: Text(c.name),
            subtitle: Text(c.description.isEmpty ? '${c.itemIds.length} titles' : c.description),
            children: [
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (o, nw) => n.reorder(c.id, o, nw),
                children: [
                  for (final id in c.itemIds)
                    ListTile(
                      key: ValueKey('${c.id}-$id'),
                      title: Text(resolveItem(id)?.title ?? id),
                      trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => n.removeItem(c.id, id)),
                    ),
                ],
              ),
              OverflowBar(children: [
                TextButton(
                  onPressed: () async {
                    final id = await showDialog<String>(
                      context: context,
                      builder: (d) => SimpleDialog(title: const Text('Add title'), children: [
                        for (final m in [...sampleItems.where((m) => m.type != MediaType.live), ...ref.read(libraryItemsProvider).where((l) => findItem(l.id) == null)])
                          SimpleDialogOption(onPressed: () => Navigator.pop(d, m.id), child: Text(m.title)),
                      ]),
                    );
                    if (id != null) n.addItem(c.id, id);
                  },
                  child: const Text('Add title'),
                ),
                TextButton(
                  onPressed: () async {
                    final name = await _prompt(context, 'Name', initial: c.name);
                    if (name == null || !context.mounted) return;
                    final desc = await _prompt(context, 'Description', initial: c.description);
                    if (desc != null && name.trim().isNotEmpty) n.edit(c.id, name.trim(), desc);
                  },
                  child: const Text('Edit'),
                ),
                TextButton(onPressed: () => n.remove(c.id), child: const Text('Delete')),
              ]),
            ],
          ),
        ),
    ]);
  }
}

class HomeLayoutScreen extends ConsumerWidget {
  const HomeLayoutScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(homeLayoutProvider);
    final n = ref.read(homeLayoutProvider.notifier);
    return ReorderableListView(
      onReorder: n.reorder,
      children: [
        for (var i = 0; i < sections.length; i++)
          SwitchListTile(
            key: ValueKey(sections[i].key),
            secondary: const Icon(Icons.drag_handle),
            title: Text(homeSectionTitles[sections[i].key]!),
            value: sections[i].visible,
            onChanged: (_) => n.toggle(i),
          ),
      ],
    );
  }
}
