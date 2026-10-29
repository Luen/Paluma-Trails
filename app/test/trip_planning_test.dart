import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/about_screen.dart';
import 'package:paluma_trails/src/brand/theme.dart';
import 'package:paluma_trails/src/content/models.dart';
import 'package:paluma_trails/src/content/trip_planning.dart';
import 'package:paluma_trails/src/map/poi_photo_card.dart';
import 'package:paluma_trails/src/map/sheets.dart';
import 'package:paluma_trails/src/trip_planning_screen.dart';

import 'support/bundle_fixture.dart';

void main() {
  Map<String, Object?> data(String file) =>
      jsonDecode(File('assets/bundle/content/$file').readAsStringSync())
          as Map<String, Object?>;
  final content = TripPlanningContent.fromJson(data('trip-planning.json'));
  final pois = {
    for (final json
        in (data('pois.json')['pois']! as List).cast<Map<String, Object?>>())
      json['id']! as String: Poi.fromJson(json),
  };
  final bundle = testBundle(tripPlanning: content, pois: pois);

  test(
    'packaged notes are dated and sourced, with no live condition promise',
    () {
      expect(content.checked, '2026-10-30');
      expect(content.intro, contains('not live'));
      expect(content.sections, hasLength(5));
      for (final section in content.sections) {
        expect(section.paragraphs, isNotEmpty);
        expect(section.sources, isNotEmpty);
        for (final source in section.sources) {
          final uri = Uri.parse(source.url);
          expect(uri.scheme, 'https');
          expect(uri.host, endsWith('parks.qld.gov.au'));
        }
      }
      expect(pois.values.fold<int>(0, (n, poi) => n + poi.photos.length), 5);
    },
  );

  for (final mode in ['light', 'dark', 'sunlight', 'large text']) {
    testWidgets('offline plan and credited gallery fit 320 px: $mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPalumaTheme(
            mode == 'dark' ? Brightness.dark : Brightness.light,
            sunlight: mode == 'sunlight',
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(mode == 'large text' ? 2 : 1),
            ),
            child: child!,
          ),
          home: TripPlanningScreen(bundle: bundle),
        ),
      );
      expect(find.textContaining('Offline notes · checked'), findsOneWidget);
      final planScroll = find.descendant(
        of: find.byKey(const PageStorageKey('trip-plan')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Getting there'),
        200,
        scrollable: planScroll,
      );
      await tester.scrollUntilVisible(
        find.text('Jourama Falls facilities'),
        500,
        scrollable: find.descendant(
          of: find.byKey(const PageStorageKey('trip-plan')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();
      expect(find.text('5 offline photographs'), findsOneWidget);
      final firstPoi = pois.values.where((p) => p.photos.isNotEmpty).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final photo = firstPoi.first.photos.first;
      final galleryScroll = find.descendant(
        of: find.byKey(const PageStorageKey('trip-photos')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text(photo.credit),
        400,
        scrollable: galleryScroll,
      );
      expect(find.text(photo.caption), findsOneWidget);
      expect(find.text(photo.licence), findsOneWidget);
      expect(find.byType(PoiPhotoCard), findsWidgets);
      expect(tester.takeException(), isNull);
      final historyButton = find.byKey(
        ValueKey('history-${firstPoi.first.id}'),
      );
      await tester.scrollUntilVisible(
        historyButton,
        200,
        scrollable: galleryScroll,
      );
      await tester.ensureVisible(historyButton);
      await tester.tap(historyButton);
      await tester.pumpAndSettle();
      expect(find.byType(PoiSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(PoiSheet))).pop();
      await tester.pumpAndSettle();
      for (final poi in firstPoi.skip(1)) {
        for (final photo in poi.photos) {
          await tester.scrollUntilVisible(
            find.text(photo.credit),
            400,
            scrollable: galleryScroll,
          );
          expect(find.text(photo.caption), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    });
  }

  testWidgets('older bundle offers gallery and an explicit notes fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: TripPlanningScreen(bundle: testBundle())),
    );
    expect(find.textContaining('older bundle'), findsOneWidget);
    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    expect(find.text('This bundle has no photographs yet.'), findsOneWidget);
  });

  testWidgets('About opens the hub without a location service', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AboutScreen(bundle: bundle)));
    await tester.scrollUntilVisible(
      find.text('Trip planning and photos · offline'),
      400,
    );
    await tester.ensureVisible(find.text('Trip planning and photos · offline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trip planning and photos · offline'));
    await tester.pumpAndSettle();
    expect(find.byType(TripPlanningScreen), findsOneWidget);
    expect(find.text('Getting there'), findsOneWidget);
  });
}
