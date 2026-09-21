import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

/// `#RRGGBB` or `#AARRGGBB`, the way the API supplies lesson colours; null for anything else.
Color? parseHexColor(String? value) {
  if (value == null) return null;
  final hex = value.replaceFirst('#', '');
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return switch (hex.length) {
    6 => Color(0xFF000000 | parsed),
    8 => Color(parsed),
    _ => null,
  };
}

/// [color] adjusted so that text in it is readable on the theme's background. The lesson
/// colours come from the gym and were chosen for a white surface: dark purple on a dark
/// screen disappears. The hue stays, only the lightness shifts.
Color readableOn(Color color, Brightness brightness) {
  final hsl = HSLColor.fromColor(color);
  return (brightness == Brightness.dark
          ? hsl.withLightness(hsl.lightness.clamp(0.72, 1.0))
          : hsl.withLightness(hsl.lightness.clamp(0.0, 0.42)))
      .toColor();
}
