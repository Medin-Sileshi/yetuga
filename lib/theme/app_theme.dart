import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF00182C);
  static const secondary = Color(0xFF29C7E4);
  static const white = Colors.white;
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.white,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w300,
        fontSize: 32,
      ),
      headlineMedium: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w300,
        fontSize: 24,
      ),
      bodyLarge: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w300,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w300,
        fontSize: 14,
      ),
      labelLarge: TextStyle(
        color: AppColors.secondary,
        fontWeight: FontWeight.w400,
        fontSize: 16,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: AppColors.white,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondary,
        textStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.secondary, width: 2),
      ),
      labelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w300,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.secondary,
        fontWeight: FontWeight.w400,
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.secondary,
    scaffoldBackgroundColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.secondary,
      secondary: AppColors.secondary,
      surface: AppColors.primary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.white,
        fontWeight: FontWeight.w300,
        fontSize: 32,
      ),
      headlineMedium: TextStyle(
        color: AppColors.white,
        fontWeight: FontWeight.w300,
        fontSize: 24,
      ),
      bodyLarge: TextStyle(
        color: AppColors.white,
        fontWeight: FontWeight.w300,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: AppColors.white,
        fontWeight: FontWeight.w300,
        fontSize: 14,
      ),
      labelLarge: TextStyle(
        color: AppColors.secondary,
        fontWeight: FontWeight.w400,
        fontSize: 16,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.secondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondary,
        textStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.white),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.white),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.secondary, width: 2),
      ),
      labelStyle: const TextStyle(
        color: AppColors.white,
        fontWeight: FontWeight.w300,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.secondary,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}
