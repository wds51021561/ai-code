import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const double _fontSize = 12.5;
const double _lineHeight = _fontSize * 1.65;
const int _highlightLimit = 200000;

class CodeEditor extends StatefulWidget {
  const CodeEditor({
    super.key,
    required this.value,
    this.onChanged,
    this.language = 'text',
    this.readOnly = false,
    this.placeholder,
  });

  final String value;
  final ValueChanged<String>? onChanged;
  final String language;
  final bool readOnly;
  final String? placeholder;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late final _HighlightingController _controller =
      _HighlightingController(text: widget.value);
  final ScrollController _textScroll = ScrollController();
  final ScrollController _gutterScroll = ScrollController();
  int _lineCount = 1;

  @override
  void initState() {
    super.initState();
    _lineCount = _countLines(widget.value);
    _textScroll.addListener(_syncGutter);
  }

  int _countLines(String text) {
    var count = 1;
    for (var index = 0; index < text.length; index++) {
      if (text.codeUnitAt(index) == 10) count++;
    }
    return count;
  }

  void _syncGutter() {
    if (!_gutterScroll.hasClients || !_textScroll.hasClients) return;
    final target = _textScroll.offset.clamp(
      0.0,
      _gutterScroll.position.maxScrollExtent,
    );
    if ((_gutterScroll.offset - target).abs() > 0.5) {
      _gutterScroll.jumpTo(target);
    }
  }

  @override
  void didUpdateWidget(covariant CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
      setState(() {
        _lineCount = _countLines(widget.value);
      });
    }
  }

  @override
  void dispose() {
    _textScroll.removeListener(_syncGutter);
    _textScroll.dispose();
    _gutterScroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    _controller.isJson = widget.language == 'json';
    _controller.colors = colors;

    final digits = math.max(2, '$_lineCount'.length);
    final gutterWidth = 18.0 + digits * 7.2;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: gutterWidth,
          color: Colors.transparent,
          child: ClipRect(
            child: ListView.builder(
              controller: _gutterScroll,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              itemExtent: _lineHeight,
              itemCount: _lineCount,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: colors.faint,
                        fontFamily: monoFontFamily,
                        fontSize: 10,
                        height: 1.65,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Container(width: 1, color: colors.line.withValues(alpha: 0.55)),
        Expanded(
          child: TextField(
            controller: _controller,
            scrollController: _textScroll,
            readOnly: widget.readOnly,
            showCursor: !widget.readOnly,
            maxLines: null,
            minLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            onChanged: (value) {
              setState(() {
                _lineCount = _countLines(value);
              });
              widget.onChanged?.call(value);
            },
            style: TextStyle(
              color: colors.ink,
              fontFamily: monoFontFamily,
              fontFamilyFallback: monoFontFallback,
              fontSize: _fontSize,
              height: 1.65,
            ),
            cursorColor: colors.accent,
            cursorWidth: 1.5,
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: TextStyle(
                color: colors.faint,
                fontFamily: monoFontFamily,
                fontSize: _fontSize,
                height: 1.65,
              ),
              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _HighlightingController extends TextEditingController {
  _HighlightingController({super.text});

  bool isJson = false;
  ToolboxColors? colors;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final composing = value.composing;
    if (withComposing && composing.isValid && !composing.isCollapsed) {
      return TextSpan(text: value.text, style: style);
    }
    final palette = colors;
    if (!isJson || palette == null || value.text.length > _highlightLimit) {
      return TextSpan(text: value.text, style: style);
    }
    return TextSpan(
      style: style,
      children: _highlightJson(value.text, style ?? const TextStyle(), palette),
    );
  }

  List<TextSpan> _highlightJson(
    String text,
    TextStyle baseStyle,
    ToolboxColors colors,
  ) {
    final spans = <TextSpan>[];
    final buffer = StringBuffer();
    var index = 0;

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString(), style: baseStyle));
      buffer.clear();
    }

    void addColored(String token, Color color, {FontWeight? weight}) {
      flush();
      spans.add(
        TextSpan(
          text: token,
          style: baseStyle.copyWith(color: color, fontWeight: weight),
        ),
      );
    }

    while (index < text.length) {
      final char = text[index];

      if (char == '"') {
        final start = index;
        index++;
        var escaped = false;
        while (index < text.length) {
          final current = text[index];
          if (escaped) {
            escaped = false;
          } else if (current == r'\') {
            escaped = true;
          } else if (current == '"') {
            index++;
            break;
          }
          index++;
        }
        final token = text.substring(start, index);
        var lookahead = index;
        while (lookahead < text.length &&
            (text[lookahead] == ' ' ||
                text[lookahead] == '\n' ||
                text[lookahead] == '\r' ||
                text[lookahead] == '\t')) {
          lookahead++;
        }
        final isKey = lookahead < text.length && text[lookahead] == ':';
        addColored(token, isKey ? colors.codeKey : colors.codeString);
        continue;
      }

      if (char == '-' ||
          (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57)) {
        final match =
            RegExp(r'-?\d+(\.\d+)?([eE][+-]?\d+)?').matchAsPrefix(text, index);
        if (match != null) {
          addColored(match.group(0)!, colors.codeNumber);
          index = match.end;
          continue;
        }
      }

      if (text.startsWith('true', index) || text.startsWith('false', index)) {
        final token = text.startsWith('true', index) ? 'true' : 'false';
        addColored(token, colors.codeBool);
        index += token.length;
        continue;
      }

      if (text.startsWith('null', index)) {
        addColored('null', colors.codeNull);
        index += 4;
        continue;
      }

      if ('{}[],:'.contains(char)) {
        addColored(char, colors.codePunct);
        index++;
        continue;
      }

      buffer.write(char);
      index++;
    }
    flush();
    return spans;
  }
}
