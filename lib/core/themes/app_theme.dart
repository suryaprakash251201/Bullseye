import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'semantic_theme.dart';

class AppTheme {
  AppTheme._();

  // Core Brand Colors
  static const _primaryBrand = Color(0xFF00ACC1); // Cyan 600
  static const _secondaryBrand = Color(0xFF00BFA5); // Teal A700
  
  // Neutral Colors (Dark)
  static const _darkBg = Color(0xFF0D1117);
  static const _darkSurface = Color(0xFF161B22);
  static const _darkSurfaceContainer = Color(0xFF21262D);
  static const _darkOutline = Color(0xFF30363D);

  // Neutral Colors (Light)
  static const _lightBg = Color(0xFFF5F7FA);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceContainer = Color(0xFFEDF2F7);
  static const _lightOutline = Color(0xFFE2E8F0);

  // Deprecated/Legacy Colors (kept for compatibility)
  static const cyan = _primaryBrand;
  static const success = Color(0xFF00C853);
  static const error = Color(0xFFFF5252);
  static const info = Color(0xFF2196F3);
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
    return GoogleFonts.interTextTheme(base).apply(
      displayColor: textColor,
      bodyColor: textColor,
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    final colorScheme = ColorScheme.dark(
      primary: const Color(0xFF26C6DA), // Cyan 400
      onPrimary: Colors.black,
      secondary: const Color(0xFF64FFDA), // Teal A200
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
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // CardTheme removed due to type compatibility issue.
      // Default CardTheme uses surface color which matches our design.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8B949E),
          );
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
      onSurface: const Color(0xFF24292F),
      surfaceContainer: _lightSurfaceContainer,
      outline: _lightOutline,
      error: const Color(0xFFCF222E),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _lightBg,
      textTheme: _buildTextTheme(base.textTheme, const Color(0xFF24292F)),
      extensions: const [SemanticThemeColors.light],

      // Component Themes
      appBarTheme: AppBarTheme(
        backgroundColor: _lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF24292F),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF24292F)),
      ),
      // CardTheme removed due to type compatibility issue. 
      // Default CardTheme uses surface color which matches our design.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      dividerTheme: const DividerThemeData(
        color: _lightOutline,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurface,
        indicatorColor: colorScheme.primary.withAlpha(30),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return const IconThemeData(color: Color(0xFF57606A));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF57606A),
          );
        }),
      ),
    );
  }
}
