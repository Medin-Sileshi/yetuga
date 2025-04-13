import 'package:flutter/material.dart';
import 'package:yetuga/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  static const String _themePreferenceKey = 'theme_preference';
  static const String _useSystemThemeKey = 'use_system_theme';

  Future<void> _loadTheme() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check if we should use system theme
    final bool useSystemTheme = prefs.getBool(_useSystemThemeKey) ?? true;

    if (useSystemTheme) {
      // Use system theme
      state = ThemeMode.system;
    } else {
      // Use saved theme preference
      final bool isDarkMode = prefs.getBool(_themePreferenceKey) ?? false;
      state = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    }
  }

  Future<void> toggleTheme() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // If currently using system theme, switch to light theme
    if (state == ThemeMode.system) {
      await prefs.setBool(_useSystemThemeKey, false);
      await prefs.setBool(_themePreferenceKey, false); // Set to light theme
      state = ThemeMode.light;
      return;
    }

    // Otherwise toggle between light and dark
    final bool isDarkMode = state == ThemeMode.dark;
    await prefs.setBool(_useSystemThemeKey, false); // Disable system theme
    await prefs.setBool(_themePreferenceKey, !isDarkMode);
    state = isDarkMode ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> useSystemTheme() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useSystemThemeKey, true);
    state = ThemeMode.system;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

// Light Theme
final lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF00182C),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF00182C),
    secondary: Color(0xFF00182C),
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF00182C),
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xFF00182C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: const Color(0xFF00182C)),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      color: Color(0xFF00182C),
      fontWeight: FontWeight.w200,
      fontSize: 32,
    ),
    headlineMedium: TextStyle(
      color: Color(0xFF00182C),
      fontWeight: FontWeight.w200,
    ),
    bodyLarge: TextStyle(color: Color(0xFF00182C)),
    bodyMedium: TextStyle(color: Color(0xFF00182C)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF00182C)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF00182C), width: 2),
    ),
    labelStyle: const TextStyle(color: Color(0xFF00182C)),
  ),
);

// Dark Theme
final darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF29C7E4),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF29C7E4),
    secondary: Color(0xFF29C7E4),
    surface: Color(0xFF00182C),
  ),
  scaffoldBackgroundColor: const Color(0xFF00182C),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF00182C),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: const Color(0xFF00182C),
      backgroundColor: const Color(0xFF29C7E4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: const Color(0xFF29C7E4)),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w200,
      fontSize: 32,
    ),
    headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w200),
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF29C7E4)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF29C7E4), width: 2),
    ),
    labelStyle: const TextStyle(color: Colors.white70),
  ),
);
