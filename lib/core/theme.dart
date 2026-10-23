import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const nebulaViolet = Color(0xFF7C4DFF);
const nebulaCyan = Color(0xFF18FFFF);
const spaceBlack = Color(0xFF05060F);

ThemeData nebulaTheme() {
  final scheme = ColorScheme.fromSeed(
      seedColor: nebulaViolet, brightness: Brightness.dark, surface: spaceBlack);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: GoogleFonts.exo2TextTheme(ThemeData.dark().textTheme),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: spaceBlack.withOpacity(0.85),
        indicatorColor: nebulaViolet.withOpacity(0.4)),
  );
}
