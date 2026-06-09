import 'dart:io';

class PlatformFilePicker {
  const PlatformFilePicker();

  Future<String?> pickDirectory({required String title}) async {
    if (Platform.isMacOS) {
      return _runMacOsPicker(
        'POSIX path of (choose folder with prompt "${_escapeAppleScript(title)}")',
      );
    }
    if (Platform.isWindows) {
      return _runWindowsPicker(_windowsFolderDialog(title));
    }
    return _runZenity(['--file-selection', '--directory', '--title=$title']);
  }

  Future<String?> pickFile({required String title}) async {
    if (Platform.isMacOS) {
      return _runMacOsPicker(
        'POSIX path of (choose file with prompt "${_escapeAppleScript(title)}")',
      );
    }
    if (Platform.isWindows) {
      return _runWindowsPicker(_windowsOpenFileDialog(title));
    }
    return _runZenity(['--file-selection', '--title=$title']);
  }

  Future<String?> _runMacOsPicker(String script) async {
    final result = await Process.run('osascript', ['-e', script]);
    return _pathFromResult(result);
  }

  Future<String?> _runWindowsPicker(String command) async {
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-STA',
      '-Command',
      command,
    ]);
    return _pathFromResult(result);
  }

  Future<String?> _runZenity(List<String> args) async {
    final result = await Process.run('zenity', args);
    return _pathFromResult(result);
  }

  String? _pathFromResult(ProcessResult result) {
    if (result.exitCode != 0) return null;
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  }

  String _escapeAppleScript(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }

  String _escapePowerShell(String value) {
    return value.replaceAll("'", "''");
  }

  String _windowsOpenFileDialog(String title) {
    final escapedTitle = _escapePowerShell(title);
    return '''
Add-Type -AssemblyName System.Windows.Forms;
\$dialog = New-Object System.Windows.Forms.OpenFileDialog;
\$dialog.Title = '$escapedTitle';
\$dialog.Filter = 'Cookie files (*.txt)|*.txt|All files (*.*)|*.*';
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::WriteLine(\$dialog.FileName)
}
''';
  }

  String _windowsFolderDialog(String title) {
    final escapedTitle = _escapePowerShell(title);
    return '''
Add-Type -AssemblyName System.Windows.Forms;
\$dialog = New-Object System.Windows.Forms.FolderBrowserDialog;
\$dialog.Description = '$escapedTitle';
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::WriteLine(\$dialog.SelectedPath)
}
''';
  }
}
