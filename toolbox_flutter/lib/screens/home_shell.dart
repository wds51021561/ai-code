import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models/types.dart';
import '../theme/app_theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/request_panel.dart';
import '../widgets/response_panel.dart';
import '../widgets/save_request_dialog.dart';
import '../widgets/sidebar.dart';
import 'env_manager_dialog.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Future<void> _send() async {
    final state = context.appState;
    if (state.sending) return;
    final result = await state.sendDraft();
    if (!mounted || result == null) return;
    if (result.error != null) {
      showToolboxToast(
        context,
        '请求失败',
        description: result.error,
        kind: ToastKind.error,
      );
    }
  }

  Future<void> _openEnvManager() async {
    final state = context.appState;
    state.setEnvManagerOpen(true);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const EnvManagerDialog(),
    );
    state.setEnvManagerOpen(false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    if (!state.hydrated) return const _LoadingScreen();

    final colors = context.colors;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!state.sending) _send();
        },
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
          if (!state.sending) _send();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.68, -1.05),
                radius: 1.35,
                colors: [
                  Color.alphaBlend(
                      colors.accent.withValues(alpha: 0.10), colors.canvas),
                  colors.canvas,
                ],
                stops: const [0, 0.68],
              ),
            ),
            child: Column(
              children: [
                _Header(onOpenEnvManager: _openEnvManager),
                Expanded(
                  child: _ApiClientBody(
                      onSend: _send,
                      onCancel: () async {
                        await state.cancelActiveRequest();
                        if (!context.mounted) return;
                        showToolboxToast(context, '请求已取消',
                            kind: ToastKind.info);
                      }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.68, -1.05),
            radius: 1.35,
            colors: [
              Color.alphaBlend(
                  colors.accent.withValues(alpha: 0.10), colors.canvas),
              colors.canvas,
            ],
            stops: const [0, 0.68],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BrandMark(size: 48, iconSize: 22),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '正在加载工作区',
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 32, this.iconSize = 16});
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C9CFF), Color(0xFFA78BFA), Color(0xFF4C6FE8)],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(Icons.handyman_rounded, size: iconSize, color: Colors.white),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onOpenEnvManager});
  final VoidCallback onOpenEnvManager;

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final colors = context.colors;
    final workspace = state.workspace;
    Environment? activeEnvironment;
    for (final environment in workspace.environments) {
      if (environment.id == workspace.activeEnvId) {
        activeEnvironment = environment;
        break;
      }
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.88),
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          const _BrandMark(),
          const SizedBox(width: 10),
          Text(
            'Toolbox',
            style: TextStyle(
              color: colors.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: colors.panel2,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: colors.line),
            ),
            child: Text(
              'DEV',
              style: TextStyle(
                color: colors.faint,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 20, color: colors.line),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.panel2.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.line),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.elevated,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: colors.line),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.send_rounded, size: 14, color: colors.accent),
                      const SizedBox(width: 7),
                      Text(
                        '接口请求',
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _EnvironmentSelector(
            activeEnvironmentName: activeEnvironment?.name,
            activeEnvId: workspace.activeEnvId,
            environments: workspace.environments,
          ),
          const SizedBox(width: 6),
          ToolboxButton(
            icon: const Icon(Icons.tune_rounded),
            variant: ToolboxButtonVariant.ghost,
            size: ToolboxButtonSize.iconSm,
            tooltip: '环境与变量',
            onPressed: onOpenEnvManager,
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: colors.line),
          const SizedBox(width: 8),
          ToolboxButton(
            icon: Icon(
              workspace.theme == ThemeModeOption.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            variant: ToolboxButtonVariant.ghost,
            size: ToolboxButtonSize.iconSm,
            tooltip:
                workspace.theme == ThemeModeOption.dark ? '切换到浅色主题' : '切换到深色主题',
            onPressed: state.toggleTheme,
          ),
        ],
      ),
    );
  }
}

class _EnvironmentSelector extends StatelessWidget {
  const _EnvironmentSelector({
    required this.activeEnvironmentName,
    required this.activeEnvId,
    required this.environments,
  });

