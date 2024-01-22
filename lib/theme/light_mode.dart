import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    background: Color.fromARGB(255, 0, 24, 43),
    primary: Color.fromARGB(255, 0, 24, 43),
    secondary: Color.fromARGB(255, 0, 24, 43),
    inversePrimary: Color.fromARGB(255, 0, 24, 43),
  ),
  textTheme: ThemeData.light().textTheme.apply(
        bodyColor: Colors.grey[200],
        displayColor: Colors.white,
      ),
);
