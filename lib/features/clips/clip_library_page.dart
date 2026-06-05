import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/controllers/post_process_controller.dart';
import '../../core/models/app_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/section_card.dart';

class ClipLibraryPage extends StatefulWidget {
  const ClipLibraryPage({super.key, required this.controller});

  final PostProcessController controller;

  @override
  State<ClipLibraryPage> createState() => _ClipLibraryPageState();
}

class _ClipLibraryPageState extends State<ClipLibraryPage> {
  final _searchCtrl = TextEditingController();
  List<ClipSegment> _segments = const [];
  var _isSearching = false;

  @override
  void initState() {
    super.initState();
    _segments = widget.controller.clipSegments;
    widget.controller.addListener(_syncFromController);
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

  Future<void> _runSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await widget.controller.searchClipSegments(query);
    if (!mounted) return;
    setState(() {
      _segments = results;
      _isSearching = false;
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_segments.isEmpty)
          SectionCard(
            title: l10n.noClipSegments,
            subtitle: l10n.noClipSegmentsHint,
            child: const SizedBox(height: 24),
          )
        else
          for (final segment in _segments) ...[
            _ClipSegmentCard(segment: segment, onAdjust: _adjustSegment),
            const SizedBox(height: 12),
          ],
      ],
    );
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
