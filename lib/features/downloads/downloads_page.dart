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

class _TaskGroupCard extends StatefulWidget {
  const _TaskGroupCard({required this.group, required this.controller});

  final TaskGroup group;
  final DownloadController controller;

  @override
  State<_TaskGroupCard> createState() => _TaskGroupCardState();
}

class _TaskGroupCardState extends State<_TaskGroupCard> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = widget.group;
    final controller = widget.controller;
    final activeCount = group.tasks
        .where((t) => t.status == DownloadStatus.downloading)
        .length;
    final doneCount = group.tasks
        .where((t) => t.status == DownloadStatus.completed)
        .length;
    final pausedCount = group.tasks
        .where((t) => t.status == DownloadStatus.paused)
        .length;
    final allDone = doneCount == group.tasks.length;
    final totalProgress = group.tasks.isEmpty
        ? 0.0
        : group.tasks.fold<double>(0, (sum, t) => sum + t.progress) /
              group.tasks.length;

    if (allDone && !_collapsed) {
      _collapsed = true;
    }

    return SectionCard(
      title: _truncateSource(group.source),
      subtitle:
          '${group.tasks.length} 个格式'
          '${doneCount > 0 ? ' · $doneCount 已完成' : ''}'
          '${activeCount > 0 ? ' · $activeCount 下载中' : ''}'
          '${pausedCount > 0 ? ' · $pausedCount 已暂停' : ''}',
      backgroundColor: allDone ? Colors.green.withAlpha(15) : null,
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
                    color: allDone ? Colors.green : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (allDone)
                      const Text(
                        '✓',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text(
                        '${totalProgress.toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (activeCount + pausedCount > 0 || !_collapsed) ...[
            const SizedBox(height: 8),
            for (final task in group.tasks)
              _CompactTaskTile(task: task, controller: controller),
          ],
          if (allDone)
            TextButton(
              onPressed: () => setState(() => _collapsed = !_collapsed),
              child: Text(
                _collapsed ? '展开已完成任务' : '收起已完成任务',
                style: const TextStyle(fontSize: 12),
              ),
            ),
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: isCompleted
          ? BoxDecoration(
              color: Colors.green.withAlpha(12),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: isCompleted ? 10 : 0,
        vertical: isCompleted ? 6 : 0,
      ),
      child: isCompleted
          ? _buildCompletedTile(context, theme, statusInfo)
          : _buildActiveTile(context, theme, colorScheme, progress, statusInfo),
    );
  }

  Widget _buildCompletedTile(
    BuildContext context,
    ThemeData theme,
    _StatusInfo statusInfo,
  ) {
    return Row(
      children: [
        Icon(statusInfo.icon, size: 16, color: Colors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '✓ ${_taskFormatLabel(task)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.green.shade700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(25),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            '已完成',
            style: TextStyle(
              fontSize: 11,
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ..._actionsFor(task.status),
      ],
    );
  }

  Widget _buildActiveTile(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    double progress,
    _StatusInfo statusInfo,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(statusInfo.icon, size: 16, color: statusInfo.color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _taskFormatLabel(task),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            SizedBox(
              width: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (task.speed != null) ...[
                    Flexible(
                      child: Text(
                        task.speed!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
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
            ),
            const SizedBox(width: 8),
            ..._actionsFor(task.status),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
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
