import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/map/sheets.dart';

import 'support/bundle_fixture.dart';

Future<void> _pump(WidgetTester tester, Widget sheet) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: sheet)));

void main() {
  testWidgets('junction sheet lists the tracks from the junction', (
    tester,
  ) async {
    final bundle = testBundle();
    await _pump(
      tester,
      JunctionSheet(bundle: bundle, junction: bundle.junctions['j1']!),
    );

    expect(find.text('Junction 1'), findsOneWidget);
    expect(find.textContaining('18.9419° S, 146.1887° E'), findsOneWidget);
    expect(find.text('Big Crystal Creek junction'), findsOneWidget);
    expect(
      find.text('Tāngaroa Walking Track · 1.2 km · 20 min · ↑ 80 m'),
      findsOneWidget,
    );
    expect(find.text('Out and back 40 min'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(
      find.text('Estimate — flat-terrain pace, elevation not included'),
      findsOneWidget,
    );
  });

  testWidgets('junction sheet shows the climb for the direction walked', (
    tester,
  ) async {
    final bundle = testBundle();
    await _pump(
      tester,
      JunctionSheet(bundle: bundle, junction: bundle.junctions['j2']!),
    );

    expect(
      find.text('Tāngaroa Walking Track · 1.2 km · 20 min · ↑ 30 m'),
      findsOneWidget,
    );
    expect(find.text('W'), findsOneWidget);
  });

  testWidgets('junction sheet says when nothing is mapped yet', (tester) async {
    final bundle = testBundle(withSegment: false);
    await _pump(
      tester,
      JunctionSheet(bundle: bundle, junction: bundle.junctions['j1']!),
    );

    expect(find.text('No mapped tracks connect here yet'), findsOneWidget);
  });

  testWidgets('POI sheet shows category, description and unverified state', (
    tester,
  ) async {
    final poi = testBundle().pois['little-crystal-creek-falls']!;
    await _pump(tester, PoiSheet(poi: poi));

    expect(find.text('Little Crystal Creek Falls'), findsOneWidget);
    expect(find.text('Unverified'), findsOneWidget);
    expect(find.text('A short steep walk to the falls.'), findsOneWidget);
    expect(find.textContaining('Waterfall ·'), findsOneWidget);
  });

  testWidgets('track sheet summarises class, length and walk time', (
    tester,
  ) async {
    final bundle = testBundle();
    await _pump(
      tester,
      TrackSheet(bundle: bundle, track: bundle.tracks.single),
    );

    expect(find.text('Tāngaroa Walking Track'), findsOneWidget);
    expect(
      find.text('Walking track · 5.4 km · 20 min · 2 junctions'),
      findsOneWidget,
    );
  });
}
