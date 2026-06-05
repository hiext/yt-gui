import 'dart:io';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../core/controllers/settings_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/cookie_service.dart'
    show CookieService, CookieEntry;
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

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _saveDirCtrl = TextEditingController(text: s.saveDirectory);
    _qualityCtrl = TextEditingController(text: s.defaultQuality);
    _ytDlpCtrl = TextEditingController(text: s.ytDlpPath ?? '');
    _ffmpegCtrl = TextEditingController(text: s.ffmpegPath ?? '');
    _aiAnalyzerCtrl = TextEditingController(text: s.aiAnalyzerCommand ?? '');
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
    super.dispose();
  }

  void _syncFromSettings() {
    final s = widget.controller.settings;
    _updateCtrlIfChanged(_saveDirCtrl, s.saveDirectory);
    _updateCtrlIfChanged(_qualityCtrl, s.defaultQuality);
    _updateCtrlIfChanged(_ytDlpCtrl, s.ytDlpPath ?? '');
    _updateCtrlIfChanged(_ffmpegCtrl, s.ffmpegPath ?? '');
    _updateCtrlIfChanged(_aiAnalyzerCtrl, s.aiAnalyzerCommand ?? '');
  }

  void _updateCtrlIfChanged(TextEditingController ctrl, String value) {
    if (ctrl.text != value) {
      ctrl.text = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final settings = widget.controller.settings;

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
                  TextFormField(
                    key: const Key('default-quality-field'),
                    controller: _qualityCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.defaultQuality,
                      helperText: l10n.defaultQualityHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: widget.controller.updateDefaultQuality,
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
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('ai-analyzer-command-field'),
                    controller: _aiAnalyzerCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.aiAnalyzerCommand,
                      helperText: l10n.aiAnalyzerCommandHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: widget.controller.updateAiAnalyzerCommand,
                  ),
                ],
              ),
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
            _CookieSection(
              configs: settings.cookieConfigs,
              defaultBrowser: settings.defaultCookieBrowser,
              onImport: (browser, domain) => _importCookies(browser, domain),
              onRemove: (domain) => _removeCookie(domain),
              onReimport: (config) => _reimportCookie(config),
            ),
          ],
        );
      },
    );
  }

  void _resetToDefaults() {
    widget.controller.updateSettings(
      DownloadSettings.defaults.copyWith(
        disclaimerAccepted: widget.controller.settings.disclaimerAccepted,
      ),
    );
  }

  Future<void> _importCookies(String browser, String domain) async {
    final l10n = AppLocalizations.of(context)!;
    final settings = widget.controller.settings;
    final saveDir = settings.saveDirectory;
    final cookieFile =
        '$saveDir/.cookies/$domain'
        '_$browser.txt';
    final ytDlpPath = settings.ytDlpPath ?? 'yt-dlp';
    final service = CookieService();
    final result = await service.importFromBrowser(
      browser: browser,
      domain: domain,
      ytDlpPath: ytDlpPath,
      outputFile: cookieFile,
      localizations: l10n,
    );
    if (!result.success) {
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
    await service.saveConfigs(configs);
    final updated = settings.copyWith(cookieConfigs: configs);
    widget.controller.updateSettings(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.detail ?? l10n.cookieImportSuccess(domain)),
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

  void _doImport(String domain) {
    if (domain.isNotEmpty) {
      widget.onImport(_browser, domain);
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
                onPressed: () => _doImport(_domainCtrl.text.trim()),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(l10n.importBtn),
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
