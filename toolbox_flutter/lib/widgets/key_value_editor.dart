import 'package:flutter/material.dart';

import '../models/defaults.dart';
import '../models/types.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class KeyValueEditor extends StatefulWidget {
  const KeyValueEditor({
    super.key,
    required this.items,
    required this.onChange,
    this.keyPlaceholder = 'Key',
    this.valuePlaceholder = 'Value',
    this.addLabel = '添加一行',
    this.keySuggestions = const [],
  });

  final List<KeyValueItem> items;
  final ValueChanged<List<KeyValueItem>> onChange;
  final String keyPlaceholder;
  final String valuePlaceholder;
  final String addLabel;
  final List<String> keySuggestions;

  @override
  State<KeyValueEditor> createState() => _KeyValueEditorState();
}

class _KeyValueEditorState extends State<KeyValueEditor> {
  void _updateItem(String id, {bool? enabled, String? key, String? value}) {
    final next = widget.items.map((item) {
      if (item.id != id) return item;
      if (enabled != null) item.enabled = enabled;
      if (key != null) item.key = key;
      if (value != null) item.value = value;
      return item;
    }).toList();

    final index = next.indexWhere((item) => item.id == id);
    if (index >= 0 && index == next.length - 1) {
      final row = next[index];
      if (row.key.isNotEmpty || row.value.isNotEmpty) {
        next.add(createEmptyKeyValue());
      }
    }
    widget.onChange(next);
  }

  void _removeItem(String id) {
    final next = widget.items.where((item) => item.id != id).toList();
    widget.onChange(next.isEmpty ? [createEmptyKeyValue()] : next);
  }

  void _addItem() {
    widget.onChange([...widget.items, createEmptyKeyValue()]);
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
                flex: 9,
                child: Text(
                  'KEY',
                  style: TextStyle(
                    color: colors.faint,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 11,
                child: Text(
                  'VALUE',
                  style: TextStyle(
                    color: colors.faint,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(width: 34),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final item in widget.items)
          _KeyValueRow(
            key: ValueKey(item.id),
            item: item,
            keyPlaceholder: widget.keyPlaceholder,
            valuePlaceholder: widget.valuePlaceholder,
            keySuggestions: widget.keySuggestions,
            onToggle: (enabled) => _updateItem(item.id, enabled: enabled),
            onKeyChanged: (key) => _updateItem(item.id, key: key),
            onValueChanged: (value) => _updateItem(item.id, value: value),
            onDelete: () => _removeItem(item.id),
          ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _addItem,
          style: TextButton.styleFrom(
            foregroundColor: colors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.add_rounded, size: 14),
          label: Text(widget.addLabel, style: const TextStyle(fontSize: 11.5)),
        ),
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    super.key,
    required this.item,
    required this.keyPlaceholder,
    required this.valuePlaceholder,
    required this.keySuggestions,
    required this.onToggle,
    required this.onKeyChanged,
    required this.onValueChanged,
    required this.onDelete,
  });

  final KeyValueItem item;
  final String keyPlaceholder;
  final String valuePlaceholder;
  final List<String> keySuggestions;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<String> onValueChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
            border: Border.all(
              color: hovered ? colors.line : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Center(
                  child: InkWell(
                    onTap: () => onToggle(!item.enabled),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color:
                            item.enabled ? colors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color:
                              item.enabled ? colors.accent : colors.lineStrong,
                        ),
                      ),
                      child: item.enabled
                          ? Icon(Icons.check_rounded,
                              size: 11, color: colors.accentInk)
                          : null,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 9,
                child: BoundTextField(
                  value: item.key,
                  onChanged: onKeyChanged,
                  hintText: keyPlaceholder,
                  style: TextStyle(
                    color: item.enabled ? colors.ink : colors.faint,
                    fontSize: 12,
                    fontFamily: monoFontFamily,
                    decoration:
                        item.enabled ? null : TextDecoration.lineThrough,
                    decorationColor: colors.faint,
                  ),
                  decoration: _cellDecoration(
                    context,
                    keyPlaceholder,
                    suggestions: keySuggestions,
                    onSuggestion: onKeyChanged,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 11,
                child: BoundTextField(
                  value: item.value,
                  onChanged: onValueChanged,
                  hintText: valuePlaceholder,
                  style: TextStyle(
                    color: item.enabled ? colors.ink : colors.muted,
                    fontSize: 12,
                    fontFamily: monoFontFamily,
                  ),
                  decoration: _cellDecoration(context, valuePlaceholder),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
              SizedBox(
                width: 34,
                child: hovered
                    ? ToolboxButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        variant: ToolboxButtonVariant.ghost,
                        size: ToolboxButtonSize.iconSm,
                        tooltip: '删除此行',
                        onPressed: onDelete,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _cellDecoration(
    BuildContext context,
    String hint, {
    List<String> suggestions = const [],
    ValueChanged<String>? onSuggestion,
  }) {
    final colors = context.colors;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: colors.faint,
        fontSize: 12,
        fontFamily: uiFontFamily,
        fontStyle: FontStyle.normal,
      ),
      suffixIcon: suggestions.isEmpty
          ? null
          : PopupMenuButton<String>(
              tooltip: '常用请求头',
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: colors.faint,
              ),
              color: colors.elevated,
              onSelected: onSuggestion,
              itemBuilder: (context) => [
                for (final suggestion in suggestions)
                  PopupMenuItem<String>(
                    value: suggestion,
                    child: Text(
                      suggestion,
                      style: TextStyle(color: colors.ink, fontSize: 11.5),
                    ),
                  ),
              ],
            ),
      suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
