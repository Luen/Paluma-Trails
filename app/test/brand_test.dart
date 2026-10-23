import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/api/app.dart';
import 'package:paluma_trails/src/brand/brand.dart';
import 'package:paluma_trails/src/brand/theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('theme', () {
    test('uses the bundled typeface and the rainforest app bar', () {
      final theme = buildPalumaTheme(Brightness.light);
      expect(theme.textTheme.bodyMedium?.fontFamily, BrandText.fontFamily);
      expect(theme.appBarTheme.backgroundColor, BrandColors.rainforest);
      expect(theme.appBarTheme.foregroundColor, BrandColors.cream);
      expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w700);
    });

    test('sunlight mode keeps a white scaffold', () {
      final theme = buildPalumaTheme(Brightness.light, sunlight: true);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    });

    test('dark mode is generated from the same seed', () {
      final theme = buildPalumaTheme(Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.appBarTheme.backgroundColor, BrandColors.rainforest);
    });

    test('brand text pairs meet WCAG AA', () {
      expect(
        _contrast(BrandColors.cream, BrandColors.rainforest),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(BrandColors.paleMist, BrandColors.rainforest),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(BrandColors.mist, BrandColors.rainforest),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('trail-pin mark', () {
    testWidgets('keeps the mark proportions', (tester) async {
      await tester.pumpWidget(const Center(child: TrailPinMark(height: 68.8)));
      final size = tester.getSize(find.byType(CustomPaint).last);
      expect(size.height, 68.8);
      expect(size.width, closeTo(50.4, 0.01));
    });

    testWidgets('paints with and without the junction accent at any size', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              TrailPinMark(height: 16),
              TrailPinMark(height: 200, accentColor: BrandColors.sand),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(TrailPinMark), findsNWidgets(2));
    });

    testWidgets('is decorative unless it has a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              TrailPinMark(),
              TrailPinMark(semanticLabel: 'Paluma Trails'),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Paluma Trails'), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('the loading screen carries the wordmark and tagline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPalumaTheme(Brightness.light),
        home: const LoadingScreen(),
      ),
    );

    expect(find.text('Paluma Trails'), findsOneWidget);
    expect(find.text(BrandText.tagline), findsOneWidget);
    expect(find.text('Opening the offline map…'), findsOneWidget);
  });

  testWidgets('the lockup reads as the product name', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPalumaTheme(Brightness.light),
        home: const Scaffold(
          backgroundColor: BrandColors.rainforest,
          body: Center(child: BrandLockup()),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Paluma Trails'), findsOneWidget);
    handle.dispose();
  });
}
