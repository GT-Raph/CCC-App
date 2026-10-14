import 'package:flutter/material.dart';

/// Colours sampled from the "Church App (CCC)" Figma file.
class CccColors {
  static const primary = Color(0xFFE7B41F);
  static const primaryTint = Color(0xFFFFFCF2);
  static const navy = Color(0xFF000850);
  static const body = Color(0xFF454545);
  static const background = Color(0xFFEEEEEE);
  static const inactive = Color(0xFFCCCCCC);

  /// Secondary labels (inactive tabs, hints); 5:1 on white, unlike
  /// [inactive], which is only for decoration.
  static const muted = Color(0xFF6F6F6F);
  static const border = Color(0xFFDFDFDF);
  static const fieldBorder = Color(0xFFDCDCDC);
  static const notification = Color(0xFFFF0000);

  /// Error text; dark enough to read on white.
  static const error = Color(0xFFC62828);
  static const scrim = Color(0xE6080808);
  static const ink = Color(0xFF000000);
  static const paper = Color(0xFFFFFFFF);
}

class CccFonts {
  static const openSans = 'OpenSans';
  static const montserrat = 'Montserrat';
  static const playfair = 'PlayfairDisplay';
  static const script = 'Satisfy';
  static const contact = 'Lexend';
}

class CccShadows {
  /// Figma: 2px 2px 10px rgba(84, 84, 84, 0.2).
  static const raised = [
    BoxShadow(color: Color(0x33545454), offset: Offset(2, 2), blurRadius: 10),
  ];
}

class CccAssets {
  static const logo = 'assets/svg/church_logo.svg';
  static const churchIcon = 'assets/svg/church_icon.svg';
  static const socialButtons = 'assets/svg/social_buttons.svg';
  static const welcomeBackground = 'assets/images/welcome_background.jpg';
  static const headerBackground = 'assets/images/header_background.jpg';
  static const liveBadge = 'assets/images/live_badge.png';
}

ThemeData buildCccTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: CccFonts.openSans,
    scaffoldBackgroundColor: CccColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: CccColors.primary,
      primary: CccColors.primary,
      // Black on the brand yellow (white on it is only 1.9:1), for Material
      // widgets such as the date picker's selected day.
      onPrimary: CccColors.ink,
      surface: CccColors.paper,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: CccColors.primary,
      selectionHandleColor: CccColors.primary,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
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
