import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/controllers/download_controller.dart';
import '../../core/models/app_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/section_card.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});

  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final completed = controller.completedTasks;
        final failed = controller.failedTasks;
        final cancelled = controller.cancelledTasks;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(l10n.history, style: Theme.of(context).textTheme.headlineMedium),
            if (completed.isEmpty && failed.isEmpty && cancelled.isEmpty) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: l10n.noHistory,
                subtitle: l10n.noHistoryDesc,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(l10n.noHistoryYet,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                )),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              _TaskSection(
                title: l10n.completedTasks,
                subtitle: l10n.completedTasksDesc,
                tasks: completed,
                controller: controller,
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _TaskSection(
                title: l10n.failedTasks,
                subtitle: l10n.failedTasksDesc,
                tasks: failed,
                controller: controller,
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              _TaskSection(
                title: l10n.cancelledTasks,
                subtitle: l10n.cancelledTasksDesc,
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
    required this.title, required this.subtitle, required this.tasks,
    required this.controller, required this.icon, required this.color,
  });

  final String title;
  final String subtitle;
  final List<DownloadTask> tasks;
  final DownloadController controller;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SectionCard(
      title: '$title (${tasks.length})',
      subtitle: tasks.isEmpty ? l10n.noRecordsHere : subtitle,
      child: tasks.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Icon(icon, color: color.withAlpha(100), size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.noRecordsHere,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                ],
              ),
            )
          : Column(children: [
              for (final task in tasks)
                _HistoryTaskTile(task: task, controller: controller, color: color, icon: icon),
            ]),
    );
  }
}

class _HistoryTaskTile extends StatelessWidget {
  const _HistoryTaskTile({
    required this.task, required this.controller,
    required this.color, required this.icon,
  });

  final DownloadTask task;
  final DownloadController controller;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall)),
              const SizedBox(width: 12),
              Chip(
                label: Text(_statusLabel(task.status, l10n), style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                side: BorderSide.none,
                backgroundColor: color.withAlpha(25),
              ),
            ]),
            const SizedBox(height: 8),
            Text(_truncateSource(task.source), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (task.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(task.errorMessage!, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (task.status == DownloadStatus.failed)
                TextButton.icon(
                  onPressed: () async => controller.retry(task.id),
                  icon: const Icon(Icons.refresh_outlined, size: 16),
                  label: Text(l10n.retry),
                ),
              if (task.status == DownloadStatus.completed)
                TextButton.icon(
                  onPressed: () async => controller.openDownloadFolder(task),
                  icon: const Icon(Icons.folder_open_outlined, size: 16),
                  label: Text(l10n.openFolder),
                ),
              TextButton.icon(
                onPressed: () => _confirmDelete(context, controller, task, l10n),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(l10n.delete),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _truncateSource(String source) {
    if (source.length <= 60) return source;
    return '${source.substring(0, 57)}...';
  }

  String _statusLabel(DownloadStatus status, AppLocalizations l10n) {
    return switch (status) {
      DownloadStatus.completed => l10n.completedTasks,
      DownloadStatus.failed => l10n.failedTasks,
      DownloadStatus.cancelled => l10n.cancelledTasks,
      _ => '?',
    };
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  DownloadController controller,
  DownloadTask task,
  AppLocalizations l10n,
) async {
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.confirmDelete),
      content: Text(l10n.confirmDeleteContent(task.title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'record'),
          child: Text(l10n.deleteRecord),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, 'files'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          child: Text(l10n.deleteWithFiles),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
      ],
    ),
  );

  if (result == null) return;
  controller.deleteFromHistory(task.id);

  if (result == 'files') {
    final path = controller.getDownloadPath(task);
    final dir = Directory(path);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
