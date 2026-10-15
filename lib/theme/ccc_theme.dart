import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand colours that stay the same in light and dark mode. Everything that
/// changes with the phone's appearance lives in [CccPalette].
class CccColors {
  /// The church's gold.
  static const primary = Color(0xFFE7B41F);

  /// Text and icons on gold: white on it is only 1.9:1.
  static const onPrimary = Color(0xFF000000);
  static const scrim = Color(0xB3000000);
}

/// The app's colours for one appearance, read with `context.palette`.
@immutable
class CccPalette extends ThemeExtension<CccPalette> {
  const CccPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.accentText,
    required this.accentTint,
    required this.error,
    required this.inverseSurface,
    required this.onInverseSurface,
  });

  final Brightness brightness;

  /// Behind everything.
  final Color background;

  /// Cards, sheets, bars and fields.
  final Color surface;

  /// Quiet fills inside a surface: search, placeholders, pressed rows.
  final Color surfaceAlt;

  /// Hairlines around cards and between rows.
  final Color line;

  /// Edges that must read as controls (outlined buttons, fields).
  final Color lineStrong;
  final Color text;

  /// Supporting copy; 7:1 or more on [surface].
  final Color textSecondary;

  /// Labels and meta; at least 4.5:1 on [background] and [surface].
  final Color textMuted;

  /// Gold that is dark enough to read as text in light mode.
  final Color accentText;

  /// A faint gold wash for selected or highlighted things.
  final Color accentTint;
  final Color error;

  /// Snackbars.
  final Color inverseSurface;
  final Color onInverseSurface;

  bool get isDark => brightness == Brightness.dark;

  static const light = CccPalette(
    brightness: Brightness.light,
    background: Color(0xFFF5F5F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEEDE9),
    line: Color(0xFFE4E2DD),
    lineStrong: Color(0xFFC9C6BF),
    text: Color(0xFF16140F),
    textSecondary: Color(0xFF57534B),
    textMuted: Color(0xFF6E6A62),
    accentText: Color(0xFF8A6500),
    accentTint: Color(0xFFFBF1D3),
    error: Color(0xFFC62828),
    inverseSurface: Color(0xFF1F1C17),
    onInverseSurface: Color(0xFFF3EFE7),
  );

  /// The welcome screen's warm night, carried through the app.
  static const dark = CccPalette(
    brightness: Brightness.dark,
    background: Color(0xFF13110D),
    surface: Color(0xFF1C1A16),
    surfaceAlt: Color(0xFF26231E),
    line: Color(0xFF2E2A24),
    lineStrong: Color(0xFF4A453D),
    text: Color(0xFFF3EFE7),
    textSecondary: Color(0xFFCBC4B7),
    textMuted: Color(0xFFA39C8F),
    accentText: Color(0xFFE7B41F),
    accentTint: Color(0xFF2B2414),
    error: Color(0xFFFF8A80),
    inverseSurface: Color(0xFFF3EFE7),
    onInverseSurface: Color(0xFF1C1A16),
  );

  @override
  CccPalette copyWith() => this;

  @override
  CccPalette lerp(CccPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return CccPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceAlt: mix(surfaceAlt, other.surfaceAlt),
      line: mix(line, other.line),
      lineStrong: mix(lineStrong, other.lineStrong),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      accentText: mix(accentText, other.accentText),
      accentTint: mix(accentTint, other.accentTint),
      error: mix(error, other.error),
      inverseSurface: mix(inverseSurface, other.inverseSurface),
      onInverseSurface: mix(onInverseSurface, other.onInverseSurface),
    );
  }
}

extension CccThemeContext on BuildContext {
  /// The app theme's palette; a theme without one (a bare MaterialApp) gets
  /// the built-in set for its brightness.
  CccPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<CccPalette>() ??
        (theme.brightness == Brightness.dark
            ? CccPalette.dark
            : CccPalette.light);
  }
}

/// The welcome screen's night palette, built around the church's gold.
class CccNight {
  /// Warm umber-black that sits well under gold.
  static const background = Color(0xFF13110D);
  static const text = Color(0xFFF6F3EC);

