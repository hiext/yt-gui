import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/app/hiext_yt_app.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';
import 'sqlite_test_setup.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUp(() async {
    initTestSqlite();
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
          await db.execute(
            'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, source TEXT NOT NULL, status TEXT NOT NULL, progress REAL NOT NULL DEFAULT 0, data TEXT NOT NULL)');
          await db.execute(
            'CREATE TABLE cookie_configs (id INTEGER PRIMARY KEY AUTOINCREMENT, domain TEXT NOT NULL UNIQUE, data TEXT NOT NULL)');
        },
      ),
    );
    DatabaseService().useTestDatabase(db);
  });

  testWidgets('navigation switches sections', (tester) async {
    // Build app using real async (DB init happens outside fake async zone)
    await tester.runAsync(() async {
      await tester.pumpWidget(const HiextYtApp());
      // Wait for real DB load to complete
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    });

    final l10n = AppLocalizations.of(
      tester.element(find.byType(TextField).first),
    )!;

    expect(find.text(l10n.newDownload), findsWidgets);
    expect(find.text(l10n.downloading), findsOneWidget);
    expect(find.text(l10n.history), findsOneWidget);
    expect(find.text(l10n.settings), findsOneWidget);
    expect(find.text(l10n.help), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text(l10n.saveAndQuality), findsOneWidget);

    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pumpAndSettle();

    expect(find.text(l10n.noHistory), findsOneWidget);
  });
}
