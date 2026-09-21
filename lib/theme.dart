import 'package:flutter/material.dart';

ThemeData buildTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E7D6B),
    secondary: const Color(0xFFF2A541),
    brightness: brightness,
  ),
  brightness: brightness,
  useMaterial3: true,
  appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, scrolledUnderElevation: 1),
  cardTheme: CardThemeData(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
);
