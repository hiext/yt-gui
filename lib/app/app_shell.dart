import 'dart:async';

import 'package:flutter/material.dart';

import '../core/controllers/download_controller.dart';
import '../core/controllers/settings_controller.dart';
import '../core/services/download_scheduler.dart';
import '../core/services/process_yt_dlp_executor.dart';
import '../core/services/settings_repository.dart';
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
    }
    _downloadController = widget.downloadController ??
        DownloadController(
          scheduler: DownloadScheduler(
            settingsProvider: () => _settingsController.settings,
          ),
          executor: ProcessYtDlpExecutor(),
          settingsProvider: () => _settingsController.settings,
        );
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
              leading: const Padding(
                padding: EdgeInsets.only(top: 16),
                child: SectionCard(
                  title: 'Hiext YT GUI',
                  subtitle: 'yt-dlp 可视化下载器',
                  child: SizedBox(height: 1),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.add_link_outlined),
                  selectedIcon: Icon(Icons.add_link),
                  label: Text('新建下载'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.downloading_outlined),
                  selectedIcon: Icon(Icons.downloading),
                  label: Text('下载中'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: Text('历史记录'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('设置'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.help_outline),
                  selectedIcon: Icon(Icons.help),
                  label: Text('帮助'),
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
