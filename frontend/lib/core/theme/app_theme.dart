import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema do app Matrix Race
/// Paleta: verde da marca (#00C853) sobre fundo escuro navy
class AppTheme {
  // ── Cor primária da marca ─────────────────────────────────────────────────
  // "primaryRed" mantém o nome por compatibilidade com o restante do código;
  // o valor foi atualizado para o verde Matrix Race.
  static const Color primaryRed   = Color(0xFF00C853);
  static const Color primaryGreen = Color(0xFF00C853); // alias semântico

  // ── Superfícies ───────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F1117);
  static const Color cardBackground = Color(0xFF181C27);
  static const Color surfaceColor   = Color(0xFF222638);

  // ── Acentos ───────────────────────────────────────────────────────────────
  static const Color accentGold    = Color(0xFFFFD700);
  static const Color successGreen  = Color(0xFF43A047);
  static const Color warningOrange = Color(0xFFFF9800);

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A8FA8);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryGreen,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: accentGold,
        surface: cardBackground,
        error: Color(0xFFCF6679),
      ),

      // ── Tipografia (Inter) ───────────────────────────────────────────────
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          headlineLarge:  TextStyle(color: textPrimary,   fontSize: 28, fontWeight: FontWeight.bold,  letterSpacing: -0.5),
          headlineMedium: TextStyle(color: textPrimary,   fontSize: 22, fontWeight: FontWeight.bold,  letterSpacing: -0.3),
          titleLarge:     TextStyle(color: textPrimary,   fontSize: 18, fontWeight: FontWeight.w600),
          titleMedium:    TextStyle(color: textPrimary,   fontSize: 16, fontWeight: FontWeight.w500),
          bodyLarge:      TextStyle(color: textPrimary,   fontSize: 16),
          bodyMedium:     TextStyle(color: textSecondary, fontSize: 14),
          labelLarge:     TextStyle(color: textPrimary,   fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Cards ───────────────────────────────────────────────────────────
      cardTheme: const CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0x14FFFFFF)), // ~8% branco
        ),
      ),

      // ── ElevatedButton ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),

      // ── OutlinedButton ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: primaryGreen),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // ── TextButton ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryGreen),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x14FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCF6679)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCF6679), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: textSecondary),
        floatingLabelStyle: const TextStyle(color: primaryGreen),
        prefixIconColor: textSecondary,
      ),

      // ── NavigationBar (Material 3) ───────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBackground,
        indicatorColor: const Color(0xFF00C853).withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryGreen, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: textSecondary, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryGreen, size: 22);
          }
          return const IconThemeData(color: textSecondary, size: 22);
        }),
        height: 62,
      ),

      // ── BottomNavigationBar (legado) ─────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textSecondary,
      ),

      // ── TabBar ──────────────────────────────────────────────────────────
      tabBarTheme: const TabBarThemeData(
        indicatorColor: primaryGreen,
        labelColor: primaryGreen,
        unselectedLabelColor: textSecondary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0x14FFFFFF),
        thickness: 1,
      ),

      // ── SnackBar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceColor,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
