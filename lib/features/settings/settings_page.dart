import 'package:flutter/material.dart';

import '../../core/controllers/settings_controller.dart';
import '../../core/models/app_models.dart';
import '../../shared/widgets/section_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('设置', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            SectionCard(
              title: '常用设置',
              subtitle: '保存路径、默认画质、下载模式等。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const Key('save-directory-field'),
                    initialValue: settings.saveDirectory,
                    decoration: const InputDecoration(
                      labelText: '保存目录',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: controller.updateSaveDirectory,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('default-quality-field'),
                    initialValue: settings.defaultQuality,
                    decoration: const InputDecoration(
                      labelText: '默认画质 / 格式',
                      helperText:
                          '例如 best、bestvideo+bestaudio 或 yt-dlp format id',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: controller.updateDefaultQuality,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<DownloadMode>(
                    key: const Key('download-mode-field'),
                    initialValue: settings.downloadMode,
                    decoration: const InputDecoration(
                      labelText: '下载模式',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DownloadMode.serial,
                        child: Text('串行下载'),
                      ),
                      DropdownMenuItem(
                        value: DownloadMode.queue,
                        child: Text('队列下载'),
                      ),
                      DropdownMenuItem(
                        value: DownloadMode.concurrent,
                        child: Text('并发下载'),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        controller.updateDownloadMode(mode);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _ConcurrentCountSelector(
                    value: settings.concurrentCount,
                    enabled: settings.downloadMode == DownloadMode.concurrent,
                    onChanged: controller.updateConcurrentCount,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('下载字幕'),
                    subtitle: const Text('启动 yt-dlp 时追加 --write-subs'),
                    value: settings.downloadSubtitles,
                    onChanged: controller.updateDownloadSubtitles,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('下载封面'),
                    subtitle: const Text('启动 yt-dlp 时追加 --write-thumbnail'),
                    value: settings.downloadThumbnail,
                    onChanged: controller.updateDownloadThumbnail,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
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
        helperText: enabled ? '最多同时下载 $value 个任务' : '仅并发下载模式生效',
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
          SizedBox(width: 40, child: Text('$value')),
        ],
      ),
    );
  }
}
