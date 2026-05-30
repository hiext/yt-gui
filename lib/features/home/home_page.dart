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
  Uri? _inspectedUrl;
  List<ResourceVariant> _variants = const [];
  ResourceVariant? _selectedVariant;

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
        const SizedBox(height: 16),
        SectionCard(
          title: '选择格式',
          subtitle: '解析成功后选择一个格式再开始下载。',
          child: _variants.isEmpty
              ? const Text('请先粘贴链接并解析可下载格式。')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._variants.map(
                      (variant) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          identical(variant, _selectedVariant)
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(variant.label),
                        subtitle: Text(variant.description),
                        onTap: () {
                          setState(() {
                            _selectedVariant = variant;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _submitting || _selectedVariant == null
                            ? null
                            : _submit,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download),
                        label: Text(_submitting ? '正在加入任务' : '下载所选格式'),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _inspect() async {
    final uri = _parseInputUrl();
    if (uri == null) {
      return;
    }

    final token = ++_inspectToken;

    setState(() {
      _inspecting = true;
      _errorText = null;
      _variants = const [];
      _selectedVariant = null;
      _inspectedUrl = null;
    });

    try {
      final variants = await widget.controller.inspect(uri);
      if (!mounted ||
          token != _inspectToken ||
          _linkController.text.trim() != uri.toString()) {
        return;
      }
      setState(() {
        _inspectedUrl = uri;
        _variants = variants;
        _selectedVariant = variants.isEmpty ? null : variants.first;
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
    final url = _inspectedUrl;
    final variant = _selectedVariant;
    if (url == null || variant == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await widget.controller.queueDownload(url: url, variant: variant);
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
    if (!_inspecting && _variants.isEmpty && _errorText == null) {
      return;
    }

    setState(() {
      _inspectToken += 1;
      _inspecting = false;
      _variants = const [];
      _selectedVariant = null;
      _inspectedUrl = null;
      _errorText = null;
    });
  }
}
