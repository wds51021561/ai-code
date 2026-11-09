import 'package:flutter/material.dart';

import '../app.dart';
import '../models/types.dart';
import '../theme/app_theme.dart';
import '../utils.dart';
import 'code_editor.dart';
import 'common.dart';

enum _ResponseTab { body, headers, request }

class ResponsePanel extends StatefulWidget {
  const ResponsePanel({super.key});

  @override
  State<ResponsePanel> createState() => _ResponsePanelState();
}

class _ResponsePanelState extends State<ResponsePanel> {
  _ResponseTab _tab = _ResponseTab.body;
  bool _formatted = true;

  @override
  Widget build(BuildContext context) {
    final state = context.appState;
    final colors = context.colors;
    final response = state.response;
    final sending = state.sending;
    final pretty = prettyJson(response?.body ?? '');

    return Container(
      color: colors.panel,
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.line)),
            ),
            child: Row(
              children: [
                Text(
                  '响应',
                  style: TextStyle(
                    color: colors.faint,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(width: 12),
                if (sending) ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('请求中',
                      style: TextStyle(color: colors.muted, fontSize: 11)),
                ] else if (response != null) ...[
                  StatusBadge(status: response.status),
                  if (response.statusText.isNotEmpty) ...[
                    const SizedBox(width: 7),
                    Text(
                      response.statusText,
                      style: TextStyle(color: colors.muted, fontSize: 11),
                    ),
                  ],
                  const SizedBox(width: 7),
                  Text('·',
                      style: TextStyle(color: colors.lineStrong, fontSize: 11)),
                  const SizedBox(width: 7),
                  Text(
                    formatDuration(response.duration),
                    style: TextStyle(
                      color: colors.muted,
                      fontFamily: monoFontFamily,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text('·',
                      style: TextStyle(color: colors.lineStrong, fontSize: 11)),
                  const SizedBox(width: 7),
                  Text(
                    formatBytes(response.size),
                    style: TextStyle(
                      color: colors.muted,
                      fontFamily: monoFontFamily,
                      fontSize: 10.5,
                    ),
                  ),
                  if (response.truncated) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '已截断',
                        style: TextStyle(color: colors.warning, fontSize: 9.5),
                      ),
                    ),
                  ],
                ] else
                  Text(
                    '尚未发送请求',
                    style: TextStyle(color: colors.faint, fontSize: 11),
                  ),
                const Spacer(),
                if (response != null && pretty.isJson)
                  ToolboxButton(
                    label: _formatted ? '原始' : '格式化',
                    icon: Icon(
                      _formatted
                          ? Icons.notes_rounded
                          : Icons.data_object_rounded,
                    ),
                    variant: ToolboxButtonVariant.ghost,
                    size: ToolboxButtonSize.sm,
                    onPressed: () => setState(() => _formatted = !_formatted),
                  ),
                ToolboxButton(
                  label: '复制',
                  icon: const Icon(Icons.content_copy_rounded),
                  variant: ToolboxButtonVariant.ghost,
                  size: ToolboxButtonSize.sm,
                  onPressed: response == null
                      ? null
                      : () => copyTextToClipboard(context, response.body,
                          message: '响应体已复制'),
                ),
              ],
            ),
          ),
          if (response != null || sending)
            UnderlineTabs<_ResponseTab>(
              items: [
                const TabItem(id: _ResponseTab.body, label: '响应体'),
                TabItem(
                  id: _ResponseTab.headers,
                  label: '响应头',
                  count: response?.headers.length ?? 0,
                ),
                const TabItem(id: _ResponseTab.request, label: '请求详情'),
              ],
              value: _tab,
              onChanged: (value) => setState(() => _tab = value),
              small: true,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          Expanded(
            child: _buildContent(
              context,
              response,
              sending,
              pretty,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SendResult? response,
    bool sending,
    PrettyJsonResult pretty,
  ) {
    final colors = context.colors;
    if (sending) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.panel2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.accent,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '正在等待响应',
              style: TextStyle(
                color: colors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '可以在请求栏点击「取消」中止请求',
              style: TextStyle(color: colors.faint, fontSize: 10.5),
            ),
          ],
        ),
      );
    }

    if (response == null) {
      return const EmptyState(
        icon: Icons.radio_button_checked_rounded,
        title: '发送请求后查看响应',
        description: '状态码、耗时、响应头与格式化后的响应体会显示在这里。按 Ctrl + Enter 快速发送。',
      );
    }

    final showPluginErrorBanner = response.error != null && response.status > 0;

    return Column(
      children: [
        if (showPluginErrorBanner)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.10),
              border: Border(
                bottom:
                    BorderSide(color: colors.warning.withValues(alpha: 0.20)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 14, color: colors.warning),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    response.error!,
                    style: TextStyle(
                        color: colors.warning, fontSize: 10.5, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: switch (_tab) {
            _ResponseTab.body => _ResponseBody(
                response: response,
                pretty: pretty,
                formatted: _formatted,
              ),
            _ResponseTab.headers => _HeadersTab(response: response),
            _ResponseTab.request => _RequestDetails(response: response),
          },
        ),
      ],
    );
  }
}

class _ResponseBody extends StatelessWidget {
  const _ResponseBody({
    required this.response,
    required this.pretty,
    required this.formatted,
  });

