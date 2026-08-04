import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/voice_swap_models.dart';
import '../embedded_tool_manifest.dart';
import '../embedded_tool_resolver.dart';
import '../log_service.dart';
import 'voice_swap_model_manager.dart';

typedef SeparationProcessRunner =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      Map<String, String>? environment,
      String? workingDirectory,
    });

typedef ByteDataLoader = Future<ByteData> Function(String path);

/// 分离 CLI 的解析结果。
class ResolvedSeparationCli {
  const ResolvedSeparationCli({
    required this.path,
    required this.isCustom,
    this.libDir,
    this.isBundledAsset = false,
  });

  final String path;
  final bool isCustom;

  /// Linux 需要设置为 LD_LIBRARY_PATH 的 lib 目录。
  final String? libDir;
  final bool isBundledAsset;
}

/// 解析并调用 sherpa-onnx-offline-source-separation。
///
/// 解析顺序与仓库其它内置工具一致：
/// 设置页已验证路径 > 系统 PATH > `assets/bin/<platform>/sherpa-sep` 内置包。
class SourceSeparationExecutor {
  SourceSeparationExecutor({
    this._platformOverride,
    this._environment,
    bool Function(String path)? fileExists,
    ByteDataLoader? loadAsset,
    SeparationProcessRunner? processRunner,
  }) : _fileExists = fileExists ?? _defaultFileExists,
       _loadAsset = loadAsset ?? rootBundle.load,
       _processRunner = processRunner ?? _defaultProcessRunner;

  final String? _platformOverride;
  final Map<String, String>? _environment;
  final bool Function(String path) _fileExists;
  final ByteDataLoader _loadAsset;
  final SeparationProcessRunner _processRunner;
  final Map<String, String> _extractedPaths = {};

  EmbeddedToolPlatform get _platform => _platformOverride == null
      ? EmbeddedToolPlatformDetector.current()
      : EmbeddedToolPlatformDetector.fromOperatingSystem(_platformOverride);

  static const _bundleRoot = 'sherpa-sep';
  static const _cliBaseName = 'sherpa-onnx-offline-source-separation';

  /// 内置包相对文件清单（bin + lib，保留相对结构，匹配 CLI 的 @loader_path/../lib）。
  static List<String> bundledRelativeFiles(EmbeddedToolPlatform platform) {
    final exe = platform == EmbeddedToolPlatform.windows
        ? '$_cliBaseName.exe'
        : _cliBaseName;
    return switch (platform) {
      EmbeddedToolPlatform.macos => [
        'bin/$exe',
        'lib/libonnxruntime.1.27.0.dylib',
        'lib/libsherpa-onnx-c-api.dylib',
        'lib/libsherpa-onnx-cxx-api.dylib',
      ],
      EmbeddedToolPlatform.linux => [
        'bin/$exe',
        'lib/libonnxruntime.so',
        'lib/libsherpa-onnx-c-api.so',
        'lib/libsherpa-onnx-cxx-api.so',
      ],
      EmbeddedToolPlatform.windows => [
        'bin/$exe',
        'lib/onnxruntime.dll',
        'lib/onnxruntime_providers_shared.dll',
        'lib/sherpa-onnx-c-api.dll',
        'lib/sherpa-onnx-cxx-api.dll',
      ],
    };
  }

  /// 解析 CLI 路径；找不到时抛出带指引的异常。
  Future<ResolvedSeparationCli> resolveCli({
    required VoiceSwapSettings settings,
  }) async {
    final custom = settings.separationBinPath?.trim();
    if (custom != null && custom.isNotEmpty) {
      _validateCliName(custom);
      if (!_fileExists(custom)) {
        throw VoiceSwapSeparationException(
          '配置的分离 CLI 路径不存在：$custom。'
          '请指向真实的 sherpa-onnx-offline-source-separation 可执行文件。',
        );
      }
      return ResolvedSeparationCli(path: custom, isCustom: true);
    }

    final platform = _platform;
    final onPath = _findOnPath(platform);
    if (onPath != null) {
      return ResolvedSeparationCli(path: onPath, isCustom: false);
    }

    final bundled = await _extractBundled(platform);
    if (bundled != null) {
      return bundled;
    }

    throw VoiceSwapSeparationException(
      '未找到分离 CLI。工具优先级：设置页路径 > 系统 PATH > 内置包。'
      '请在设置中指定分离 CLI 路径，安装到 PATH，或运行 '
      '`dart run tools/fetch_embedded_tools.dart --tool=sherpa-onnx-separation` 刷新内置包。',
    );
  }

