import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design System do Matrix Race
/// Tipografia: Exo 2 (display/headlines) + Inter (body)
/// Paleta: verde neon (#00E676) sobre dark navy com profundidade
class AppTheme {
  // ── Cor primária da marca ─────────────────────────────────────────────────
  // "primaryRed" mantém o nome por compatibilidade com o restante do código;
  // o valor foi atualizado para o verde Matrix Race.
  static const Color primaryRed   = Color(0xFF00E676);
  static const Color primaryGreen = Color(0xFF00E676); // alias semântico
  static const Color primaryDim   = Color(0xFF00C853); // variante mais escura

  // ── Superfícies com profundidade ────────────────────────────────────────
  static const Color darkBackground = Color(0xFF080B12);
  static const Color cardBackground = Color(0xFF111827);
  static const Color surfaceColor   = Color(0xFF1E2536);
  static const Color surfaceHigh    = Color(0xFF283040);

  // ── Acentos ───────────────────────────────────────────────────────────────
  static const Color accentGold    = Color(0xFFFFD700);
  static const Color successGreen  = Color(0xFF43A047);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color accentCyan    = Color(0xFF00BCD4);

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF8892A8);

  // ── Bordas ────────────────────────────────────────────────────────────────
  static const Color borderSubtle  = Color(0x14FFFFFF); // ~8% branco
  static const Color borderMedium  = Color(0x28FFFFFF); // ~16% branco

  // ═════════════════════════════════════════════════════════════════════════
  //  HELPERS DE ESTILO — usados pelas telas para manter consistência
  // ═════════════════════════════════════════════════════════════════════════

  /// Gradiente principal para hero cards
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradiente de fundo para cards especiais
  static LinearGradient cardGradient({double opacity = 0.15}) => LinearGradient(
    colors: [
      primaryGreen.withValues(alpha: opacity),
      cardBackground,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradiente sutil para fundos de seções
  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF0D1117)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Sombra glow verde para elementos de destaque
  static List<BoxShadow> glowShadow({Color? color, double blur = 20, double spread = 0}) => [
    BoxShadow(
      color: (color ?? primaryGreen).withValues(alpha: 0.25),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];

  /// Sombra suave para cards elevados
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Decoração padrão para cards com borda sutil
  static BoxDecoration cardDecoration({
    Color? color,
    double radius = 16,
    bool withBorder = true,
    List<BoxShadow>? shadows,
  }) => BoxDecoration(
    color: color ?? cardBackground,
    borderRadius: BorderRadius.circular(radius),
    border: withBorder ? Border.all(color: borderSubtle) : null,
    boxShadow: shadows,
  );

  /// Decoração para cards com borda de destaque à esquerda
  static BoxDecoration accentCardDecoration({
    Color accentColor = primaryGreen,
    double radius = 14,
  }) => BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderSubtle),
    boxShadow: [
      BoxShadow(
        color: accentColor.withValues(alpha: 0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  /// Estilo para texto de headline display (Exo 2)
  static TextStyle displayStyle({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.bold,
    Color color = textPrimary,
  }) => GoogleFonts.exo2(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: -0.5,
  );

  /// Decoração para glassmorphism (efeito vidro)
  static BoxDecoration glassDecoration({
    double radius = 16,
    Color? borderColor,
  }) => BoxDecoration(
    color: const Color(0xFF111827).withValues(alpha: 0.85),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ?? borderMedium,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  /// Chip/badge de status
  static BoxDecoration chipDecoration(Color color) => BoxDecoration(
    color: color.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: color.withValues(alpha: 0.4)),
  );

  // ═════════════════════════════════════════════════════════════════════════
  //  TEMA
  // ═════════════════════════════════════════════════════════════════════════

  static ThemeData get darkTheme {
    final exo2Headline = GoogleFonts.exo2TextTheme(
      const TextTheme(
        headlineLarge:  TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold,  letterSpacing: -0.5),
        headlineMedium: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold,  letterSpacing: -0.3),
        headlineSmall:  TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );

    final interBody = GoogleFonts.interTextTheme(
      const TextTheme(
        titleLarge:  TextStyle(color: textPrimary,   fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary,   fontSize: 16, fontWeight: FontWeight.w500),
        titleSmall:  TextStyle(color: textSecondary,  fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge:   TextStyle(color: textPrimary,   fontSize: 16),
        bodyMedium:  TextStyle(color: textSecondary, fontSize: 14),
        bodySmall:   TextStyle(color: textSecondary, fontSize: 12),
        labelLarge:  TextStyle(color: textPrimary,   fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall:  TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );

    final mergedTextTheme = exo2Headline.merge(interBody);

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

      // ── Tipografia mesclada ───────────────────────────────────────────
      textTheme: mergedTextTheme,

      // ── AppBar ────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.exo2(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: borderSubtle),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── ElevatedButton ────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: const Color(0xFF0A0E17),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.exo2(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          elevation: 0,
        ).copyWith(
          overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.1)),
        ),
      ),

      // ── OutlinedButton ────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: primaryGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── TextButton ────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryGreen),
      ),

      // ── Inputs ────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCF6679)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCF6679), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: textSecondary),
        floatingLabelStyle: const TextStyle(color: primaryGreen),
        prefixIconColor: textSecondary,
      ),

      // ── NavigationBar (Material 3) ────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBackground,
        indicatorColor: primaryGreen.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              color: primaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }
          return GoogleFonts.inter(
            color: textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryGreen, size: 22);
          }
          return const IconThemeData(color: textSecondary, size: 22);
        }),
        height: 64,
      ),

      // ── BottomNavigationBar (legado) ──────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textSecondary,
      ),

      // ── TabBar ────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        indicatorColor: primaryGreen,
        labelColor: primaryGreen,
        unselectedLabelColor: textSecondary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
      ),

      // ── Divider ───────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
      ),

      // ── SnackBar ──────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceColor,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── Dialog ────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSubtle),
        ),
      ),

      // ── PopupMenu ─────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderSubtle),
        ),
      ),

      // ── ProgressIndicator ─────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryGreen,
      ),

      // ── FloatingActionButton ──────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: const Color(0xFF0A0E17),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
