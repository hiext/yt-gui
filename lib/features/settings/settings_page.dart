import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/controllers/settings_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/cookie_service.dart';
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

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _saveDirCtrl = TextEditingController(text: s.saveDirectory);
    _qualityCtrl = TextEditingController(text: s.defaultQuality);
    _ytDlpCtrl = TextEditingController(text: s.ytDlpPath ?? '');
    _ffmpegCtrl = TextEditingController(text: s.ffmpegPath ?? '');
    widget.controller.addListener(_syncFromSettings);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromSettings);
    _saveDirCtrl.dispose();
    _qualityCtrl.dispose();
    _ytDlpCtrl.dispose();
    _ffmpegCtrl.dispose();
    super.dispose();
  }

  void _syncFromSettings() {
    final s = widget.controller.settings;
    _updateCtrlIfChanged(_saveDirCtrl, s.saveDirectory);
    _updateCtrlIfChanged(_qualityCtrl, s.defaultQuality);
    _updateCtrlIfChanged(_ytDlpCtrl, s.ytDlpPath ?? '');
    _updateCtrlIfChanged(_ffmpegCtrl, s.ffmpegPath ?? '');
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
        final settings = widget.controller.settings;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '设置',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('恢复默认'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '保存与画质',
              subtitle: '文件保存位置和默认下载质量。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const Key('save-directory-field'),
                    controller: _saveDirCtrl,
                    decoration: InputDecoration(
                      labelText: '保存目录',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        tooltip: '浏览目录',
                        onPressed: _browseDirectory,
                      ),
                    ),
                    onChanged: widget.controller.updateSaveDirectory,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('default-quality-field'),
                    controller: _qualityCtrl,
                    decoration: const InputDecoration(
                      labelText: '默认画质 / 格式',
                      helperText:
                          '例如 best、bestvideo+bestaudio 或 yt-dlp format id',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: widget.controller.updateDefaultQuality,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '外部工具',
              subtitle: 'yt-dlp 和 ffmpeg 的路径，留空则使用应用内置版本。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const Key('yt-dlp-path-field'),
                    controller: _ytDlpCtrl,
                    decoration: InputDecoration(
                      labelText: 'yt-dlp 路径',
                      helperText: '留空时使用应用内置 yt-dlp',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        tooltip: '浏览文件',
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
                      labelText: 'ffmpeg 路径',
                      helperText: '留空时使用应用内置 ffmpeg',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        tooltip: '浏览文件',
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
              title: '下载模式',
              subtitle: '控制并行任务数量和调度策略。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<DownloadMode>(
                    key: const Key('download-mode-field'),
                    // ignore: deprecated_member_use
                    value: settings.downloadMode,
                    decoration: const InputDecoration(
                      labelText: '调度模式',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DownloadMode.serial,
                        child: Text('串行下载 — 一个一个来'),
                      ),
                      DropdownMenuItem(
                        value: DownloadMode.queue,
                        child: Text('队列下载 — 排队等待'),
                      ),
                      DropdownMenuItem(
                        value: DownloadMode.concurrent,
                        child: Text('并发下载 — 同时进行'),
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
              title: '附加选项',
              subtitle: '下载时附带字幕和封面文件。',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('下载字幕'),
                    subtitle: const Text('启动 yt-dlp 时追加 --write-subs'),
                    value: settings.downloadSubtitles,
                    onChanged: widget.controller.updateDownloadSubtitles,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('下载封面'),
                    subtitle: const Text('启动 yt-dlp 时追加 --write-thumbnail'),
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
    widget.controller.updateSettings(DownloadSettings.defaults);
  }

  Future<void> _importCookies(String browser, String domain) async {
    final settings = widget.controller.settings;
    final cookieFile =
        '${settings.saveDirectory}/.cookies/${domain}_${browser}.txt';
    final service = CookieService();
    final ok = await service.importFromBrowser(
      browser: browser,
      domain: domain,
      ytDlpPath: settings.ytDlpPath ?? 'yt-dlp',
      outputFile: cookieFile,
    );
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cookie 导入失败，请确认浏览器已安装且已登录')),
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
        SnackBar(content: Text('已导入 $domain 的 cookies ($browser)')),
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
    // Use system file picker to choose a directory
    final result = await Process.run('zenity', [
      '--file-selection',
      '--directory',
      '--title=选择保存目录',
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
    final result = await Process.run('zenity', [
      '--file-selection',
      '--title=选择可执行文件',
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

  final List<String> _importedDomains = [];

  @override
  void initState() {
    super.initState();
    _importedDomains.addAll(widget.configs.map((c) => c.domain));
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    super.dispose();
  }

  List<String> get _availablePresets =>
      _presetSites.where((d) => !_importedDomains.contains(d)).toList();

  void _doImport(String domain) {
    if (domain.isNotEmpty) {
      widget.onImport(_browser, domain);
      setState(() => _importedDomains.add(domain));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Cookie 管理',
      subtitle: '从浏览器导入登录态，解决 YouTube 等网站的验证问题。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Browser selector + import
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _browser,
                  decoration: const InputDecoration(
                    labelText: '浏览器',
                    border: OutlineInputBorder(),
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _domainCtrl,
                        decoration: const InputDecoration(
                          labelText: '域名',
                          hintText: '输入域名后点导入',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onFieldSubmitted: (v) => _doImport(v.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _doImport(_domainCtrl.text.trim()),
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('导入'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Preset sites
          if (_availablePresets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('常用网站', style: Theme.of(context).textTheme.labelMedium),
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
  if (domain.contains('youtube') || domain.contains('youtu.be'))
    return Icons.play_circle_outline;
  if (domain.contains('bilibili')) return Icons.tv_outlined;
  if (domain.contains('twitter') || domain.contains('x.com'))
    return Icons.alternate_email;
  if (domain.contains('instagram')) return Icons.camera_alt_outlined;
  if (domain.contains('tiktok')) return Icons.music_note_outlined;
  if (domain.contains('facebook')) return Icons.people_outline;
  if (domain.contains('twitch')) return Icons.live_tv_outlined;
  if (domain.contains('reddit')) return Icons.forum_outlined;
  if (domain.contains('nicovideo')) return Icons.videocam_outlined;
  if (domain.contains('soundcloud')) return Icons.audiotrack_outlined;
  if (domain.contains('vimeo')) return Icons.play_circle_outline;
  if (domain.contains('pornhub') || domain.contains('xvideos'))
    return Icons.visibility_off_outlined;
  return Icons.language;
}

class _CookieTile extends StatelessWidget {
  const _CookieTile({
    required this.config,
    required this.onRemove,
    required this.onReimport,
  });

  final CookieConfig config;
  final VoidCallback onRemove;
  final VoidCallback onReimport;

  @override
  Widget build(BuildContext context) {
    final expired = config.isExpired;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        expired ? Icons.cookie_outlined : Icons.cookie,
        color: expired ? Colors.orange : Colors.green,
        size: 20,
      ),
      title: Text(config.domain, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        '${config.browser} · ${expired
            ? '已过期'
            : config.importedAt != null
            ? '${DateTime.now().difference(config.importedAt!).inDays} 天前'
            : '刚导入'}',
        style: TextStyle(fontSize: 12, color: expired ? Colors.orange : null),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: '重新导入',
            onPressed: onReimport,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: '删除',
            onPressed: onRemove,
          ),
        ],
      ),
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
    return InputDecorator(
      decoration: InputDecoration(
        labelText: '并发数量',
        helperText: enabled ? '同时下载 $value 个任务' : '仅并发模式下生效',
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
