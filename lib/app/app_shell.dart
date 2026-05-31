import 'dart:async';

import 'package:flutter/material.dart';

import '../core/controllers/download_controller.dart';
import '../core/controllers/settings_controller.dart';
import '../core/services/cookie_service.dart';
import '../core/services/download_scheduler.dart';
import '../core/services/process_yt_dlp_executor.dart';
import '../core/services/settings_repository.dart';
import '../core/services/task_repository.dart';
import '../l10n/app_localizations.dart';
import '../features/downloads/downloads_page.dart';
import '../features/help/help_page.dart';
import '../features/history/history_page.dart';
import '../features/home/home_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/widgets/section_card.dart';

enum AppSection { home, downloads, history, settings, help }

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
    _downloadController =
        widget.downloadController ??
        DownloadController(
          scheduler: DownloadScheduler(
            settingsProvider: () => _settingsController.settings,
          ),
          executor: ProcessYtDlpExecutor(),
          settingsProvider: () => _settingsController.settings,
          taskRepository: TaskRepository(),
        );
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
    _downloadController.dispose();
    _settingsController.dispose();
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
      HistoryPage(controller: _downloadController),
      SettingsPage(controller: _settingsController),
      const HelpPage(),
    ];

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
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
                child: SectionCard(
                  title: l10n.appTitle,
                  subtitle: l10n.appSubtitle,
                  child: const SizedBox(height: 1),
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
                  icon: const Icon(Icons.history_outlined),
                  selectedIcon: const Icon(Icons.history),
                  label: Text(l10n.history),
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
    );
  }

  void _selectSection(AppSection section) {
    setState(() {
      _section = section;
    });
  }
}