  /// 执行人声/伴奏分离。
  Future<SeparationOutput> separate({
    required ResolvedSeparationCli cli,
    required String inputWav,
    required String outputVocalsWav,
    required String outputAccompanimentWav,
    required String uvrModelPath,
    bool Function()? isCancelled,
  }) async {
    final args = <String>[
      '--uvr-model=$uvrModelPath',
      '--input-wav=$inputWav',
      '--output-vocals-wav=$outputVocalsWav',
      '--output-accompaniment-wav=$outputAccompanimentWav',
    ];

    final process = await _processRunner(
      cli.path,
      args,
      environment: _runtimeEnvironment(cli),
    );
    _activeProcess = process;
    try {
      final stdoutDone = process.stdout.drain<void>();
      final stderrDone = process.stderr.drain<void>();
      final exitCode = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      if (isCancelled?.call() ?? false) {
        throw VoiceSwapCancelledException();
      }
      if (exitCode != 0) {
        throw VoiceSwapSeparationException(
          '分离进程退出码 $exitCode。请确认输入为 wav、模型完整（缺失时请重新下载）。',
        );
      }
      if (!File(outputVocalsWav).existsSync() ||
          !File(outputAccompanimentWav).existsSync()) {
        throw VoiceSwapSeparationException(
          '分离完成但未生成预期的 vocals/accompaniment 文件',
        );
      }
      return SeparationOutput(
        vocalsWav: outputVocalsWav,
        accompanimentWav: outputAccompanimentWav,
      );
    } finally {
      _activeProcess = null;
    }
  }

  /// 取消正在运行的分离。
  void cancel() {
    _activeProcess?.kill(ProcessSignal.sigterm);
  }

  Map<String, String>? _runtimeEnvironment(ResolvedSeparationCli cli) {
    if (cli.libDir == null) return _environment;
    final env = Map<String, String>.of(_environment ?? Platform.environment);
    if (_platform == EmbeddedToolPlatform.linux) {
      env['LD_LIBRARY_PATH'] = [
        cli.libDir,
        env['LD_LIBRARY_PATH'],
      ].whereType<String>().join(':');
    }
    if (_platform == EmbeddedToolPlatform.windows) {
      env['PATH'] = [cli.libDir, env['PATH']].whereType<String>().join(';');
    }
    return env;
  }

  String? _findOnPath(EmbeddedToolPlatform platform) {
    final name = platform == EmbeddedToolPlatform.windows
        ? '$_cliBaseName.exe'
        : _cliBaseName;
    final pathEnv = (_environment ?? Platform.environment)['PATH'] ?? '';
    for (final dir in pathEnv.split(Platform.isWindows ? ';' : ':')) {
      if (dir.isEmpty) continue;
      final candidate = '$dir${Platform.pathSeparator}$name';
      if (_fileExists(candidate)) return candidate;
    }
    return null;
  }

