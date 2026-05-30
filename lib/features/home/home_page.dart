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
  bool _inspecting = false;
  bool _submitting = false;
  int _inspectToken = 0;
  String? _errorText;
  String? _videoTitle;
  String? _videoId;
  List<ResourceVariant> _variants = const [];
  final Set<String?> _selected = {};

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  List<ResourceVariant> get _videoVariants =>
      _variants.where((v) => v.type == ResourceType.video).toList();

  List<ResourceVariant> get _audioVariants =>
      _variants.where((v) => v.type == ResourceType.audio).toList();

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
                onChanged: (_) => _clearInspectResult(),
                onSubmitted: (_) => _inspect(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _inspecting ? null : _inspect,
                  icon: _inspecting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_inspecting ? '正在解析' : '解析链接'),
                ),
              ),
            ],
          ),
        ),
        if (_variants.isNotEmpty) ...[
          const SizedBox(height: 16),
          if (_videoTitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.movie_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _videoTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (_videoId != null)
                    IconButton(
                      icon: const Icon(Icons.folder_open_outlined, size: 20),
                      tooltip: '打开下载目录',
                      onPressed: () => _openDownloadFolder(context),
                    ),
                ],
              ),
            ),
          if (_videoVariants.isNotEmpty)
            _VariantGroup(
              title: '视频格式',
              icon: Icons.videocam_outlined,
              variants: _videoVariants,
              selected: _selected,
              onToggle: _toggle,
            ),
          if (_audioVariants.isNotEmpty) ...[
            const SizedBox(height: 16),
            _VariantGroup(
              title: '音频格式',
              icon: Icons.headphones_outlined,
              variants: _audioVariants,
              selected: _selected,
              onToggle: _toggle,
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submitting || _selected.isEmpty ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_submitting ? '正在加入任务' : '下载所选 ($_selectedCount 项)'),
            ),
          ),
        ] else if (!_inspecting && _errorText == null) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: '选择格式',
            subtitle: '解析成功后在这里选择要下载的格式。',
            child: const Text('请先粘贴链接并解析可下载格式。'),
          ),
        ],
      ],
    );
  }

  int get _selectedCount => _selected.length;

  void _toggle(String? formatId) {
    setState(() {
      if (_selected.contains(formatId)) {
        _selected.remove(formatId);
      } else {
        _selected.add(formatId);
      }
    });
  }

  void _openDownloadFolder(BuildContext context) {
    // No-op: folder opening is handled after download completes in downloads/history page
  }

  Future<void> _inspect() async {
    final uri = _parseInputUrl();
    if (uri == null) return;

    final token = ++_inspectToken;

    setState(() {
      _inspecting = true;
      _errorText = null;
      _variants = const [];
      _selected.clear();
      _videoTitle = null;
      _videoId = null;
    });

    try {
      final variants = await widget.controller.inspect(uri);
      if (!mounted ||
          token != _inspectToken ||
          _linkController.text.trim() != uri.toString()) {
        return;
      }
      setState(() {
        _variants = variants;
        _videoTitle = variants.isNotEmpty ? variants.first.videoTitle : null;
        _videoId = variants.isNotEmpty ? variants.first.videoId : null;
      });
    } catch (error) {
      if (!mounted ||
          token != _inspectToken ||
          _linkController.text.trim() != uri.toString()) {
        return;
      }
      setState(() {
        _errorText = '解析失败：$error';
      });
    } finally {
      if (mounted && token == _inspectToken) {
        setState(() {
          _inspecting = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final selectedVariants = _variants
        .where((v) => _selected.contains(v.formatId))
        .toList();
    if (selectedVariants.isEmpty) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await widget.controller.queueDownloads(
        url: Uri.parse(_linkController.text.trim()),
        variants: selectedVariants,
        title: _videoTitle,
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

  Uri? _parseInputUrl() {
    final raw = _linkController.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      setState(() {
        _errorText = '请输入完整链接，例如 https://...';
      });
      return null;
    }
    return uri;
  }

  void _clearInspectResult() {
    if (!_inspecting && _variants.isEmpty && _errorText == null) return;
    setState(() {
      _inspectToken += 1;
      _inspecting = false;
      _variants = const [];
      _selected.clear();
      _videoTitle = null;
      _videoId = null;
      _errorText = null;
    });
  }
}

class _VariantGroup extends StatelessWidget {
  const _VariantGroup({
    required this.title,
    required this.icon,
    required this.variants,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final IconData icon;
  final List<ResourceVariant> variants;
  final Set<String?> selected;
  final ValueChanged<String?> onToggle;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '$title (${variants.length})',
      subtitle: '勾选要下载的格式，可以多选。',
      child: Column(
        children: [
          for (final variant in variants)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected.contains(variant.formatId),
              onChanged: (_) => onToggle(variant.formatId),
              title: Text(variant.label),
              subtitle: Text(
                variant.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              secondary: variant.isRecommended
                  ? const Icon(Icons.star, color: Colors.amber, size: 20)
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ),
    );
  }
}
