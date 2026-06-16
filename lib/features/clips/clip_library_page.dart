import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/controllers/post_process_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/clip_preview_service.dart';
import '../../core/services/local_clip_worker_service.dart';
import '../../core/services/media_asset_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/section_card.dart';

typedef ClipActionCallback =
    Future<void> Function(
      MediaAsset asset,
      ClipCandidate candidate,
      ClipExportRecord? export,
    );
typedef ClipDeleteCallback = Future<void> Function(ClipCandidate candidate);
typedef AssetActionCallback = Future<void> Function(MediaAsset asset);

class ClipLibraryPage extends StatefulWidget {
  const ClipLibraryPage({
    super.key,
    required this.controller,
    this.mediaAssetRepository,
    this.resolveClipPreviewPath,
    this.localClipWorkerService,
    this.previewClip,
    this.regenerateClip,
    this.deleteClipCandidate,
    this.clearClipResults,
    this.openLocalPath,
  });

  final PostProcessController controller;
  final MediaAssetRepository? mediaAssetRepository;
  final ClipPreviewPathResolver? resolveClipPreviewPath;
  final LocalClipWorkerService? localClipWorkerService;
  final ClipActionCallback? previewClip;
  final ClipActionCallback? regenerateClip;
  final ClipDeleteCallback? deleteClipCandidate;
  final AssetActionCallback? clearClipResults;
  final Future<void> Function(String path)? openLocalPath;

  @override
  State<ClipLibraryPage> createState() => _ClipLibraryPageState();
}

class _ClipLibraryPageState extends State<ClipLibraryPage> {
  final _searchCtrl = TextEditingController();
  late final MediaAssetRepository _mediaAssetRepository;
  late final ClipPreviewPathResolver _resolveClipPreviewPath;
  late final LocalClipWorkerService _localClipWorkerService;
  List<ClipSegment> _segments = const [];
  List<_MediaAssetView> _assetViews = const [];
  List<_MediaAssetView> _visibleAssetViews = const [];
  var _isSearching = false;
  var _isLoadingAssets = true;
  ClipExportStatus? _exportStatusFilter;
  _ClipQualityFilter _qualityFilter = _ClipQualityFilter.all;