  final String? activeEnvironmentName;
  final String? activeEnvId;
  final List<Environment> environments;

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final colors = context.colors;
    final value = activeEnvId ?? '';
    return Tooltip(
      message: activeEnvironmentName == null
          ? '未使用环境'
          : '当前环境：$activeEnvironmentName',
      child: Container(
        width: 172,
        height: 32,
        padding: const EdgeInsets.only(left: 9, right: 6),
        decoration: BoxDecoration(
          color: colors.panel2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            Icon(Icons.public_rounded, size: 13, color: colors.faint),
            const SizedBox(width: 5),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  isDense: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 14, color: colors.faint),
                  dropdownColor: colors.elevated,
                  borderRadius: BorderRadius.circular(8),
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 11.5,
                    fontFamily: uiFontFamily,
                  ),
                  items: [
                    DropdownMenuItem(
                        value: '',
                        child: Text('不使用环境',
                            style: TextStyle(
                                color: colors.muted, fontSize: 11.5))),
                    for (final environment in environments)
                      DropdownMenuItem(
                        value: environment.id,
                        child: Text(
                          environment.name.isEmpty ? '未命名环境' : environment.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                  ],
                  onChanged: (next) => state
                      .setActiveEnv(next == null || next.isEmpty ? null : next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiClientBody extends StatefulWidget {
  const _ApiClientBody({required this.onSend, required this.onCancel});
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  State<_ApiClientBody> createState() => _ApiClientBodyState();
}

class _ApiClientBodyState extends State<_ApiClientBody> {
  double _split = 52;
  String? _currentSavedId;
  bool _savedResetScheduled = false;

  SavedRequest? get _currentSaved {
    final state = context.appState;
    for (final saved in state.workspace.saved) {
      if (saved.id == _currentSavedId) return saved;
    }
    return null;
  }

  void _loadRequest(RequestConfig request, String? savedId) {
    context.appState.replaceDraft(request);
    setState(() => _currentSavedId = savedId);
  }

  void _newRequest() {
    context.appState.resetDraft();
    setState(() => _currentSavedId = null);
  }

  Future<void> _saveRequest() async {
    final state = context.appState;
    final current = _currentSaved;
    final name = await showSaveRequestDialog(
      context,
      initialName: current?.name ?? suggestedRequestName(state.workspace.draft),
      updating: current != null,
    );
    if (!mounted || name == null) return;
    final id = state.saveRequest(name, current?.id);
    setState(() => _currentSavedId = id);
    if (!mounted) return;
    showToolboxToast(
      context,
      current != null ? '收藏已更新' : '请求已保存',
      description: name,
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final colors = context.colors;
    if (_currentSavedId != null &&
        !state.workspace.saved.any((saved) => saved.id == _currentSavedId)) {
      if (!_savedResetScheduled) {
        _savedResetScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _currentSavedId = null;
            _savedResetScheduled = false;
          });
        });
      }
    } else {
      _savedResetScheduled = false;
    }
    return Row(
      children: [
        Sidebar(
          activeSavedId: _currentSavedId,
          onLoadRequest: _loadRequest,
          onNewRequest: _newRequest,
        ),
        Expanded(
          child: Container(
            color: colors.canvas,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                final minTop = 220.0;
                final maxTop = math.max(minTop, height - 180);
                final topHeight = (height * _split / 100).clamp(minTop, maxTop);

                return Column(
                  children: [
                    SizedBox(
                      height: topHeight,
                      child: RequestPanel(
                        sending: state.sending,
                        onSend: widget.onSend,
                        onCancel: widget.onCancel,
                        onSave: _saveRequest,
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeRow,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {
                          setState(() {
                            _split = (_split + details.delta.dy / height * 100)
                                .clamp(28, 76);
                          });
                        },
                        onDoubleTap: () => setState(() => _split = 52),
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: colors.panel,
                            border:
                                Border(bottom: BorderSide(color: colors.line)),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.drag_handle_rounded,
                              size: 12,
                              color: colors.faint,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ResponsePanel(
                        key: ValueKey(state.response),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
