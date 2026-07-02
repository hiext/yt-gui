import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'embedded_tool_resolver.dart';
import 'log_service.dart';

class EmbeddedToolExecutableResolver {
  EmbeddedToolExecutableResolver({
    Future<ByteData> Function(String path)? loadAsset,
  }) : _loadAsset = loadAsset ?? rootBundle.load;

  final Future<ByteData> Function(String path) _loadAsset;
  final Map<String, String> _extractedPaths = {};

  Future<String> ensureExecutable(ResolvedEmbeddedTool tool) async {
    if (!tool.isBundledAsset) {
      return tool.path;
    }

    final cached = _extractedPaths[tool.path];
    if (cached != null) {
      if (File(cached).existsSync()) return cached;
      _extractedPaths.remove(tool.path);
    }

    try {
      final data = await _loadAsset(tool.path);
      final dir = Directory.systemTemp.createTempSync('hiext-yt-tools-');
      final fileName = tool.path.split('/').last;
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
      File(filePath).writeAsBytesSync(data.buffer.asUint8List());
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', filePath]);
      }
      _extractedPaths[tool.path] = filePath;
      LogService.instance.debug(
        'Extracted ${tool.kind.name} bundled asset to $filePath',
        'executor',
      );
      return filePath;
    } catch (error) {
      final message = missingToolMessage(tool);
      LogService.instance.error('$message\n$error', 'executor');
      throw EmbeddedToolResolutionException(message);
    }
  }

  static String missingToolMessage(ResolvedEmbeddedTool tool) {
    final command = tool.kind.baseExecutableName;
    return 'Missing $command. Tool priority is Settings path > system PATH > bundled asset. '
        'Set a valid path in Settings, install $command on PATH, or refresh bundled tools with '
        '`dart run tools/fetch_embedded_tools.dart --tool=$command`. '
        'If the primary download is unavailable, configure mirrors in tools/embedded_tools.lock.json.';
  }
}
