import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox_flutter/app.dart';
import 'package:toolbox_flutter/models/defaults.dart';
import 'package:toolbox_flutter/screens/home_shell.dart';
import 'package:toolbox_flutter/state/app_state.dart';
import 'package:toolbox_flutter/theme/app_theme.dart';

void main() {
  testWidgets('renders the toolbox shell and request tabs', (tester) async {
    tester.view.physicalSize = const Size(1480, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState()..hydrate(createDefaultWorkspace());
    addTearDown(state.dispose);

    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildToolboxTheme(dark: true),
          home: const HomeShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Toolbox'), findsOneWidget);
    expect(find.text('接口请求'), findsOneWidget);
    expect(find.text('发送'), findsOneWidget);
    expect(find.text('Params'), findsOneWidget);
    expect(find.text('Headers'), findsOneWidget);
    expect(find.text('响应'), findsOneWidget);

    await tester.tap(find.byTooltip('环境与变量'));
    await tester.pumpAndSettle();
    expect(find.text('环境与变量'), findsOneWidget);
    expect(find.text('全局变量'), findsWidgets);
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('保存请求'), findsOneWidget);
    expect(find.text('请求名称'), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
  });

  testWidgets('renders all request tabs at the minimum window size',
      (tester) async {
    tester.view.physicalSize = const Size(1120, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState()..hydrate(createDefaultWorkspace());
    addTearDown(state.dispose);

    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildToolboxTheme(dark: true),
          home: const HomeShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['Body', 'Auth', '扩展', '设置', 'Params']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
  });
}
