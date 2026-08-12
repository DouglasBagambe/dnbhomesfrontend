import 'package:flutter/material.dart';
import 'tokens.dart';

abstract final class AppTheme {
  static TextTheme _text(Color color) => TextTheme(
        displaySmall: TextStyle(
          fontSize: 36,
          height: 1.1,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
          color: color,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w600,
          letterSpacing: -.6,
          color: color,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
          color: color,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: color),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: color),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: color),
        labelLarge: TextStyle(
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      );
  static ThemeData get light => _build(
        Brightness.light,
        AppColors.canvas,
        AppColors.surface,
        AppColors.ink,
        AppColors.brand,
        AppColors.line,
      );
  static ThemeData get dark => _build(
        Brightness.dark,
        AppColors.darkCanvas,
        AppColors.darkSurface,
        const Color(0xFFF0F4F1),
        AppColors.brandDark,
        AppColors.darkLine,
      );
  static ThemeData _build(
    Brightness brightness,
    Color canvas,
    Color surface,
    Color ink,
    Color brand,
    Color line,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
      surface: surface,
    ).copyWith(primary: brand, surface: surface, outline: line);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: _text(ink),
      fontFamily: 'Roboto',
      dividerColor: line,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: line.withValues(alpha: .72)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: line),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: brand.withValues(alpha: .12),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: brand.withValues(alpha: .12),
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w600),
      ),
    );
  }
}
