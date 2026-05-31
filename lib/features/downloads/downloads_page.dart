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
        final groups = controller.taskGroups;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('下载中', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            if (groups.isEmpty)
              SectionCard(
                title: '任务列表',
                subtitle: '粘贴链接并选择格式后，下载任务会显示在这里。',
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.downloading_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                ),
              )
            else
              for (final group in groups) ...[
                _TaskGroupCard(group: group, controller: controller),
                const SizedBox(height: 16),
              ],
          ],
        );
      },
    );
  }
}

class _TaskGroupCard extends StatelessWidget {
  const _TaskGroupCard({required this.group, required this.controller});

  final TaskGroup group;
  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCount = group.tasks
        .where((t) => t.status == DownloadStatus.downloading)
        .length;
    final doneCount = group.tasks
        .where((t) => t.status == DownloadStatus.completed)
        .length;
    final pausedCount = group.tasks
        .where((t) => t.status == DownloadStatus.paused)
        .length;
    final totalProgress = group.tasks.isEmpty
        ? 0.0
        : group.tasks.fold<double>(0, (sum, t) => sum + t.progress) /
              group.tasks.length;

    return SectionCard(
      title: _truncateSource(group.source),
      subtitle:
          '${group.tasks.length} 个格式'
          '${doneCount > 0 ? ' · $doneCount 已完成' : ''}'
          '${activeCount > 0 ? ' · $activeCount 下载中' : ''}'
          '${pausedCount > 0 ? ' · $pausedCount 已暂停' : ''}',
      child: Column(
        children: [
          // Group progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalProgress / 100,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: Text(
                  '${totalProgress.toStringAsFixed(0)}%',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Individual task tiles
          for (final task in group.tasks)
            _CompactTaskTile(task: task, controller: controller),
        ],
      ),
    );
  }

  String _truncateSource(String source) {
    if (source.length <= 80) return source;
    return '${source.substring(0, 77)}...';
  }
}

class _CompactTaskTile extends StatelessWidget {
  const _CompactTaskTile({required this.task, required this.controller});

  final DownloadTask task;
  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = task.progress.clamp(0, 100) / 100;
    final statusInfo = _statusInfo(task.status, colorScheme);

    final isCompleted = task.status == DownloadStatus.completed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status icon
          Icon(statusInfo.icon, size: 16, color: statusInfo.color),
          const SizedBox(width: 10),
          // Label + progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCompleted
                      ? '✓ ${_taskFormatLabel(task)}'
                      : _taskFormatLabel(task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isCompleted ? Colors.green : null,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${task.progress.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusInfo.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Speed info
          if (task.speed != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 60),
              child: Text(
                task.speed!,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Actions
          ..._actionsFor(task.status),
        ],
      ),
    );
  }

  String _taskFormatLabel(DownloadTask task) {
    final variant = task.variants.isNotEmpty ? task.variants.first : null;
    if (variant == null) return task.title;
    final type = variant.type == ResourceType.video ? '视频' : '音频';
    return '$type  ${variant.label}';
  }

  List<Widget> _actionsFor(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.downloading => [
        GestureDetector(
          onTap: () => controller.pause(task.id),
          child: const Icon(Icons.pause_outlined, size: 18),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => controller.cancel(task.id),
          child: const Icon(Icons.cancel_outlined, size: 18),
        ),
      ],
      DownloadStatus.paused => [
        GestureDetector(
          onTap: () => controller.resume(task.id),
          child: const Icon(Icons.play_arrow_outlined, size: 18),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => controller.cancel(task.id),
          child: const Icon(Icons.cancel_outlined, size: 18),
        ),
      ],
      DownloadStatus.failed => [
        GestureDetector(
          onTap: () => controller.retry(task.id),
          child: const Icon(Icons.refresh_outlined, size: 18),
        ),
      ],
      DownloadStatus.completed => [
        GestureDetector(
          onTap: () => controller.openDownloadFolder(task),
          child: const Icon(Icons.folder_open_outlined, size: 18),
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
        '',
        cs.tertiary,
      ),
      DownloadStatus.paused => _StatusInfo(
        Icons.pause_circle,
        '',
        cs.secondary,
      ),
      DownloadStatus.completed => _StatusInfo(
        Icons.check_circle,
        '',
        Colors.green,
      ),
      DownloadStatus.failed => _StatusInfo(Icons.error, '', cs.error),
      DownloadStatus.cancelled => _StatusInfo(Icons.cancel, '', cs.outline),
    };
  }
}

class _StatusInfo {
  const _StatusInfo(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
}
