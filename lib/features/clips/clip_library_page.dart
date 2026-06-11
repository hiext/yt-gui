import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/controllers/post_process_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/media_asset_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/section_card.dart';

class ClipLibraryPage extends StatefulWidget {
  const ClipLibraryPage({
    super.key,
    required this.controller,
    this.mediaAssetRepository,
    this.openLocalPath,
  });

  final PostProcessController controller;
  final MediaAssetRepository? mediaAssetRepository;
  final Future<void> Function(String path)? openLocalPath;

  @override
  State<ClipLibraryPage> createState() => _ClipLibraryPageState();
}

class _ClipLibraryPageState extends State<ClipLibraryPage> {
  final _searchCtrl = TextEditingController();
  late final MediaAssetRepository _mediaAssetRepository;
  List<ClipSegment> _segments = const [];
  List<_MediaAssetView> _assetViews = const [];
  List<_MediaAssetView> _visibleAssetViews = const [];
  var _isSearching = false;
  var _isLoadingAssets = true;
  ClipExportStatus? _exportStatusFilter;

  @override
  void initState() {
    super.initState();
    _mediaAssetRepository =
        widget.mediaAssetRepository ?? MediaAssetRepository();
    _segments = widget.controller.clipSegments;
    widget.controller.addListener(_syncFromController);
    _loadMediaAssets();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _syncFromController() {
    if (_searchCtrl.text.trim().isEmpty) {
      setState(() => _segments = widget.controller.clipSegments);
    } else {
      _runSearch(_searchCtrl.text);
    }
  }

  Future<void> _loadMediaAssets() async {
    final views = <_MediaAssetView>[];
    try {
      final assets = await _mediaAssetRepository.loadMediaAssets();
      for (final asset in assets) {
        views.add(
          _MediaAssetView(
            asset: asset,
            candidates: await _mediaAssetRepository
                .loadCompatibleClipCandidates(asset.id),
            exports: await _mediaAssetRepository
                .loadCompatibleClipExportRecords(asset.id),
          ),
        );
      }
    } catch (_) {
      // Keep the legacy clip list usable even if the newer media library schema
      // is unavailable in older test databases or partially migrated installs.
    }
    if (!mounted) return;
    setState(() {
      _assetViews = views;
      _visibleAssetViews = _filterAssetViews(
        views,
        _searchCtrl.text,
        _exportStatusFilter,
      );
      _isLoadingAssets = false;
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await widget.controller.searchClipSegments(query);
    if (!mounted) return;
    setState(() {
      _segments = results;
      _visibleAssetViews = _filterAssetViews(
        _assetViews,
        query,
        _exportStatusFilter,
      );
      _isSearching = false;
    });
  }

  void _setExportStatusFilter(ClipExportStatus? status) {
    setState(() {
      _exportStatusFilter = status;
      _visibleAssetViews = _filterAssetViews(
        _assetViews,
        _searchCtrl.text,
        _exportStatusFilter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final runningCount = widget.controller.runningTasks.length;
    final queuedCount = widget.controller.queuedTasks.length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.clips, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.clipLibrary,
          subtitle: l10n.clipLibraryDesc,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('clip-search-field'),
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: l10n.clipSearch,
                  hintText: l10n.clipSearchHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.search),
                ),
                onChanged: _runSearch,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.video_library_outlined, size: 16),
                    label: Text('${_visibleAssetViews.length} media assets'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.queue_outlined, size: 16),
                    label: Text(l10n.aiQueuedTasks(queuedCount)),
                  ),
                  Chip(
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(l10n.aiRunningTasks(runningCount)),
                  ),
                  Chip(
                    avatar: const Icon(Icons.sell_outlined, size: 16),
                    label: Text(l10n.clipSegmentsCount(_segments.length)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<ClipExportStatus?>(
                  key: const Key('clip-export-status-filter'),
                  initialValue: _exportStatusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Export status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All exports')),
                    DropdownMenuItem(
                      value: ClipExportStatus.pending,
                      child: Text('pending'),
                    ),
                    DropdownMenuItem(
                      value: ClipExportStatus.cutting,
                      child: Text('cutting'),
                    ),
                    DropdownMenuItem(
                      value: ClipExportStatus.completed,
                      child: Text('completed'),
                    ),
                    DropdownMenuItem(
                      value: ClipExportStatus.failed,
                      child: Text('failed'),
                    ),
                    DropdownMenuItem(
                      value: ClipExportStatus.cancelled,
                      child: Text('cancelled'),
                    ),
                  ],
                  onChanged: _setExportStatusFilter,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingAssets)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_visibleAssetViews.isNotEmpty) ...[
          for (final view in _visibleAssetViews) ...[
            _MediaAssetCard(view: view, onOpenLocalPath: _openLocalPath),
            const SizedBox(height: 12),
          ],
        ],
        if (_visibleAssetViews.isNotEmpty) const SizedBox(height: 4),
        if (_segments.isEmpty &&
            _visibleAssetViews.isEmpty &&
            !_isLoadingAssets)
          SectionCard(
            title: l10n.noClipSegments,
            subtitle: l10n.noClipSegmentsHint,
            child: const SizedBox(height: 24),
          )
        else if (_segments.isNotEmpty)
          for (final segment in _segments) ...[
            _ClipSegmentCard(segment: segment, onAdjust: _adjustSegment),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Future<void> _openLocalPath(String path) async {
    if (path.trim().isEmpty) return;
    if (widget.openLocalPath != null) {
      await widget.openLocalPath!(path);
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      await Process.run('xdg-open', [path]);
    }
  }

  Future<void> _adjustSegment(
    ClipSegment segment, {
    int startDeltaMs = 0,
    int endDeltaMs = 0,
  }) async {
    final start = math.max(0, segment.effectiveStartMs + startDeltaMs);
    final end = math.max(start + 1000, segment.effectiveEndMs + endDeltaMs);
    await widget.controller.adjustClipTiming(
      segment.id,
      adjustedStartMs: start,
      adjustedEndMs: end,
    );
    await _runSearch(_searchCtrl.text);
  }
}

List<_MediaAssetView> _filterAssetViews(
  List<_MediaAssetView> views,
  String query,
  ClipExportStatus? exportStatus,
) {
  final needle = query.trim().toLowerCase();
  return [
    for (final view in views)
      if (_viewMatches(view, needle, exportStatus)) view,
  ];
}

bool _viewMatches(
  _MediaAssetView view,
  String needle,
  ClipExportStatus? exportStatus,
) {
  final statusMatches =
      exportStatus == null ||
      view.exports.any((record) => record.status == exportStatus);
  if (!statusMatches) return false;
  if (needle.isEmpty) return true;
  return [
    view.asset.title,
    view.asset.mediaPath,
    view.asset.sourceUrl,
    ...view.asset.metadata.values.map((value) => '$value'),
    for (final candidate in view.candidates) ...[
      candidate.title,
      candidate.summary,
      candidate.reason,
      ...candidate.tags,
      ...candidate.keywords,
    ],
    for (final record in view.exports) ...[
      record.outputPath,
      record.status.name,
      record.errorMessage ?? '',
    ],
  ].any((value) => value.toLowerCase().contains(needle));
}

class _MediaAssetView {
  const _MediaAssetView({
    required this.asset,
    required this.candidates,
    required this.exports,
  });

  final MediaAsset asset;
  final List<ClipCandidate> candidates;
  final List<ClipExportRecord> exports;
}

class _MediaAssetCard extends StatelessWidget {
  const _MediaAssetCard({required this.view, required this.onOpenLocalPath});

  final _MediaAssetView view;
  final Future<void> Function(String path) onOpenLocalPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = view.asset;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  asset.mediaType == MediaAssetType.audio
                      ? Icons.graphic_eq_outlined
                      : Icons.video_library_outlined,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    asset.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  _formatDuration(asset.durationMs),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              asset.mediaPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: Key('open-media-${asset.id}'),
                  onPressed: () => onOpenLocalPath(asset.mediaPath),
                  child: const Text('Open media'),
                ),
                OutlinedButton(
                  key: Key('open-output-${asset.id}'),
                  onPressed: view.exports.isEmpty
                      ? null
                      : () => onOpenLocalPath(
                          File(view.exports.first.outputPath).parent.path,
                        ),
                  child: const Text('Open output'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${view.candidates.length} candidates')),
                Chip(label: Text('${view.exports.length} exports')),
                Chip(label: Text(_formatBytes(asset.fileSizeBytes))),
              ],
            ),
            if (view.candidates.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final candidate in view.candidates.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _CandidateLine(candidate: candidate),
                ),
            ],
            if (view.exports.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final record in view.exports.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _ExportLine(record: record),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '0s';
    final seconds = (ms / 1000).round();
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _CandidateLine extends StatelessWidget {
  const _CandidateLine({required this.candidate});

  final ClipCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Icon(Icons.auto_awesome_motion_outlined, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            candidate.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          '${(candidate.score * 100).toStringAsFixed(0)}%',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ExportLine extends StatelessWidget {
  const _ExportLine({required this.record});

  final ClipExportRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Icon(Icons.cut_outlined, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            record.outputPath,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Text(record.status.name, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ClipSegmentCard extends StatelessWidget {
  const _ClipSegmentCard({required this.segment, required this.onAdjust});

  final ClipSegment segment;
  final Future<void> Function(
    ClipSegment segment, {
    int startDeltaMs,
    int endDeltaMs,
  })
  onAdjust;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final transcript = segment.transcripts.map((t) => t.text).join(' ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.movie_filter_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    segment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${_formatTime(segment.effectiveStartMs)} - ${_formatTime(segment.effectiveEndMs)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(segment.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              '${l10n.clipReason}: ${segment.reason}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (transcript.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${l10n.clipTranscript}: $transcript',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(
                    '${l10n.clipConfidence}: ${(segment.confidence * 100).toStringAsFixed(0)}%',
                  ),
                ),
                for (final keyword in segment.keywords.take(6))
                  Chip(label: Text(keyword)),
                for (final tag in segment.tags.take(4))
                  Chip(label: Text('#$tag')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => onAdjust(segment, startDeltaMs: -1000),
                  child: Text(l10n.clipStartEarlier),
                ),
                OutlinedButton(
                  onPressed: () => onAdjust(segment, startDeltaMs: 1000),
                  child: Text(l10n.clipStartLater),
                ),
                OutlinedButton(
                  onPressed: () => onAdjust(segment, endDeltaMs: -1000),
                  child: Text(l10n.clipEndEarlier),
                ),
                OutlinedButton(
                  onPressed: () => onAdjust(segment, endDeltaMs: 1000),
                  child: Text(l10n.clipEndLater),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
