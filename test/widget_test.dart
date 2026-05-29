import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/app/hiext_yt_app.dart';

void main() {
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
    expect(find.text('常用设置'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pumpAndSettle();

    expect(find.text('已完成任务'), findsOneWidget);
  });
}
