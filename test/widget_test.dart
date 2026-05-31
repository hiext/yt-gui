import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/app/hiext_yt_app.dart';
import 'package:hiext_yt_gui/core/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUp(() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
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

    expect(find.text('新建下载'), findsWidgets);
    expect(find.text('下载中'), findsOneWidget);
    expect(find.text('历史记录'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('帮助'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsWidgets);
    expect(find.text('保存与画质'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pumpAndSettle();

    expect(find.text('没有历史'), findsOneWidget);
  });
}
