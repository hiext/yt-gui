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
              subtitle: '这里会显示正在下载的内容和进度。',
              child: tasks.isEmpty
                  ? const Text('当前没有下载任务。')
                  : Column(
                      children: [
                        for (final task in tasks)
                          _DownloadTaskTile(
                            task: task,
                            controller: controller,
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

class _DownloadTaskTile extends StatelessWidget {
  const _DownloadTaskTile({required this.task, required this.controller});

  final DownloadTask task;
  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    final progress = task.progress.clamp(0, 100) / 100;

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
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Chip(label: Text(_statusLabel(task.status))),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('进度：${task.progress.toStringAsFixed(1)}%'),
                if (task.speed != null) Text('速度：${task.speed}'),
                if (task.eta != null) Text('剩余：${task.eta}'),
                if (task.errorMessage != null) Text('错误：${task.errorMessage}'),
              ],
            ),
            if (_actionsFor(task.status).isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: _actionsFor(task.status),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _actionsFor(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.downloading => [
          TextButton.icon(
            onPressed: () async => controller.pause(task.id),
            icon: const Icon(Icons.pause_outlined),
            label: const Text('暂停'),
          ),
          TextButton.icon(
            onPressed: () async => controller.cancel(task.id),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('取消'),
          ),
        ],
      DownloadStatus.paused => [
          TextButton.icon(
            onPressed: () async => controller.resume(task.id),
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('恢复'),
          ),
          TextButton.icon(
            onPressed: () async => controller.cancel(task.id),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('取消'),
          ),
        ],
      DownloadStatus.failed => [
          TextButton.icon(
            onPressed: () async => controller.retry(task.id),
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('重试'),
          ),
        ],
      _ => const [],
    };
  }

  String _statusLabel(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.idle => '等待',
      DownloadStatus.parsing => '解析中',
      DownloadStatus.ready => '已准备',
      DownloadStatus.queued => '排队中',
      DownloadStatus.downloading => '下载中',
      DownloadStatus.paused => '已暂停',
      DownloadStatus.completed => '已完成',
      DownloadStatus.failed => '失败',
      DownloadStatus.cancelled => '已取消',
    };
  }
}
