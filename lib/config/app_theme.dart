// lib/config/app_theme.dart
import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════
/// COLOR TOKEN SYSTEM
/// ════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF112E81);      // Deep Blue
  static const Color secondary = Color(0xFF4647AE);    // Indigo
  static const Color accent = Color(0xFF4382DF);       // Vibrant Blue

  // Surfaces
  static const Color canvas = Color(0xFFF8FAFC);       // Slate 50
  static const Color surface = Colors.white;
  static const Color mutedPastel = Color(0xFFAACCD6);  // Pale Blue-Grey
  static const Color neutralDark = Color(0xFF0F172A);  // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color successBg = Color(0x1F22C55E);
  static const Color successText = Color(0xFF15803D);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerBg = Color(0x1FEF4444);
  static const Color dangerText = Color(0xFFB91C1C);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0x1FF59E0B);
  static const Color warningText = Color(0xFFB45309);

  static const Color reserved = Color(0xFF8B5CF6);
  static const Color reservedBg = Color(0x1F8B5CF6);
  static const Color reservedText = Color(0xFF6D28D9);

  static const Color infoBg = Color(0x1F4382DF);
  static const Color infoText = Color(0xFF1D4ED8);

  // Computed
  static Color get borderMuted => Color(0xFFAACCD6).withValues(alpha: 0.35);
  static Color get shadowColor => primary.withValues(alpha: 0.04);
}

/// ════════════════════════════════════════════════════════
/// SPACING UTILITY
/// ════════════════════════════════════════════════════════
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// ════════════════════════════════════════════════════════
/// CARD DECORATION SYSTEM
/// ════════════════════════════════════════════════════════
class AppDecorations {
  AppDecorations._();

  static BoxDecoration card(BuildContext context) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderMuted, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration cardFlat(BuildContext context) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderMuted, width: 1),
      );
}

/// ════════════════════════════════════════════════════════
/// BADGE SYSTEM
/// ════════════════════════════════════════════════════════
class AppBadge {
  static Widget paid({String label = 'Paid'}) => _statusBadge(
        label: label,
        bg: AppColors.successBg,
        fg: AppColors.successText,
        icon: Icons.check_circle,
      );

  static Widget unpaid({String label = 'Unpaid'}) => _statusBadge(
        label: label,
        bg: AppColors.dangerBg,
        fg: AppColors.dangerText,
        icon: Icons.error,
      );

  static Widget partial({String label = 'Pending'}) => _statusBadge(
        label: label,
        bg: AppColors.warningBg,
        fg: AppColors.warningText,
        icon: Icons.pending,
      );

  static Widget reserved({String label = 'Reserved'}) => _statusBadge(
        label: label,
        bg: AppColors.reservedBg,
        fg: AppColors.reservedText,
        icon: Icons.bookmark,
      );

  static Widget status({
    required String label,
    required Color bg,
    required Color fg,
    IconData? icon,
  }) =>
      _statusBadge(label: label, bg: bg, fg: fg, icon: icon);

  static Widget _statusBadge({
    required String label,
    required Color bg,
    required Color fg,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════
/// GLOBAL THEME DATA
/// ════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.canvas,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          tertiary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.borderMuted, width: 1),
          ),
          shadowColor: AppColors.shadowColor,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.primary,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.accent.withValues(alpha: 0.3),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.accent);
            }
            return const IconThemeData(color: Colors.white70);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12);
            }
            return const TextStyle(color: Colors.white60, fontSize: 11);
          }),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: AppColors.primary,
          selectedIconTheme: const IconThemeData(color: Colors.white),
          unselectedIconTheme: const IconThemeData(color: Colors.white60),
          selectedLabelTextStyle:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          unselectedLabelTextStyle: const TextStyle(color: Colors.white60),
          indicatorColor: AppColors.accent.withValues(alpha: 0.3),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.secondary,
            side: BorderSide(color: AppColors.borderMuted),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.canvas,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.mutedPastel.withValues(alpha: 0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.mutedPastel.withValues(alpha: 0.4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          labelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.canvas,
          selectedColor: AppColors.secondary.withValues(alpha: 0.15),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          side: BorderSide(color: AppColors.borderMuted),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        dividerTheme:
            DividerThemeData(color: AppColors.borderMuted, thickness: 1),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.neutralDark,
              fontSize: 22),
          titleLarge: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.neutralDark,
              fontSize: 18),
          titleMedium: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.neutralDark,
              fontSize: 15),
          bodyMedium: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.neutralDark,
              fontSize: 14),
          bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          labelSmall: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.neutralDark,
              fontSize: 18),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}
