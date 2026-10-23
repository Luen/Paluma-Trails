import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';

/// Builds the app theme: Material 3 seeded from trail green, the bundled
/// typeface, and a rainforest app bar so launch, loading and the map read as
/// one surface. Sunlight mode is the same palette at maximum contrast on a
/// white scaffold; see docs/branding.md#contrast-and-modes.
ThemeData buildPalumaTheme(Brightness brightness, {bool sunlight = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.trailGreen,
    brightness: brightness,
    contrastLevel: sunlight ? 1.0 : 0.0,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: BrandText.fontFamily,
    scaffoldBackgroundColor: sunlight ? const Color(0xFFFFFFFF) : null,
  );

  // Headings are bold, like trail signage; body and labels keep the Material
  // weights. Only 400, 500 and 700 are bundled.
  final text = base.textTheme;
  final textTheme = text.copyWith(
    headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
    headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: BrandColors.rainforest,
      foregroundColor: BrandColors.cream,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: BrandColors.cream),
      // Light status-bar icons on the rainforest bar.
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: BrandColors.rainforest,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      dragHandleColor: scheme.onSurfaceVariant,
    ),
  );
}
