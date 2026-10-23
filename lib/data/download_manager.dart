import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/media_item.dart';

enum DlStatus { running, paused, done, error }

class DlTask {
  final String id, title, url, path;
  final int received, total;
  final DlStatus status;
  const DlTask({required this.id, required this.title, required this.url, required this.path,
      this.received = 0, this.total = 0, this.status = DlStatus.paused});
  double get progress => total > 0 ? received / total : 0;
  DlTask copyWith({int? received, int? total, DlStatus? status}) => DlTask(
      id: id, title: title, url: url, path: path,
      received: received ?? this.received, total: total ?? this.total, status: status ?? this.status);
}

/// Resumable downloads using HTTP Range requests, stored in app documents dir.
class DownloadManager extends StateNotifier<Map<String, DlTask>> {
  final _dio = Dio();
  final _tokens = <String, CancelToken>{};
  Box<String> get _box => Hive.box<String>('downloads');

  DownloadManager() : super(_restore());

  static Map<String, DlTask> _restore() {
    final box = Hive.box<String>('downloads');
    final m = <String, DlTask>{};
    for (final k in box.keys.cast<String>()) {
      final j = jsonDecode(box.get(k)!) as Map<String, dynamic>;
      final f = File(j['path'] as String);
      if (!f.existsSync()) { box.delete(k); continue; }
      m[k] = DlTask(id: k, title: j['title'], url: j['url'], path: j['path'],
          received: f.lengthSync(), total: j['total'] ?? 0,
          status: j['done'] == true ? DlStatus.done : DlStatus.paused);
    }
    return m;
  }

  void _set(DlTask t) {
    state = {...state, t.id: t};
    if (t.status != DlStatus.running) {
      _box.put(t.id, jsonEncode({'title': t.title, 'url': t.url, 'path': t.path,
        'total': t.total, 'done': t.status == DlStatus.done}));
    }
  }

  Future<void> start(MediaItem m) async {
    final url = m.streamUrl;
    if (url == null || !url.startsWith('http')) return;
    var t = state[m.id];
    if (t?.status == DlStatus.running || t?.status == DlStatus.done) return;
    final path = t?.path ?? '${(await getApplicationDocumentsDirectory()).path}/dl_${m.id}.mp4';
    final file = File(path);
    var have = await file.exists() ? await file.length() : 0;
    t = DlTask(id: m.id, title: m.title, url: url, path: path, received: have,
        total: t?.total ?? 0, status: DlStatus.running);
    _set(t);
    final token = CancelToken();
    _tokens[m.id] = token;
    try {
      final r = await _dio.get<ResponseBody>(url,
          cancelToken: token,
          options: Options(
            responseType: ResponseType.stream,
            headers: {...?m.headers, if (have > 0) 'range': 'bytes=$have-'},
            validateStatus: (s) => s != null && (s < 400 || s == 416),
          ));
      if (r.statusCode == 416) { // already complete
        _set(t.copyWith(status: DlStatus.done));
        return;
      }
      final resumed = r.statusCode == 206;
      if (!resumed) have = 0;
      final len = int.tryParse(r.headers.value('content-length') ?? '') ?? 0;
      final total = len > 0 ? len + have : t.total;
      final sink = file.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      var got = have, lastTick = 0;
      try {
        await for (final chunk in r.data!.stream) {
          sink.add(chunk);
          got += chunk.length;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastTick > 300) {
            lastTick = now;
            state = {...state, m.id: state[m.id]!.copyWith(received: got, total: total)};
          }
        }
      } finally {
        await sink.close();
      }
      _set(state[m.id]!.copyWith(received: got, total: total, status: DlStatus.done));
    } on DioException catch (e) {
      _set(state[m.id]!.copyWith(status: CancelToken.isCancel(e) ? DlStatus.paused : DlStatus.error));
    } catch (_) {
      _set(state[m.id]!.copyWith(status: DlStatus.error));
    }
  }

  void pause(String id) => _tokens[id]?.cancel();

  Future<void> delete(String id) async {
    _tokens[id]?.cancel();
    final t = state[id];
    if (t != null) {
      final f = File(t.path);
      if (await f.exists()) await f.delete();
    }
    _box.delete(id);
    state = {...state}..remove(id);
  }
}

final downloadsProvider =
    StateNotifierProvider<DownloadManager, Map<String, DlTask>>((_) => DownloadManager());
