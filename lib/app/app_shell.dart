import 'dart:async';

import 'package:flutter/material.dart';

import '../core/controllers/download_controller.dart';
import '../core/controllers/post_process_controller.dart';
import '../core/controllers/license_controller.dart';
import '../core/controllers/settings_controller.dart';
import '../core/services/ai_clip_analyzer_executor.dart';
import '../core/services/auto_clip_service.dart';
import '../core/services/auto_clip_orchestrator.dart';
import '../core/services/cookie_service.dart';
import '../core/services/download_scheduler.dart';
import '../core/services/post_process_repository.dart';
import '../core/services/process_yt_dlp_executor.dart';
import '../core/services/settings_repository.dart';
import '../core/services/task_repository.dart';
import '../features/clips/clip_library_page.dart';
import '../l10n/app_localizations.dart';
import '../features/downloads/downloads_page.dart';
import '../features/help/help_page.dart';
import '../features/history/history_page.dart';
import '../features/license/license_page.dart';
import '../features/home/home_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/widgets/debug_log_overlay.dart';
import '../shared/widgets/section_card.dart';
import '../core/services/log_service.dart';

enum AppSection { home, downloads, clips, history, license, settings, help }

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.settingsController, this.downloadController});

  final SettingsController? settingsController;
  final DownloadController? downloadController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.home;
  late final SettingsController _settingsController;
  late final DownloadController _downloadController;
  late final PostProcessController _postProcessController;
  late final LicenseController _licenseController;
  bool _startupDisclaimerHandled = false;
  bool _debugLogVisible = false;
  final _debugTapTimes = <DateTime>[];

  @override
  void initState() {
    super.initState();
    if (widget.settingsController != null) {
      _settingsController = widget.settingsController!;
    } else {
      _settingsController = SettingsController(
        repository: SettingsRepository(),
      );
      unawaited(_settingsController.load());
      unawaited(_loadCookieConfigs());
    }
    _settingsController.addListener(_handleSettingsChanged);
    _syncLogLevel();
    _licenseController = LicenseController();
    unawaited(_licenseController.load());
    LogService.instance.info(
      'AppShell init — settings loaded, disclaimer=${_settingsController.settings.disclaimerAccepted}',
      'app',
    );
    _postProcessController = PostProcessController(
      executor: AiClipAnalyzerExecutor(),
      settingsProvider: () => _settingsController.settings,
      repository: PostProcessRepository(),
      autoClipService: AutoClipService(
        entitlementsProvider: () => _licenseController.entitlements,
      ),
    );
    _downloadController =
        widget.downloadController ??
        DownloadController(
          scheduler: DownloadScheduler(
            settingsProvider: () => _settingsController.settings,
            entitlementsProvider: () => _licenseController.entitlements,
          ),
          executor: ProcessYtDlpExecutor(),
          settingsProvider: () => _settingsController.settings,
          taskRepository: TaskRepository(),
          postProcessController: _postProcessController,
          autoClipOrchestrator: AutoClipOrchestrator(
            entitlementsProvider: () => _licenseController.entitlements,
          ),
        );
    unawaited(_postProcessController.loadPendingTasks());
    unawaited(_downloadController.loadPendingTasks());
  }

  Future<void> _loadCookieConfigs() async {
    final configs = await CookieService().loadConfigs();
    final updated = _settingsController.settings.copyWith(
      cookieConfigs: configs,
    );
    _settingsController.updateSettings(updated);
  }

  @override
  void dispose() {
    _settingsController.removeListener(_handleSettingsChanged);
    _downloadController.dispose();
    _postProcessController.dispose();
    _settingsController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        controller: _downloadController,
        onShowDownloads: () => _selectSection(AppSection.downloads),
      ),
      DownloadsPage(controller: _downloadController),
      ClipLibraryPage(controller: _postProcessController),
      HistoryPage(controller: _downloadController),
      LicenseStatusPage(controller: _licenseController),
      SettingsPage(controller: _settingsController),
      const HelpPage(),
    ];

    final l10n = AppLocalizations.of(context)!;

    return DebugLogOverlay(
      visible: _debugLogVisible,
      onClose: () => setState(() => _debugLogVisible = false),
      child: Scaffold(
        body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _section.index,
                  onDestinationSelected: (index) {
                    setState(() {
                      _section = AppSection.values[index];
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: GestureDetector(
                      onTap: _onBrandTap,
                      child: SectionCard(
                        title: l10n.appTitle,
                        subtitle: l10n.appSubtitle,
                        child: const SizedBox(height: 1),
                      ),
                    ),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.add_link_outlined),
                      selectedIcon: const Icon(Icons.add_link),
                      label: Text(l10n.newDownload),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.downloading_outlined),
                      selectedIcon: const Icon(Icons.downloading),
                      label: Text(l10n.downloading),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.auto_awesome_motion_outlined),
                      selectedIcon: const Icon(Icons.auto_awesome_motion),
                      label: Text(l10n.clips),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.history_outlined),
                      selectedIcon: const Icon(Icons.history),
                      label: Text(l10n.history),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.workspace_premium_outlined),
                      selectedIcon: Icon(Icons.workspace_premium),
                      label: Text('升级'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: Text(l10n.settings),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.help_outline),
                      selectedIcon: const Icon(Icons.help),
                      label: Text(l10n.help),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(index: _section.index, children: pages),
                ),
              ],
            ),
          ),
      ),
    );
  }

  void _selectSection(AppSection section) {
    setState(() {
      _section = section;
    });
    LogService.instance.debug('Navigated to ${section.name}', 'nav');
  }

  void _onBrandTap() {
    final now = DateTime.now();
    _debugTapTimes.removeWhere(
      (t) => now.difference(t) > const Duration(minutes: 1),
    );
    _debugTapTimes.add(now);
    if (_debugTapTimes.length >= 3) {
      _debugTapTimes.clear();
      setState(() {
        _debugLogVisible = !_debugLogVisible;
      });
      LogService.instance.info(
        'Debug log panel ${_debugLogVisible ? "opened" : "closed"}',
        'debug',
      );
    }
  }

  void _handleSettingsChanged() {
    _syncLogLevel();
    if (_startupDisclaimerHandled ||
        !_settingsController.hasLoaded ||
        _settingsController.settings.disclaimerAccepted ||
        !mounted) {
      return;
    }
    _startupDisclaimerHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _settingsController.settings.disclaimerAccepted) {
        return;
      }
      unawaited(_showStartupDisclaimerDialog());
    });
  }

  void _syncLogLevel() {
    if (LogService.instance.level != _settingsController.settings.logLevel) {
      LogService.instance.setLevel(_settingsController.settings.logLevel);
    }
  }

  Future<void> _showStartupDisclaimerDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(l10n.disclaimerTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.disclaimerSubtitle,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.disclaimerBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                _settingsController.acknowledgeDisclaimer();
                Navigator.of(context).pop();
              },
              child: Text(l10n.disclaimerAcknowledge),
            ),
          ],
        );
      },
    );
  }
}
