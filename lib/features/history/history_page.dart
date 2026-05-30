import 'package:flutter/material.dart';

import '../../core/controllers/download_controller.dart';
import '../../core/models/app_models.dart';
import '../../shared/widgets/section_card.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});

  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final completed = controller.completedTasks;
        final failed = controller.failedTasks;
        final cancelled = controller.cancelledTasks;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('历史记录', style: Theme.of(context).textTheme.headlineMedium),
            if (completed.isEmpty && failed.isEmpty && cancelled.isEmpty) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: '没有历史',
                subtitle: '完成或取消下载后，记录会显示在这里。',
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '还没有历史记录',
                          style: Theme.of(context).textTheme.bodyLarge
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
              ),
            ] else ...[
              const SizedBox(height: 16),
              _TaskSection(
                title: '已完成任务',
                subtitle: '下载成功的任务。',
                tasks: completed,
                controller: controller,
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _TaskSection(
                title: '失败任务',
                subtitle: '可以从这里重新加入下载队列。',
                tasks: failed,
                controller: controller,
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              _TaskSection(
                title: '已取消任务',
                subtitle: '用户取消的任务。',
                tasks: cancelled,
                controller: controller,
                icon: Icons.cancel_outlined,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.subtitle,
    required this.tasks,
    required this.controller,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final List<DownloadTask> tasks;
  final DownloadController controller;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '$title (${tasks.length})',
      subtitle: tasks.isEmpty ? '暂无记录' : subtitle,
      child: tasks.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Icon(icon, color: color.withAlpha(100), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '此分类暂无记录',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final task in tasks)
                  _HistoryTaskTile(
                    task: task,
                    controller: controller,
                    color: color,
                    icon: icon,
                  ),
              ],
            ),
    );
  }
}

class _HistoryTaskTile extends StatelessWidget {
  const _HistoryTaskTile({
    required this.task,
    required this.controller,
    required this.color,
    required this.icon,
  });

  final DownloadTask task;
  final DownloadController controller;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
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
                  label: Text(
                    _statusLabel(task.status),
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  side: BorderSide.none,
                  backgroundColor: color.withAlpha(25),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _truncateSource(task.source),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (task.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                task.errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (task.status == DownloadStatus.failed) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async => controller.retry(task.id),
                  icon: const Icon(Icons.refresh_outlined, size: 18),
                  label: const Text('重试'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _truncateSource(String source) {
    if (source.length <= 60) return source;
    return '${source.substring(0, 57)}...';
  }

  String _statusLabel(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.completed => '已完成',
      DownloadStatus.failed => '失败',
      DownloadStatus.cancelled => '已取消',
      _ => '历史',
    };
  }
}
