import 'package:flutter/material.dart';

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    background: Color.fromARGB(255, 0, 24, 43),
    primary: Color.fromARGB(255, 0, 24, 43),
    secondary: Color.fromARGB(255, 0, 24, 43),
    inversePrimary: Color.fromARGB(255, 0, 24, 43),
  ),
  textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: Colors.grey[200],
        displayColor: Colors.white,
      ),
);
