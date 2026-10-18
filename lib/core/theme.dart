import 'package:flutter/material.dart';

/// CIT-U Theme System for TeknoyCart
/// Curated modern color tokens matching institutional Maroon & Gold.
class TeknoyTheme {
  TeknoyTheme._();

  // Core Theme Colors (Curated HSL-derived shades for premium high-contrast accessibility)
  static const Color citMaroon = Color(0xFF800000); // Primary deep institutional Maroon
  static const Color citMaroonLight = Color(0xFFB22222); // Interactive accent Crimson
  static const Color citMaroonDark = Color(0xFF4A0000); // Deep background Burgundy

  static const Color citGold = Color(0xFFF5B041); // Vibrant warm gold accent
  static const Color citGoldLight = Color(0xFFFCDD7B); // Glowing warm highlights

  // Neutral Tones (HSL Tailored Dark Mode)
  static const Color darkBg = Color(0xFF0F0F12); // Unified app-wide dark canvas (matches the #0F0F12 used across views)
  static const Color darkSurface = Color(0xFF141418); // Floating container surface
  static const Color darkBorder = Color(0xFF22222A); // Micro-divider/border gray

  // Neutral Tones (Light Mode)
  static const Color lightBg = Color(0xFFF6F6F9); // Clean campus background
  static const Color lightSurface = Color(0xFFFFFFFF); // Container surface
  static const Color lightBorder = Color(0xFFECECEF); // Micro-divider/border

  // Extended Dark Neutral Scale — view-level live values captured as named tokens (wave 7b; values frozen byte-identical)
  static const Color darkFill = Color(0xFF14141A); // Deepest fill: page-local form/section backgrounds
  static const Color darkSurfaceAlt = Color(0xFF16161A); // Card surface used by profile/KYC cards
  static const Color darkSurfaceHigh = Color(0xFF191922); // Card surface used by cart/inbox/notification cards
  static const Color darkSurfaceRaised = Color(0xFF1E1E28); // Raised surface: sheets and tray-style containers
  static const Color darkCardBorder = Color(0xFF1E1E24); // Card outline (dark theme) + dark chip surface
  static const Color darkHover = Color(0xFF1E1E26); // Pointer hover + secondary dark field fills
  static const Color darkHighlight = Color(0xFF262632); // Press/highlight wash
  static const Color darkDivider = Color(0xFF282830); // Card borders/dividers in dark mode
  static const Color darkInputFill = Color(0xFF101014); // Input fill in the global dark theme
  static const Color darkSurfaceTop = Color(0xFF16161C); // darkSurfaceGradient top stop
  static const Color darkSurfaceBottom = Color(0xFF121216); // darkSurfaceGradient bottom stop

  // Extended Light Neutral Scale — same capture rule (wave 7b)
  static const Color lightBgAlt = Color(0xFFF8FAFC); // Cool-toned page backdrop used by checkout/feed bodies
  static const Color lightSurfaceMuted = Color(0xFFF1F1F5); // Subtle fill: chips, segmented controls, fields
  static const Color lightDivider = Color(0xFFE5E7EB); // Card borders/dividers in light mode
  static const Color lightCardBorder = Color(0xFFE2E2E6); // Card outline (light theme)
  static const Color lightTextPrimary = Color(0xFF0F172A); // Primary text on light surfaces
  static const Color lightTextSecondary = Color(0xFF64748B); // Secondary text on light surfaces
  static const Color lightTextMuted = Color(0xFF94A3B8); // Muted hints/icons on light surfaces

  // Extended Status/Brand — same capture rule (wave 7b)
  static const Color successDark = Color(0xFF2E7D32); // Text-safe success green for light surfaces
  static const Color warningDark = Color(0xFFD97706); // Text-safe amber for pending/awaiting states
  static const Color citMaroonMuted = Color(0xFF5A413D); // Desaturated maroon ink on maroon-tinted light pills

  // Status/Alert Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Premium Elevation Shadows for visual depth
  static List<BoxShadow> get kElevationLow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
  static List<BoxShadow> get kElevationHigh => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: citMaroon.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  // High-End Linear Gradients
  static Gradient get primaryGradient => const LinearGradient(
        colors: [citMaroon, citMaroonLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Gradient get accentGradient => const LinearGradient(
        colors: [citGold, citGoldLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Gradient get darkSurfaceGradient => const LinearGradient(
        colors: [darkSurfaceTop, darkSurfaceBottom],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  /// Premium Dark Theme Configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: citMaroon,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: citMaroon,
        secondary: citGold,
        surface: darkSurface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
      ),
      hoverColor: darkHover,
      highlightColor: darkHighlight,
      splashColor: citMaroon.withValues(alpha: 0.15),
      
      // Card Theme
      cardTheme: const CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: darkCardBorder, width: 0.8),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Input Decoration Theme (High impact: unifies search, posts, and message inputs)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white30),
        labelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Colors.white60),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: citMaroon, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1),
        ),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: citMaroon,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: citGold,
          side: const BorderSide(color: citGold, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Text Theme with modern typography scale
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1),
        titleLarge: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
        titleMedium: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 15, color: Colors.white, height: 1.4),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white60, height: 1.4),
        labelLarge: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: citGold, letterSpacing: 0.5),
      ),
      
      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  /// Premium Light Theme Configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: citMaroon,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: citMaroon,
        secondary: citGold,
        surface: lightSurface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
      ),
      hoverColor: Colors.white.withValues(alpha: 0.85),
      highlightColor: Colors.white,
      splashColor: citMaroon.withValues(alpha: 0.05),
      
      // Card Theme
      cardTheme: const CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: lightCardBorder, width: 0.8),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.black38),
        labelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: citMaroon, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1),
        ),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: citMaroon,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: citMaroon,
          side: const BorderSide(color: citMaroon, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -1),
        titleLarge: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -0.5),
        titleMedium: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 15, color: Colors.black87, height: 1.4),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black54, height: 1.4),
        labelLarge: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: citMaroon, letterSpacing: 0.5),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
