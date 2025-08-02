import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // "Old Money" Light Color Palette
  static final Color primaryColor = Color(0xFF0A2342); // Deep Navy Blue
  static final Color secondaryColor = Color(0xFF2C4A6B); // Softer Slate Blue
  static final Color backgroundColor = Color(0xFFE8DBC4); // Light Beige/Tan
  static final Color textOnPrimary = Color(
    0xFFFDFBF7,
  ); // Creamy White for text on navy buttons

  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: GoogleFonts.poppins().fontFamily, // Default font for body text
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: primaryColor,
      elevation: 0,
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.ebGaramond(
        fontSize: 42,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      bodyLarge: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      labelLarge: GoogleFonts.poppins(
        fontSize: 16,
        color: textOnPrimary,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: secondaryColor,
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
