import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Brand colors - Premium Dark Neon Aesthetic 
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color primary = Color(0xFF06B6D4); // Electric Cyan
  static const Color primaryLight = Color(0xFF22D3EE);
  static const Color teal = Color(0xFF14B8A6);
  static const Color tealDark = Color(0xFF0F766E);
  static const Color cyan = Color(0xFF22D3EE);

  static const Color accent = Color(0xFF8B5CF6); // Deep Purple/Magenta
  static const Color accentLight = Color(0xFFA78BFA);

  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFB91C1C);
  static const Color info = Color(0xFF3B82F6);

  // Dark theme surface colors - Ultra modern deep darks
  static const Color darkBg = Color(0xFF040609); // Near pitch black
  static const Color darkSurface = Color(0xFF0C1220); // Deep navy tint
  static const Color darkCard = Color(0xFF111827); 
  static const Color darkElevated = Color(0xFF1F2937);
  static const Color darkBorder = Color(0xFF374151);

  // Light theme surface colors (Kept for fallback, though app is dark-first)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightElevated = Color(0xFFF1F5F9);

  // Terminal colors
  static const Color terminalGreen = Color(0xFF4ADE80);
  static const Color terminalBg = Color(0xFF000000);

  // Gradient presets - Enhanced for premium depth
  static const LinearGradient cardGradientDark = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardGradientLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)], // Cyan to Purple
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroGradientDark = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF0A0F1A), Color(0xFF040609)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient heroGradientLight = LinearGradient(
    colors: [Color(0xFFE0F7FA), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shadows - Added glowing effects
  static List<BoxShadow> get cardShadowDark => [
    BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 20, offset: const Offset(0, 8)),
    BoxShadow(color: primary.withAlpha(5), blurRadius: 20, spreadRadius: -5),
  ];
  static List<BoxShadow> get cardShadowLight => [
    BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 24, offset: const Offset(0, 10)),
  ];
  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(color: color.withAlpha(80), blurRadius: 20, spreadRadius: 4),
    BoxShadow(color: color.withAlpha(30), blurRadius: 40, spreadRadius: 8),
  ];

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.apply(fontFamily: GoogleFonts.outfit().fontFamily); // Changed to Outfit for a more modern tech look
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    final outfitFont = GoogleFonts.outfit().fontFamily;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.black,
        secondary: accent, 
        onSecondary: Colors.white,
        tertiary: teal,
        surface: darkSurface,
        onSurface: Colors.white,
        error: error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkBg,
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, // Fully transparent for glassmorphism
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: outfitFont,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // More rounded
          side: const BorderSide(color: Color(0xFF1E293B), width: 1), // Subtle border
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent, // Handled by AppBottomNav glassmorphism
        selectedItemColor: primary,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: primary.withAlpha(40),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: outfitFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return TextStyle(
            fontFamily: outfitFont,
            fontSize: 12,
            color: Colors.white54,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkElevated.withAlpha(150), // Semi-transparent
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: darkBorder.withAlpha(150)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkElevated,
        selectedColor: primary.withAlpha(40),
        labelStyle: const TextStyle(color: Colors.white70),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: darkBorder.withAlpha(100)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelStyle: TextStyle(
          fontFamily: outfitFont,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: outfitFont,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1E293B), // Subtle slate divider
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primary.withAlpha(50)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        elevation: 24,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return darkElevated;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    final outfitFont = GoogleFonts.outfit().fontFamily;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        tertiary: teal,
        surface: lightSurface,
        onSurface: const Color(0xFF0F172A),
        error: error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: lightBg,
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: outfitFont,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: lightBorder),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: primary.withAlpha(30),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: outfitFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return TextStyle(
            fontFamily: outfitFont,
            fontSize: 12,
            color: const Color(0xFF64748B),
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightElevated,
        selectedColor: primary.withAlpha(30),
        labelStyle: const TextStyle(color: Color(0xFF334155)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: lightBorder),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelStyle: TextStyle(
          fontFamily: outfitFont,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: outfitFont,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: lightBorder),
        ),
        elevation: 12,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return lightElevated;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: lightBorder),
        ),
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
