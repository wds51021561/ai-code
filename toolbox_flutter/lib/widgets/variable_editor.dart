import 'package:flutter/material.dart';

import '../models/defaults.dart';
import '../models/types.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class VariableEditor extends StatefulWidget {
  const VariableEditor({
    super.key,
    required this.variables,
    required this.onChange,
  });

  final List<Variable> variables;
  final ValueChanged<List<Variable>> onChange;

  @override
  State<VariableEditor> createState() => _VariableEditorState();
}

class _VariableEditorState extends State<VariableEditor> {
  static const _suggestions = [
    'baseUrl',
    'apiToken',
    'signSecret',
    'cryptoKey',
    'accessKey',
    'userId',
    'tenantId',
  ];

  void _updateItem(
    String id, {
    bool? enabled,
    String? key,
    String? value,
    bool? secret,
  }) {
    final next = widget.variables.map((item) {
      if (item.id != id) return item;
      if (enabled != null) item.enabled = enabled;
      if (key != null) item.key = key;
      if (value != null) item.value = value;
      if (secret != null) item.secret = secret;
      return item;
    }).toList();

    final index = next.indexWhere((item) => item.id == id);
    if (index >= 0 && index == next.length - 1) {
      final row = next[index];
      if (row.key.isNotEmpty || row.value.isNotEmpty) {
        next.add(createEmptyVariable());
      }
    }
    widget.onChange(next);
  }

  void _removeItem(String id) {
    final next = widget.variables.where((item) => item.id != id).toList();
    widget.onChange(next.isEmpty ? [createEmptyVariable()] : next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 22),
              Expanded(
                flex: 8,
                child: Text(
                  '变量名',
                  style: TextStyle(
                    color: colors.faint,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 12,
                child: Text(
                  '值',
                  style: TextStyle(
                    color: colors.faint,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 30),
              const SizedBox(width: 28),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final variable in widget.variables)
          _VariableRow(
            key: ValueKey(variable.id),
            variable: variable,
            suggestions: _suggestions,
            onToggle: (enabled) => _updateItem(variable.id, enabled: enabled),
            onKeyChanged: (key) => _updateItem(variable.id, key: key),
            onValueChanged: (value) => _updateItem(variable.id, value: value),
            onSecretChanged: (secret) =>
                _updateItem(variable.id, secret: secret),
            onDelete: () => _removeItem(variable.id),
          ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () =>
              widget.onChange([...widget.variables, createEmptyVariable()]),
          style: TextButton.styleFrom(
            foregroundColor: colors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.add_rounded, size: 14),
          label: const Text('添加变量', style: TextStyle(fontSize: 11.5)),
        ),
      ],
    );
  }
}

class _VariableRow extends StatefulWidget {
  const _VariableRow({
    super.key,
    required this.variable,
    required this.suggestions,
    required this.onToggle,
    required this.onKeyChanged,
    required this.onValueChanged,
    required this.onSecretChanged,
    required this.onDelete,
  });

  final Variable variable;
  final List<String> suggestions;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<String> onValueChanged;
  final ValueChanged<bool> onSecretChanged;
  final VoidCallback onDelete;

  @override
  State<_VariableRow> createState() => _VariableRowState();
}

class _VariableRowState extends State<_VariableRow> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final variable = widget.variable;
    return HoverBuilder(
      builder: (context, hovered) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: hovered
                ? colors.panel2.withValues(alpha: 0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: hovered ? colors.line : Colors.transparent),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Center(
                  child: InkWell(
                    onTap: () => widget.onToggle(!variable.enabled),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: variable.enabled
                            ? colors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: variable.enabled
                              ? colors.accent
                              : colors.lineStrong,
                        ),
                      ),
                      child: variable.enabled
                          ? Icon(Icons.check_rounded,
                              size: 11, color: colors.accentInk)
                          : null,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 8,
                child: BoundTextField(
                  value: variable.key,
                  onChanged: widget.onKeyChanged,
                  hintText: '变量名',
                  style: TextStyle(
                    color: variable.enabled ? colors.ink : colors.faint,
                    fontSize: 12,
                    fontFamily: monoFontFamily,
                    decoration:
                        variable.enabled ? null : TextDecoration.lineThrough,
                  ),
                  decoration: _cellDecoration(context),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 12,
                child: BoundTextField(
                  value: variable.value,
                  onChanged: widget.onValueChanged,
                  hintText: variable.secret ? '敏感值' : '变量值',
                  obscureText: variable.secret && !_revealed,
                  obscureCharacter: '•',
                  style: TextStyle(
                    color: variable.enabled ? colors.ink : colors.muted,
                    fontSize: 12,
                    fontFamily: monoFontFamily,
                  ),
                  decoration: _cellDecoration(
                    context,
                    suffix: variable.secret
                        ? InkWell(
                            onTap: () => setState(() => _revealed = !_revealed),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                _revealed
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 14,
                                color: colors.faint,
                              ),
                            ),
                          )
                        : null,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
              SizedBox(
                width: 30,
                child: Center(
                  child: InkWell(
                    onTap: () => widget.onSecretChanged(!variable.secret),
                    borderRadius: BorderRadius.circular(5),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        variable.secret
                            ? Icons.shield_outlined
                            : Icons.shield_outlined,
                        size: 14,
                        color: variable.secret ? colors.accent : colors.faint,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: hovered
                    ? ToolboxButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        variant: ToolboxButtonVariant.ghost,
                        size: ToolboxButtonSize.iconSm,
                        tooltip: '删除变量',
                        onPressed: widget.onDelete,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _cellDecoration(BuildContext context, {Widget? suffix}) {
    final colors = context.colors;
    return InputDecoration(
      hintText: widget.variable.secret ? '敏感值' : '变量值',
      hintStyle: TextStyle(
        color: colors.faint,
        fontSize: 12,
        fontFamily: uiFontFamily,
      ),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      filled: false,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.accent.withValues(alpha: 0.45)),
      ),
    );
  }
}
