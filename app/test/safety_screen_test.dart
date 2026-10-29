import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:paluma_trails/src/location/location_service.dart';
import 'package:paluma_trails/src/safety_screen.dart';

import 'support/bundle_fixture.dart';

class _Driver implements LocationDriver {
  final StreamController<Position> positionsController =
      StreamController<Position>.broadcast();

  LocationPermission permission = LocationPermission.whileInUse;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Stream<Position> positions({LocationSettings? settings}) =>
      positionsController.stream;

  @override
  Future<LocationPermission> requestPermission() async => permission;
}

Position _position({double latitude = -18.95, double longitude = 146.15}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime(2026, 10, 26, 14, 32),
      accuracy: 8,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      hasAccuracy: true,
      hasHeading: false,
      hasSpeed: false,
      hasAltitude: false,
    );

/// A road to the east and a walking track to the west, so the safety page has
/// both a way out and something that is not one.
const _tracksGeoJson = '''
{"type":"FeatureCollection","features":[
  {"type":"Feature","properties":{"id":"road-1","name":"Dam Road","class":"road"},
   "geometry":{"type":"LineString","coordinates":[[146.16,-18.96],[146.16,-18.94]]}},
  {"type":"Feature","properties":{"id":"walk-1","name":"Walking track","class":"track"},
   "geometry":{"type":"LineString","coordinates":[[146.14,-18.96],[146.14,-18.94]]}}
]}
''';

Future<List<Uri>> _pumpSafety(
  WidgetTester tester, {
  required LocationService location,
}) async {
  final launched = <Uri>[];
  await tester.pumpWidget(
    MaterialApp(
      home: SafetyScreen(
        bundle: testBundle(tracksGeoJson: _tracksGeoJson),
        location: location,
        launch: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
    ),
  );
  return launched;
}

void main() {
  testWidgets('shows the emergency numbers and offline guidance', (
    tester,
  ) async {
    final driver = _Driver();
    final location = LocationService(driver: driver);
    addTearDown(() {
      location.dispose();
      driver.positionsController.close();
    });

    final launched = await _pumpSafety(tester, location: location);

    expect(find.text('Safety & emergency'), findsOneWidget);
    expect(find.text('Call 000'), findsOneWidget);
    expect(find.text('Call 112'), findsOneWidget);
    expect(find.textContaining('Give your coordinates.'), findsOneWidget);
    expect(find.text('Before you set out'), findsOneWidget);
    expect(find.text('Use my location'), findsOneWidget);
    expect(find.textContaining('No reception points'), findsNothing);

    await tester.tap(find.text('Call 000'));
    await tester.pump();
    await tester.tap(find.text('Call 112'));
    await tester.pump();

    expect(launched, [Uri.parse('tel:000'), Uri.parse('tel:112')]);
  });

  testWidgets('shows coordinates, nearest junction and nearest road', (
    tester,
  ) async {
    final driver = _Driver();
    final location = LocationService(driver: driver);
    addTearDown(() {
      location.dispose();
      driver.positionsController.close();
    });

    await _pumpSafety(tester, location: location);

    await tester.tap(find.text('Use my location'));
    await tester.pump();
    await tester.pump();

    driver.positionsController.add(_position());
    await tester.pump();

    expect(find.text('18.95000° S, 146.15000° E'), findsOneWidget);
    expect(find.textContaining('Junction 1'), findsOneWidget);
    expect(find.textContaining('Dam Road'), findsOneWidget);
    expect(find.text('±8 m'), findsOneWidget);
    expect(find.textContaining('No reception points'), findsOneWidget);
  });

  testWidgets('explains a refused permission without hiding the numbers', (
    tester,
  ) async {
    final driver = _Driver()..permission = LocationPermission.denied;
    final location = LocationService(driver: driver);
    addTearDown(() {
      location.dispose();
      driver.positionsController.close();
    });

    await _pumpSafety(tester, location: location);

    expect(find.text('Call 000'), findsOneWidget);
    expect(find.text('Use my location'), findsOneWidget);

    await tester.tap(find.text('Use my location'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Location permission is needed to show where you are.'),
      findsWidgets,
    );
    expect(find.text('Call 000'), findsOneWidget);
    expect(find.text('Allow location'), findsOneWidget);
  });
}
