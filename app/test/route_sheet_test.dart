import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/content/bundle_repository.dart';
import 'package:paluma_trails/src/content/models.dart';
import 'package:paluma_trails/src/map/route_sheet.dart';

import 'support/bundle_fixture.dart';

/// The same small network the planner tests use: a 2.2 km loop through j1, j2
/// and j3, a 300 m spur to j4, and j5 off the network.
LoadedBundle _network() => testBundle(
  junctions: const {
    'j1': Junction(id: 'j1', number: 1, location: GeoPoint(-18.94, 146.18)),
    'j2': Junction(
      id: 'j2',
      number: 2,
      name: 'Creek Junction',
      location: GeoPoint(-18.945, 146.19),
    ),
    'j3': Junction(id: 'j3', number: 3, location: GeoPoint(-18.95, 146.2)),
    'j4': Junction(
      id: 'j4',
      number: 4,
      name: 'Lookout',
      location: GeoPoint(-18.955, 146.21),
    ),
    'j5': Junction(id: 'j5', number: 5, location: GeoPoint(-18.96, 146.22)),
  },
  segments: const [
    Segment(
      from: 'j1',
      to: 'j2',
      trackId: 'ridge',
      trackName: 'Ridge Track',
      distanceM: 1000,
      walkMinutes: 20,
      bearingDeg: 90,
    ),
    Segment(
      from: 'j2',
      to: 'j3',
      trackId: 'creek',
      trackName: 'Creek Track',
      distanceM: 500,
      walkMinutes: 10,
      bearingDeg: 120,
    ),
    Segment(
      from: 'j3',
      to: 'j1',
      trackId: 'gully',
      trackName: 'Gully Track',
      distanceM: 700,
      walkMinutes: 14,
      bearingDeg: 240,
    ),
    Segment(
      from: 'j3',
      to: 'j4',
      trackId: 'spur',
      trackName: 'Spur Track',
      distanceM: 300,
      walkMinutes: 6,
      bearingDeg: 300,
    ),
  ],
);

Future<void> _open(
  WidgetTester tester, {
  String? initialFromId,
  ValueChanged<Junction>? onFocus,
}) async {
  final bundle = _network();
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRoutePlanSheet(
              context,
              bundle: bundle,
              initialFromId: initialFromId,
              onFocus: (junction) async => onFocus?.call(junction),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _chooseTo(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('asks for junctions before showing a total', (tester) async {
    await _open(tester);

    expect(find.text('Plan a walk'), findsOneWidget);
    expect(find.text('Pick two junctions'), findsOneWidget);
    expect(find.textContaining('walking'), findsNothing);
  });

  testWidgets('shows the shortest distance and time', (tester) async {
    await _open(tester, initialFromId: 'j1');
    await _chooseTo(tester, 'Junction 3');

    expect(find.text('700 m'), findsOneWidget);
    expect(find.text('~14 min walking'), findsOneWidget);
    expect(find.text('Junction 1 to Junction 3'), findsOneWidget);
    expect(find.textContaining('via Gully Track'), findsOneWidget);
    expect(find.textContaining('check park alerts'), findsOneWidget);
  });

  testWidgets('out and back doubles the total and says each way', (
    tester,
  ) async {
    await _open(tester, initialFromId: 'j1');
    await _chooseTo(tester, '2 · Creek Junction');

    await tester.tap(find.text('Out and back'));
    await tester.pumpAndSettle();

    expect(find.text('2.0 km'), findsOneWidget);
    expect(find.text('~40 min walking'), findsOneWidget);
    expect(find.text('1.0 km each way'), findsOneWidget);
    expect(find.text('Back to the start'), findsOneWidget);
  });

  testWidgets('a loop drops the destination field and returns to the start', (
    tester,
  ) async {
    await _open(tester, initialFromId: 'j1');

    await tester.tap(find.text('Loop'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('2.2 km'), findsOneWidget);
    expect(find.text('~44 min walking'), findsOneWidget);
    expect(find.text('Loop from Junction 1 and back'), findsOneWidget);
  });

  testWidgets('explains a junction with no loop', (tester) async {
    await _open(tester, initialFromId: 'j4');

    await tester.tap(find.text('Loop'));
    await tester.pumpAndSettle();

    expect(find.text('No mapped loop from here'), findsOneWidget);
  });

  testWidgets('explains when the content has no route', (tester) async {
    await _open(tester, initialFromId: 'j1');
    await _chooseTo(tester, 'Junction 5');

    expect(
      find.text('No mapped route between these junctions'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a junction in the itinerary focuses it', (tester) async {
    Junction? focused;
    await _open(tester, initialFromId: 'j1', onFocus: (j) => focused = j);
    await _chooseTo(tester, 'Junction 3');

    await tester.tap(find.widgetWithText(ListTile, 'Junction 3'));
    await tester.pumpAndSettle();

    expect(find.text('Plan a walk'), findsNothing);
    expect(focused?.id, 'j3');
  });
}
