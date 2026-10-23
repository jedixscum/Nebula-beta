import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../core/theme.dart';
import '../data/addon_service.dart';
import '../data/download_manager.dart';
import '../data/history_store.dart';
import '../domain/media_item.dart';

/// Player on media_kit (libmpv): HW decode, audio/subtitle tracks, pitch, HTTP headers.
class PlayerScreen extends ConsumerStatefulWidget {
  final MediaItem item;
  const PlayerScreen({super.key, required this.item});
  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  // 64 MB demuxer buffer; pitch control must be enabled at construction.
  late final Player _p = Player(configuration: const PlayerConfiguration(pitch: true, bufferSize: 64 * 1024 * 1024));
  late final VideoController _vc = VideoController(_p);
  final _subs = <StreamSubscription>[];
  final _floating = Floating();
  final _hist = HistoryStore();

  Duration _pos = Duration.zero, _dur = Duration.zero, _buffer = Duration.zero;
  bool _playing = false, _buffering = true;
  Tracks _tracks = const Tracks();
  String _subText = '';
  int _w = 0, _h = 0, _lastSaveSec = -100;
  double _speed = 1.0, _pitch = 1.0, _subSize = 18;
  double? _aspect;
  bool _fill = false, _controls = true, _lens = false, _stats = false, _fullscreen = false;
  bool _failed = false, _glow = true;
  String? _trLang, _hw;

  static const _speeds = [0.25, 0.5, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0];
  static const _pitches = [0.8, 0.9, 1.0, 1.1, 1.25];

  bool get _isLive => widget.item.type == MediaType.live;
  void _u(VoidCallback f) { if (mounted) setState(f); }

  @override
  void initState() {
    super.initState();
    _tracks = _p.state.tracks;
    _subs.addAll([
      _p.stream.playing.listen((v) => _u(() => _playing = v)),
      _p.stream.buffering.listen((v) => _u(() => _buffering = v)),
      _p.stream.duration.listen((v) => _u(() => _dur = v)),
      _p.stream.buffer.listen((v) => _u(() => _buffer = v)),
      _p.stream.tracks.listen((v) => _u(() => _tracks = v)),
      _p.stream.subtitle.listen((v) => _u(() => _subText = v.join('\n').trim())),
      _p.stream.width.listen((v) => _u(() => _w = v ?? 0)),
      _p.stream.height.listen((v) => _u(() => _h = v ?? 0)),
      _p.stream.error.listen((_) => _u(() => _failed = true)),
      _p.stream.position.listen((v) {
        if (!mounted) return;
        if (!_isLive && _dur > Duration.zero && (v.inSeconds - _lastSaveSec).abs() >= 5) {
          _lastSaveSec = v.inSeconds;
          _hist.save(widget.item, v, _dur);
        }
        setState(() => _pos = v);
      }),
    ]);
    _start();
  }

