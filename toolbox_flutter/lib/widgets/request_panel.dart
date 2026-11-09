import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models/defaults.dart';
import '../models/plugins.dart';
import '../models/types.dart';
import '../theme/app_theme.dart';
import '../utils.dart';
import 'code_editor.dart';
import 'common.dart';
import 'key_value_editor.dart';

enum _RequestTab { params, headers, body, auth, plugins, settings }

class RequestPanel extends StatefulWidget {
  const RequestPanel({
    super.key,
    required this.sending,
    required this.onSend,
    required this.onCancel,
    required this.onSave,
  });

  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  State<RequestPanel> createState() => _RequestPanelState();
}

class _RequestPanelState extends State<RequestPanel> {
  _RequestTab _tab = _RequestTab.params;

  static const _commonHeaders = [
    'Accept',
    'Accept-Encoding',
    'Accept-Language',
    'Authorization',
    'Cache-Control',
    'Content-Type',
    'Cookie',
    'Origin',
    'Referer',
    'User-Agent',
    'X-Request-Id',
    'X-Signature',
    'X-Timestamp',
    'X-Nonce',
  ];

  void _handleUrlBlur() {
    final draft = context.appState.workspace.draft;
    final hasParams = draft.params.any(
      (param) => param.key.trim().isNotEmpty || param.value.trim().isNotEmpty,
    );
    if (hasParams) return;
    final extracted = extractUrlQuery(draft.url);
    if (extracted == null) return;
    context.appState.updateDraft((request) {
      request.url = extracted.url;
      request.params = [...extracted.params, createEmptyKeyValue()];
    });
  }

