import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'app.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ToolboxBootstrap());
}

class ToolboxBootstrap extends StatefulWidget {
  const ToolboxBootstrap({super.key});

  @override
  State<ToolboxBootstrap> createState() => _ToolboxBootstrapState();
}

class _ToolboxBootstrapState extends State<ToolboxBootstrap> {
  final AppState _state = AppState();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await _state.flush();
        return AppExitResponse.exit;
      },
    );
    _state.load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(state: _state, child: const ToolboxApp());
  }
}
