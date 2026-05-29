import 'package:flutter/material.dart';

import '../../shared/widgets/section_card.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('帮助', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const SectionCard(
          title: '三步上手',
          subtitle: '复制链接、粘贴、开始下载。',
          child: Text('这里会放新手引导和常见问题。'),
        ),
      ],
    );
  }
}
