import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../models/voice_swap_models.dart';
import '../log_service.dart';
import 'voice_swap_model_catalog.dart';

/// 下载响应抽象（便于单测注入）。
class VoiceSwapDownloadResponse {
  const VoiceSwapDownloadResponse({
    required this.statusCode,
    this.contentLength,
    required this.stream,
  });

  final int statusCode;
  final int? contentLength;
  final Stream<List<int>> stream;
}

typedef VoiceSwapDownloader =
    Future<VoiceSwapDownloadResponse> Function(Uri url);

/// 模型管理：下载（带进度）、sha256 校验、tar.bz2 解压与路径解析。
///
/// 目录布局（均在用户模型目录下）：
/// - `downloads/<id>`         下载缓存（原始文件/压缩包）
/// - `.checksums/<id>.sha256` 首次下载后计算并锁定的校验值
/// - `models/<id>/`           普通模型为单文件；压缩包为解压后的内容
class VoiceSwapModelManager {
  VoiceSwapModelManager({
    required this.settings,
    this.catalog = const VoiceSwapModelCatalog(),
    VoiceSwapDownloader? downloader,
    Future<void> Function(File archive, Directory targetRoot)? extractor,
  }) : _downloader = downloader ?? _defaultDownloader,
       _extractor = extractor ?? _extractWithTarOrArchive;

  final VoiceSwapSettings settings;
  final VoiceSwapModelCatalog catalog;
  final VoiceSwapDownloader _downloader;
  final Future<void> Function(File archive, Directory targetRoot) _extractor;

  String get modelDir => settings.resolvedModelDir;

  String _join(String path, String part) =>
      '$path${Platform.pathSeparator}$part';

  String downloadPath(String id) => _join(_join(modelDir, 'downloads'), id);
  String modelRoot(String id) => _join(_join(modelDir, 'models'), id);
  String checksumPath(String id) =>
      _join(_join(modelDir, '.checksums'), '$id.sha256');

  /// 模型是否已就绪。
  Future<bool> isAvailable(String id) async {
    final model = _modelOf(id);
    if (model.archive) {
      final dir = Directory(modelRoot(id));
      if (!dir.existsSync() || dir.listSync().isEmpty) return false;
      final cache = File(downloadPath(id));
      if (cache.existsSync()) {
        return _verifyChecksum(id, cache, model.sha256);
      }
      return true;
    }
    final target = _finalTarget(model);
    if (!File(target).existsSync()) return false;
    return _verifyChecksum(id, File(target), model.sha256);
  }

