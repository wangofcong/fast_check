import 'package:flutter_test/flutter_test.dart';

import 'package:fast_check/main.dart';
import 'helpers/test_setup.dart';

void main() {
  setupTestDatabase();

  testWidgets('App builds successfully with bottom navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FastCheckApp());
    await tester.pumpAndSettle();

    // 底部导航应显示四个标签
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    // 首页标题应显示
    expect(find.text('打卡提醒'), findsOneWidget);
  });
}
