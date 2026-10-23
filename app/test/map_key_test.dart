import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/map/map_key.dart';
import 'package:paluma_trails/src/map/map_options.dart';
import 'package:paluma_trails/src/map/map_palette.dart';
import 'package:paluma_trails/src/map/sheets.dart';

import 'support/bundle_fixture.dart';

void main() {
  group('map palette', () {
    test('maps each track class to a colour', () {
      expect(MapPalette.trackColour('track'), MapPalette.walkingTrack);
      expect(MapPalette.trackColour('walk'), MapPalette.walkingTrack);
      expect(MapPalette.trackColour('other'), MapPalette.walkingTrack);
      expect(MapPalette.trackColour('mtb'), MapPalette.mtbTrack);
      expect(MapPalette.trackColour('road'), MapPalette.road);
      expect(MapPalette.trackColour('connector'), MapPalette.connector);
    });

    test('dashes only informal and unknown classes', () {
      for (final trackClass in MapPalette.solidClasses) {
        expect(MapPalette.isDashed(trackClass), isFalse, reason: trackClass);
      }
      expect(MapPalette.isDashed('other'), isTrue);
      expect(MapPalette.isDashed('something-new'), isTrue);
    });

    test('parses its hex values', () {
      expect(MapPalette.color('#2E7D32'), const Color(0xFF2E7D32));
    });
  });

  testWidgets('the key names every symbol in words', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MapKey())));

    for (final label in [
      'Walking track',
      'Informal or unclassified track',
      'Mountain bike',
      'Road',
      'Connector',
      'Numbered junction',
      'Point of interest',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('the display sheet includes the map key', (tester) async {
    final options = MapOptions();
    addTearDown(options.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showDisplaySettingsSheet(context, options: options),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Map key'), 100);
    expect(find.text('Map key'), findsOneWidget);
  });

  testWidgets('junction sheet badges match the map markers', (tester) async {
    final bundle = testBundle();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JunctionSheet(
            bundle: bundle,
            junction: bundle.junctions['j1']!,
          ),
        ),
      ),
    );

    // The junction itself and the junction at the other end of its segment.
    expect(find.byType(JunctionBadge), findsNWidgets(2));
  });

  testWidgets('track sheet shows the class as a line sample and in words', (
    tester,
  ) async {
    final bundle = testBundle();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackSheet(bundle: bundle, track: bundle.tracks.first),
        ),
      ),
    );

    expect(find.byType(TrackClassSwatch), findsOneWidget);
    expect(find.textContaining('Walking track'), findsOneWidget);
  });
}
