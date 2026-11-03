import 'package:flutter/material.dart';

ThemeData zulloTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFEC2863),
      ).copyWith(
        primary: const Color(0xFFEC2863),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFFFEDF3),
        onPrimaryContainer: const Color(0xFFEC2863),
        secondary: const Color(0xFF697180),
        tertiary: const Color(0xFF697180),
        tertiaryContainer: const Color(0xFFF0F2F6),
        onTertiaryContainer: const Color(0xFF20242C),
        surfaceTint: Colors.transparent,
        surfaceContainerLow: const Color(0xFFF7F8FA),
        surfaceContainerLowest: Colors.white,
        surface: Colors.white,
        onSurface: const Color(0xFF20242C),
        surfaceContainerHighest: const Color(0xFFF0F2F6),
        surfaceContainer: const Color(0xFFF7F8FA),
        surfaceContainerHigh: const Color(0xFFF0F2F6),
        secondaryContainer: const Color(0xFFFFEDF3),
        onSecondaryContainer: const Color(0xFFEC2863),
      ),
      dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF22262E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0),
      cardTheme: CardThemeData(
          color: const Color(0xFFF6F7F9),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22262E),
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48))),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
