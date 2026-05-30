import 'package:flutter/material.dart';

import '../../core/controllers/download_controller.dart';
import '../../core/models/app_models.dart';
import '../../shared/widgets/section_card.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key, required this.controller});

  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tasks = controller.allTasks;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('下载中', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            SectionCard(
              title: '任务列表',
              subtitle: tasks.isEmpty
                  ? '粘贴链接并选择格式后，下载任务会显示在这里。'
                  : '${tasks.length} 个任务 — 下载中、等待中或已暂停。',
              child: tasks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.downloading_outlined,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '还没有下载任务',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '回到「新建下载」页粘贴链接开始',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final task in tasks)
                          _DownloadTaskTile(task: task, controller: controller),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DownloadTaskTile extends StatelessWidget {
  const _DownloadTaskTile({required this.task, required this.controller});

  final DownloadTask task;
  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = task.progress.clamp(0, 100) / 100;
    final statusInfo = _statusInfo(task.status, colorScheme);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  avatar: Icon(
                    statusInfo.icon,
                    size: 16,
                    color: statusInfo.color,
                  ),
                  label: Text(
                    statusInfo.label,
                    style: TextStyle(color: statusInfo.color, fontSize: 12),
                  ),
                  backgroundColor: statusInfo.color.withAlpha(25),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${task.progress.toStringAsFixed(0)}%',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _infoChip(Icons.speed, task.speed),
                _infoChip(Icons.timer_outlined, task.eta),
                if (task.errorMessage != null)
                  _infoChip(Icons.error_outline, task.errorMessage),
              ].whereType<Widget>().toList(),
            ),
            if (_actionsFor(task.status).isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _actionsFor(task.status),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _infoChip(IconData icon, String? text) {
    if (text == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  List<Widget> _actionsFor(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.downloading => [
        TextButton.icon(
          onPressed: () async => controller.pause(task.id),
          icon: const Icon(Icons.pause_outlined, size: 18),
          label: const Text('暂停'),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () async => controller.cancel(task.id),
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('取消'),
        ),
      ],
      DownloadStatus.paused => [
        TextButton.icon(
          onPressed: () async => controller.resume(task.id),
          icon: const Icon(Icons.play_arrow_outlined, size: 18),
          label: const Text('恢复'),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () async => controller.cancel(task.id),
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('取消'),
        ),
      ],
      DownloadStatus.failed => [
        TextButton.icon(
          onPressed: () async => controller.retry(task.id),
          icon: const Icon(Icons.refresh_outlined, size: 18),
          label: const Text('重试'),
        ),
      ],
      _ => const [],
    };
  }

  _StatusInfo _statusInfo(DownloadStatus status, ColorScheme cs) {
    return switch (status) {
      DownloadStatus.idle ||
      DownloadStatus.parsing ||
      DownloadStatus.ready ||
      DownloadStatus.queued => _StatusInfo(Icons.schedule, '等待中', cs.primary),
      DownloadStatus.downloading => _StatusInfo(
        Icons.downloading,
        '下载中',
        cs.tertiary,
      ),
      DownloadStatus.paused => _StatusInfo(
        Icons.pause_circle,
        '已暂停',
        cs.secondary,
      ),
      DownloadStatus.completed => _StatusInfo(
        Icons.check_circle,
        '已完成',
        Colors.green,
      ),
      DownloadStatus.failed => _StatusInfo(Icons.error, '失败', cs.error),
      DownloadStatus.cancelled => _StatusInfo(Icons.cancel, '已取消', cs.outline),
    };
  }
}

class _StatusInfo {
  const _StatusInfo(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
}
