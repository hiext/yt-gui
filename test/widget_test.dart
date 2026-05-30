import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/app/hiext_yt_app.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('navigation switches sections', (tester) async {
    await tester.pumpWidget(const HiextYtApp());

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
