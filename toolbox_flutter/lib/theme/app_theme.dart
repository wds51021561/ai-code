import 'package:flutter/material.dart';

import '../models/types.dart';

const String uiFontFamily = 'Microsoft YaHei UI';
const List<String> uiFontFallback = [
  'Microsoft YaHei',
  'Segoe UI',
  'sans-serif'
];
const String monoFontFamily = 'Cascadia Code';
const List<String> monoFontFallback = ['Consolas', 'Courier New', 'monospace'];

class ToolboxColors extends ThemeExtension<ToolboxColors> {
  const ToolboxColors({required this.dark});
  final bool dark;

  Color get canvas => dark ? const Color(0xFF0A0C10) : const Color(0xFFF3F6FA);
  Color get panel => dark ? const Color(0xFF10141A) : const Color(0xFFFFFFFF);
  Color get panel2 => dark ? const Color(0xFF151A22) : const Color(0xFFF3F6FA);
  Color get elevated =>
      dark ? const Color(0xFF1A202A) : const Color(0xFFFFFFFF);
  Color get line => dark ? const Color(0xFF222A35) : const Color(0xFFE2E8F1);
  Color get lineStrong =>
      dark ? const Color(0xFF303A49) : const Color(0xFFCBD5E4);
  Color get ink => dark ? const Color(0xFFE8EEF7) : const Color(0xFF172033);
  Color get muted => dark ? const Color(0xFF8D99AA) : const Color(0xFF5E6D83);
  Color get faint => dark ? const Color(0xFF5D6878) : const Color(0xFF94A3B8);
  Color get accent => dark ? const Color(0xFF7C9CFF) : const Color(0xFF4C6FE8);
  Color get accentSoft =>
      dark ? const Color(0x1F7C9CFF) : const Color(0x1A4C6FE8);
  Color get accentInk =>
      dark ? const Color(0xFF08101F) : const Color(0xFFFFFFFF);
  Color get success => dark ? const Color(0xFF3DDC97) : const Color(0xFF12855B);
  Color get warning => dark ? const Color(0xFFF4BD68) : const Color(0xFFB16C0C);
  Color get danger => dark ? const Color(0xFFFF7086) : const Color(0xFFD94B62);
  Color get send => dark ? const Color(0xFF35D08A) : const Color(0xFF169C67);
  Color get sendInk => dark ? const Color(0xFF03150C) : const Color(0xFFFFFFFF);
  Color get methodGet =>
      dark ? const Color(0xFF43D69A) : const Color(0xFF0D8F5D);
  Color get methodPost =>
      dark ? const Color(0xFFF4BD68) : const Color(0xFFB16C0C);
  Color get methodPut =>
      dark ? const Color(0xFF7C9CFF) : const Color(0xFF4568DC);
  Color get methodPatch =>
      dark ? const Color(0xFFC49BFF) : const Color(0xFF7C3AED);
  Color get methodDelete =>
      dark ? const Color(0xFFFF7086) : const Color(0xFFD94B62);
  Color get methodOther =>
      dark ? const Color(0xFF8D99AA) : const Color(0xFF64748B);
  Color get codeKey => dark ? const Color(0xFF8FB5FF) : const Color(0xFF2F5FC4);
  Color get codeString =>
      dark ? const Color(0xFF9FE3A5) : const Color(0xFF18794E);
  Color get codeNumber =>
      dark ? const Color(0xFFF4BD68) : const Color(0xFF9A5B00);
  Color get codeBool =>
      dark ? const Color(0xFFCE9DFF) : const Color(0xFF7C3AED);
  Color get codeNull =>
      dark ? const Color(0xFFFF8FA3) : const Color(0xFFC02D4B);
  Color get codePunct =>
      dark ? const Color(0xFF7C8798) : const Color(0xFF7B8798);
  Color get overlay => dark ? const Color(0xAD03060C) : const Color(0x57111827);
  Color get scrollThumb =>
      dark ? const Color(0xFF2B3543) : const Color(0xFFCBD5E4);

  @override
  ToolboxColors copyWith({bool? dark}) =>
      ToolboxColors(dark: dark ?? this.dark);

  @override
  ToolboxColors lerp(ThemeExtension<ToolboxColors>? other, double t) {
    if (other is! ToolboxColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension ToolboxThemeContext on BuildContext {
  ToolboxColors get colors =>
      Theme.of(this).extension<ToolboxColors>() ??
      const ToolboxColors(dark: true);
}

Color methodColor(ToolboxColors colors, HttpMethod method) {
  return switch (method) {
    HttpMethod.get => colors.methodGet,
    HttpMethod.post => colors.methodPost,
    HttpMethod.put => colors.methodPut,
    HttpMethod.patch => colors.methodPatch,
    HttpMethod.delete => colors.methodDelete,
    HttpMethod.head || HttpMethod.options => colors.methodOther,
  };
}

Color statusColor(ToolboxColors colors, int status) {
  if (status == 0) return colors.danger;
  if (status < 300) return colors.success;
  if (status < 500) return colors.warning;
  return colors.danger;
}

ThemeData buildToolboxTheme({required bool dark}) {
  final colors = ToolboxColors(dark: dark);
  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: colors.accent,
    onPrimary: colors.accentInk,
    secondary: colors.success,
    onSecondary: colors.sendInk,
    error: colors.danger,
    onError: colors.panel,
    surface: colors.panel,
    onSurface: colors.ink,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.canvas,
    canvasColor: colors.panel,
    dividerColor: colors.line,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: colors.panel2,
    fontFamily: uiFontFamily,
    fontFamilyFallback: uiFontFallback,
    extensions: [colors],
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
      fontFamily: uiFontFamily,
      fontFamilyFallback: uiFontFallback,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      textStyle: TextStyle(
          color: colors.ink, fontSize: 11.5, fontFamily: uiFontFamily),
      waitDuration: const Duration(milliseconds: 400),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(8),
      radius: const Radius.circular(999),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered)
            ? colors.lineStrong
            : colors.scrollThumb,
      ),
      crossAxisMargin: 2,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: colors.panel2,
      hintStyle: TextStyle(color: colors.faint, fontSize: 12.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.line),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.elevated,
      contentTextStyle: TextStyle(color: colors.ink, fontSize: 12),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.line),
      ),
    ),
  );
}