  /// Secondary text; 8.5:1 on [background].
  static const muted = Color(0xFFB5AEA1);

  /// The logo's construction lines continued across the screen.
  static const line = Color(0x52E7B41F);
  static const glow = Color(0x24E7B41F);

  /// Outlined buttons: a faint fill, and an edge at 3.4:1 on [background].
  static const buttonFill = Color(0x0FFFFFFF);
  static const buttonEdge = Color(0x5CFFFFFF);
}

class CccFonts {
  static const openSans = 'OpenSans';
}

class CccAssets {
  static const logo = 'assets/svg/church_logo.svg';
  static const socialButtons = 'assets/svg/social_buttons.svg';
  static const welcomeBackground = 'assets/images/welcome_background.jpg';
}

/// Status and navigation bar icons that read on [brightness].
SystemUiOverlayStyle cccSystemBars(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: brightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
  );
}

ThemeData buildCccTheme([Brightness brightness = Brightness.light]) {
  final p = brightness == Brightness.dark ? CccPalette.dark : CccPalette.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: CccColors.primary,
    onPrimary: CccColors.onPrimary,
    primaryContainer: p.accentTint,
    onPrimaryContainer: p.text,
    secondary: CccColors.primary,
    onSecondary: CccColors.onPrimary,
    error: p.error,
    onError: p.isDark ? Colors.black : Colors.white,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceAlt,
    surfaceContainerHighest: p.surfaceAlt,
    outline: p.lineStrong,
    outlineVariant: p.line,
    inverseSurface: p.inverseSurface,
    onInverseSurface: p.onInverseSurface,
    inversePrimary: CccColors.primary,
    shadow: Colors.black,
    scrim: Colors.black,
  );
  const shape10 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: CccFonts.openSans,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: p.text),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: CccColors.primary,
      selectionColor: CccColors.primary.withValues(alpha: 0.35),
      selectionHandleColor: CccColors.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.inverseSurface,
      actionTextColor: p.isDark ? p.onInverseSurface : CccColors.primary,
      contentTextStyle: TextStyle(
        fontFamily: CccFonts.openSans,
        fontSize: 14.5,
        height: 1.35,
        color: p.onInverseSurface,
      ),
      shape: shape10,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      titleTextStyle: TextStyle(
        fontFamily: CccFonts.openSans,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: p.text,
      ),
      contentTextStyle: TextStyle(
        fontFamily: CccFonts.openSans,
        fontSize: 15,
        height: 1.45,
        color: p.textSecondary,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CccColors.primary,
    ),
    listTileTheme: ListTileThemeData(
      textColor: p.text,
      iconColor: p.textSecondary,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.text, shape: shape10),
    ),
    extensions: [p],
  );
  return base.copyWith(
    textTheme: _withoutTracking(base.textTheme),
    primaryTextTheme: _withoutTracking(base.primaryTextTheme),
  );
}

/// Material 3 adds letter spacing to its text styles, which every Text and
/// TextField inherits. The design uses none.
TextTheme _withoutTracking(TextTheme theme) {
  TextStyle? untracked(TextStyle? style) => style?.copyWith(letterSpacing: 0);
  return TextTheme(
    displayLarge: untracked(theme.displayLarge),
    displayMedium: untracked(theme.displayMedium),
    displaySmall: untracked(theme.displaySmall),
    headlineLarge: untracked(theme.headlineLarge),
    headlineMedium: untracked(theme.headlineMedium),
    headlineSmall: untracked(theme.headlineSmall),
    titleLarge: untracked(theme.titleLarge),
    titleMedium: untracked(theme.titleMedium),
    titleSmall: untracked(theme.titleSmall),
    bodyLarge: untracked(theme.bodyLarge),
    bodyMedium: untracked(theme.bodyMedium),
    bodySmall: untracked(theme.bodySmall),
    labelLarge: untracked(theme.labelLarge),
    labelMedium: untracked(theme.labelMedium),
    labelSmall: untracked(theme.labelSmall),
  );
}