  Future<ResolvedSeparationCli?> _extractBundled(
    EmbeddedToolPlatform platform,
  ) async {
    final platformDir = platform.directoryName;
    final files = bundledRelativeFiles(platform);
    if (files.isEmpty) return null;
    final cacheKey = 'assets/bin/$platformDir/$_bundleRoot';
    final cached = _extractedPaths[cacheKey];
    if (cached != null) {
      final exe = _cliPathInDir(cached, platform);
      if (exe != null && File(exe).existsSync()) {
        return ResolvedSeparationCli(
          path: exe,
          isCustom: false,
          libDir: '$cached${Platform.pathSeparator}lib',
          isBundledAsset: true,
        );
      }
      _extractedPaths.remove(cacheKey);
    }

    final dir = Directory.systemTemp.createTempSync('hiext-sherpa-sep-');
    try {
      for (final relative in files) {
        final assetPath = 'assets/bin/$platformDir/$_bundleRoot/$relative';
        final data = await _loadAsset(assetPath);
        final target = File(
          '${dir.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}',
        );
        target.parent.createSync(recursive: true);
        target.writeAsBytesSync(data.buffer.asUint8List());
        if (!Platform.isWindows && relative.startsWith('bin/')) {
          await Process.run('chmod', ['+x', target.path]);
        }
      }
    } catch (error) {
      LogService.instance.error('提取内置分离 CLI 失败: $error', 'voice-swap');
      return null;
    }

    if (platform == EmbeddedToolPlatform.macos) {
      await _adHocSignMacOs(dir.path);
    }

    _extractedPaths[cacheKey] = dir.path;
    final exe = _cliPathInDir(dir.path, platform);
    if (exe == null) return null;
    return ResolvedSeparationCli(
      path: exe,
      isCustom: false,
      libDir: '${dir.path}${Platform.pathSeparator}lib',
      isBundledAsset: true,
    );
  }

  /// macOS 上对解压产物做 ad-hoc 重签名。
  ///
  /// sherpa-onnx 官方 universal2 二进制的 arm64 切片在较新 macOS 上会因
  /// 「Code Signature Invalid」被 dyld 直接 SIGKILL（Rosetta 不强制校验所以
  /// x86_64 可跑）。ad-hoc 签名可让 Apple Silicon 原生运行；失败时记日志，
  /// 不阻断流程（用户可改用 Rosetta 或自定义路径）。
  Future<void> _adHocSignMacOs(String dir) async {
    final targets = <String>[
      '$dir${Platform.pathSeparator}bin${Platform.pathSeparator}$_cliBaseName',
      ...Directory(
        '$dir${Platform.pathSeparator}lib',
      ).listSync().whereType<File>().map((f) => f.path),
    ];
    try {
      final result = await Process.run('codesign', [
        '--force',
        '--sign',
        '-',
        ...targets,
      ]);
      if (result.exitCode != 0) {
        LogService.instance.error(
          '内置分离 CLI ad-hoc 签名失败（${result.stderr}），'
              'Apple Silicon 原生运行可能被系统拦截',
          'voice-swap',
        );
      }
    } catch (error) {
      LogService.instance.error('内置分离 CLI ad-hoc 签名失败: $error', 'voice-swap');
    }
  }

  String? _cliPathInDir(String dir, EmbeddedToolPlatform platform) {
    final name = platform == EmbeddedToolPlatform.windows
        ? '$_cliBaseName.exe'
        : _cliBaseName;
    final candidate =
        '$dir${Platform.pathSeparator}bin${Platform.pathSeparator}$name';
    return File(candidate).existsSync() ? candidate : null;
  }

  void _validateCliName(String path) {
    final fileName = path
        .split(RegExp(r'[/\\]+'))
        .where((part) => part.isNotEmpty)
        .last
        .toLowerCase();
    final valid = {_cliBaseName, '$_cliBaseName.exe'};
    if (!valid.contains(fileName)) {
      throw VoiceSwapSeparationException(
        '配置的路径看起来不是分离 CLI：$path。请选择真实的 '
        '$_cliBaseName 可执行文件。',
      );
    }
  }

  static bool _defaultFileExists(String path) =>
      FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

  static Future<Process> _defaultProcessRunner(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
  }) => Process.start(
    executable,
    arguments,
    environment: environment,
    workingDirectory: workingDirectory,
    runInShell: false,
  );

  Process? _activeProcess;
}

/// 分离输出路径。
class SeparationOutput {
  const SeparationOutput({
    required this.vocalsWav,
    required this.accompanimentWav,
  });

  final String vocalsWav;
  final String accompanimentWav;
}

class VoiceSwapSeparationException implements Exception {
  const VoiceSwapSeparationException(this.message);

  final String message;

  @override
  String toString() => message;
}
