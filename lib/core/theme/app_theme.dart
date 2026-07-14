import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    const primaryColor = Color(0xFF2A5954);
    // Create solid light tints instead of transparent colors to avoid black background
    final surfaceColor = Color.lerp(Colors.white, primaryColor, 0.03)!;
    final bgColor = Color.lerp(Colors.white, primaryColor, 0.05)!;
    
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        surface: surfaceColor, 
        primary: primaryColor,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: bgColor,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primaryColor.withValues(alpha: 0.1)),
        ),
        color: Colors.white,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: const Color(0xFF0F4C75),
        surface: const Color(0xFF1B262C),
        primary: const Color(0xFF3282B8),
      ),
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF222831).withOpacity(0.7),
      ),
    );
  }
}
