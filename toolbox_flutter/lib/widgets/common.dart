import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/types.dart';
import '../theme/app_theme.dart';

enum ToolboxButtonVariant { primary, send, secondary, ghost, danger, soft }

enum ToolboxButtonSize { sm, md, icon, iconSm }

class ToolboxButton extends StatelessWidget {
  const ToolboxButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.variant = ToolboxButtonVariant.secondary,
    this.size = ToolboxButtonSize.md,
    this.tooltip,
    this.expand = false,
  });

  final String? label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final ToolboxButtonVariant variant;
  final ToolboxButtonSize size;
  final String? tooltip;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground, border, overlay) = switch (variant) {
      ToolboxButtonVariant.primary => (
          colors.accent,
          colors.accentInk,
          null,
          Colors.white
        ),
      ToolboxButtonVariant.send => (
          colors.send,
          colors.sendInk,
          null,
          Colors.white
        ),
      ToolboxButtonVariant.secondary => (
          colors.panel2,
          colors.ink,
          colors.line,
          colors.ink
        ),
      ToolboxButtonVariant.ghost => (
          Colors.transparent,
          colors.muted,
          null,
          colors.ink
        ),
      ToolboxButtonVariant.danger => (
          colors.danger.withValues(alpha: 0.10),
          colors.danger,
          colors.danger.withValues(alpha: 0.20),
          colors.danger
        ),
      ToolboxButtonVariant.soft => (
          colors.accentSoft,
          colors.accent,
          null,
          colors.accent
        ),
    };

    final (height, horizontal, fontSize, iconSize) = switch (size) {
      ToolboxButtonSize.sm => (28.0, 10.0, 12.0, 13.0),
      ToolboxButtonSize.md => (36.0, 14.0, 13.0, 15.0),
      ToolboxButtonSize.icon => (36.0, 0.0, 13.0, 16.0),
      ToolboxButtonSize.iconSm => (28.0, 0.0, 13.0, 15.0),
    };
    final square =
        size == ToolboxButtonSize.icon || size == ToolboxButtonSize.iconSm;

    final button = SizedBox(
      height: height,
      width: square ? height : (expand ? double.infinity : null),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: variant == ToolboxButtonVariant.ghost ||
                  variant == ToolboxButtonVariant.soft
              ? Colors.transparent
              : background.withValues(alpha: 0.45),
          disabledForegroundColor: foreground.withValues(alpha: 0.4),
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          minimumSize: Size(square ? height : 0, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                size == ToolboxButtonSize.sm || square ? 7 : 8),
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
          overlayColor: overlay.withValues(alpha: 0.08),
          textStyle: TextStyle(
            fontFamily: uiFontFamily,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              IconTheme(
                data: IconThemeData(size: iconSize, color: foreground),
                child: icon!,
              ),
            if (icon != null && label != null) const SizedBox(width: 6),
            if (label != null)
              Flexible(
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class MethodBadge extends StatelessWidget {
  const MethodBadge({super.key, required this.method, this.minWidth = 50});
  final HttpMethod method;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = methodColor(colors, method);
    return Container(
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        method.value,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontFamily: monoFontFamily,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final int status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = statusColor(colors, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status == 0 ? 'ERR' : '$status',
            style: TextStyle(
              color: color,
              fontFamily: monoFontFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class TabItem<T> {
  const TabItem({required this.id, required this.label, this.count});
  final T id;
  final String label;
  final int? count;
}

class UnderlineTabs<T> extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.small = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final List<TabItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  final bool small;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            for (final item in items)
              _UnderlineTab<T>(
                item: item,
                active: item.id == value,
                small: small,
                onTap: () => onChanged(item.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnderlineTab<T> extends StatelessWidget {
  const _UnderlineTab({
    required this.item,
    required this.active,
    required this.small,
    required this.onTap,
  });

  final TabItem<T> item;
  final bool active;
  final bool small;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 10 : 12,
          vertical: small ? 8 : 10,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? colors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: TextStyle(
                color: active ? colors.ink : colors.muted,
                fontSize: small ? 11.5 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (item.count != null && item.count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? colors.accentSoft : colors.panel2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${item.count}',
                  style: TextStyle(
                    color: active ? colors.accent : colors.faint,
                    fontFamily: monoFontFamily,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<({T id, String label})> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            InkWell(
              onTap: () => onChanged(item.id),
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      item.id == value ? colors.elevated : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border:
                      item.id == value ? Border.all(color: colors.line) : null,
                ),
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: item.id == value ? colors.ink : colors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BoundTextField extends StatefulWidget {
  const BoundTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.style,
    this.focusNode,
    this.onSubmitted,
    this.onBlur,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.obscureText = false,
    this.obscureCharacter,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.prefixIcon,
    this.contentPadding,
    this.decoration,
    this.enabled = true,
    this.autofocus = false,
    this.scrollController,
    this.textAlignVertical,
    this.inputFormatters,
    this.showBorder = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final TextStyle? style;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onBlur;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final bool obscureText;
  final String? obscureCharacter;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final EdgeInsets? contentPadding;
  final InputDecoration? decoration;
  final bool enabled;
  final bool autofocus;
  final ScrollController? scrollController;
  final TextAlignVertical? textAlignVertical;
  final List<TextInputFormatter>? inputFormatters;
  final bool showBorder;

  @override
  State<BoundTextField> createState() => _BoundTextFieldState();
}

class _BoundTextFieldState extends State<BoundTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) widget.onBlur?.call();
  }

  @override
  void didUpdateWidget(covariant BoundTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final baseDecoration = widget.decoration ??
        InputDecoration(
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          contentPadding: widget.contentPadding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          filled: true,
          fillColor: colors.panel2,
          isDense: true,
          border: widget.showBorder
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.line),
                )
              : InputBorder.none,
          enabledBorder: widget.showBorder
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.line),
                )
              : InputBorder.none,
          focusedBorder: widget.showBorder
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: colors.accent.withValues(alpha: 0.5)),
                )
              : InputBorder.none,
        );
    final decoration =
        widget.decoration != null && widget.contentPadding != null
            ? baseDecoration.copyWith(contentPadding: widget.contentPadding)
            : baseDecoration;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: widget.style ??
          TextStyle(
              color: colors.ink, fontSize: 12.5, fontFamily: uiFontFamily),
      maxLines: widget.expands ? null : widget.maxLines,
      minLines: widget.minLines,
      expands: widget.expands,
      obscureText: widget.obscureText,
      obscuringCharacter: widget.obscureCharacter ?? '•',
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      scrollController: widget.scrollController,
      textAlignVertical: widget.textAlignVertical,
      inputFormatters: widget.inputFormatters,
      cursorColor: colors.accent,
      decoration: decoration,
    );
  }
}

class HoverBuilder extends StatefulWidget {
  const HoverBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(context, _hovered),
    );
  }
}

class SectionHint extends StatelessWidget {
  const SectionHint({
    super.key,
    required this.title,
    required this.description,
    this.action,
  });

  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 11,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 12),
          action!,
        ],
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: 20, vertical: compact ? 24 : 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 44 : 48,
              height: compact ? 44 : 48,
              decoration: BoxDecoration(
                color: colors.panel2,
                borderRadius: BorderRadius.circular(compact ? 12 : 16),
                border: Border.all(color: colors.line),
              ),
              child: Icon(icon, size: compact ? 20 : 22, color: colors.faint),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.muted,
                fontSize: compact ? 12 : 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.faint,
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ToastKind { info, success, error }

