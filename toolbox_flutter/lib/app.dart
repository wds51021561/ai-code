import 'package:flutter/material.dart';

import 'models/types.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);
}

extension AppStateContext on BuildContext {
  AppState get appState {
    final scope = dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing above this context');
    return scope!.notifier!;
  }
}

class ToolboxApp extends StatelessWidget {
  const ToolboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.appState.workspace.theme;
    return MaterialApp(
      title: 'Toolbox',
      debugShowCheckedModeBanner: false,
      theme: buildToolboxTheme(dark: false),
      darkTheme: buildToolboxTheme(dark: true),
      themeMode:
          theme == ThemeModeOption.dark ? ThemeMode.dark : ThemeMode.light,
      home: const HomeShell(),
    );
  }
}
