import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import '../models/schema.dart';
import '../models/types.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/file_dialog.dart';
import '../widgets/variable_editor.dart';

const String _globalId = '__globals__';

class EnvManagerDialog extends StatefulWidget {
  const EnvManagerDialog({super.key});

  @override
  State<EnvManagerDialog> createState() => _EnvManagerDialogState();
}

class _EnvManagerDialogState extends State<EnvManagerDialog> {
  String _selectedId = _globalId;
  bool _initialized = false;
  String? _deleteTarget;
  Workspace? _pendingImport;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final workspace = context.appState.workspace;
    _selectedId = workspace.activeEnvId ??
        (workspace.environments.isEmpty
            ? _globalId
            : workspace.environments.first.id);
  }

  Environment? get _selectedEnvironment {
    final workspace = context.appState.workspace;
    for (final environment in workspace.environments) {
      if (environment.id == _selectedId) return environment;
    }
    return null;
  }

  bool get _isGlobal => _selectedId == _globalId;

  void _addEnvironment() {
    final id = context.appState.addEnvironment();
    setState(() => _selectedId = id);
  }

  Future<void> _exportWorkspace() async {
    final state = context.appState;
    final path = await showSaveWorkspaceFileDialog(
      context,
      initialDirectory: state.defaultDirectoryPath,
      suggestedName: state.defaultExportName,
    );
    if (!mounted || path == null) return;
    final outcome = await state.exportWorkspaceTo(path);
    if (!mounted) return;
    if (!outcome.ok) {
      showToolboxToast(
        context,
        '导出失败',
        description: outcome.error,
        kind: ToastKind.error,
      );
      return;
    }
    showToolboxToast(
      context,
      '工作区已导出',
      description: outcome.path,
      kind: ToastKind.success,
    );
  }

  Future<void> _importWorkspace() async {
    final state = context.appState;
    final path = await showOpenWorkspaceFileDialog(
      context,
      initialDirectory: state.defaultDirectoryPath,
    );
    if (!mounted || path == null) return;
    final outcome = await state.importWorkspaceFrom(path);
    if (!mounted) return;
    if (!outcome.ok) {
      showToolboxToast(
        context,
        '导入失败',
        description: outcome.error,
        kind: ToastKind.error,
      );
      return;
    }
    final normalized = normalizeWorkspace(outcome.data);
    if (normalized == null) {
      showToolboxToast(
        context,
        '导入失败',
        description: '文件不是有效的 Toolbox 工作区',
        kind: ToastKind.error,
      );
      return;
    }
    setState(() => _pendingImport = normalized);
    await _confirmImport();
  }

  Future<void> _confirmImport() async {
    final pending = _pendingImport;
    if (pending == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '导入工作区',
      message: '导入会覆盖当前的全部环境、全局变量、请求草稿、历史记录和收藏。建议先导出备份。确定继续吗？',
      confirmLabel: '导入并覆盖',
    );
    if (!confirmed || !mounted) return;
    context.appState.replaceWorkspace(pending);
    setState(() {
      _pendingImport = null;
      _selectedId = pending.activeEnvId ??
          (pending.environments.isEmpty
              ? _globalId
              : pending.environments.first.id);
    });
    showToolboxToast(context, '工作区已导入', kind: ToastKind.success);
  }

  Future<void> _deleteEnvironment() async {
    final target = _deleteTarget;
    if (target == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '删除环境',
      message: '删除后，该环境下的所有变量将被移除，且无法恢复。确定删除吗？',
      confirmLabel: '删除环境',
    );
    if (!confirmed || !mounted) return;
    context.appState.deleteEnvironment(target);
    final workspace = context.appState.workspace;
    setState(() {
      _deleteTarget = null;
      _selectedId = workspace.environments.isEmpty
          ? _globalId
          : workspace.environments.first.id;
    });
    showToolboxToast(context, '环境已删除', kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final colors = context.colors;
    final workspace = state.workspace;
    final selected = _selectedEnvironment;
    final active = selected != null && workspace.activeEnvId == selected.id;
    final size = MediaQuery.sizeOf(context);
    final width = math.min(1100.0, size.width - 48);
    final height = math.min(720.0, size.height - 72);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: colors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.line),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '环境与变量',
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '环境变量和全局变量可用于 URL、请求头、请求体、认证信息与插件配置。同名时环境变量优先。',
                          style: TextStyle(
                              color: colors.muted, fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  ToolboxButton(
                    icon: const Icon(Icons.close_rounded),
                    variant: ToolboxButtonVariant.ghost,
                    size: ToolboxButtonSize.iconSm,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.line),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 228,
                    decoration: BoxDecoration(
                      color: colors.panel2.withValues(alpha: 0.35),
                      border: Border(right: BorderSide(color: colors.line)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: Text(
                            '变量集合',
                            style: TextStyle(
                              color: colors.faint,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            children: [
                              _CollectionTile(
                                icon: Icons.data_object_rounded,
                                name: '全局变量',
                                count: workspace.globalVariables.length,
                                selected: _isGlobal,
                                onTap: () =>
                                    setState(() => _selectedId = _globalId),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                                child: Text(
                                  '环境',
                                  style: TextStyle(
                                    color: colors.faint,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              for (final environment in workspace.environments)
                                _CollectionTile(
                                  icon: Icons.public_rounded,
                                  name: environment.name.isEmpty
                                      ? '未命名环境'
                                      : environment.name,
                                  count: environment.variables.length,
                                  selected: environment.id == _selectedId,
                                  active:
                                      workspace.activeEnvId == environment.id,
                                  onTap: () => setState(
                                      () => _selectedId = environment.id),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: colors.line)),
                          ),
                          child: ToolboxButton(
                            label: '新建环境',
                            icon: const Icon(Icons.add_rounded),
                            variant: ToolboxButtonVariant.ghost,
                            size: ToolboxButtonSize.sm,
                            expand: true,
                            onPressed: _addEnvironment,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                          decoration: BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: colors.line)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _isGlobal
                                    ? _GlobalHeader()
                                    : _EnvironmentHeader(
                                        environment: selected,
                                        active: active,
                                        onNameChanged: (value) {
                                          if (selected != null) {
                                            context.appState.updateEnvironment(
                                              selected.id,
                                              name: value,
                                            );
                                          }
                                        },
                                        onSetActive: selected == null
                                            ? null
                                            : () => context.appState
                                                .setActiveEnv(selected.id),
                                      ),
                              ),
                              if (selected != null)
                                ToolboxButton(
                                  icon:
                                      const Icon(Icons.delete_outline_rounded),
                                  variant: ToolboxButtonVariant.ghost,
                                  size: ToolboxButtonSize.iconSm,
                                  tooltip: '删除环境',
                                  onPressed: () async {
                                    setState(() => _deleteTarget = selected.id);
                                    await _deleteEnvironment();
                                  },
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: VariableEditor(
                              key: ValueKey(_selectedId),
                              variables: _isGlobal
                                  ? workspace.globalVariables
                                  : (selected?.variables ?? []),
                              onChange: (variables) {
                                if (_isGlobal) {
                                  context.appState
                                      .setGlobalVariables(variables);
                                } else if (selected != null) {
                                  context.appState.updateEnvironment(
                                    selected.id,
                                    variables: variables,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: colors.line)),
                          ),
                          child: Text(
                            '变量按“全局 → 环境”顺序合并；值为空或未启用的变量会被忽略。',
                            style:
                                TextStyle(color: colors.faint, fontSize: 10.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.panel2.withValues(alpha: 0.6),
                border: Border(top: BorderSide(color: colors.line)),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  ToolboxButton(
                    label: '导入',
                    icon: const Icon(Icons.upload_file_rounded),
                    variant: ToolboxButtonVariant.ghost,
                    size: ToolboxButtonSize.sm,
                    onPressed: _importWorkspace,
                  ),
                  const SizedBox(width: 4),
                  ToolboxButton(
                    label: '导出',
                    icon: const Icon(Icons.download_rounded),
                    variant: ToolboxButtonVariant.ghost,
                    size: ToolboxButtonSize.sm,
                    onPressed: _exportWorkspace,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 12, color: colors.faint),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '导出文件包含敏感变量，请妥善保管',
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: colors.faint, fontSize: 10.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ToolboxButton(
                    label: '完成',
                    variant: ToolboxButtonVariant.primary,
                    size: ToolboxButtonSize.sm,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.icon,
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String name;
  final int count;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? colors.accent.withValues(alpha: 0.25)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 14, color: selected ? colors.accent : colors.faint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? colors.ink : colors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                '$count',
                style: TextStyle(
                  color: colors.faint,
                  fontFamily: monoFontFamily,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '全局变量',
              style: TextStyle(
                  color: colors.ink, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.panel2,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '始终生效',
                style: TextStyle(color: colors.muted, fontSize: 9.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '全局变量对所有环境生效，被当前环境中的同名变量覆盖。',
          style: TextStyle(color: colors.muted, fontSize: 11.5, height: 1.5),
        ),
      ],
    );
  }
}

class _EnvironmentHeader extends StatelessWidget {
  const _EnvironmentHeader({
    required this.environment,
    required this.active,
    required this.onNameChanged,
    required this.onSetActive,
  });

  final Environment? environment;
  final bool active;
  final ValueChanged<String> onNameChanged;
  final VoidCallback? onSetActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (environment == null) {
      return Text(
        '请选择环境',
        style: TextStyle(color: colors.muted, fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: BoundTextField(
                value: environment!.name,
                onChanged: onNameChanged,
                hintText: '环境名称',
                showBorder: false,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              ),
            ),
            const SizedBox(width: 10),
            if (active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '当前环境',
                      style: TextStyle(color: colors.success, fontSize: 10),
                    ),
                  ],
                ),
              )
            else
              ToolboxButton(
                label: '设为当前',
                variant: ToolboxButtonVariant.soft,
                size: ToolboxButtonSize.sm,
                onPressed: onSetActive,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '共 ${environment!.variables.length} 个变量，支持在请求中使用 ',
                style:
                    TextStyle(color: colors.muted, fontSize: 11.5, height: 1.5),
              ),
              TextSpan(
                text: '{{变量名}}',
                style: TextStyle(
                  color: colors.accent,
                  fontFamily: monoFontFamily,
                  fontSize: 10.5,
                ),
              ),
              TextSpan(
                text: '。',
                style: TextStyle(color: colors.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
