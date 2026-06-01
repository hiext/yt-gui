import 'package:flutter/material.dart';

import '../../core/controllers/download_controller.dart';
import '../../core/models/app_models.dart';
import '../../l10n/app_localizations.dart';
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
  bool _showCookiePrompt = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  List<ResourceVariant> get _mergeVariant =>
      _variants.where((v) => v.formatId == 'bestvideo+bestaudio').toList();
  List<ResourceVariant> get _videoVariants => _variants
      .where(
        (v) =>
            v.type == ResourceType.video && v.formatId != 'bestvideo+bestaudio',
      )
      .toList();
  List<ResourceVariant> get _audioVariants =>
      _variants.where((v) => v.type == ResourceType.audio).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final host = _linkController.text.isNotEmpty
        ? Uri.tryParse(_linkController.text.trim())?.host ?? ''
        : '';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.newDownload,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.pasteLink,
          subtitle: l10n.pasteLinkDesc,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _linkController,
                decoration: InputDecoration(
                  hintText: l10n.pasteLinkHint,
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
                  label: Text(_inspecting ? l10n.parsing : l10n.parseLink),
                ),
              ),
            ],
          ),
        ),
        if (_showCookiePrompt) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.orange.withAlpha(30),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.cookie_outlined,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.cookiePrompt(host),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
                      tooltip: l10n.openDownloadDir,
                      onPressed: () => _openDownloadFolder(context),
                    ),
                ],
              ),
            ),
          if (_mergeVariant.isNotEmpty)
            _VariantGroup(
              title: l10n.recommendedQuality,
              icon: Icons.star_outlined,
              variants: _mergeVariant,
              selected: _selected,
              onToggle: _toggle,
              highlight: true,
              l10n: l10n,
            ),
          if (_videoVariants.isNotEmpty) ...[
            const SizedBox(height: 16),
            _VariantGroup(
              title: l10n.videoFormats,
              icon: Icons.videocam_outlined,
              variants: _videoVariants,
              selected: _selected,
              onToggle: _toggle,
              l10n: l10n,
            ),
          ],
          if (_audioVariants.isNotEmpty) ...[
            const SizedBox(height: 16),
            _VariantGroup(
              title: l10n.audioFormats,
              icon: Icons.headphones_outlined,
              variants: _audioVariants,
              selected: _selected,
              onToggle: _toggle,
              l10n: l10n,
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
              label: Text(
                _submitting
                    ? l10n.addingTask
                    : l10n.downloadSelectedCount(_selected.length),
              ),
            ),
          ),
        ] else if (!_inspecting && _errorText == null) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: l10n.selectFormat,
            subtitle: l10n.selectFormatDesc,
            child: Text(l10n.selectFormatHint),
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
    if (_videoId == null) return;
    widget.controller.openDownloadFolder(
      DownloadTask(
        id: '',
        title: '',
        source: '',
        status: DownloadStatus.completed,
        progress: 100,
        variants: _variants,
      ),
    );
  }

  Future<void> _inspect() async {
    final uri = _parseInputUrl();
    if (uri == null) return;
    final l10n = AppLocalizations.of(context)!;
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
          _linkController.text.trim() != uri.toString())
        return;
      final hasCookie = widget.controller.resolveCookieFile(uri) != null;
      setState(() {
        _variants = variants;
        _videoTitle = variants.isNotEmpty ? variants.first.videoTitle : null;
        _videoId = variants.isNotEmpty ? variants.first.videoId : null;
        _showCookiePrompt = !hasCookie;
      });
    } catch (error) {
      if (!mounted ||
          token != _inspectToken ||
          _linkController.text.trim() != uri.toString())
        return;
      setState(() {
        _errorText = l10n.parseFailed('$error');
      });
    } finally {
      if (mounted && token == _inspectToken)
        setState(() {
          _inspecting = false;
        });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
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
        _errorText = l10n.addTaskFailed('$error');
      });
    } finally {
      if (mounted)
        setState(() {
          _submitting = false;
        });
    }
  }

  Uri? _parseInputUrl() {
    final l10n = AppLocalizations.of(context)!;
    final raw = _linkController.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      setState(() {
        _errorText = l10n.pleaseEnterUrl;
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
      _showCookiePrompt = false;
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
    this.highlight = false,
    required this.l10n,
  });
  final String title;
  final IconData icon;
  final List<ResourceVariant> variants;
  final Set<String?> selected;
  final ValueChanged<String?> onToggle;
  final bool highlight;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '$title (${variants.length})',
      subtitle: highlight ? l10n.recommendedQualityDesc : l10n.checkToSelect,
      backgroundColor: highlight
          ? Theme.of(context).colorScheme.primaryContainer.withAlpha(60)
          : null,
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
