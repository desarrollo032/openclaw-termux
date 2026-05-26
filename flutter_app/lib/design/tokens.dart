import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// Design Tokens — sistema de diseño unificado
// Inspirado en Linear, Vercel, Stripe
// ─────────────────────────────────────────────

/// Espaciado en grid de 4px — consistencia visual
class Spacing {
  Spacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Bordes redondeados — jerarquía visual
class RadiusTokens {
  RadiusTokens._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 18;
  static const double pill = 100;
}

/// Animaciones — duraciones consistentes
class AppDurations {
  AppDurations._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration pageTransition = Duration(milliseconds: 350);
}

/// Paleta de colores — marca y estados
class AppColors {
  AppColors._();

  // Marca — violeta-azulado moderno
  static const Color accent = Color(0xFF6C63FF);
  static const Color accentLight = Color(0xFFEEF0FF);
  static const Color accentDark = Color(0xFF3F37C9);
  static const Color accentSubtle = Color(0xFFA29BFE);

  // Dark mode
  static const Color darkBg = Color(0xFF0D0D12);
  static const Color darkSurface = Color(0xFF16161E);
  static const Color darkSurfaceAlt = Color(0xFF1E1E2A);
  static const Color darkSurfaceElevated = Color(0xFF28283A);
  static const Color darkBorder = Color(0xFF2A2A3E);

  // Light mode
  static const Color lightBg = Color(0xFFF8F9FE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF0F1FA);
  static const Color lightBorder = Color(0xFFE4E5F0);

  // Estados
  static const Color statusGreen = Color(0xFF22C55E);
  static const Color statusGreenBg = Color(0xFF052E16);
  static const Color statusAmber = Color(0xFFF59E0B);
  static const Color statusAmberBg = Color(0xFF451A03);
  static const Color statusRed = Color(0xFFEF4444);
  static const Color statusRedBg = Color(0xFF450A0A);
  static const Color statusGrey = Color(0xFF6B7280);

  // Texto
  static const Color mutedText = Color(0xFF6B7280);
  static const Color darkMutedText = Color(0xFF9CA3AF);

  // Sombras
  static List<BoxShadow> cardShadow(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withAlpha(80)
              : accent.withAlpha(10),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> cardShadowElevated(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withAlpha(120)
              : accent.withAlpha(16),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}

/// Construye un ColorScheme Material 3 para modo dark o light
ColorScheme _baseScheme({
  required bool isDark,
  Color? primary,
}) {
  if (isDark) {
    return ColorScheme.dark(
      primary: primary ?? AppColors.accent,
      onPrimary: Colors.white,
      secondary: primary ?? AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: Colors.white,
      onSurfaceVariant: AppColors.darkMutedText,
      error: AppColors.statusRed,
      onError: Colors.white,
      outline: AppColors.darkBorder,
    );
  }
  return ColorScheme.light(
    primary: primary ?? AppColors.accent,
    onPrimary: Colors.white,
    secondary: primary ?? AppColors.accent,
    onSecondary: Colors.white,
    surface: AppColors.lightBg,
    onSurface: const Color(0xFF0A0A0A),
    onSurfaceVariant: AppColors.mutedText,
    error: AppColors.statusRed,
    onError: Colors.white,
    outline: AppColors.lightBorder,
  );
}

/// Construye ThemeData completo a partir de un booleano isDark
/// Elimina la duplicación masiva usando un solo método parametrizado
ThemeData buildOpenClawTheme({
  required bool isDark,
  ColorScheme? dynamicScheme,
}) {
  final base = isDark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme);
  final cs = dynamicScheme ?? _baseScheme(isDark: isDark);

  // Colores contextuales light/dark
  final scaffoldBg = isDark ? AppColors.darkBg : AppColors.lightBg;
  final cardColor = isDark ? AppColors.darkSurface : AppColors.lightBg;
  final inputFill = isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface;
  final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
  final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightBg;
  final onSurfaceColor = isDark ? Colors.white : const Color(0xFF0A0A0A);

  return base.copyWith(
    scaffoldBackgroundColor: scaffoldBg,
    colorScheme: cs,
    textTheme: textTheme.apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scaffoldBg,
      foregroundColor: onSurfaceColor,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: onSurfaceColor,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardColor,
      shadowColor: Colors.black.withAlpha(isDark ? 80 : 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        side: BorderSide(color: borderColor),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xl,
          vertical: Spacing.lg - 2,
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white70 : onSurfaceColor,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xl,
          vertical: Spacing.lg - 2,
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        borderSide: const BorderSide(color: AppColors.statusRed),
      ),
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.lg - 2,
      ),
      labelStyle: GoogleFonts.inter(
        color: isDark ? AppColors.darkMutedText : AppColors.mutedText,
      ),
      hintStyle: GoogleFonts.inter(
        color: (isDark ? AppColors.darkMutedText : AppColors.mutedText)
            .withAlpha(120),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return AppColors.statusGrey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.accent.withAlpha(80);
        }
        return borderColor;
      }),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: borderColor,
      linearMinHeight: 4,
    ),
    dividerTheme: DividerThemeData(
      color: borderColor,
      space: 1,
      thickness: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceColor,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.xl),
        side: BorderSide(color: borderColor),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark
          ? AppColors.darkSurfaceElevated
          : const Color(0xFF0A0A0A),
      contentTextStyle: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.md + 2),
        side: isDark ? BorderSide(color: borderColor) : BorderSide.none,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: isDark ? AppColors.darkMutedText : AppColors.mutedText,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: 2,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return AppColors.statusGrey;
      }),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );
}
