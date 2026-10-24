import 'package:flutter/material.dart';

import '../data/update_service.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  final _service = UpdateService();
  NebulaVersion? _current;
  NebulaUpdate? _update;
  String? _error;
  bool _checking = false;
  bool _downloading = false;
  double _progress = 0;
  String? _token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _token = await _service.readToken();
    _current = await _service.currentVersion();
    if (mounted) setState(() {});
    if (_token?.isNotEmpty == true) await _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
      _update = null;
    });
    try {
      final update = await _service.check();
      if (mounted) setState(() => _update = update);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _saveToken() async {
    final controller = TextEditingController(text: _token ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GitHub update access'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Read-only GitHub token',
            hintText: 'github_pat_…',
            helperText: 'Nebula stores this in Android secure storage.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Clear')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _service.saveToken(value);
    _token = value.trim().isEmpty ? null : value.trim();
    if (mounted) setState(() {});
    if (_token != null) await _check();
  }

  Future<void> _downloadAndInstall() async {
    final update = _update;
    if (update == null) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final path = await _service.download(update, (value) {
        if (mounted) setState(() => _progress = value.clamp(0, 1));
      });
      await _service.install(path);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _installLocal() async {
    try {
      await _service.pickAndInstallLocalApk();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('404')) return 'Nebula could not access the private GitHub release feed. Add a read-only GitHub token below.';
    if (text.contains('permission_required')) return 'Android needs permission to install updates.';
    return text.replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _current;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: .28),
                theme.colorScheme.secondary.withValues(alpha: .10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: .25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.rocket_launch_rounded, size: 34),
            const SizedBox(height: 14),
            Text('Nebula Updates', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(current == null ? 'Checking installed version…' : 'Installed ${current.name} · build ${current.build}', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('Beta update channel'),
                subtitle: const Text('Checks the latest Nebula GitHub Actions release without uninstalling the app.'),
              ),
              const SizedBox(height: 8),
              if (_checking)
                const LinearProgressIndicator()
              else if (_update != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.new_releases_outlined),
                  title: Text(_update!.name),
                  subtitle: Text('Build ${_update!.build} · ${_update!.assetName}'),
                ),
                if (_update!.notes.trim().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_update!.notes, maxLines: 8, overflow: TextOverflow.ellipsis)),
                if (_downloading) ...[
                  LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                  const SizedBox(height: 8),
                  Text('${(_progress * 100).round()}% downloaded'),
                ] else
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _downloadAndInstall, icon: const Icon(Icons.download_rounded), label: const Text('Download & Install Update'))),
              ] else if (_error == null && !_checking)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('You are up to date'),
                  subtitle: Text('No newer Nebula build was found.'),
                ),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _checking ? null : _check, icon: const Icon(Icons.refresh), label: const Text('Check for Updates'))),
            ]),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Update check needs attention'),
              subtitle: Text(_error!),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('GitHub access token'),
              subtitle: Text(_token?.isNotEmpty == true ? 'Configured securely' : 'Required while the Nebula repository is private'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saveToken,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.install_mobile_outlined),
              title: const Text('Install APK manually'),
              subtitle: const Text('Install a downloaded Nebula APK over the current installation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _installLocal,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Your Nebula data is not removed during an update. Android upgrades the existing installation in place, preserving add-ons, favorites, history, catalog customization, themes and other app data.'),
          ),
        ),
      ],
    );
  }
}