  Future<void> _start() async {
    try {
      await _p.open(Media(widget.item.streamUrl!, httpHeaders: widget.item.headers), play: false);
      final e = _isLive ? null : _hist.get(widget.item.id);
      if (e != null && e.posMs > 5000 && e.posMs < e.durMs * 0.95) {
        try {
          await _p.stream.duration.firstWhere((d) => d > Duration.zero).timeout(const Duration(seconds: 10));
          await _p.seek(Duration(milliseconds: e.posMs)); // resume
        } catch (_) {/* start from the beginning */}
      }
      await _p.play();
      WakelockPlus.enable();
    } catch (_) {
      _u(() => _failed = true);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) { s.cancel(); }
    if (!_isLive && _dur > Duration.zero) _hist.save(widget.item, _pos, _dur);
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _floating.dispose();
    _p.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _skip(Duration d) {
    final t = _pos + d;
    _p.seek(t < Duration.zero ? Duration.zero : (_dur > Duration.zero && t > _dur ? _dur : t));
  }

  void _toggleFullscreen() {
    _fullscreen = !_fullscreen;
    SystemChrome.setEnabledSystemUIMode(_fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(
        _fullscreen ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : []);
    setState(() {});
  }

  Future<void> _pip() async {
    try {
      if (await _floating.isPipAvailable) {
        // floating 2.x uses the PiP configuration directly on enable().
        await _floating.enable(aspectRatio: Rational(16, 9));
      } else {
        _snack('Picture-in-Picture is not available on this device');
      }
    } catch (_) { _snack('Picture-in-Picture failed'); }
  }

  Future<T?> _choose<T>(String title, List<(String, T)> opts) => showDialog<T>(
        context: context,
        builder: (d) => SimpleDialog(title: Text(title), children: [
          for (final o in opts) SimpleDialogOption(onPressed: () => Navigator.pop(d, o.$2), child: Text(o.$1)),
        ]),
      );

  String _label(String id, String? title, String? lang) {
    if (id == 'auto') return 'Auto';
    if (id == 'no') return 'Off';
    final s = [title, lang].where((e) => e != null && e.isNotEmpty).join(' · ');
    return s.isEmpty ? 'Track $id' : s;
  }

  Future<void> _audioMenu() async {
    final t = await _choose<AudioTrack>('Audio track',
        [for (final a in _tracks.audio) (_label(a.id, a.title, a.language), a)]);
    if (t != null) await _p.setAudioTrack(t);
  }

  Future<void> _qualityMenu() async {
    final vids = _tracks.video.where((v) => v.id != 'auto' && v.id != 'no').toList();
    if (vids.length < 2) { _snack('This stream has a single quality'); return; }
    final t = await _choose<VideoTrack>('Quality', [
      ('Auto', VideoTrack.auto()),
      for (final v in vids) (v.h != null ? '${v.h}p' : _label(v.id, v.title, v.language), v),
    ]);
    if (t != null) await _p.setVideoTrack(t);
  }

  Future<void> _pitchMenu() async {
    final v = await _choose<double>('Pitch', [for (final x in _pitches) ('${x}x', x)]);
    if (v != null) { await _p.setPitch(v); _u(() => _pitch = v); }
  }

  Future<void> _onlineSubs() async {
    _snack('Searching subtitle addons…');
    final fromStream = widget.item.extSubs;
    final fromAddons = await subtitlesFor(ref, widget.item.typeStr, widget.item.id);
    final all = [...fromStream, ...fromAddons];
    if (!mounted) return;
    if (all.isEmpty) { _snack('No online subtitles found'); return; }
    final s = await _choose<ExtSub>('Online subtitles', [for (final e in all) (e.lang, e)]);
    if (s != null) await _p.setSubtitleTrack(SubtitleTrack.uri(s.url, title: s.lang, language: s.lang));
  }

  Future<void> _subMenu(String a) async {
    try {
      if (a.startsWith('emb:')) {
        final t = _tracks.subtitle.firstWhere((e) => e.id == a.substring(4));
        await _p.setSubtitleTrack(t);
        return;
      }
      switch (a) {
        case 'off': await _p.setSubtitleTrack(SubtitleTrack.no());
        case 'file':
          final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'vtt', 'ass']);
          final path = r?.files.single.path;
          if (path != null) await _p.setSubtitleTrack(SubtitleTrack.uri(path, title: r!.files.single.name));
        case 'online': await _onlineSubs();
        case 'tr_off': setState(() => _trLang = null);
        case 'tr_es': setState(() => _trLang = 'ES');
        case 'tr_fr': setState(() => _trLang = 'FR');
        case 'size_up': setState(() => _subSize = (_subSize + 2).clamp(12, 40));
        case 'size_down': setState(() => _subSize = (_subSize - 2).clamp(12, 40));
        case 'glow': setState(() => _glow = !_glow);
      }
    } catch (e) {
      _snack('Subtitles failed: $e');
    }
  }

