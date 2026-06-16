import 'package:flutter/material.dart';

/// App-level theme configuration.
///
/// Uses Snapmaker brand colors: cyan primary, dark surfaces.
class AppTheme {
  AppTheme._();

  // ── Brand Colors ──

  /// Snapmaker brand cyan — used for primary actions, selected states.
  static const Color primaryCyan = Color(0xFF00D4AA);

  /// Deep navy background for dark theme scaffolds.
  static const Color darkBackground = Color(0xFF1A1A2E);

  /// Slightly lighter navy for cards and surfaces.
  static const Color darkSurface = Color(0xFF16213E);

  /// Warm orange accent for warnings, estop, destructive actions.
  static const Color accentOrange = Color(0xFFFF6B35);

  // ── Theme Data ──

  /// Light theme variant for accessibility / user preference.
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryCyan,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      );

  /// Default dark theme with Snapmaker brand colors.
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryCyan,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: darkBackground,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: darkSurface,
        ),
        cardTheme: CardTheme(
          color: darkSurface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
}
