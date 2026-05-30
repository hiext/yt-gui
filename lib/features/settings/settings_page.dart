import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/controllers/settings_controller.dart';
import '../../core/models/app_models.dart';
import '../../shared/widgets/section_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _saveDirCtrl;
  late final TextEditingController _qualityCtrl;
  late final TextEditingController _ytDlpCtrl;
  late final TextEditingController _ffmpegCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _saveDirCtrl = TextEditingController(text: s.saveDirectory);
    _qualityCtrl = TextEditingController(text: s.defaultQuality);
    _ytDlpCtrl = TextEditingController(text: s.ytDlpPath ?? '');
    _ffmpegCtrl = TextEditingController(text: s.ffmpegPath ?? '');
    widget.controller.addListener(_syncFromSettings);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromSettings);
    _saveDirCtrl.dispose();
    _qualityCtrl.dispose();
    _ytDlpCtrl.dispose();
    _ffmpegCtrl.dispose();
    super.dispose();
  }

  void _syncFromSettings() {
    final s = widget.controller.settings;
    _updateCtrlIfChanged(_saveDirCtrl, s.saveDirectory);
    _updateCtrlIfChanged(_qualityCtrl, s.defaultQuality);
    _updateCtrlIfChanged(_ytDlpCtrl, s.ytDlpPath ?? '');
    _updateCtrlIfChanged(_ffmpegCtrl, s.ffmpegPath ?? '');
  }

  void _updateCtrlIfChanged(TextEditingController ctrl, String value) {
    if (ctrl.text != value) {
      ctrl.text = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final settings = widget.controller.settings;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '设置',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('恢复默认'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '保存与画质',
              subtitle: '文件保存位置和默认下载质量。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const Key('save-directory-field'),
                    controller: _saveDirCtrl,
                    decoration: InputDecoration(
                      labelText: '保存目录',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        tooltip: '浏览目录',
                        onPressed: _browseDirectory,
                      ),
                    ),
                    onChanged: widget.controller.updateSaveDirectory,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('default-quality-field'),
                    controller: _qualityCtrl,
                    decoration: const InputDecoration(
                      labelText: '默认画质 / 格式',
                      helperText:
                          '例如 best、bestvideo+bestaudio 或 yt-dlp format id',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: widget.controller.updateDefaultQuality,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '外部工具',
              subtitle: 'yt-dlp 和 ffmpeg 的路径，留空则使用应用内置版本。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const Key('yt-dlp-path-field'),
                    controller: _ytDlpCtrl,
                    decoration: InputDecoration(
                      labelText: 'yt-dlp 路径',
                      helperText: '留空时使用应用内置 yt-dlp',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        tooltip: '浏览文件',
                        onPressed: () => _browseFile(_ytDlpCtrl),
                      ),
                    ),
                    onChanged: widget.controller.updateYtDlpPath,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('ffmpeg-path-field'),
                    controller: _ffmpegCtrl,
                    decoration: InputDecoration(
                      labelText: 'ffmpeg 路径',
                      helperText: '留空时使用应用内置 ffmpeg',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        tooltip: '浏览文件',
                        onPressed: () => _browseFile(_ffmpegCtrl),
                      ),
                    ),
                    onChanged: widget.controller.updateFfmpegPath,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '下载模式',
              subtitle: '控制并行任务数量和调度策略。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<DownloadMode>(
                    key: const Key('download-mode-field'),
                    // ignore: deprecated_member_use
                    value: settings.downloadMode,
                    decoration: const InputDecoration(
                      labelText: '调度模式',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DownloadMode.serial,
                        child: Text('串行下载 — 一个一个来'),
                      ),
                      DropdownMenuItem(
                        value: DownloadMode.queue,
                        child: Text('队列下载 — 排队等待'),
                      ),
                      DropdownMenuItem(
                        value: DownloadMode.concurrent,
                        child: Text('并发下载 — 同时进行'),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        widget.controller.updateDownloadMode(mode);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _ConcurrentCountSelector(
                    value: settings.concurrentCount,
                    enabled: settings.downloadMode == DownloadMode.concurrent,
                    onChanged: widget.controller.updateConcurrentCount,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '附加选项',
              subtitle: '下载时附带字幕和封面文件。',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('下载字幕'),
                    subtitle: const Text('启动 yt-dlp 时追加 --write-subs'),
                    value: settings.downloadSubtitles,
                    onChanged: widget.controller.updateDownloadSubtitles,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('下载封面'),
                    subtitle: const Text('启动 yt-dlp 时追加 --write-thumbnail'),
                    value: settings.downloadThumbnail,
                    onChanged: widget.controller.updateDownloadThumbnail,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetToDefaults() {
    widget.controller.updateSettings(DownloadSettings.defaults);
  }

  Future<void> _browseDirectory() async {
    // Use system file picker to choose a directory
    final result = await Process.run('zenity', [
      '--file-selection',
      '--directory',
      '--title=选择保存目录',
    ]);
    if (result.exitCode == 0) {
      final path = (result.stdout as String).trim();
      if (path.isNotEmpty) {
        _saveDirCtrl.text = path;
        widget.controller.updateSaveDirectory(path);
      }
    }
  }

  Future<void> _browseFile(TextEditingController ctrl) async {
    final result = await Process.run('zenity', [
      '--file-selection',
      '--title=选择可执行文件',
    ]);
    if (result.exitCode == 0) {
      final path = (result.stdout as String).trim();
      if (path.isNotEmpty) {
        ctrl.text = path;
        if (identical(ctrl, _ytDlpCtrl)) {
          widget.controller.updateYtDlpPath(path);
        } else {
          widget.controller.updateFfmpegPath(path);
        }
      }
    }
  }
}

class _ConcurrentCountSelector extends StatelessWidget {
  const _ConcurrentCountSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: '并发数量',
        helperText: enabled ? '同时下载 $value 个任务' : '仅并发模式下生效',
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 8,
              divisions: 7,
              label: '$value',
              onChanged: enabled ? (next) => onChanged(next.round()) : null,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text('$value', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
