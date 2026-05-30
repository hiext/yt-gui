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
          subtitle: '下载视频只需要三步。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Step(
                number: '1',
                title: '粘贴链接',
                description: '在「新建下载」页面粘贴视频网页地址（支持 YouTube、Bilibili 等数千个网站）。',
              ),
              _Step(
                number: '2',
                title: '选择格式',
                description: '点击「解析链接」查看可选格式，选一个合适的画质或音频格式。',
              ),
              _Step(
                number: '3',
                title: '开始下载',
                description: '点击「下载所选格式」，任务会加入队列并自动开始。',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionCard(
          title: '下载模式说明',
          subtitle: '在「设置」页面可以切换三种模式。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModeHelp(
                title: '串行下载',
                description: '一次只下载一个任务，上一个完成后自动开始下一个。适合带宽有限的场景。',
              ),
              SizedBox(height: 12),
              _ModeHelp(
                title: '队列下载',
                description: '手动管理下载次序。新任务加入队列尾部，完成后不会自动开始下一个。',
              ),
              SizedBox(height: 12),
              _ModeHelp(
                title: '并发下载',
                description: '同时下载多个任务。在「设置」中可调整并发数量（1-8），适合带宽充裕的场景。',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionCard(
          title: '工具配置',
          subtitle: '应用内置了 yt-dlp 和 ffmpeg，也可以使用系统安装的版本。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Faq(
                question: '如何使用自己安装的 yt-dlp？',
                answer:
                    '在「设置」页面的「yt-dlp 路径」中输入完整路径（例如 /usr/bin/yt-dlp），留空则使用应用内置版本。',
              ),
              SizedBox(height: 12),
              _Faq(
                question: 'ffmpeg 有什么用？',
                answer:
                    'yt-dlp 使用 ffmpeg 进行格式转换和合并（例如将分离的视频和音频合并为单个文件）。缺少 ffmpeg 时部分功能可能不可用。',
              ),
              SizedBox(height: 12),
              _Faq(
                question: '支持哪些视频网站？',
                answer:
                    'yt-dlp 支持数千个网站，包括 YouTube、Bilibili、Twitter/X、TikTok、Instagram 等。完整列表可在 yt-dlp 官方文档查阅。',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionCard(
          title: '断点续传',
          subtitle: '下载中断后可以继续，不需要从头开始。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Faq(
                question: '暂停后恢复会丢失进度吗？',
                answer: '不会。暂停时 yt-dlp 会保留已下载的部分文件（.part 和 .ytdl），恢复后会从断点继续。',
              ),
              SizedBox(height: 12),
              _Faq(
                question: '应用崩溃后能恢复吗？',
                answer:
                    '可以。重新启动应用后，之前的 .part 文件仍然存在。只需在历史记录中对失败任务点击「重试」，yt-dlp 会自动检测并续传。',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            child: Text(
              number,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeHelp extends StatelessWidget {
  const _ModeHelp({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.arrow_right, size: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          answer,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
