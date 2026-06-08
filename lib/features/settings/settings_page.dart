import 'dart:io';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../core/controllers/settings_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/cookie_service.dart'
    show CookieService, CookieEntry, CookieImportResult;
import '../../core/services/embedded_tool_manifest.dart';
import '../../core/services/embedded_tool_resolver.dart';
import '../../core/services/log_service.dart';
import '../../shared/widgets/section_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _saveDirCtrl;
  late final TextEditingController _qualityCtrl;
  late final TextEditingController _ytDlpCtrl;
  late final TextEditingController _ffmpegCtrl;
  late final TextEditingController _aiAnalyzerCtrl;
  late final TextEditingController _aiCloudNameCtrl;
  late final TextEditingController _aiCloudEndpointCtrl;
  late final TextEditingController _aiCloudApiKeyCtrl;
  late final TextEditingController _aiCloudModelCtrl;
  AiCloudVendor _newAiCloudVendor = AiCloudVendor.openAI;
  bool _saved = true;
  DateTime? _lastSavedAt;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _saveDirCtrl = TextEditingController(text: s.saveDirectory);
    _qualityCtrl = TextEditingController(text: s.defaultQuality);
    _ytDlpCtrl = TextEditingController(text: s.ytDlpPath ?? '');
    _ffmpegCtrl = TextEditingController(text: s.ffmpegPath ?? '');
    _aiAnalyzerCtrl = TextEditingController(text: s.aiAnalyzerCommand ?? '');
    final cloudConfig = s.selectedAiCloudConfig;
    _aiCloudNameCtrl = TextEditingController(text: cloudConfig?.name ?? '');
    _aiCloudEndpointCtrl = TextEditingController(
      text: cloudConfig?.endpoint ?? '',
    );
    _aiCloudApiKeyCtrl = TextEditingController(text: cloudConfig?.apiKey ?? '');
    _aiCloudModelCtrl = TextEditingController(text: cloudConfig?.model ?? '');
    widget.controller.addListener(_syncFromSettings);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromSettings);
    _saveDirCtrl.dispose();
    _qualityCtrl.dispose();
    _ytDlpCtrl.dispose();
    _ffmpegCtrl.dispose();
    _aiAnalyzerCtrl.dispose();
    _aiCloudNameCtrl.dispose();
    _aiCloudEndpointCtrl.dispose();
    _aiCloudApiKeyCtrl.dispose();
    _aiCloudModelCtrl.dispose();
    super.dispose();
  }

  void _syncFromSettings() {
    final s = widget.controller.settings;
    _updateCtrlIfChanged(_saveDirCtrl, s.saveDirectory);
    _updateCtrlIfChanged(_qualityCtrl, s.defaultQuality);
    _updateCtrlIfChanged(_ytDlpCtrl, s.ytDlpPath ?? '');
    _updateCtrlIfChanged(_ffmpegCtrl, s.ffmpegPath ?? '');
    _updateCtrlIfChanged(_aiAnalyzerCtrl, s.aiAnalyzerCommand ?? '');
    final cloudConfig = s.selectedAiCloudConfig;
    _updateCtrlIfChanged(_aiCloudNameCtrl, cloudConfig?.name ?? '');
    _updateCtrlIfChanged(_aiCloudEndpointCtrl, cloudConfig?.endpoint ?? '');
    _updateCtrlIfChanged(_aiCloudApiKeyCtrl, cloudConfig?.apiKey ?? '');
    _updateCtrlIfChanged(_aiCloudModelCtrl, cloudConfig?.model ?? '');
    _markDirty();
  }

  void _updateCtrlIfChanged(TextEditingController ctrl, String value) {
    if (ctrl.text != value) {
      ctrl.text = value;
    }
  }

  static const _qualityPresets = [
    'best',
    'bestvideo+bestaudio',
    'bestvideo',
    'bestaudio',
    'bv*+ba*',
    'bv*+ba/b',
    'worstvideo+worstaudio',
    'worst',
  ];

  String _normalizeQualityValue(String value) {
    return _qualityPresets.contains(value) ? value : 'best';
  }

  List<DropdownMenuItem<AiCloudVendor>> _aiCloudVendorItems(
    AppLocalizations l10n,
  ) {
    return [
      for (final vendor in AiCloudVendor.values)
        DropdownMenuItem(
          value: vendor,
          child: Text(_aiCloudVendorLabel(l10n, vendor)),
        ),
    ];
  }

  String _aiCloudVendorLabel(AppLocalizations l10n, AiCloudVendor vendor) {
    return switch (vendor) {
      AiCloudVendor.custom => l10n.aiCloudVendorCustom,
      AiCloudVendor.openAI => l10n.aiCloudVendorOpenAI,
      AiCloudVendor.gemini => l10n.aiCloudVendorGemini,
      AiCloudVendor.anthropic => l10n.aiCloudVendorAnthropic,
      AiCloudVendor.groq => l10n.aiCloudVendorGroq,
      AiCloudVendor.deepSeek => l10n.aiCloudVendorDeepSeek,
      AiCloudVendor.qwen => l10n.aiCloudVendorQwen,
      AiCloudVendor.openRouter => l10n.aiCloudVendorOpenRouter,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final settings = widget.controller.settings;
        final cloudConfig = settings.selectedAiCloudConfig;
        final cloudEnabled =
            settings.aiAnalysisProvider == AiAnalysisProvider.cloudEndpoint;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settings,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _resetToDefaults,
                          icon: const Icon(Icons.restore_outlined),
                          label: Text(l10n.restoreDefaults),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.settings,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _resetToDefaults,
                      icon: const Icon(Icons.restore_outlined),
                      label: Text(l10n.restoreDefaults),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: l10n.saveAndQuality,
              subtitle: l10n.saveAndQualityDesc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const Key('save-directory-field'),
                    controller: _saveDirCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.saveDirectory,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        tooltip: l10n.browseDirectory,
                        onPressed: _browseDirectory,
                      ),
                    ),
                    onChanged: widget.controller.updateSaveDirectory,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('default-quality-field'),
                    initialValue: _normalizeQualityValue(
                      settings.defaultQuality,
                    ),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.defaultQuality,
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'best', child: Text('best (推荐)')),
                      DropdownMenuItem(
                        value: 'bestvideo+bestaudio',
                        child: Text('bestvideo+bestaudio'),
                      ),
                      DropdownMenuItem(
                        value: 'bestvideo',
                        child: Text('bestvideo'),
                      ),
                      DropdownMenuItem(
                        value: 'bestaudio',
                        child: Text('bestaudio'),
                      ),
                      DropdownMenuItem(
                        value: 'bv*+ba*',
                        child: Text('bv*+ba* (最佳视频+音频)'),
                      ),
                      DropdownMenuItem(
                        value: 'bv*+ba/b',
                        child: Text('bv*+ba/b'),
                      ),
                      DropdownMenuItem(
                        value: 'worstvideo+worstaudio',
                        child: Text('worstvideo+worstaudio'),
                      ),
                      DropdownMenuItem(value: 'worst', child: Text('worst')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        widget.controller.updateDefaultQuality(v);
                        _qualityCtrl.text = v;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 240,
                    child: TextFormField(
                      key: const Key('recommended-variant-count-field'),
                      initialValue: settings.recommendedVariantCount.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.recommendedVariantCount,
                        helperText: l10n.recommendedVariantCountHint,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final count = int.tryParse(value);
                        if (count != null) {
                          widget.controller.updateRecommendedVariantCount(
                            count,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: l10n.externalTools,
              subtitle: l10n.externalToolsDesc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const Key('yt-dlp-path-field'),
                    controller: _ytDlpCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.ytDlpPath,
                      helperText: l10n.ytDlpPathHint,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        tooltip: l10n.browseFile,
                        onPressed: () => _browseFile(_ytDlpCtrl),
                      ),
                    ),
                    onChanged: widget.controller.updateYtDlpPath,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('ffmpeg-path-field'),
                    controller: _ffmpegCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.ffmpegPath,
                      helperText: l10n.ffmpegPathHint,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        tooltip: l10n.browseFile,
                        onPressed: () => _browseFile(_ffmpegCtrl),
                      ),
                    ),
                    onChanged: widget.controller.updateFfmpegPath,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: l10n.aiClipAnalysis,
              subtitle: l10n.aiClipAnalysisDesc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<AiAnalysisProvider>(
                    key: const Key('ai-analysis-provider-field'),
                    initialValue: settings.aiAnalysisProvider,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.aiAnalysisProvider,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: AiAnalysisProvider.builtIn,
                        child: Text(l10n.aiProviderBuiltIn),
                      ),
                      DropdownMenuItem(
                        value: AiAnalysisProvider.externalCommand,
                        child: Text(l10n.aiProviderExternalCommand),
                      ),
                      DropdownMenuItem(
                        value: AiAnalysisProvider.cloudEndpoint,
                        child: Text(l10n.aiProviderCloudEndpoint),
                      ),
                    ],
                    onChanged: (provider) {
                      if (provider != null) {
                        widget.controller.updateAiAnalysisProvider(provider);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<BuiltInClipAnalyzerMode>(
                    key: const Key('built-in-clip-analyzer-mode-field'),
                    initialValue: settings.builtInClipAnalyzerMode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.builtInClipAnalyzerMode,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: BuiltInClipAnalyzerMode.balanced,
                        child: Text(l10n.builtInBalanced),
                      ),
                      DropdownMenuItem(
                        value: BuiltInClipAnalyzerMode.visualFocused,
                        child: Text(l10n.builtInVisualFocused),
                      ),
                      DropdownMenuItem(
                        value: BuiltInClipAnalyzerMode.audioFocused,
                        child: Text(l10n.builtInAudioFocused),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        widget.controller.updateBuiltInClipAnalyzerMode(mode);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('ai-analyzer-command-field'),
                    controller: _aiAnalyzerCtrl,
                    enabled:
                        settings.aiAnalysisProvider ==
                        AiAnalysisProvider.externalCommand,
                    decoration: InputDecoration(
                      labelText: l10n.aiAnalyzerCommand,
                      helperText: l10n.aiAnalyzerCommandHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: widget.controller.updateAiAnalyzerCommand,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 620;
                      final profileField = DropdownButtonFormField<String>(
                        key: ValueKey(
                          'ai-cloud-profile-${settings.selectedAiCloudConfigId}',
                        ),
                        initialValue: cloudConfig?.id,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.aiCloudProfile,
                          helperText: l10n.aiCloudProfileHint,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final config in settings.aiCloudConfigs)
                            DropdownMenuItem(
                              value: config.id,
                              child: Text(config.name),
                            ),
                        ],
                        onChanged: cloudEnabled
                            ? (id) {
                                if (id != null) {
                                  widget.controller.updateSelectedAiCloudConfig(
                                    id,
                                  );
                                }
                              }
                            : null,
                      );
                      final addVendorField =
                          DropdownButtonFormField<AiCloudVendor>(
                            key: const Key('ai-cloud-add-vendor-field'),
                            initialValue: _newAiCloudVendor,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l10n.aiCloudVendor,
                              border: const OutlineInputBorder(),
                            ),
                            items: _aiCloudVendorItems(l10n),
                            onChanged: cloudEnabled
                                ? (vendor) {
                                    if (vendor != null) {
                                      setState(() {
                                        _newAiCloudVendor = vendor;
                                      });
                                    }
                                  }
                                : null,
                          );
                      final addButton = FilledButton.tonalIcon(
                        onPressed: cloudEnabled
                            ? () => widget.controller.addAiCloudConfig(
                                _newAiCloudVendor,
                              )
                            : null,
                        icon: const Icon(Icons.add_outlined),
                        label: Text(l10n.addAiCloudProfile),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            profileField,
                            const SizedBox(height: 12),
                            addVendorField,
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: addButton,
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: profileField),
                          const SizedBox(width: 12),
                          Expanded(child: addVendorField),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: addButton,
                          ),
                        ],
                      );
                    },
                  ),
                  if (cloudConfig == null) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.aiCloudNoProfiles,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AiCloudVendor>(
                      key: ValueKey('ai-cloud-vendor-${cloudConfig.id}'),
                      initialValue: cloudConfig.vendor,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.aiCloudVendor,
                        helperText: l10n.aiCloudVendorHint,
                        border: const OutlineInputBorder(),
                      ),
                      items: _aiCloudVendorItems(l10n),
                      onChanged: cloudEnabled
                          ? (vendor) {
                              if (vendor != null) {
                                widget.controller.updateSelectedAiCloudVendor(
                                  vendor,
                                );
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('ai-cloud-name-field'),
                      controller: _aiCloudNameCtrl,
                      enabled: cloudEnabled,
                      decoration: InputDecoration(
                        labelText: l10n.aiCloudProfileName,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: widget.controller.updateSelectedAiCloudName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('ai-cloud-endpoint-field'),
                      controller: _aiCloudEndpointCtrl,
                      enabled: cloudEnabled,
                      decoration: InputDecoration(
                        labelText: l10n.aiCloudEndpoint,
                        helperText: l10n.aiCloudEndpointHint,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: widget.controller.updateAiCloudEndpoint,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('ai-cloud-model-field'),
                      controller: _aiCloudModelCtrl,
                      enabled: cloudEnabled,
                      decoration: InputDecoration(
                        labelText: l10n.aiCloudModel,
                        helperText: l10n.aiCloudModelHint,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: widget.controller.updateAiCloudModel,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('ai-cloud-api-key-field'),
                      controller: _aiCloudApiKeyCtrl,
                      enabled: cloudEnabled,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.aiCloudApiKey,
                        helperText: l10n.aiCloudApiKeyHint,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: widget.controller.updateAiCloudApiKey,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: cloudEnabled
                            ? () => widget.controller.removeAiCloudConfig(
                                cloudConfig.id,
                              )
                            : null,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.deleteAiCloudProfile),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Auto Clip ──
            SectionCard(
              title: l10n.autoClipSection,
              subtitle: l10n.autoClipSectionDesc,
              child: _buildAutoClipSection(l10n, settings),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: l10n.downloadMode,
              subtitle: l10n.downloadModeDesc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<DownloadMode>(
                    key: const Key('download-mode-field'),
                    // ignore: deprecated_member_use
                    value: settings.downloadMode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.scheduleMode,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: DownloadMode.serial,
                        child: Text(
                          l10n.serialDownload,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: DownloadMode.queue,
                        child: Text(
                          l10n.queueDownload,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: DownloadMode.concurrent,
                        child: Text(
                          l10n.concurrentDownload,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        widget.controller.updateDownloadMode(mode);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _ConcurrentCountSelector(
                    value: settings.concurrentCount,
                    enabled: settings.downloadMode == DownloadMode.concurrent,
                    onChanged: widget.controller.updateConcurrentCount,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: l10n.additionalOptions,
              subtitle: l10n.additionalOptionsDesc,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.downloadSubtitles),
                    subtitle: Text(l10n.downloadSubtitlesDesc),
                    value: settings.downloadSubtitles,
                    onChanged: widget.controller.updateDownloadSubtitles,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.downloadThumbnail),
                    subtitle: Text(l10n.downloadThumbnailDesc),
                    value: settings.downloadThumbnail,
                    onChanged: widget.controller.updateDownloadThumbnail,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Log Level ──
            SectionCard(
              title: 'Log Level / 日志级别',
              subtitle: 'Set the verbosity of debug logging.',
              child: DropdownButtonFormField<LogLevel>(
                initialValue: settings.logLevel,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Log Level',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: LogLevel.debug, child: Text('Debug')),
                  DropdownMenuItem(value: LogLevel.info, child: Text('Info')),
                  DropdownMenuItem(
                    value: LogLevel.warning,
                    child: Text('Warning'),
                  ),
                  DropdownMenuItem(value: LogLevel.error, child: Text('Error')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    LogService.instance.setLevel(v);
                    widget.controller.updateSettings(
                      widget.controller.settings.copyWith(logLevel: v),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            _CookieSection(
              configs: settings.cookieConfigs,
              defaultBrowser: settings.defaultCookieBrowser,
              onImport: (browser, domain) => _importCookies(browser, domain),
              onRemove: (domain) => _removeCookie(domain),
              onReimport: (config) => _reimportCookie(config),
            ),
            const SizedBox(height: 24),
            // ── Save status bar ──
            _buildSaveBar(l10n),
            const SizedBox(height: 48),
          ],
        );
      },
    );
  }

  void _markDirty() {
    if (_saved) setState(() => _saved = false);
  }

  void _doSave() {
    // Flush all text field values now — each onChanged already updates
    // the controller immediately; this just provides confirmation.
    widget.controller.updateSettings(widget.controller.settings);
    setState(() {
      _saved = true;
      _lastSavedAt = DateTime.now();
    });
  }

  String _saveStatusText(AppLocalizations l10n) {
    if (_saved && _lastSavedAt != null) {
      final h = _lastSavedAt!.hour.toString().padLeft(2, '0');
      final m = _lastSavedAt!.minute.toString().padLeft(2, '0');
      return l10n.settingsSavedAt(h, m);
    }
    if (_saved) return l10n.settingsSaved;
    return l10n.settingsUnsaved;
  }

  Widget _buildSaveBar(AppLocalizations l10n) {
    final saved = _saved;
    return Card(
      color: saved
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              saved ? Icons.check_circle_outline : Icons.info_outline,
              size: 20,
              color: saved
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _saveStatusText(l10n),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: saved
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: saved ? null : _doSave,
              child: Text(l10n.saveSettingsBtn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoClipSection(
    AppLocalizations l10n,
    DownloadSettings settings,
  ) {
    final config = settings.autoClipConfig;
    final enabled = config.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('auto-clip-enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.autoClipEnabled),
          value: enabled,
          onChanged: (v) {
            widget.controller.updateAutoClipConfig(config.copyWith(enabled: v));
          },
        ),
        const SizedBox(height: 8),
        Text(
          '${l10n.autoClipMinConfidence}: ${config.minConfidence.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          key: const Key('auto-clip-confidence'),
          value: config.minConfidence,
          min: 0,
          max: 1,
          divisions: 20,
          label: config.minConfidence.toStringAsFixed(2),
          onChanged: enabled
              ? (v) {
                  widget.controller.updateAutoClipConfig(
                    config.copyWith(
                      minConfidence: double.parse(v.toStringAsFixed(2)),
                    ),
                  );
                }
              : null,
        ),
        Text(
          '${l10n.autoClipMaxClips}: ${config.maxClipsPerVideo}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          key: const Key('auto-clip-max-clips'),
          value: config.maxClipsPerVideo.toDouble(),
          min: 1,
          max: 20,
          divisions: 19,
          label: '${config.maxClipsPerVideo}',
          onChanged: enabled
              ? (v) {
                  widget.controller.updateAutoClipConfig(
                    config.copyWith(maxClipsPerVideo: v.round()),
                  );
                }
              : null,
        ),
        Text(
          '${l10n.autoClipMaxDuration}: ${config.maxClipDurationSec}s',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Slider(
          key: const Key('auto-clip-max-duration'),
          value: config.maxClipDurationSec.toDouble(),
          min: 10,
          max: 120,
          divisions: 22,
          label: '${config.maxClipDurationSec}s',
          onChanged: enabled
              ? (v) {
                  widget.controller.updateAutoClipConfig(
                    config.copyWith(maxClipDurationSec: v.round()),
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('auto-clip-start-offset'),
                initialValue: config.startOffsetMs.toString(),
                enabled: enabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.autoClipStartOffset,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  final ms = int.tryParse(v);
                  if (ms != null) {
                    widget.controller.updateAutoClipConfig(
                      config.copyWith(startOffsetMs: ms),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: const Key('auto-clip-end-offset'),
                initialValue: config.endOffsetMs.toString(),
                enabled: enabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.autoClipEndOffset,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  final ms = int.tryParse(v);
                  if (ms != null) {
                    widget.controller.updateAutoClipConfig(
                      config.copyWith(endOffsetMs: ms),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _resetToDefaults() {
    widget.controller.updateSettings(
      DownloadSettings.defaults.copyWith(
        disclaimerAccepted: widget.controller.settings.disclaimerAccepted,
      ),
    );
    _markDirty();
  }

  String _resolveYtDlpPath(DownloadSettings settings) {
    return const EmbeddedToolResolver()
        .resolveExecutable(
          kind: EmbeddedToolKind.ytDlp,
          settings: settings,
          allowMissingCustomFallback: true,
        )
        .path;
  }

  Future<void> _importCookies(String browser, String domain) async {
    final l10n = AppLocalizations.of(context)!;
    final settings = widget.controller.settings;
    final saveDir = settings.saveDirectory;
    final cookieFile =
        '$saveDir/.cookies/$domain'
        '_$browser.txt';
    final ytDlpPath = _resolveYtDlpPath(settings);

    final service = CookieService();
    try {
      final result = await service.importFromBrowser(
        browser: browser,
        domain: domain,
        ytDlpPath: ytDlpPath,
        outputFile: cookieFile,
        localizations: l10n,
      );
      _handleImportResult(result, domain, browser, cookieFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.cookieImportFailed),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleImportResult(
    CookieImportResult result,
    String domain,
    String browser,
    String cookieFile,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final settings = widget.controller.settings;

    if (!result.success) {
      LogService.instance.error(
        'Cookie import failed: $domain ($browser) — ${result.detail}',
        'cookie',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cookieImportFailed,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  result.detail ?? l10n.unknownError,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final fileExists = File(cookieFile).existsSync();
    final fileSize = fileExists ? File(cookieFile).lengthSync() : 0;
    LogService.instance.info(
      'Cookie import OK: $domain ($browser) → $cookieFile '
          '($fileSize bytes, exists=$fileExists)',
      'cookie',
    );

    final configs = List<CookieConfig>.from(settings.cookieConfigs)
      ..removeWhere((c) => c.domain == domain)
      ..add(
        CookieConfig(
          domain: domain,
          browser: browser,
          cookieFile: cookieFile,
          importedAt: DateTime.now(),
        ),
      );
    CookieService().saveConfigs(configs);
    final updated = settings.copyWith(cookieConfigs: configs);
    widget.controller.updateSettings(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.cookieImportSuccess(domain)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _removeCookie(String domain) async {
    final settings = widget.controller.settings;
    final configs = List<CookieConfig>.from(settings.cookieConfigs)
      ..removeWhere((c) => c.domain == domain);
    await CookieService().saveConfigs(configs);
    final updated = settings.copyWith(cookieConfigs: configs);
    widget.controller.updateSettings(updated);
  }

  Future<void> _reimportCookie(CookieConfig config) async {
    await _importCookies(config.browser, config.domain);
  }

  Future<void> _browseDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    // Use system file picker to choose a directory
    final result = await Process.run('zenity', [
      '--file-selection',
      '--directory',
      '--title=${l10n.filePickerSaveDirTitle}',
    ]);
    if (result.exitCode == 0) {
      final path = (result.stdout as String).trim();
      if (path.isNotEmpty) {
        _saveDirCtrl.text = path;
        widget.controller.updateSaveDirectory(path);
      }
    }
  }

  Future<void> _browseFile(TextEditingController ctrl) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await Process.run('zenity', [
      '--file-selection',
      '--title=${l10n.filePickerExecutableTitle}',
    ]);
    if (result.exitCode == 0) {
      final path = (result.stdout as String).trim();
      if (path.isNotEmpty) {
        ctrl.text = path;
        if (identical(ctrl, _ytDlpCtrl)) {
          widget.controller.updateYtDlpPath(path);
        } else {
          widget.controller.updateFfmpegPath(path);
        }
      }
    }
  }
}

class _CookieSection extends StatefulWidget {
  const _CookieSection({
    required this.configs,
    required this.defaultBrowser,
    required this.onImport,
    required this.onRemove,
    required this.onReimport,
  });

  final List<CookieConfig> configs;
  final String? defaultBrowser;
  final Future<void> Function(String browser, String domain) onImport;
  final void Function(String domain) onRemove;
  final void Function(CookieConfig config) onReimport;

  @override
  State<_CookieSection> createState() => _CookieSectionState();
}

class _CookieSectionState extends State<_CookieSection> {
  String _browser = 'chrome';
  final _domainCtrl = TextEditingController();
  bool _importing = false;

  static const _presetSites = <String>[
    'youtube.com',
    'bilibili.com',
    'twitter.com',
    'x.com',
    'instagram.com',
    'tiktok.com',
    'facebook.com',
    'twitch.tv',
    'reddit.com',
    'nicovideo.jp',
    'vimeo.com',
    'dailymotion.com',
    'pornhub.com',
    'xvideos.com',
    'pinterest.com',
    'soundcloud.com',
    'bandcamp.com',
  ];

  @override
  void dispose() {
    _domainCtrl.dispose();
    super.dispose();
  }

  Set<String> get _importedDomains =>
      widget.configs.map((c) => c.domain).toSet();

  List<String> get _availablePresets =>
      _presetSites.where((d) => !_importedDomains.contains(d)).toList();

  Future<void> _doImport(String domain) async {
    if (domain.isEmpty || _importing) return;
    setState(() => _importing = true);
    try {
      await widget.onImport(_browser, domain);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SectionCard(
      title: l10n.cookieManagement,
      subtitle: l10n.cookieManagementDesc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Browser selector + import
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final browserField = DropdownButtonFormField<String>(
                initialValue: _browser,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.browser,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'chrome', child: Text('Chrome')),
                  DropdownMenuItem(value: 'firefox', child: Text('Firefox')),
                  DropdownMenuItem(value: 'edge', child: Text('Edge')),
                  DropdownMenuItem(value: 'brave', child: Text('Brave')),
                  DropdownMenuItem(value: 'opera', child: Text('Opera')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _browser = v);
                },
              );
              final domainField = TextFormField(
                controller: _domainCtrl,
                decoration: InputDecoration(
                  labelText: l10n.domain,
                  hintText: l10n.enterDomainHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onFieldSubmitted: (v) => _doImport(v.trim()),
              );
              final importButton = FilledButton.tonalIcon(
                onPressed: _importing
                    ? null
                    : () => _doImport(_domainCtrl.text.trim()),
                icon: _importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined, size: 18),
                label: Text(_importing ? l10n.importing : l10n.importBtn),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    browserField,
                    const SizedBox(height: 12),
                    domainField,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: importButton,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: browserField),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Expanded(child: domainField),
                        const SizedBox(width: 8),
                        importButton,
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // Preset sites
          if (_availablePresets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.commonSites,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final site in _availablePresets)
                  ActionChip(
                    avatar: Icon(_siteIcon(site), size: 16),
                    label: Text(site, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _doImport(site),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          // List of imported cookies
          if (widget.configs.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            for (final config in widget.configs)
              _CookieTile(
                config: config,
                onRemove: () => widget.onRemove(config.domain),
                onReimport: () => widget.onReimport(config),
              ),
          ],
        ],
      ),
    );
  }
}

IconData _siteIcon(String domain) {
  if (domain.contains('youtube') || domain.contains('youtu.be')) {
    return Icons.play_circle_outline;
  }
  if (domain.contains('bilibili')) {
    return Icons.tv_outlined;
  }
  if (domain.contains('twitter') || domain.contains('x.com')) {
    return Icons.alternate_email;
  }
  if (domain.contains('instagram')) {
    return Icons.camera_alt_outlined;
  }
  if (domain.contains('tiktok')) {
    return Icons.music_note_outlined;
  }
  if (domain.contains('facebook')) {
    return Icons.people_outline;
  }
  if (domain.contains('twitch')) {
    return Icons.live_tv_outlined;
  }
  if (domain.contains('reddit')) {
    return Icons.forum_outlined;
  }
  if (domain.contains('nicovideo')) {
    return Icons.videocam_outlined;
  }
  if (domain.contains('soundcloud')) {
    return Icons.audiotrack_outlined;
  }
  if (domain.contains('vimeo')) {
    return Icons.play_circle_outline;
  }
  if (domain.contains('pornhub') || domain.contains('xvideos')) {
    return Icons.visibility_off_outlined;
  }
  return Icons.language;
}

Color _browserColor(String browser) {
  return switch (browser) {
    'chrome' => const Color(0xFF4285F4),
    'firefox' => const Color(0xFFFF7139),
    'edge' => const Color(0xFF0078D7),
    'brave' => const Color(0xFFFB542B),
    'opera' => const Color(0xFFFF1B2D),
    _ => Colors.grey,
  };
}

IconData _browserIcon(String browser) {
  return switch (browser) {
    'chrome' => Icons.language,
    'firefox' => Icons.local_fire_department_outlined,
    'edge' => Icons.explore_outlined,
    'brave' => Icons.shield_outlined,
    'opera' => Icons.circle_outlined,
    _ => Icons.language,
  };
}

class _CookieTile extends StatefulWidget {
  const _CookieTile({
    required this.config,
    required this.onRemove,
    required this.onReimport,
  });

  final CookieConfig config;
  final VoidCallback onRemove;
  final VoidCallback onReimport;

  @override
  State<_CookieTile> createState() => _CookieTileState();
}

class _CookieTileState extends State<_CookieTile> {
  bool _expanded = false;
  List<CookieEntry>? _entries;

  void _loadEntries() {
    _entries ??= CookieService().parseCookieFile(widget.config.cookieFile);
  }

  @override
  Widget build(BuildContext context) {
    _loadEntries();
    final l10n = AppLocalizations.of(context)!;
    final entries = _entries ?? const [];
    final brColor = _browserColor(widget.config.browser);
    final brIcon = _browserIcon(widget.config.browser);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cookie, color: brColor, size: 20),
          title: Text(
            widget.config.domain,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Row(
            children: [
              Icon(brIcon, size: 13, color: brColor),
              const SizedBox(width: 4),
              Text(
                '${widget.config.browser} · ${l10n.cookiesCount(entries.length)}',
                style: TextStyle(fontSize: 12, color: brColor),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                tooltip: l10n.viewDetails,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: l10n.reimport,
                onPressed: widget.onReimport,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: l10n.delete,
                onPressed: widget.onRemove,
              ),
            ],
          ),
        ),
        if (_expanded && entries.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 28, right: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 8),
                Text(
                  '${l10n.fileLabel}: ${widget.config.cookieFile}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ...entries
                    .take(12)
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: e.isExpired ? Colors.orange : brColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              e.expiryText(l10n),
                              style: TextStyle(
                                fontSize: 10,
                                color: e.isExpired
                                    ? Colors.orange
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (entries.length > 12)
                  Text(
                    l10n.moreCookies(entries.length - 12),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ConcurrentCountSelector extends StatelessWidget {
  const _ConcurrentCountSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.concurrentCount,
        helperText: enabled
            ? l10n.concurrentHint(value)
            : l10n.concurrentDisabledHint,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 8,
              divisions: 7,
              label: '$value',
              onChanged: enabled ? (next) => onChanged(next.round()) : null,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text('$value', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
