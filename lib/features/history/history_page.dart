import 'package:flutter/material.dart';

import '../../shared/widgets/section_card.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('历史记录', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const SectionCard(
          title: '已完成任务',
          subtitle: '历史下载会在这里保留，方便打开文件夹或重新下载。',
          child: Text('还没有历史记录。'),
        ),
      ],
    );
  }
}
