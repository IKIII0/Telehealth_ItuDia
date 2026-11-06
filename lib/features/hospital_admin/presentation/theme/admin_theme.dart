import 'package:flutter/material.dart';

/// Palet warna khusus Web Dashboard Admin Rumah Sakit.
///
/// Nuansa medis: teal gelap sebagai warna utama, hijau untuk status aman,
/// kuning untuk hal yang menunggu tindakan, dan merah untuk risiko.
class AdminColors {
  AdminColors._();

  static const Color background = Color(0xFFF2F6F9);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF7FAFC);

  static const Color sidebar = Color(0xFF0A3543);
  static const Color sidebarActive = Color(0xFF11566A);
  static const Color sidebarText = Color(0xFFD7E7EE);
  static const Color sidebarMuted = Color(0xFF8FB1BF);

  static const Color primary = Color(0xFF0E7490);
  static const Color primaryDark = Color(0xFF0B4F63);
  static const Color accent = Color(0xFF14B8A6);

  static const Color textPrimary = Color(0xFF10323F);
  static const Color textMuted = Color(0xFF647C8A);
  static const Color border = Color(0xFFE2EAF0);

  static const Color success = Color(0xFF15803D);
  static const Color successSoft = Color(0xFFE7F7EC);

  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFEF3C7);

  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerSoft = Color(0xFFFDE8E8);

  static const Color info = Color(0xFF1D4ED8);
  static const Color infoSoft = Color(0xFFE4EDFF);

  /// Warna solid untuk badge risiko/peringatan.
  static Color forRisk(bool isHigh, bool isMedium) {
    if (isHigh) return danger;
    if (isMedium) return warning;
    return success;
  }
}

/// Tema lokal untuk subtree dashboard admin.
///
/// Diterapkan lewat widget [Theme] di dalam shell admin sehingga tema
/// aplikasi mobile (pasien/dokter) tidak berubah.
class AdminTheme {
  AdminTheme._();

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AdminColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AdminColors.primary,
          onPrimary: Colors.white,
          secondary: AdminColors.accent,
          surface: AdminColors.surface,
          error: AdminColors.danger,
        );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: AdminColors.background,
      textTheme: base.textTheme.apply(
        bodyColor: AdminColors.textPrimary,
        displayColor: AdminColors.textPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: AdminColors.border,
        space: 1,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AdminColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.surface,
        foregroundColor: AdminColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AdminColors.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.surfaceMuted,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.danger, width: 1.6),
        ),
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.primary,
          side: const BorderSide(color: AdminColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AdminColors.surface,
        selectedColor: AdminColors.primary.withValues(alpha: 0.12),
        side: const BorderSide(color: AdminColors.border),
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AdminColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AdminColors.textPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
