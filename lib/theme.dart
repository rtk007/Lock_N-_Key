import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF64FFDA), // Teal accent
      onPrimary: Colors.black,
      secondary: Color(0xFF1E88E5), // Blue accent
      onSecondary: Colors.white,
      surface: Color(0xFF1E293B), // Slate 800
      onSurface: Color(0xFFF8FAFC), // Slate 50
      background: Color(0xFF0F172A), // Slate 900
      onBackground: Color(0xFFF8FAFC), // Slate 50
      error: Color(0xFFEF4444), // Red 500
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
    cardColor: const Color(0xFF1E293B), // Slate 800
    dividerColor: const Color(0xFF334155), // Slate 700
    
    // AppBar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F172A),
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
      titleTextStyle: TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
      displayMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
      displaySmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
      headlineMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFFF8FAFC)),
      titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFFF8FAFC)),
      bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFFE2E8F0)), // Slate 200
      bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFFCBD5E1)), // Slate 300
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF334155), // Slate 700
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF64FFDA), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)), // Slate 400
      hintStyle: const TextStyle(color: Color(0xFF64748B)), // Slate 500
    ),

    // ElevatedButton Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: const Color(0xFF64FFDA),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),

    // TextButton Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF64FFDA),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Navigation Rail Theme
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFF1E293B),
      selectedIconTheme: IconThemeData(color: Color(0xFF64FFDA)),
      unselectedIconTheme: IconThemeData(color: Color(0xFF94A3B8)),
      selectedLabelTextStyle: TextStyle(color: Color(0xFF64FFDA), fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: Color(0xFF94A3B8)),
      indicatorColor: Colors.transparent, // Disable default pill indicator
      useIndicator: false,
    ),
  );
}
