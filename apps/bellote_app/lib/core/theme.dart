import 'package:material_ui/material_ui.dart';

abstract final class AppTheme {
  static const felt = Color(0xFF0B3D2E);
  static const feltDeep = Color(0xFF06281E);
  static const feltLight = Color(0xFF14513D);
  static const gold = Color(0xFFE7BD6A);
  static const goldSoft = Color(0xFFF1D79E);
  static const cream = Color(0xFFF8F2E2);
  static const ink = Color(0xFF16211C);
  static const red = Color(0xFFB3261E);
  static const muted = Color(0xFF9DB3A8);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
    ).copyWith(
      primary: gold,
      onPrimary: feltDeep,
      secondary: goldSoft,
      onSecondary: feltDeep,
      surface: feltDeep,
      onSurface: cream,
      surfaceContainerHighest: feltLight,
      error: const Color(0xFFFFB4AB),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: feltDeep,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: cream, displayColor: cream),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: cream,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        iconTheme: IconThemeData(color: cream),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: feltDeep,
          minimumSize: const Size(0, 50),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldSoft,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: gold.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: goldSoft),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.18),
        labelStyle: TextStyle(color: goldSoft.withValues(alpha: 0.9)),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: gold, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: felt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: gold.withValues(alpha: 0.25)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: felt,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF233B31),
        contentTextStyle: const TextStyle(color: cream),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: gold.withValues(alpha: 0.18),
    );
  }

  static BoxDecoration feltBackground() => const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.15,
          colors: [feltLight, felt, feltDeep],
          stops: [0, 0.55, 1],
        ),
      );
}
