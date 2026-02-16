import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'semantic_theme.dart';

class AppTheme {
  AppTheme._();

  // Core Brand Colors - Inspired by "Soft UI"
  static const _primaryBrand = Color(0xFF2979FF); // Vibrant Blue
  static const _secondaryBrand = Color(0xFF00E5FF); // Cyan Accent
  
  // Neutral Colors (Dark)
  static const _darkBg = Color(0xFF0D1117);
  static const _darkSurface = Color(0xFF161B22);
  static const _darkSurfaceContainer = Color(0xFF21262D);
  static const _darkOutline = Color(0xFF30363D);

  // Neutral Colors (Light)
  static const _lightBg = Color(0xFFF5F7FA); // Soft Blue-Grey
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceContainer = Color(0xFFFFFFFF);
  static const _lightOutline = Color(0xFFE2E8F0);

  // Deprecated/Legacy Colors (kept for compatibility)
  static const cyan = _primaryBrand;
  static const success = Color(0xFF00C853);
  static const error = Color(0xFFFF5252);
  static const info = _primaryBrand;
  static const warning = Color(0xFFFFAB00);
  
  static const darkCard = _darkSurface;
  static const lightCard = _lightSurface;
  static const darkBorder = _darkOutline;
  static const darkElevated = _darkSurfaceContainer;
  static const primaryLight = _primaryBrand;
  static const teal = _secondaryBrand;
  static const accent = _secondaryBrand;
  static const terminalBg = _darkBg;

  // Text Styling
  static TextTheme _buildTextTheme(TextTheme base, Color textColor) {
    return base.apply(
      fontFamily: GoogleFonts.inter().fontFamily,
      displayColor: textColor,
      bodyColor: textColor,
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    final colorScheme = ColorScheme.dark(
      primary: const Color(0xFF448AFF), // Lighter Blue for Dark Mode
      onPrimary: Colors.white,
      secondary: const Color(0xFF18FFFF), // Cyan Accent
      onSecondary: Colors.black,
      surface: _darkSurface,
      onSurface: const Color(0xFFC9D1D9),
      surfaceContainer: _darkSurfaceContainer,
      outline: _darkOutline,
      error: const Color(0xFFFF5252),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkBg,
      textTheme: _buildTextTheme(base.textTheme, const Color(0xFFC9D1D9)),
      extensions: const [SemanticThemeColors.dark],
      
      // Component Themes
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _darkOutline),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      dividerTheme: const DividerThemeData(
        color: _darkOutline,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkBg,
        indicatorColor: colorScheme.primary.withAlpha(50),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return const IconThemeData(color: Color(0xFF8B949E));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final baseStyle = TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8B949E),
          );
          
          if (states.contains(WidgetState.selected)) {
            return baseStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            );
          }
          return baseStyle;
        }),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    final colorScheme = ColorScheme.light(
      primary: _primaryBrand,
      onPrimary: Colors.white,
      secondary: _secondaryBrand,
      onSecondary: Colors.white,
      surface: _lightSurface,
      onSurface: const Color(0xFF1E293B), // Darker, cleaner text
      surfaceContainer: _lightSurfaceContainer,
      outline: _lightOutline,
      error: const Color(0xFFFF3D00),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _lightBg,
      textTheme: _buildTextTheme(base.textTheme, const Color(0xFF1E293B)),
      extensions: const [SemanticThemeColors.light],

      // Component Themes
      appBarTheme: AppBarTheme(
        backgroundColor: _lightBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E293B),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 4,
        shadowColor: Colors.black.withAlpha(20), // Soft shadow
        surfaceTintColor: Colors.white, // No tint
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide.none, // Clean look
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9), // Lighter Grey
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      dividerTheme: const DividerThemeData(
        color: _lightOutline,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurface,
        indicatorColor: colorScheme.primary.withAlpha(30),
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return const IconThemeData(color: Color(0xFF64748B));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final baseStyle = TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          );

          if (states.contains(WidgetState.selected)) {
            return baseStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            );
          }
          return baseStyle;
        }),
      ),
      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );
  }
}
