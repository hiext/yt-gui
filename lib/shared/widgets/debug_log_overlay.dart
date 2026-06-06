import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/app_models.dart';
import '../../core/services/log_service.dart';

class DebugLogOverlay extends StatefulWidget {
  const DebugLogOverlay({
    super.key,
    required this.child,
    this.visible = false,
    this.onClose,
  });

  final Widget child;
  final bool visible;
  final VoidCallback? onClose;

  @override
  State<DebugLogOverlay> createState() => _DebugLogOverlayState();
}

class _DebugLogOverlayState extends State<DebugLogOverlay> {
  final _scrollCtrl = ScrollController();
  bool _autoScroll = true;
  double _panelHeight = 220;

  @override
  void didUpdateWidget(covariant DebugLogOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        LogService.instance.addListener(_onLogUpdate);
      } else {
        LogService.instance.removeListener(_onLogUpdate);
      }
    }
  }

  void _onLogUpdate() {
    if (_autoScroll && _scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    LogService.instance.removeListener(_onLogUpdate);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _colorForLevel(LogLevel level) {
    return switch (level) {
      LogLevel.debug => Colors.grey,
      LogLevel.info => Colors.lightBlue,
      LogLevel.warning => Colors.orange,
      LogLevel.error => Colors.red,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return widget.child;

    return Column(
      children: [
        Expanded(child: widget.child),
        // Drag handle
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (d) {
            setState(() {
              _panelHeight = (_panelHeight - d.delta.dy).clamp(100, 600);
            });
          },
          child: Container(
            height: 6,
            color: Theme.of(context).colorScheme.outlineVariant,
            child: Center(
              child: Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        // Log panel
        AnimatedBuilder(
          animation: LogService.instance,
          builder: (context, _) => _buildLogPanel(),
        ),
      ],
    );
  }

  Widget _buildLogPanel() {
    final entries = LogService.instance.entries;
    final theme = Theme.of(context);

    return SizedBox(
      height: _panelHeight,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: theme.colorScheme.surfaceContainerHigh,
              child: Row(
                children: [
                  const Icon(Icons.terminal, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Debug Log (${entries.length})',
                    style: theme.textTheme.labelMedium,
                  ),
                  const Spacer(),
                  _buildLevelChip(LogService.instance.level),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_all, size: 18),
                    onPressed: () {
                      final text = LogService.instance.entries
                          .map((e) =>
                              '[${_fmt(e.timestamp)}] '
                              '${e.level.name.toUpperCase().padRight(5)} '
                              '${e.source != null ? '[${e.source}] ' : ''}'
                              '${e.message}')
                          .join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                    },
                    tooltip: 'Copy all',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _autoScroll = !_autoScroll),
                    tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => LogService.instance.clear(),
                    tooltip: 'Clear',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
            // Log entries
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'No log entries yet. Level: ${LogService.instance.level.name}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final line =
                            '[${_fmt(entry.timestamp)}] '
                            '${entry.level.name.toUpperCase().padRight(5)} '
                            '${entry.source != null ? '[${entry.source}] ' : ''}'
                            '${entry.message}';
                        return GestureDetector(
                          onLongPress: () {
                            Clipboard.setData(ClipboardData(text: line));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 1,
                            ),
                            child: Text(
                              line,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _colorForLevel(entry.level),
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelChip(LogLevel level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _colorForLevel(level).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level.name.toUpperCase(),
        style: TextStyle(fontSize: 10, color: _colorForLevel(level)),
      ),
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}
