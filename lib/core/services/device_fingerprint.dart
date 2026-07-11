import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Generates a stable, privacy-preserving device fingerprint used for license
/// device binding. Reads read-only machine identifiers per platform and hashes
/// them with an app salt; the raw machine id never leaves the device.
class DeviceFingerprint {
  const DeviceFingerprint({ProcessRunner? processRunner})
      : _run = processRunner ?? _defaultRun;

  static const _salt = 'hiext-yt-gui-v1';
  final ProcessRunner _run;

  Future<String> compute() async {
    final raw = await _rawMachineId();
    final digest = sha256.convert(utf8.encode('$raw|$_salt'));
    return digest.toString().substring(0, 32);
  }

  Future<String> _rawMachineId() async {
    try {
      if (Platform.isLinux) return await _linuxId();
      if (Platform.isMacOS) return await _macosId();
      if (Platform.isWindows) return await _windowsId();
    } catch (_) {
      // fall through to hostname fallback
    }
    return Platform.localHostname;
  }

  Future<String> _linuxId() async {
    for (final path in ['/etc/machine-id', '/var/lib/dbus/machine-id']) {
      final file = File(path);
      if (file.existsSync()) {
        final id = (await file.readAsString()).trim();
        if (id.isNotEmpty) return id;
      }
    }
    return Platform.localHostname;
  }

  Future<String> _macosId() async {
    final result = await _run('ioreg', [
      '-rd1',
      '-c',
      'IOPlatformExpertDevice',
    ]);
    final match = RegExp(r'"IOPlatformUUID"\s*=\s*"([^"]+)"')
        .firstMatch(result);
    return match?.group(1) ?? Platform.localHostname;
  }

  Future<String> _windowsId() async {
    final result = await _run('reg', [
      'query',
      r'HKLM\SOFTWARE\Microsoft\Cryptography',
      '/v',
      'MachineGuid',
    ]);
    final match = RegExp(r'MachineGuid\s+REG_SZ\s+([0-9a-fA-F-]+)')
        .firstMatch(result);
    return match?.group(1) ?? Platform.localHostname;
  }
}

typedef ProcessRunner = Future<String> Function(
  String executable,
  List<String> arguments,
);

Future<String> _defaultRun(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  return '${result.stdout}';
}