  final SendResult response;
  final PrettyJsonResult pretty;
  final bool formatted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (response.status == 0 && response.error != null) {
      return _RequestError(
          message: response.error!, url: response.finalUrl ?? '');
    }
    if (response.body.isEmpty) {
      return const EmptyState(
        icon: Icons.notes_rounded,
        title: '响应体为空',
        description: '服务端没有返回内容',
        compact: true,
      );
    }
    return Column(
      children: [
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.line)),
          ),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  response.contentType.isEmpty
                      ? 'unknown content type'
                      : response.contentType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.faint,
                    fontFamily: monoFontFamily,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text('·',
                  style: TextStyle(color: colors.lineStrong, fontSize: 10)),
              const SizedBox(width: 7),
              Text(
                '${response.body.length} 字符',
                style: TextStyle(
                  color: colors.faint,
                  fontFamily: monoFontFamily,
                  fontSize: 10,
                ),
              ),
              if (pretty.isJson) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 9, color: colors.success),
                      const SizedBox(width: 3),
                      Text('JSON',
                          style: TextStyle(color: colors.success, fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: CodeEditor(
            value: formatted && pretty.isJson ? pretty.text : response.body,
            language: pretty.isJson ? 'json' : 'text',
            readOnly: true,
          ),
        ),
      ],
    );
  }
}

class _HeadersTab extends StatelessWidget {
  const _HeadersTab({required this.response});
  final SendResult response;

  @override
  Widget build(BuildContext context) {
    if (response.headers.isEmpty) {
      return const EmptyState(
        icon: Icons.list_alt_rounded,
        title: '没有响应头',
        description: '服务端没有返回可显示的响应头',
        compact: true,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _ValueTable(
        rows: response.headers,
        firstColumn: '响应头',
      ),
    );
  }
}

class _RequestDetails extends StatelessWidget {
  const _RequestDetails({required this.response});
  final SendResult response;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.panel2.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '实际请求',
                  style: TextStyle(
                    color: colors.faint,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${response.request.method}  ',
                        style: TextStyle(
                          color: colors.accent,
                          fontFamily: monoFontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                      TextSpan(
                        text: response.finalUrl ?? response.request.url,
                        style: TextStyle(
                          color: colors.ink,
                          fontFamily: monoFontFamily,
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (response.pluginLog.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.accentSoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: colors.accent.withValues(alpha: 0.20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 11, color: colors.accent),
                      const SizedBox(width: 5),
                      Text(
                        '扩展执行日志',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  for (final item in response.pluginLog)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 10.5,
                                  height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            '请求头',
            style: TextStyle(
              color: colors.faint,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: response.request.headers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '没有请求头',
                      style: TextStyle(color: colors.faint, fontSize: 11),
                    ),
                  )
                : _ValueTable(
                    rows: response.request.headers,
                    firstColumn: '请求头',
                    embedded: true,
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            '请求体',
            style: TextStyle(
              color: colors.faint,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.panel2.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.line),
            ),
            child:
                response.request.body == null || response.request.body!.isEmpty
                    ? Text('无请求体',
                        style: TextStyle(color: colors.faint, fontSize: 11))
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            response.request.body!,
                            style: TextStyle(
                              color: colors.ink,
                              fontFamily: monoFontFamily,
                              fontSize: 11,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _RequestError extends StatelessWidget {
  const _RequestError({required this.message, required this.url});
  final String message;
  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: colors.danger.withValues(alpha: 0.20)),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  size: 22, color: colors.danger),
            ),
            const SizedBox(height: 14),
            Text(
              '请求失败',
              style: TextStyle(
                color: colors.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted, fontSize: 11, height: 1.55),
            ),
            if (url.isNotEmpty) ...[
              const SizedBox(height: 7),
              SelectableText(
                url,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.faint,
                  fontFamily: monoFontFamily,
                  fontSize: 10,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              '请检查 URL、网络连接、代理设置和 HTTPS 证书选项。若请求被取消，也会显示在这里。',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: colors.faint, fontSize: 10.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueTable extends StatelessWidget {
  const _ValueTable({
    required this.rows,
    required this.firstColumn,
    this.embedded = false,
  });

  final List<List<String>> rows;
  final String firstColumn;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: embedded ? null : BorderRadius.circular(12),
        border: embedded ? null : Border.all(color: colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.panel2.withValues(alpha: 0.5),
              border: Border(bottom: BorderSide(color: colors.line)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 230,
                  child: Text(
                    firstColumn,
                    style: TextStyle(
                      color: colors.faint,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '值',
                    style: TextStyle(
                      color: colors.faint,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < rows.length; index++)
            Container(
              decoration: BoxDecoration(
                border: index == rows.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                            color: colors.line.withValues(alpha: 0.7))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 230,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: colors.line)),
                    ),
                    child: Text(
                      rows[index][0],
                      style: TextStyle(
                        color: colors.muted,
                        fontFamily: monoFontFamily,
                        fontSize: 10.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: SelectableText(
                        rows[index].length > 1 ? rows[index][1] : '',
                        style: TextStyle(
                          color: colors.ink,
                          fontFamily: monoFontFamily,
                          fontSize: 10.5,
                          height: 1.45,
                        ),
                      ),
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
