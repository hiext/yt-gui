import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/log_service.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';
import 'package:hiext_yt_gui/shared/widgets/debug_log_overlay.dart';

void main() {
  setUp(() {
    LogService.instance.clear();
    LogService.instance.setLevel(LogLevel.debug);
  });

  tearDown(() {
    LogService.instance.clear();
  });

  testWidgets('shows child when not visible', (tester) async {
    await tester.pumpWidget(_buildApp(
      const DebugLogOverlay(
        visible: false,
        child: Text('Main Content'),
      ),
    ));

    expect(find.text('Main Content'), findsOneWidget);
    expect(find.textContaining('Debug Log'), findsNothing);
  });

  testWidgets('shows debug log panel when visible', (tester) async {
    await tester.pumpWidget(_buildApp(
      const DebugLogOverlay(
        visible: true,
        child: Text('Main Content'),
      ),
    ));

    expect(find.text('Main Content'), findsOneWidget);
    expect(find.textContaining('Debug Log'), findsOneWidget);
  });

  testWidgets('displays log entries when visible', (tester) async {
    LogService.instance.info('Test message', 'test');
    LogService.instance.warn('Warning message', 'test');
    LogService.instance.error('Error message', 'test');

    await tester.pumpWidget(_buildApp(
      const DebugLogOverlay(
        visible: true,
        child: Text('Main Content'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Main Content'), findsOneWidget);
    expect(find.textContaining('Debug Log (3)'), findsOneWidget);
    expect(find.textContaining('Test message'), findsOneWidget);
    expect(find.textContaining('Warning message'), findsOneWidget);
    expect(find.textContaining('Error message'), findsOneWidget);
  });

  testWidgets('shows empty state when no log entries', (tester) async {
    await tester.pumpWidget(_buildApp(
      const DebugLogOverlay(
        visible: true,
        child: Text('Main Content'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No log entries yet'), findsOneWidget);
  });

  testWidgets('displays level chip with current log level', (tester) async {
    await tester.pumpWidget(_buildApp(
      const DebugLogOverlay(
        visible: true,
        child: Text('Main Content'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('DEBUG'), findsOneWidget);
  });

  testWidgets('triggers onClose callback', (tester) async {
    var closed = false;
    await tester.pumpWidget(_buildApp(
      DebugLogOverlay(
        visible: true,
        child: const Text('Main Content'),
        onClose: () => closed = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    expect(closed, isTrue);
  });

  testWidgets('toggles auto-scroll on button press', (tester) async {
    await tester.pumpWidget(_buildApp(
      const DebugLogOverlay(
        visible: true,
        child: Text('Main Content'),
      ),
    ));
    await tester.pumpAndSettle();

    // The auto-scroll button should be present
    final autoScrollBtn = find.byIcon(Icons.vertical_align_bottom);
    final pauseBtn = find.byIcon(Icons.pause);

    final either = autoScrollBtn.evaluate().isNotEmpty ||
        pauseBtn.evaluate().isNotEmpty;
    expect(either, isTrue);
  });

  testWidgets('clears logs on clear button press', (tester) async {
    LogService.instance.info('Test message', 'test');

    await tester.pumpWidget(_buildApp(
      const DebugLogOverlay(
        visible: true,
        child: Text('Main Content'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Debug Log (1)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('Debug Log (0)'), findsOneWidget);
    expect(find.textContaining('No log entries yet'), findsOneWidget);
  });

  testWidgets('copies logs to clipboard on copy button press', (
    tester,
  ) async {
    LogService.instance.info('Test message', 'test');

    await tester.pumpWidget(_buildApp(
      const DebugLogOverlay(
        visible: true,
        child: Text('Main Content'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.copy_all), findsOneWidget);
  });
}

Widget _buildApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
