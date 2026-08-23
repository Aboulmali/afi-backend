import 'package:flutter/material.dart';

class AppColors {
  // Light
  static const accent = Color(0xFF16A34A);
  static const accentHover = Color(0xFF15803D);
  static const accentActive = Color(0xFF166534);
  static const accentSoft = Color(0xFFDCFCE7);
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF5F5F7);
  static const surfaceWarm = Color(0xFFFBFBFD);
  static const fg = Color(0xFF1D1D1F);
  static const fg2 = Color(0xFF424245);
  static const muted = Color(0xFF6E6E73);
  static const meta = Color(0xFF86868B);
  static const border = Color(0xFFD2D2D7);
  static const borderSoft = Color(0xFFE8E8ED);
  static const success = Color(0xFF16A34A);
  static const warn = Color(0xFFF59E0B);
  static const warnSoft = Color(0xFFFEF3C7);
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0xFFFEE2E2);
  static const info = Color(0xFF3B82F6);
  static const infoSoft = Color(0xFFDBEAFE);
  static const chartGreen = Color(0xFF16A34A);
  static const chartGreen2 = Color(0xFF22C55E);
  static const chartGreen3 = Color(0xFF4ADE80);
  static const chartGreen4 = Color(0xFF86EFAC);
  static const chartWarn = Color(0xFFF59E0B);
  static const chartDanger = Color(0xFFEF4444);
  static const chartOther = Color(0xFF6B7280);
  static const toastSuccessBg = Color(0xFFDCFCE7);
  static const toastSuccessFg = Color(0xFF166534);
  static const toastErrorBg = Color(0xFFFEE2E2);
  static const toastErrorFg = Color(0xFF991B1B);
  static const toastWarnBg = Color(0xFFFEF3C7);
  static const toastWarnFg = Color(0xFF92400E);
  static const toastInfoBg = Color(0xFFDBEAFE);
  static const toastInfoFg = Color(0xFF1E40AF);
}

class AppDark {
  static const accent = Color(0xFF22C55E);
  static const accentSoft = Color(0xFF052E16);
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF1C1C1E);
  static const surfaceWarm = Color(0xFF161618);
  static const fg = Color(0xFFF5F5F7);
  static const fg2 = Color(0xFFA1A1A6);
  static const muted = Color(0xFF8E8E93);
  static const meta = Color(0xFF636366);
  static const border = Color(0xFF38383A);
  static const borderSoft = Color(0xFF2C2C2E);
  static const toastSuccessBg = Color(0xFF052E16);
  static const toastSuccessFg = Color(0xFF86EFAC);
  static const toastErrorBg = Color(0xFF450A0A);
  static const toastErrorFg = Color(0xFFFCA5A5);
  static const toastWarnBg = Color(0xFF451A03);
  static const toastWarnFg = Color(0xFFFCD34D);
  static const toastInfoBg = Color(0xFF172554);
  static const toastInfoFg = Color(0xFF93C5FD);
  static const infoSoft = Color(0xFF172554);
  static const dangerSoft = Color(0xFF450A0A);
  static const warnSoft = Color(0xFF451A03);
}

class AppTheme {
  static ThemeData light() => _build(false);
  static ThemeData dark() => _build(true);

  static ThemeData _build(bool isDark) {
    final accent = isDark ? AppDark.accent : AppColors.accent;
    final surface = isDark ? AppDark.surface : AppColors.surface;
    final fg = isDark ? AppDark.fg : AppColors.fg;
    final fg2 = isDark ? AppDark.fg2 : AppColors.fg2;
    final muted = isDark ? AppDark.muted : AppColors.muted;
    final meta = isDark ? AppDark.meta : AppColors.meta;
    final border = isDark ? AppDark.border : AppColors.border;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final bg = isDark ? AppDark.bg : AppColors.bg;
    final accentSoft = isDark ? AppDark.accentSoft : AppColors.accentSoft;

    const font = 'Inter';
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      fontFamily: font,
      splashFactory: InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: bg,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: fg, letterSpacing: -0.03),
        displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: fg, letterSpacing: -0.03),
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: fg, letterSpacing: -0.02),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: fg),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: fg),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: fg),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: fg, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: fg2, height: 1.4),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: muted, height: 1.4),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg),
        labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg2),
        labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: muted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontFamily: font, fontSize: 22, fontWeight: FontWeight.w700, color: fg),
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: meta, fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: borderSoft, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: fg, fontFamily: font),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return bg;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentSoft;
          return border;
        }),
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? accent : Colors.transparent),
        side: BorderSide(color: border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: muted,
        indicatorColor: accent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        dividerColor: Colors.transparent,
      ),
    );
  }
}

extension CtxX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