  /// 保证模型可用：缺失时按 [autoDownload] 决定是否自动下载。
  Future<VoiceSwapModelFile> ensureAvailable(
    String id, {
    bool autoDownload = true,
    void Function(VoiceSwapProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final model = _modelOf(id);
    if (await isAvailable(id)) return model;
    if (!autoDownload) {
      throw VoiceSwapModelMissingException(
        '模型 ${model.name} 未就绪，且已关闭自动下载。'
        '请在设置中打开自动下载，或手动放置到 ${modelRoot(model.id)}',
      );
    }

    final downloadFile = File(downloadPath(id));
    if (!downloadFile.existsSync() ||
        !await _verifyChecksum(id, downloadFile, model.sha256)) {
      await _download(
        model,
        downloadFile,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    }

    if (model.archive) {
      await _extractTo(model, downloadFile);
    } else {
      final target = _finalTarget(model);
      File(target).parent.createSync(recursive: true);
      if (File(target).existsSync()) File(target).deleteSync();
      await downloadFile.copy(target);
    }

    await _persistChecksum(id, downloadFile);
    if (!await isAvailable(id)) {
      throw VoiceSwapModelException('模型 ${model.name} 校验失败');
    }
    return model;
  }

  /// 批量保证模型可用，进度按模型粒度汇总。
  Future<List<VoiceSwapModelFile>> ensureModels(
    List<String> ids, {
    bool autoDownload = true,
    void Function(VoiceSwapProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (ids.isEmpty) return const [];
    final result = <VoiceSwapModelFile>[];
    for (var i = 0; i < ids.length; i++) {
      if (isCancelled?.call() ?? false) {
        throw VoiceSwapCancelledException();
      }
      final id = ids[i];
      final file = await ensureAvailable(
        id,
        autoDownload: autoDownload,
        isCancelled: isCancelled,
        onProgress: (p) => onProgress?.call(
          VoiceSwapProgress(
            stage: VoiceSwapStage.downloadingModels,
            progress: (i + p.progress.clamp(0.0, 1.0)) / ids.length,
            message: p.message,
          ),
        ),
      );
      result.add(file);
    }
    return result;
  }

  /// 普通模型的最终文件路径；不存在时返回 null。
  String? resolveFilePath(String id) {
    final model = _modelOf(id);
    final target = _finalTarget(model);
    return File(target).existsSync() ? target : null;
  }

  /// 解压目录；不存在返回 null。
  String? resolveDir(String id) {
    final dir = Directory(modelRoot(id));
    return dir.existsSync() ? dir.path : null;
  }

  /// 在解压目录中按目录名（忽略大小写全名匹配）定位子目录。
  String? resolveDirInModel(String id, {required String dirName}) {
    final dir = Directory(modelRoot(id));
    if (!dir.existsSync()) return null;
    final lowered = dirName.toLowerCase();
    for (final entry in dir.listSync(recursive: true).whereType<Directory>()) {
      if (_baseName(entry.path).toLowerCase() == lowered) {
        return entry.path;
      }
    }
    return null;
  }

  /// 在解压目录中按候选文件名（忽略大小写全名匹配）定位文件。
  String? resolveFileInDir(String id, {required List<String> candidateNames}) {
    final dir = Directory(modelRoot(id));
    if (!dir.existsSync()) return null;
    final lowered = candidateNames.map((n) => n.toLowerCase()).toSet();
    for (final entry in dir.listSync(recursive: true).whereType<File>()) {
      final name = _baseName(entry.path).toLowerCase();
      if (lowered.contains(name)) return entry.path;
    }
    return null;
  }

  /// 取路径最后一段（避免目录 uri 尾斜杠干扰）。
  String _baseName(String path) => path.split(Platform.pathSeparator).last;

  VoiceSwapModelFile _modelOf(String id) => VoiceSwapModelCatalog.modelOf(id);

  String _finalTarget(VoiceSwapModelFile model) =>
      _join(modelRoot(model.id), model.name);

  Future<void> _download(
    VoiceSwapModelFile model,
    File target, {
    void Function(VoiceSwapProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    target.parent.createSync(recursive: true);
    if (target.existsSync()) target.deleteSync();

    final response = await _downloader(Uri.parse(model.url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VoiceSwapModelException(
        '下载 ${model.name} 失败（HTTP ${response.statusCode}）：${model.url}',
      );
    }
    final total = response.contentLength;
    var received = 0;
    final sink = target.openWrite();
    try {
      await for (final chunk in response.stream) {
        if (isCancelled?.call() ?? false) {
          throw VoiceSwapCancelledException();
        }
        received += chunk.length;
        sink.add(chunk);
        if (total != null && total > 0) {
          onProgress?.call(
            VoiceSwapProgress(
              stage: VoiceSwapStage.downloadingModels,
              progress: received / total,
              message: '下载 ${model.name}',
            ),
          );
        }
      }
      await sink.flush();
    } on VoiceSwapCancelledException {
      if (target.existsSync()) target.deleteSync();
      rethrow;
    } catch (error) {
      if (target.existsSync()) target.deleteSync();
      LogService.instance.error('模型下载失败 ${model.name}: $error', 'voice-swap');
      throw VoiceSwapModelException('下载 ${model.name} 失败：$error');
    } finally {
      await sink.close();
    }
    onProgress?.call(
      VoiceSwapProgress(
        stage: VoiceSwapStage.downloadingModels,
        progress: 1,
        message: '下载 ${model.name}',
      ),
    );
  }

  Future<void> _extractTo(VoiceSwapModelFile model, File archiveFile) async {
    final root = Directory(modelRoot(model.id));
    if (root.existsSync()) root.deleteSync(recursive: true);
    root.createSync(recursive: true);
    try {
      await _extractor(archiveFile, root);
    } on VoiceSwapCancelledException {
      rethrow;
    } catch (error) {
      LogService.instance.error('模型解压失败 ${model.name}: $error', 'voice-swap');
      throw VoiceSwapModelException('解压 ${model.name} 失败：$error');
    }
  }

  Future<bool> _verifyChecksum(
    String id,
    File file,
    String? knownSha256,
  ) async {
    if (!file.existsSync() || file.lengthSync() == 0) return false;
    final expected = knownSha256 ?? _readSidecarChecksum(id);
    if (expected == null || expected.isEmpty) return true;
    final actual = await _sha256Hex(file);
    return actual.toLowerCase() == expected.toLowerCase();
  }

  Future<void> _persistChecksum(String id, File file) async {
    final actual = await _sha256Hex(file);
    final sidecar = File(checksumPath(id));
    sidecar.parent.createSync(recursive: true);
    await sidecar.writeAsString(actual.trim());
  }

  String? _readSidecarChecksum(String id) {
    final sidecar = File(checksumPath(id));
    if (!sidecar.existsSync()) return null;
    return sidecar.readAsStringSync().trim();
  }

  Future<String> _sha256Hex(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static Future<VoiceSwapDownloadResponse> _defaultDownloader(Uri url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      request.followRedirects = true;
      final response = await request.close();
      return VoiceSwapDownloadResponse(
        statusCode: response.statusCode,
        contentLength: response.contentLength,
        stream: response,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// 优先系统 tar，失败时回退纯 Dart 解压（archive 包）。
  static Future<void> _extractWithTarOrArchive(
    File archive,
    Directory root,
  ) async {
    try {
      final result = await Process.run('tar', [
        '-xjf',
        archive.path,
        '-C',
        root.path,
      ]);
      if (result.exitCode == 0) {
        _flattenSingleTopLevel(root);
        return;
      }
    } catch (_) {
      // 系统 tar 不可用时回退纯 Dart 解压。
    }
    _extractWithArchive(archive, root);
  }

  static void _extractWithArchive(File archive, Directory root) {
    final bytes = archive.readAsBytesSync();
    final bz2 = BZip2Decoder().decodeBytes(bytes);
    final tar = TarDecoder().decodeBytes(bz2);
    for (final entry in tar) {
      final clean = entry.name
          .split('/')
          .where((part) => part.isNotEmpty)
          .join('/');
      if (clean.isEmpty || !entry.isFile) continue;
      final dest = File('${root.path}${Platform.pathSeparator}$clean');
      dest.parent.createSync(recursive: true);
      dest.writeAsBytesSync(entry.content as List<int>);
    }
    _flattenSingleTopLevel(root);
  }

  /// 解压结果若只有一个顶层目录，把内容上移到 [root]。
  static void _flattenSingleTopLevel(Directory root) {
    final entries = root.listSync();
    if (entries.length != 1 || entries.first is! Directory) return;
    final top = entries.first as Directory;
    for (final child in top.listSync()) {
      child.renameSync(
        '${root.path}${Platform.pathSeparator}${child.uri.pathSegments.last}',
      );
    }
    if (top.listSync().isEmpty) top.deleteSync();
  }
}

class VoiceSwapModelException implements Exception {
  const VoiceSwapModelException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VoiceSwapModelMissingException extends VoiceSwapModelException {
  const VoiceSwapModelMissingException(super.message);
}

class VoiceSwapCancelledException implements Exception {
  const VoiceSwapCancelledException();

  @override
  String toString() => 'Voice swap cancelled';
}
