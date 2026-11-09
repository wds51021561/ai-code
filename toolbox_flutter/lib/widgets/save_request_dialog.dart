import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

Future<String?> showSaveRequestDialog(
  BuildContext context, {
  required String initialName,
  required bool updating,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _SaveRequestDialog(
      initialName: initialName,
      updating: updating,
    ),
  );
}

class _SaveRequestDialog extends StatefulWidget {
  const _SaveRequestDialog({
    required this.initialName,
    required this.updating,
  });

  final String initialName;
  final bool updating;

  @override
  State<_SaveRequestDialog> createState() => _SaveRequestDialogState();
}

class _SaveRequestDialogState extends State<_SaveRequestDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: colors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.line),
      ),
      child: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.updating ? '更新收藏' : '保存请求',
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.updating
                              ? '将覆盖当前收藏的请求内容，名称也可以一并修改。'
                              : '保存到左侧收藏列表，方便下次快速打开。',
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '请求名称',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                    style: TextStyle(color: colors.ink, fontSize: 13),
                    cursorColor: colors.accent,
                    decoration: InputDecoration(
                      hintText: '例如：获取用户详情',
                      hintStyle: TextStyle(color: colors.faint, fontSize: 12.5),
                      filled: true,
                      fillColor: colors.panel2,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
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
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: colors.panel2.withValues(alpha: 0.6),
                border: Border(top: BorderSide(color: colors.line)),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ToolboxButton(
                    label: '取消',
                    variant: ToolboxButtonVariant.ghost,
                    size: ToolboxButtonSize.sm,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  ToolboxButton(
                    label: widget.updating ? '更新' : '保存',
                    variant: ToolboxButtonVariant.primary,
                    size: ToolboxButtonSize.sm,
                    onPressed: _controller.text.trim().isEmpty ? null : _submit,
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
