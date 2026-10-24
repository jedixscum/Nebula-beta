import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

const _repo = 'jedixscum/Nebula-beta';
const _api = 'https://api.github.com';

class NebulaUpdate {
  final String tag;
  final String name;
  final String notes;
  final int build;
  final String assetName;
  final String assetUrl;
  final int size;

  const NebulaUpdate({
    required this.tag,
    required this.name,
    required this.notes,
    required this.build,
    required this.assetName,
    required this.assetUrl,
    required this.size,
  });
}

class NebulaVersion {
  final String name;
  final int build;
  const NebulaVersion(this.name, this.build);
}

class UpdateService {
  static const _channel = MethodChannel('nebula/updater');
  static const _storage = FlutterSecureStorage();
  final Dio _dio = Dio(BaseOptions(
    headers: const {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2026-03-10',
    },
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 30),
  ));

  Future<String?> readToken() => _storage.read(key: 'github_update_token');

  Future<void> saveToken(String value) async {
    if (value.trim().isEmpty) {
      await _storage.delete(key: 'github_update_token');
    } else {
      await _storage.write(key: 'github_update_token', value: value.trim());
    }
  }

  Future<NebulaVersion> currentVersion() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getVersion');
    return NebulaVersion(
      raw?['name']?.toString() ?? '0.1.0',
      int.tryParse(raw?['build']?.toString() ?? '') ?? 1,
    );
  }

  Future<bool> isTv() async => await _channel.invokeMethod<bool>('isTv') ?? false;

  Future<NebulaUpdate?> check() async {
    final token = await readToken();
    final headers = token == null || token.isEmpty ? <String, dynamic>{} : {'Authorization': 'Bearer $token'};
    final response = await _dio.get<List<dynamic>>('$_api/repos/$_repo/releases', queryParameters: {'per_page': 20}, options: Options(headers: headers));
    final releases = response.data ?? const [];
    final tv = await isTv();
    final assetName = tv ? 'nebula-android-tv.apk' : 'nebula-universal.apk';
    final current = await currentVersion();

    for (final raw in releases) {
      if (raw is! Map) continue;
      if (raw['draft'] == true) continue;
      final assets = raw['assets'] is List ? raw['assets'] as List : const [];
      Map<dynamic, dynamic>? asset;
      for (final candidate in assets) {
        if (candidate is Map && candidate['name'] == assetName) {
          asset = candidate;
          break;
        }
      }
      if (asset == null) continue;

      final tag = raw['tag_name']?.toString() ?? '';
      final build = _buildFromTag(tag);
      if (build <= current.build) return null;

      return NebulaUpdate(
        tag: tag,
        name: raw['name']?.toString() ?? tag,
        notes: raw['body']?.toString() ?? 'Nebula update',
        build: build,
        assetName: assetName,
        assetUrl: asset['url']?.toString() ?? '',
        size: int.tryParse(asset['size']?.toString() ?? '') ?? 0,
      );
    }
    return null;
  }

  Future<String> download(NebulaUpdate update, void Function(double) onProgress) async {
    final token = await readToken();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${update.assetName}');
    if (await file.exists()) await file.delete();
    final headers = <String, dynamic>{
      'Accept': 'application/octet-stream',
      'X-GitHub-Api-Version': '2026-03-10',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    await _dio.download(
      update.assetUrl,
      file.path,
      options: Options(headers: headers, followRedirects: true, responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );
    return file.path;
  }

  Future<void> install(String path) async {
    final result = await _channel.invokeMethod<String>('installApk', {'path': path});
    if (result == 'permission_required') {
      await _channel.invokeMethod('openInstallSettings');
      throw StateError('Allow Nebula to install updates, then tap Install again.');
    }
    if (result != 'started') throw StateError(result ?? 'Could not start Android package installer.');
  }

  Future<String?> pickAndInstallLocalApk() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['apk']);
    final path = picked?.files.single.path;
    if (path == null) return null;
    await install(path);
    return path;
  }

  int _buildFromTag(String tag) {
    final match = RegExp(r'(\d+)$').firstMatch(tag);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