  void _extractQuery() {
    final draft = context.appState.workspace.draft;
    final extracted = extractUrlQuery(draft.url);
    if (extracted == null) {
      showToolboxToast(context, '当前 URL 中没有查询参数', kind: ToastKind.info);
      return;
    }
    final existing = draft.params
        .where((param) =>
            param.key.trim().isNotEmpty || param.value.trim().isNotEmpty)
        .toList();
    context.appState.updateDraft((request) {
      request.url = extracted.url;
      request.params = [
        ...existing,
        ...extracted.params,
        createEmptyKeyValue()
      ];
    });
    showToolboxToast(context, '已把 URL 查询参数拆分到表格', kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final colors = context.colors;
    final draft = state.workspace.draft;
    final enabledPlugins =
        draft.plugins.where((plugin) => plugin.enabled).length;
    final activeParams = draft.params
        .where((param) => param.enabled && param.key.trim().isNotEmpty)
        .length;
    final activeHeaders = draft.headers
        .where((header) => header.enabled && header.key.trim().isNotEmpty)
        .length;

    return Container(
      color: colors.panel,
      child: Column(
        children: [
          _buildToolbar(context, draft),
          UnderlineTabs<_RequestTab>(
            items: [
              TabItem(
                  id: _RequestTab.params, label: 'Params', count: activeParams),
              TabItem(
                  id: _RequestTab.headers,
                  label: 'Headers',
                  count: activeHeaders),
              const TabItem(id: _RequestTab.body, label: 'Body'),
              const TabItem(id: _RequestTab.auth, label: 'Auth'),
              TabItem(
                  id: _RequestTab.plugins, label: '扩展', count: enabledPlugins),
              const TabItem(id: _RequestTab.settings, label: '设置'),
            ],
            value: _tab,
            onChanged: (value) => setState(() => _tab = value),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: _buildTabContent(context, draft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, RequestConfig draft) {
    final state = context.appState;
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          _MethodSelector(
            value: draft.method,
            onChanged: (method) =>
                state.updateDraft((request) => request.method = method),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BoundTextField(
              value: draft.url,
              onChanged: (value) =>
                  state.updateDraft((request) => request.url = value),
              onBlur: _handleUrlBlur,
              onSubmitted: (_) {
                if (!widget.sending) widget.onSend();
              },
              hintText: 'https://api.example.com/users 或 {{baseUrl}}/users',
              style: TextStyle(
                color: colors.ink,
                fontFamily: monoFontFamily,
                fontSize: 12.5,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              textInputAction: TextInputAction.go,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 86,
            child: ToolboxButton(
              label: widget.sending ? '取消' : '发送',
              icon: widget.sending
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.danger,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              variant: widget.sending
                  ? ToolboxButtonVariant.danger
                  : ToolboxButtonVariant.send,
              onPressed: widget.sending ? widget.onCancel : widget.onSend,
            ),
          ),
          const SizedBox(width: 8),
          ToolboxButton(
            label: '保存',
            icon: const Icon(Icons.bookmark_add_outlined),
            variant: ToolboxButtonVariant.secondary,
            tooltip: '保存请求（收藏）',
            onPressed: widget.onSave,
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, RequestConfig draft) {
    return switch (_tab) {
      _RequestTab.params => _Constrained(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHint(
                title: '查询参数',
                description:
                    '值支持 {{变量}}，发送时会自动 URL 编码。粘贴带 ?a=1 的 URL 并移开焦点时，参数会自动拆分到表格。',
                action: ToolboxButton(
                  label: '从 URL 拆分',
                  icon: const Icon(Icons.content_cut_rounded),
                  variant: ToolboxButtonVariant.ghost,
                  size: ToolboxButtonSize.sm,
                  onPressed: _extractQuery,
                ),
              ),
              const SizedBox(height: 12),
              KeyValueEditor(
                items: draft.params,
                onChange: (params) => context.appState
                    .updateDraft((request) => request.params = params),
                keyPlaceholder: '参数名',
                valuePlaceholder: '参数值',
              ),
            ],
          ),
        ),
      _RequestTab.headers => _Constrained(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHint(
                title: '请求头',
                description:
                    'Content-Type 会根据 Body 模式自动补全，也可以在这里手动覆盖。插件和认证写入的请求头同样会出现在实际请求中。',
              ),
              const SizedBox(height: 12),
              KeyValueEditor(
                items: draft.headers,
                onChange: (headers) => context.appState
                    .updateDraft((request) => request.headers = headers),
                keyPlaceholder: '请求头',
                valuePlaceholder: '值，支持 {{变量}}',
                keySuggestions: _commonHeaders,
              ),
            ],
          ),
        ),
      _RequestTab.body => _Constrained(child: _BodyPanel(draft: draft)),
      _RequestTab.auth => _Constrained(child: _AuthPanel(draft: draft)),
      _RequestTab.plugins => _Constrained(child: _PluginsPanel(draft: draft)),
      _RequestTab.settings => _Constrained(child: _SettingsPanel(draft: draft)),
    };
  }
}

class _Constrained extends StatelessWidget {
  const _Constrained({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({required this.value, required this.onChanged});
  final HttpMethod value;
  final ValueChanged<HttpMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = methodColor(colors, value);
    return Container(
      width: 104,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<HttpMethod>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 14, color: colors.faint),
          dropdownColor: colors.elevated,
          borderRadius: BorderRadius.circular(8),
          style: TextStyle(
            color: color,
            fontFamily: monoFontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          items: [
            for (final method in HttpMethod.values)
              DropdownMenuItem(
                value: method,
                child: Text(
                  method.value,
                  style: TextStyle(
                    color: methodColor(colors, method),
                    fontFamily: monoFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _BodyPanel extends StatelessWidget {
  const _BodyPanel({required this.draft});
  final RequestConfig draft;

  static const _modes = [
    (id: BodyMode.none, label: 'none'),
    (id: BodyMode.json, label: 'JSON'),
    (id: BodyMode.text, label: 'Text'),
    (id: BodyMode.formUrlencoded, label: 'Form URL'),
    (id: BodyMode.formData, label: 'Form Data'),
  ];

  void _setMode(BuildContext context, BodyMode mode) {
    final state = context.appState;
    state.updateDraft((request) {
      request.body.mode = mode;
      if (mode == BodyMode.json && request.body.raw.trim().isEmpty) {
        request.body.raw = '{\n  \n}';
      }
    });
  }

  void _formatJson(BuildContext context) {
    try {
      final decoded = jsonDecode(draft.body.raw);
      final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      context.appState.updateDraft((request) => request.body.raw = formatted);
      if (context.mounted) {
        showToolboxToast(context, 'JSON 已格式化', kind: ToastKind.success);
      }
    } catch (error) {
      if (context.mounted) {
        showToolboxToast(
          context,
          'JSON 格式错误',
          description: error.toString(),
          kind: ToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = draft.body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: SectionHint(
                title: '请求体',
                description: '支持 JSON、文本、表单编码和 multipart 文本字段；值支持 {{变量}}。',
              ),
            ),
            const SizedBox(width: 12),
            SegmentedTabs<BodyMode>(
              items: _modes,
              value: body.mode,
              onChanged: (mode) => _setMode(context, mode),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (body.mode == BodyMode.none)
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: colors.panel2.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.line),
            ),
            child: EmptyState(
              icon: Icons.info_outline_rounded,
              title: '该请求没有 Body',
              description: 'GET、HEAD 等请求通常不需要请求体',
              compact: true,
            ),
          )
        else if (body.mode == BodyMode.json || body.mode == BodyMode.text)
          _CodeBody(
            draft: draft,
            onFormat: () => _formatJson(context),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.panel2.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KeyValueEditor(
                  items: body.form,
                  onChange: (form) => context.appState
                      .updateDraft((request) => request.body.form = form),
                  keyPlaceholder: '字段名',
                  valuePlaceholder: '字段值，支持 {{变量}}',
                ),
                if (body.mode == BodyMode.formData) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: colors.line),
                  const SizedBox(height: 8),
                  Text(
                    '当前版本 multipart/form-data 支持文本字段，文件上传将在后续版本加入。',
                    style: TextStyle(color: colors.faint, fontSize: 10.5),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CodeBody extends StatelessWidget {
  const _CodeBody({required this.draft, required this.onFormat});
  final RequestConfig draft;
  final VoidCallback onFormat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isJson = draft.body.mode == BodyMode.json;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.panel2.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(
              top: BorderSide(color: colors.line),
              left: BorderSide(color: colors.line),
              right: BorderSide(color: colors.line),
            ),
          ),
          child: Row(
            children: [
              Text(
                isJson ? 'application/json' : 'text/plain',
                style: TextStyle(
                  color: colors.muted,
                  fontFamily: monoFontFamily,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${draft.body.raw.length} 字符',
                style: TextStyle(color: colors.faint, fontSize: 10),
              ),
              const Spacer(),
              if (isJson)
                ToolboxButton(
                  label: '格式化',
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  variant: ToolboxButtonVariant.ghost,
                  size: ToolboxButtonSize.sm,
                  onPressed: onFormat,
                ),
            ],
          ),
        ),
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: colors.panel2.withValues(alpha: 0.25),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border(
              left: BorderSide(color: colors.line),
              right: BorderSide(color: colors.line),
              bottom: BorderSide(color: colors.line),
            ),
          ),
          child: CodeEditor(
            value: draft.body.raw,
            language: isJson ? 'json' : 'text',
            placeholder: isJson ? '{\n  "name": "value"\n}' : '请输入文本内容',
            onChanged: (value) => context.appState
                .updateDraft((request) => request.body.raw = value),
          ),
        ),
      ],
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.draft});
  final RequestConfig draft;

  static const _types = [
    (id: AuthType.none, label: 'None'),
    (id: AuthType.bearer, label: 'Bearer'),
    (id: AuthType.basic, label: 'Basic'),
    (id: AuthType.apiKey, label: 'API Key'),
  ];

  void _patch(BuildContext context, void Function(AuthConfig auth) mutate) {
    context.appState.updateDraft((request) => mutate(request.auth));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = draft.auth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHint(
          title: '认证',
          description: '认证在请求插件之前应用。需要签名、加密等更复杂的认证流程时，可组合下方扩展插件。',
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedTabs<AuthType>(
            items: _types,
            value: auth.type,
            onChanged: (type) => _patch(context, (value) => value.type = type),
          ),
        ),
        const SizedBox(height: 16),
        if (auth.type == AuthType.none)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            decoration: BoxDecoration(
              color: colors.panel2.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.line),
            ),
            alignment: Alignment.center,
            child: Text(
              '当前请求不使用认证。',
              style: TextStyle(color: colors.muted, fontSize: 11.5),
            ),
          ),
        if (auth.type == AuthType.bearer)
          _LabeledField(
            label: 'Token',
            hint: '会写入 Authorization: Bearer <token>，支持 {{apiToken}}。',
            child: BoundTextField(
              value: auth.token,
              onChanged: (value) =>
                  _patch(context, (item) => item.token = value),
              hintText: '{{apiToken}}',
              style: TextStyle(
                  color: colors.ink,
                  fontFamily: monoFontFamily,
                  fontSize: 12.5),
            ),
          ),
        if (auth.type == AuthType.basic)
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: '用户名',
                  child: BoundTextField(
                    value: auth.username,
                    onChanged: (value) =>
                        _patch(context, (item) => item.username = value),
                    hintText: 'username',
                    style: TextStyle(
                        color: colors.ink,
                        fontFamily: monoFontFamily,
                        fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  label: '密码',
                  child: BoundTextField(
                    value: auth.password,
                    onChanged: (value) =>
                        _patch(context, (item) => item.password = value),
                    hintText: '{{password}}',
                    obscureText: true,
                    style: TextStyle(
                        color: colors.ink,
                        fontFamily: monoFontFamily,
                        fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        if (auth.type == AuthType.apiKey)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Key',
                  child: BoundTextField(
                    value: auth.key,
                    onChanged: (value) =>
                        _patch(context, (item) => item.key = value),
                    hintText: 'X-API-Key',
                    style: TextStyle(
                        color: colors.ink,
                        fontFamily: monoFontFamily,
                        fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 14,
                child: _LabeledField(
                  label: 'Value',
                  child: BoundTextField(
                    value: auth.value,
                    onChanged: (value) =>
                        _patch(context, (item) => item.value = value),
                    hintText: '{{apiToken}}',
                    style: TextStyle(
                        color: colors.ink,
                        fontFamily: monoFontFamily,
                        fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 128,
                child: _LabeledField(
                  label: '添加到',
                  child: _SmallDropdown<ApiKeyLocation>(
                    value: auth.addTo,
                    items: const [
                      (id: ApiKeyLocation.header, label: 'Header'),
                      (id: ApiKeyLocation.query, label: 'Query'),
                    ],
                    onChanged: (value) =>
                        _patch(context, (item) => item.addTo = value),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _PluginsPanel extends StatelessWidget {
  const _PluginsPanel({required this.draft});
  final RequestConfig draft;

  void _move(BuildContext context, String id, int direction) {
    final index = draft.plugins.indexWhere((plugin) => plugin.id == id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= draft.plugins.length) return;
    context.appState.updateDraft((request) {
      final next = [...request.plugins];
      final item = next.removeAt(index);
      next.insert(target, item);
      request.plugins = next;
    });
  }

  void _updatePlugin(
    BuildContext context,
    String id, {
    bool? enabled,
    Map<String, dynamic>? config,
  }) {
    context.appState.updateDraft((request) {
      for (final plugin in request.plugins) {
        if (plugin.id != id) continue;
        if (enabled != null) plugin.enabled = enabled;
        if (config != null) plugin.config = config;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.panel2.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.extension_rounded,
                    size: 16, color: colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '请求扩展',
                      style: TextStyle(
                        color: colors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '插件在发送前按列表顺序执行，在响应后逆序执行。适合接入签名、加密、解密、自定义请求头等企业网关规范。',
                      style: TextStyle(
                          color: colors.muted, fontSize: 11, height: 1.55),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < draft.plugins.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PluginCard(
              key: ValueKey(draft.plugins[index].id),
              definition: getPluginDefinition(draft.plugins[index].id),
              config: draft.plugins[index],
              index: index,
              total: draft.plugins.length,
              onToggle: (enabled) => _updatePlugin(
                  context, draft.plugins[index].id,
                  enabled: enabled),
              onConfigChange: (config) => _updatePlugin(
                  context, draft.plugins[index].id,
                  config: config),
              onMove: (direction) =>
                  _move(context, draft.plugins[index].id, direction),
            ),
          ),
      ],
    );
  }
}

class _PluginCard extends StatefulWidget {
  const _PluginCard({
    super.key,
    required this.definition,
    required this.config,
    required this.index,
    required this.total,
    required this.onToggle,
    required this.onConfigChange,
    required this.onMove,
  });

  final PluginDefinition? definition;
  final RequestPluginConfig config;
  final int index;
  final int total;
  final ValueChanged<bool> onToggle;
  final ValueChanged<Map<String, dynamic>> onConfigChange;
  final ValueChanged<int> onMove;

  @override
  State<_PluginCard> createState() => _PluginCardState();
}

class _PluginCardState extends State<_PluginCard> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  late String _committed;
  bool _expanded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _committed = jsonEncode(widget.config.config);
    _controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(widget.config.config),
    );
  }

  @override
  void didUpdateWidget(covariant _PluginCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = jsonEncode(widget.config.config);
    if (next != _committed) {
      _committed = next;
      _controller.text =
          const JsonEncoder.withIndent('  ').convert(widget.config.config);
      _error = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleConfigChanged(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        setState(() => _error = '配置必须是一个 JSON 对象');
        return;
      }
      final map = Map<String, dynamic>.from(decoded);
      _committed = jsonEncode(map);
      widget.onConfigChange(map);
      setState(() => _error = null);
    } catch (_) {
      setState(() => _error = 'JSON 格式不完整或无效，当前修改尚未应用');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final definition = widget.definition;
    if (definition == null) return const SizedBox.shrink();
    final enabled = widget.config.enabled;
    final isAes = definition.id == 'aes-256-gcm';

    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? colors.accentSoft.withValues(alpha: 0.35)
            : colors.panel2.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? colors.accent.withValues(alpha: 0.25) : colors.line,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: enabled
                        ? colors.accent.withValues(alpha: 0.10)
                        : colors.panel,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: enabled
                          ? colors.accent.withValues(alpha: 0.25)
                          : colors.line,
                    ),
                  ),
                  child: Icon(
                    isAes
                        ? Icons.lock_outline_rounded
                        : Icons.fingerprint_rounded,
                    size: 15,
                    color: enabled ? colors.accent : colors.faint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            definition.name,
                            style: TextStyle(
                              color: colors.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.panel2,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              definition.id,
                              style: TextStyle(
                                color: colors.faint,
                                fontFamily: monoFontFamily,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        definition.description,
                        style: TextStyle(
                            color: colors.muted, fontSize: 11, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ToolboxButton(
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  variant: ToolboxButtonVariant.ghost,
                  size: ToolboxButtonSize.iconSm,
                  tooltip: '上移',
                  onPressed: widget.index <= 0 ? null : () => widget.onMove(-1),
                ),
                ToolboxButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  variant: ToolboxButtonVariant.ghost,
                  size: ToolboxButtonSize.iconSm,
                  tooltip: '下移',
                  onPressed: widget.index >= widget.total - 1
                      ? null
                      : () => widget.onMove(1),
                ),
                const SizedBox(width: 4),
                _MiniSwitch(value: enabled, onChanged: widget.onToggle),
                const SizedBox(width: 4),
                ToolboxButton(
                  label: '配置',
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  variant: ToolboxButtonVariant.ghost,
                  size: ToolboxButtonSize.sm,
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: colors.line.withValues(alpha: 0.8))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 12, color: colors.faint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          definition.configHint,
                          style: TextStyle(
                              color: colors.faint,
                              fontSize: 10.5,
                              height: 1.45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _handleConfigChanged,
                    minLines: 5,
                    maxLines: 9,
                    style: TextStyle(
                      color: colors.ink,
                      fontFamily: monoFontFamily,
                      fontSize: 11.5,
                      height: 1.65,
                    ),
                    cursorColor: colors.accent,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colors.panel,
                      contentPadding: const EdgeInsets.all(10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _error == null
                              ? colors.line
                              : colors.danger.withValues(alpha: 0.6),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _error == null
                              ? colors.accent.withValues(alpha: 0.5)
                              : colors.danger.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _error ?? '配置支持 {{变量}}，有效 JSON 会立即保存到当前请求。',
                    style: TextStyle(
                      color: _error == null ? colors.faint : colors.danger,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 34,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? colors.accent : colors.lineStrong,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 140),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 3,
                    offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.draft});
  final RequestConfig draft;

  void _commitTimeout(BuildContext context, String value) {
    final parsed = int.tryParse(value) ?? 30000;
    final clamped = parsed.clamp(1000, 300000);
    context.appState
        .updateDraft((request) => request.settings.timeoutMs = clamped);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = draft.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHint(
          title: '请求设置',
          description: '控制超时、TLS 校验与代理。设置随当前请求一起保存。',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.panel2.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.line),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SettingLabel(
                      title: '超时时间',
                      description: '发起请求后等待响应的最长时间，范围 1 到 300 秒。',
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 220,
                    child: BoundTextField(
                      value: '${settings.timeoutMs}',
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed == null || parsed <= 0) return;
                        context.appState.updateDraft(
                          (request) => request.settings.timeoutMs = parsed,
                        );
                      },
                      onBlur: () =>
                          _commitTimeout(context, '${settings.timeoutMs}'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        color: colors.ink,
                        fontFamily: monoFontFamily,
                        fontSize: 12.5,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.panel2,
                        isDense: true,
                        suffixText: 'ms',
                        suffixStyle:
                            TextStyle(color: colors.faint, fontSize: 10),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: colors.accent.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: colors.line),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SettingLabel(
                      title: '校验 HTTPS 证书',
                      description: '关闭后允许自签名证书。仅建议在测试环境使用，会降低连接安全性。',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _MiniSwitch(
                      value: settings.rejectUnauthorized,
                      onChanged: (value) => context.appState.updateDraft(
                        (request) =>
                            request.settings.rejectUnauthorized = value,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: colors.line),
              const SizedBox(height: 14),
              _SettingLabel(
                title: 'HTTP 代理',
                description: '可选。支持 http:// 或 https:// 代理，留空表示直连。',
              ),
              const SizedBox(height: 8),
              BoundTextField(
                value: settings.proxyUrl,
                onChanged: (value) => context.appState.updateDraft(
                  (request) => request.settings.proxyUrl = value,
                ),
                hintText: 'http://127.0.0.1:7890',
                style: TextStyle(
                  color: colors.ink,
                  fontFamily: monoFontFamily,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.panel2.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 13, color: colors.faint),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '请求由 Flutter 运行时直接发送，不经过浏览器同源策略；仅支持 http/https，响应体最多读取 15 MB。',
                  style: TextStyle(
                      color: colors.faint, fontSize: 10.5, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child, this.hint});
  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: colors.muted, fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...[
          const SizedBox(height: 5),
          Text(
            hint!,
            style: TextStyle(color: colors.faint, fontSize: 10.5, height: 1.4),
          ),
        ],
      ],
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel({required this.title, required this.description});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              color: colors.ink, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(color: colors.muted, fontSize: 10.5, height: 1.45),
        ),
      ],
    );
  }
}

class _SmallDropdown<T> extends StatelessWidget {
  const _SmallDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<({T id, String label})> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: colors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 14, color: colors.faint),
          dropdownColor: colors.elevated,
          borderRadius: BorderRadius.circular(8),
          style: TextStyle(
              color: colors.ink, fontSize: 12, fontFamily: uiFontFamily),
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item.id,
                child: Text(item.label, style: const TextStyle(fontSize: 12)),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}