OverlayEntry? _activeToast;
Timer? _toastTimer;

void showToolboxToast(
  BuildContext context,
  String title, {
  String? description,
  ToastKind kind = ToastKind.info,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final previous = _activeToast;
  if (previous != null) {
    try {
      previous.remove();
    } catch (_) {
      // The previous toast may already have been removed by its timer.
    }
  }
  _toastTimer?.cancel();

  late final OverlayEntry entry;
  void dismiss() {
    if (entry.mounted) entry.remove();
    if (identical(_activeToast, entry)) _activeToast = null;
  }

  entry = OverlayEntry(
    builder: (context) => _ToastOverlay(
      title: title,
      description: description,
      kind: kind,
      onDismiss: dismiss,
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(const Duration(seconds: 3), dismiss);
}

class _ToastOverlay extends StatelessWidget {
  const _ToastOverlay({
    required this.title,
    required this.description,
    required this.kind,
    required this.onDismiss,
  });

  final String title;
  final String? description;
  final ToastKind kind;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (kind) {
      ToastKind.info => colors.accent,
      ToastKind.success => colors.success,
      ToastKind.error => colors.danger,
    };
    final icon = switch (kind) {
      ToastKind.info => Icons.info_outline_rounded,
      ToastKind.success => Icons.check_circle_outline_rounded,
      ToastKind.error => Icons.error_outline_rounded,
    };
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width < 468 ? width - 48 : 420.0;

    return Positioned(
      right: 24,
      bottom: 24,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - value)),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: onDismiss,
            child: Container(
              width: maxWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: colors.elevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (description != null && description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            description!,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 10.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确认',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return AlertDialog(
        title: Text(title, style: TextStyle(fontSize: 15, color: colors.ink)),
        content: Text(
          message,
          style: TextStyle(fontSize: 13, height: 1.6, color: colors.muted),
        ),
        actions: [
          ToolboxButton(
            label: '取消',
            variant: ToolboxButtonVariant.ghost,
            size: ToolboxButtonSize.sm,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          ToolboxButton(
            label: confirmLabel,
            variant: ToolboxButtonVariant.danger,
            size: ToolboxButtonSize.sm,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

void copyTextToClipboard(BuildContext context, String text, {String? message}) {
  Clipboard.setData(ClipboardData(text: text));
  showToolboxToast(
    context,
    message ?? '已复制到剪贴板',
    kind: ToastKind.success,
  );
}