  @override
  void initState() {
    super.initState();
    _mediaAssetRepository =
        widget.mediaAssetRepository ?? MediaAssetRepository();
    _localClipWorkerService =
        widget.localClipWorkerService ??
        LocalClipWorkerService(repository: _mediaAssetRepository);
    final previewService = ClipPreviewService();
    _resolveClipPreviewPath =
        widget.resolveClipPreviewPath ??
        (asset, candidate, export) => previewService.resolvePreviewPath(
          asset: asset,
          candidate: candidate,
          export: export,
        );
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
        final candidates = await _mediaAssetRepository
            .loadCompatibleClipCandidates(asset.id);
        final exports = await _mediaAssetRepository
            .loadCompatibleClipExportRecords(asset.id);
        views.add(
          _MediaAssetView(
            asset: asset,
            candidates: candidates,
            exports: exports,
            galleryItems: await _buildGalleryItems(asset, candidates, exports),
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
        _qualityFilter,
      );
      _isLoadingAssets = false;
    });
  }

  Future<List<_ClipGalleryItem>> _buildGalleryItems(
    MediaAsset asset,
    List<ClipCandidate> candidates,
    List<ClipExportRecord> exports,
  ) async {
    final exportsByCandidateId = <String, ClipExportRecord>{};
    for (final record in exports) {
      final candidateId = record.candidateId;
      if (candidateId == null) continue;
      exportsByCandidateId.putIfAbsent(candidateId, () => record);
    }
    final usedExportIds = <String>{};
    final items = <_ClipGalleryItem>[];
    for (final candidate in candidates) {
      final export = exportsByCandidateId[candidate.id];
      if (export != null) usedExportIds.add(export.id);
      items.add(
        _ClipGalleryItem(
          candidate: candidate,
          export: export,
          previewPath: await _resolveClipPreviewPath(asset, candidate, export),
        ),
      );
    }
    for (final export in exports) {
      if (usedExportIds.contains(export.id)) continue;
      final candidate = ClipCandidate(
        id: 'export:${export.id}',
        mediaAssetId: asset.id,
        startMs: export.startMs,
        endMs: export.endMs,
        title: File(export.outputPath).uri.pathSegments.last,
        summary: export.outputPath,
        score: export.status == ClipExportStatus.completed ? 1 : 0,
        source: ClipCandidateSource.local,
        reason: export.errorMessage ?? 'exported clip',
      );
      items.add(
        _ClipGalleryItem(
          candidate: candidate,
          export: export,
          previewPath: await _resolveClipPreviewPath(asset, candidate, export),
        ),
      );
    }
    return items;
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
        _qualityFilter,
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
        _qualityFilter,
      );
    });
  }

  void _setQualityFilter(_ClipQualityFilter? filter) {
    setState(() {
      _qualityFilter = filter ?? _ClipQualityFilter.all;
      _visibleAssetViews = _filterAssetViews(
        _assetViews,
        _searchCtrl.text,
        _exportStatusFilter,
        _qualityFilter,
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
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
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
                        DropdownMenuItem(
                          value: null,
                          child: Text('All exports'),
                        ),
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
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<_ClipQualityFilter>(
                      key: const Key('clip-quality-filter'),
                      initialValue: _qualityFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Clip quality',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _ClipQualityFilter.all,
                          child: Text('All quality'),
                        ),
                        DropdownMenuItem(
                          value: _ClipQualityFilter.highScore,
                          child: Text('High score'),
                        ),
                        DropdownMenuItem(
                          value: _ClipQualityFilter.needsReview,
                          child: Text('Needs review'),
                        ),
                      ],
                      onChanged: _setQualityFilter,
                    ),
                  ),
                ],
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
            _MediaAssetCard(
              view: view,
              onOpenLocalPath: _openLocalPath,
              onPreviewClip: _previewClip,
              onRegenerateClip: _regenerateClip,
              onDeleteClip: _deleteClipCandidate,
              onClearResults: _clearClipResults,
            ),
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

  Future<void> _previewClip(
    MediaAsset asset,
    ClipCandidate candidate,
    ClipExportRecord? export,
  ) async {
    if (widget.previewClip != null) {
      await widget.previewClip!(asset, candidate, export);
      return;
    }
    final path = export?.outputPath.trim();
    if (path != null && path.isNotEmpty) {
      await _openLocalPath(path);
    }
  }

  Future<void> _regenerateClip(
    MediaAsset asset,
    ClipCandidate candidate,
    ClipExportRecord? export,
  ) async {
    if (widget.regenerateClip != null) {
      await widget.regenerateClip!(asset, candidate, export);
    } else {
      await _localClipWorkerService.exportCandidate(
        asset: asset,
        candidate: candidate,
        settings: widget.controller.settingsProvider(),
      );
    }
    await _loadMediaAssets();
  }

  Future<void> _deleteClipCandidate(ClipCandidate candidate) async {
    if (widget.deleteClipCandidate != null) {
      await widget.deleteClipCandidate!(candidate);
    } else {
      await _mediaAssetRepository.deleteClipCandidate(candidate.id);
    }
    await _loadMediaAssets();
  }

  Future<void> _clearClipResults(MediaAsset asset) async {
    if (widget.clearClipResults != null) {
      await widget.clearClipResults!(asset);
    } else {
      await _mediaAssetRepository.clearClipResultsForAsset(asset.id);
    }
    await _loadMediaAssets();
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
  _ClipQualityFilter qualityFilter,
) {
  final needle = query.trim().toLowerCase();
  return [
    for (final view in views)
      if (_viewMatches(view, needle, exportStatus, qualityFilter))
        _filterGalleryItems(view, qualityFilter),
  ];
}

