import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox_flutter/theme/app_theme.dart';
import 'package:toolbox_flutter/widgets/file_dialog.dart';

void main() {
  testWidgets('file browser lists directories and json files', (tester) async {
    final temp = Directory.systemTemp.createTempSync('toolbox-file-dialog-');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    File('${temp.path}${Platform.pathSeparator}a.json').writeAsStringSync('{}');
    Directory('${temp.path}${Platform.pathSeparator}sub').createSync();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildToolboxTheme(dark: true),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSaveWorkspaceFileDialog(
                  context,
                  initialDirectory: temp.path,
                  suggestedName: 'toolbox-workspace.json',
                ),
                child: const Text('打开对话框'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开对话框'));
    await tester.pumpAndSettle();

    expect(find.text('导出工作区'), findsOneWidget);
    expect(find.text('a.json'), findsOneWidget);
    expect(find.text('sub'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });
}