  Future<void> _toggleStats() async {
    _stats = !_stats;
    if (_stats) {
      try { _hw = await (_p.platform as NativePlayer).getProperty('hwdec-current'); } catch (_) { _hw = '?'; }
    }
    _u(() {});
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final introEnd = widget.item.introEndSec;
    final showSkip = introEnd != null && _pos.inSeconds >= 1 && _pos.inSeconds < introEnd;
    final sub = _trLang == null || _subText.isEmpty ? _subText : '[$_trLang] $_subText (mock)';
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _controls = !_controls),
        child: Stack(fit: StackFit.expand, children: [
          if (_failed)
            const Center(child: Text('Could not play this stream.'))
          else
            Video(
              controller: _vc,
              controls: NoVideoControls,
              aspectRatio: _aspect,
              fit: _fill ? BoxFit.cover : BoxFit.contain,
              subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false), // we draw our own
            ),
          if (_buffering && !_failed) const Center(child: CircularProgressIndicator()),
          if (_lens) const IgnorePointer(child: _LensOverlay()),
          if (sub.isNotEmpty)
            Positioned(
              left: 24, right: 24, bottom: _controls ? 140 : 40,
              child: IgnorePointer(
                child: Text(sub, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: _subSize, color: Colors.white, fontWeight: FontWeight.w600, shadows: [
                      if (_glow) const Shadow(color: nebulaCyan, blurRadius: 14),
                      const Shadow(color: Colors.black, blurRadius: 3),
                    ])),
              ),
            ),
          if (_stats)
            Positioned(
              top: 70, left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black54, border: Border.all(color: nebulaCyan), borderRadius: BorderRadius.circular(8)),
                child: Text('${_w}x$_h  speed ${_speed}x  pitch ${_pitch}x\n'
                    'buffered: ${_fmt(_buffer)}\ndecoder: ${_hw ?? '-'}',
                    style: const TextStyle(color: nebulaCyan, fontSize: 12)),
              ),
            ),
          if (showSkip)
            Positioned(
              right: 16, bottom: _controls ? 190 : 60,
              child: FilledButton.tonal(onPressed: () => _p.seek(Duration(seconds: introEnd)), child: const Text('Skip intro')),
            ),
          if (_controls) _buildControls(),
        ]),
      ),
    );
  }

  Widget _buildControls() => Container(
        color: Colors.black38,
        child: SafeArea(
          child: Column(children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
              Expanded(child: Text(widget.item.title, overflow: TextOverflow.ellipsis)),
              IconButton(icon: const Icon(Icons.picture_in_picture_alt), tooltip: 'Picture-in-Picture', onPressed: _pip),
              PopupMenuButton<String>(
                onSelected: (a) {
                  switch (a) {
                    case 'lens': setState(() => _lens = !_lens);
                    case 'stats': _toggleStats();
                    case 'audio': _audioMenu();
                    case 'pitch': _pitchMenu();
                    case 'quality': _qualityMenu();
                    case 'download':
                      ref.read(downloadsProvider.notifier).start(widget.item);
                      _snack('Download started (Profile > Downloads)');
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'audio', child: Text('Audio track')),
                  PopupMenuItem(value: 'pitch', child: Text('Pitch (${_pitch}x)')),
                  const PopupMenuItem(value: 'quality', child: Text('Quality')),
                  PopupMenuItem(value: 'lens', child: Text(_lens ? 'Nebula Lens: on' : 'Nebula Lens: off')),
                  PopupMenuItem(value: 'stats', child: Text(_stats ? 'Hide stats' : 'Show stats')),
                  if (!_isLive && (widget.item.streamUrl ?? '').startsWith('http'))
                    const PopupMenuItem(value: 'download', child: Text('Download')),
                ],
              ),
            ]),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.replay_30), onPressed: () => _skip(const Duration(seconds: -30))),
              IconButton(icon: const Icon(Icons.replay_10), onPressed: () => _skip(const Duration(seconds: -10))),
              IconButton(iconSize: 56, icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle), onPressed: _p.playOrPause),
              IconButton(icon: const Icon(Icons.forward_10), onPressed: () => _skip(const Duration(seconds: 10))),
              IconButton(icon: const Icon(Icons.forward_30), onPressed: () => _skip(const Duration(seconds: 30))),
            ]),
            if (!_isLive && _dur > Duration.zero)
              Row(children: [
                Padding(padding: const EdgeInsets.only(left: 12), child: Text(_fmt(_pos))),
                Expanded(
                  child: Slider(
                    value: _pos.inMilliseconds.clamp(0, _dur.inMilliseconds).toDouble(),
                    max: _dur.inMilliseconds.toDouble(),
                    onChanged: (x) => _p.seek(Duration(milliseconds: x.toInt())),
                  ),
                ),
                Padding(padding: const EdgeInsets.only(right: 12), child: Text(_fmt(_dur))),
              ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              PopupMenuButton<double>(
                  tooltip: 'Speed',
                  child: Chip(label: Text('${_speed}x')),
                  onSelected: (s) { _p.setRate(s); setState(() => _speed = s); },
                  itemBuilder: (_) => [for (final s in _speeds) PopupMenuItem(value: s, child: Text('${s}x'))]),
              PopupMenuButton<String>(
                  tooltip: 'Aspect ratio',
                  child: const Chip(label: Text('Aspect')),
                  onSelected: (a) => setState(() {
                        _fill = a == 'fill';
                        _aspect = switch (a) { '4:3' => 4 / 3, '16:9' => 16 / 9, '21:9' => 21 / 9, _ => null };
                      }),
                  itemBuilder: (_) => const [
                        PopupMenuItem(value: 'orig', child: Text('Original')),
                        PopupMenuItem(value: '4:3', child: Text('4:3')),
                        PopupMenuItem(value: '16:9', child: Text('16:9')),
                        PopupMenuItem(value: '21:9', child: Text('21:9')),
                        PopupMenuItem(value: 'fill', child: Text('Fill screen')),
                      ]),
              PopupMenuButton<String>(
                  tooltip: 'Subtitles',
                  icon: const Icon(Icons.closed_caption),
                  onSelected: _subMenu,
                  itemBuilder: (_) => [
                        const PopupMenuItem(value: 'off', child: Text('Off')),
                        for (final t in _tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no'))
                          PopupMenuItem(value: 'emb:${t.id}', child: Text(_label(t.id, t.title, t.language))),
                        const PopupMenuItem(value: 'online', child: Text('Search online (addons)')),
                        const PopupMenuItem(value: 'file', child: Text('Load .srt/.vtt/.ass file')),
                        const PopupMenuItem(value: 'tr_off', child: Text('No translation')),
                        const PopupMenuItem(value: 'tr_es', child: Text('Translate to ES (mock)')),
                        const PopupMenuItem(value: 'tr_fr', child: Text('Translate to FR (mock)')),
                        const PopupMenuItem(value: 'size_up', child: Text('Larger text')),
                        const PopupMenuItem(value: 'size_down', child: Text('Smaller text')),
                        PopupMenuItem(value: 'glow', child: Text(_glow ? 'Neon glow: on' : 'Neon glow: off')),
                      ]),
              IconButton(icon: Icon(_fullscreen ? Icons.fullscreen_exit : Icons.fullscreen), onPressed: _toggleFullscreen),
            ]),
          ]),
        ),
      );
}

/// Vignette + color grade drawn over the video.
class _LensOverlay extends StatelessWidget {
  const _LensOverlay();
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(radius: 1.1, colors: [
            nebulaViolet.withOpacity(0.08), Colors.transparent, Colors.black.withOpacity(0.55)
          ], stops: const [0, 0.55, 1]),
        ),
      );
}