bool _viewMatches(
  _MediaAssetView view,
  String needle,
  ClipExportStatus? exportStatus,
  _ClipQualityFilter qualityFilter,
) {
  final statusMatches =
      exportStatus == null ||
      view.exports.any((record) => record.status == exportStatus);
  if (!statusMatches) return false;
  if (!_qualityMatches(view, qualityFilter)) return false;
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

bool _qualityMatches(_MediaAssetView view, _ClipQualityFilter filter) {
  return switch (filter) {
    _ClipQualityFilter.all => true,
    _ClipQualityFilter.highScore => view.galleryItems.any(
      (item) => item.candidate.score >= 0.75,
    ),
    _ClipQualityFilter.needsReview => view.galleryItems.any(
      (item) => item.candidate.score < 0.6,
    ),
  };
}

_MediaAssetView _filterGalleryItems(
  _MediaAssetView view,
  _ClipQualityFilter filter,
) {
  if (filter == _ClipQualityFilter.all) return view;
  final items = view.galleryItems.where((item) {
    return switch (filter) {
      _ClipQualityFilter.all => true,
      _ClipQualityFilter.highScore => item.candidate.score >= 0.75,
      _ClipQualityFilter.needsReview => item.candidate.score < 0.6,
    };
  }).toList();
  return _MediaAssetView(
    asset: view.asset,
    candidates: view.candidates,
    exports: view.exports,
    galleryItems: items,
  );
}

enum _ClipQualityFilter { all, highScore, needsReview }

class _MediaAssetView {
  const _MediaAssetView({
    required this.asset,
    required this.candidates,
    required this.exports,
    required this.galleryItems,
  });

  final MediaAsset asset;
  final List<ClipCandidate> candidates;
  final List<ClipExportRecord> exports;
  final List<_ClipGalleryItem> galleryItems;
}

class _ClipGalleryItem {
  const _ClipGalleryItem({
    required this.candidate,
    required this.export,
    required this.previewPath,
  });

  final ClipCandidate candidate;
  final ClipExportRecord? export;
  final String? previewPath;
}

class _MediaAssetCard extends StatelessWidget {
  const _MediaAssetCard({
    required this.view,
    required this.onOpenLocalPath,
    required this.onPreviewClip,
    required this.onRegenerateClip,
    required this.onDeleteClip,
    required this.onClearResults,
  });

  final _MediaAssetView view;
  final Future<void> Function(String path) onOpenLocalPath;
  final ClipActionCallback onPreviewClip;
  final ClipActionCallback onRegenerateClip;
  final ClipDeleteCallback onDeleteClip;
  final AssetActionCallback onClearResults;

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
                OutlinedButton.icon(
                  key: Key('clear-results-${asset.id}'),
                  onPressed: view.galleryItems.isEmpty
                      ? null
                      : () => onClearResults(asset),
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Clear results'),
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
            if (view.galleryItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.view_carousel_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('Clip gallery', style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth >= 820
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in view.galleryItems)
                        SizedBox(
                          width: itemWidth,
                          child: _ClipGalleryCard(
                            asset: asset,
                            item: item,
                            onOpenLocalPath: onOpenLocalPath,
                            onPreviewClip: onPreviewClip,
                            onRegenerateClip: onRegenerateClip,
                            onDeleteClip: onDeleteClip,
                          ),
                        ),
                    ],
                  );
                },
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

class _ClipGalleryCard extends StatelessWidget {
  const _ClipGalleryCard({
    required this.asset,
    required this.item,
    required this.onOpenLocalPath,
    required this.onPreviewClip,
    required this.onRegenerateClip,
    required this.onDeleteClip,
  });

  final MediaAsset asset;
  final _ClipGalleryItem item;
  final Future<void> Function(String path) onOpenLocalPath;
  final ClipActionCallback onPreviewClip;
  final ClipActionCallback onRegenerateClip;
  final ClipDeleteCallback onDeleteClip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidate = item.candidate;
    final export = item.export;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClipPreviewFrame(
            key: Key('clip-preview-${candidate.id}'),
            previewPath: item.previewPath,
            startLabel: _formatTime(candidate.startMs),
            endLabel: _formatTime(candidate.endMs),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        candidate.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(candidate.durationMs),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (candidate.summary.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    candidate.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (candidate.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    candidate.reason,
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
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(
                        '${(candidate.score * 100).toStringAsFixed(0)}%',
                      ),
                    ),
                    if (export != null) Chip(label: Text(export.status.name)),
                    for (final tag in candidate.tags.take(3))
                      Chip(label: Text('#$tag')),
                    for (final keyword in candidate.keywords.take(3))
                      Chip(label: Text(keyword)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: Key('preview-clip-${candidate.id}'),
                      onPressed: () => onPreviewClip(asset, candidate, export),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Preview'),
                    ),
                    OutlinedButton.icon(
                      key: Key('regenerate-clip-${candidate.id}'),
                      onPressed: () =>
                          onRegenerateClip(asset, candidate, export),
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Regenerate'),
                    ),
                    OutlinedButton.icon(
                      key: export == null
                          ? null
                          : Key('open-clip-${export.id}'),
                      onPressed: export == null || export.outputPath.isEmpty
                          ? null
                          : () => onOpenLocalPath(export.outputPath),
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: const Text('Open clip'),
                    ),
                    OutlinedButton.icon(
                      onPressed: export == null || export.outputPath.isEmpty
                          ? null
                          : () => onOpenLocalPath(
                              File(export.outputPath).parent.path,
                            ),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Open folder'),
                    ),
                    OutlinedButton.icon(
                      key: Key('delete-clip-${candidate.id}'),
                      onPressed: () => onDeleteClip(candidate),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipPreviewFrame extends StatelessWidget {
  const _ClipPreviewFrame({
    super.key,
    required this.previewPath,
    required this.startLabel,
    required this.endLabel,
  });

  final String? previewPath;
  final String startLabel;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = previewPath == null || previewPath!.trim().isEmpty
        ? null
        : File(previewPath!);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null && image.existsSync())
            Image.file(image, fit: BoxFit.cover)
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Icon(
                Icons.movie_filter_outlined,
                size: 42,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: _PreviewPill(label: '$startLabel - $endLabel'),
          ),
        ],
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.white),
        ),
      ),
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
}

String _formatTime(int ms) {
  final totalSeconds = ms ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatDuration(int ms) {
  if (ms <= 0) return '0s';
  final seconds = (ms / 1000).round();
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}
