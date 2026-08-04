import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/controllers/voice_swap_controller.dart';
import '../../core/models/voice_swap_models.dart';
import '../../core/services/voice_swap/voice_swap_model_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/section_card.dart';
import 'voice_swap_preset_labels.dart';

/// 一键换声页面。
class VoiceSwapPage extends StatefulWidget {
  const VoiceSwapPage({
    super.key,
    required this.controller,
    this.pickFiles,
  });

  final VoiceSwapController controller;

  /// 文件选择器（可注入以便测试）。
  final Future<FilePickerResult?> Function()? pickFiles;

  @override
  State<VoiceSwapPage> createState() => _VoiceSwapPageState();
}

class _VoiceSwapPageState extends State<VoiceSwapPage> {
  String? _inputVideo;
  String? _presetVoiceId = 'kokoro-zf-xiaobei';
  String? _outputVideo;
  String? _lastError;

  VoiceSwapController get _controller => widget.controller;

  Future<FilePickerResult?> _defaultPickFiles() => FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['mp4', 'mkv', 'webm', 'mov', 'avi', 'm4v'],
    dialogTitle: '选择视频',
  );

  Future<void> _pickVideo() async {
    final picker = widget.pickFiles ?? _defaultPickFiles;
    final picked = await picker();
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final path = picked.files.first.path;
    if (path == null || path.isEmpty) return;
    setState(() {
      _inputVideo = path;
      _outputVideo = _deriveOutputPath(path);
      _lastError = null;
    });
  }

  static String _deriveOutputPath(String inputPath) {
    final file = File(inputPath);
    final dir = file.parent.path;
    final base = file.uri.pathSegments.last;
    final dot = base.lastIndexOf('.');
    final stem = dot > 0 ? base.substring(0, dot) : base;
    final ext = dot > 0 ? base.substring(dot) : '';
    return '$dir${Platform.pathSeparator}${stem}_voice_swap$ext';
  }

  Future<void> _start() async {
    final input = _inputVideo;
    final output = _outputVideo;
    if (input == null || output == null) {
      setState(() => _lastError = '请先选择视频文件');
      return;
    }
    setState(() => _lastError = null);
    await _controller.start(
      inputVideo: input,
      outputVideo: output,
      presetVoiceId: _presetVoiceId ?? 'kokoro-zf-xiaobei',
    );
  }

  Future<void> _openOutputFolder() async {
    final result = _controller.result;
    if (result == null) return;
    final dir = File(result.outputPath).parent.path;
    if (Platform.isMacOS) {
      await Process.run('open', [dir]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [dir]);
    } else {
      await Process.run('xdg-open', [dir]);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _controller;
    final running = controller.isRunning;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.voiceSwapTitle,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.voiceSwapDesc,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.voiceSwapFirstRunNote,
          subtitle: l10n.voiceSwapDesc,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _videoPicker(l10n, running),
              const SizedBox(height: 16),
              _presetVoiceDropdown(l10n, running),
              const SizedBox(height: 16),
              _actionButtons(l10n, controller, running),
              if (running) _progressArea(l10n, controller),
              if (controller.stage == VoiceSwapStage.done &&
                  controller.result != null)
                _doneArea(l10n, controller),
              if (controller.stage == VoiceSwapStage.failed)
                _errorArea(l10n, controller),
            ],
          ),
        ),
      ],
    );
  }

  Widget _videoPicker(AppLocalizations l10n, bool running) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.voiceSwapPickVideo,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: running ? null : _pickVideo,
          icon: const Icon(Icons.video_file_outlined),
          label: Text(l10n.voiceSwapPickVideo),
        ),
        if (_inputVideo != null) ...[
          const SizedBox(height: 8),
          Text(
            _inputVideo!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _presetVoiceDropdown(AppLocalizations l10n, bool running) {
    final voices = VoiceSwapModelCatalog.presetVoices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.voiceSwapPresetVoiceLabel,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(_presetVoiceId),
          initialValue: _presetVoiceId,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final voice in voices)
              DropdownMenuItem(
                value: voice.id,
                child: Text('${voiceSwapPresetLabel(l10n, voice)}'
                    '（${voiceSwapPresetGender(l10n, voice)}）'),
              ),
          ],
          onChanged: running
              ? null
              : (v) => setState(() => _presetVoiceId = v),
        ),
      ],
    );
  }

  Widget _actionButtons(
    AppLocalizations l10n,
    VoiceSwapController controller,
    bool running,
  ) {
    if (running) {
      return Row(
        children: [
          OutlinedButton.icon(
            onPressed: controller.cancel,
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(l10n.voiceSwapCancel),
          ),
        ],
      );
    }
    return Row(
      children: [
        FilledButton.icon(
          onPressed: _inputVideo == null ? null : _start,
          icon: const Icon(Icons.record_voice_over_outlined),
          label: Text(l10n.voiceSwapStart),
        ),
        if (controller.stage == VoiceSwapStage.done) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: controller.reset,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.voiceSwapReset),
          ),
        ],
      ],
    );
  }

  Widget _progressArea(AppLocalizations l10n, VoiceSwapController controller) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: controller.progress.clamp(0.0, 1.0),
          ),
          const SizedBox(height: 8),
          Text(
            controller.message ?? l10n.voiceSwapRunning,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _doneArea(AppLocalizations l10n, VoiceSwapController controller) {
    final result = controller.result!;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.voiceSwapDoneTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.outputPath,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openOutputFolder,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(l10n.voiceSwapOpenOutputFolder),
          ),
        ],
      ),
    );
  }

  Widget _errorArea(AppLocalizations l10n, VoiceSwapController controller) {
    final error = controller.error ?? _lastError ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        error,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
