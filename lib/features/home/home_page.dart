import 'package:flutter/material.dart';

import '../../core/controllers/download_controller.dart';
import '../../core/models/app_models.dart';
import '../../shared/widgets/section_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onShowDownloads,
  });

  final DownloadController controller;
  final VoidCallback onShowDownloads;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _linkController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('新建下载', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        SectionCard(
          title: '粘贴链接',
          subtitle: '把视频页面地址放进来，我们帮你找可下载内容。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _linkController,
                decoration: InputDecoration(
                  hintText: '在这里粘贴视频链接',
                  border: const OutlineInputBorder(),
                  errorText: _errorText,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_submitting ? '正在加入任务' : '开始下载推荐方案'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionCard(
          title: '推荐方案',
          subtitle: '默认先给你最适合大多数人的下载方式。',
          child: Text('当前会使用 yt-dlp 的 best 推荐格式，后续解析成功后可扩展为手动选择格式。'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final raw = _linkController.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      setState(() {
        _errorText = '请输入完整链接，例如 https://...';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await widget.controller.queueDownload(
        url: uri,
        variant: const ResourceVariant(
          label: '推荐',
          description: '使用 yt-dlp 推荐格式',
          isRecommended: true,
          formatId: 'best',
        ),
      );
      widget.onShowDownloads();
    } catch (error) {
      setState(() {
        _errorText = '加入任务失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}
