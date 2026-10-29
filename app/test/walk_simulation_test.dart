import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/content/models.dart';
import 'package:paluma_trails/src/location/location_service.dart';
import 'package:paluma_trails/src/location/trail_locator.dart';
import 'package:paluma_trails/src/location/walk_simulation.dart';
import 'package:paluma_trails/src/location/walk_tracker.dart';
import 'package:paluma_trails/src/map/walk_preview.dart';

const track = TrackPolyline(
  id: 'test',
  name: 'Test track',
  points: [
    GeoPoint(-19, 146),
    GeoPoint(-19, 146.001),
    GeoPoint(-18.999, 146.001),
  ],
);

void main() {
  test('preview follows each leg and stops exactly at the final vertex', () {
    final simulation = WalkSimulation(track);
    addTearDown(simulation.dispose);
    simulation.advance(const Duration(seconds: 1));
    expect(simulation.position.longitude, inExclusiveRange(146, 146.001));
    expect(simulation.position.latitude, -19);
    expect(simulation.position.heading, closeTo(90, 0.1));
    simulation.advance(const Duration(seconds: 3));
    expect(simulation.position.longitude, 146.001);
    expect(simulation.position.latitude, greaterThan(-19));
    expect(simulation.position.heading, closeTo(0, 0.1));
    simulation.advance(const Duration(days: 1));
    expect(simulation.complete, isTrue);
    expect(simulation.progress, 1);
    expect(simulation.position.latitude, closeTo(-18.999, 1e-9));
    expect(simulation.position.isMocked, isTrue);
  });

  test('pause, speed and restart change only simulated progress', () {
    final simulation = WalkSimulation(track);
    addTearDown(simulation.dispose);
    simulation.speed = 20;
    simulation.advance(const Duration(seconds: 1));
    expect(simulation.metres, closeTo(24, 0.001));
    simulation.togglePause();
    simulation.advance(const Duration(seconds: 10));
    expect(simulation.metres, closeTo(24, 0.001));
    simulation.restart();
    expect(simulation.metres, 0);
    expect(simulation.paused, isFalse);
    expect(() => simulation.speed = 0, throwsArgumentError);
    expect(() => simulation.speed = 1000, throwsArgumentError);
  });

  test('degenerate geometry is rejected and repeated vertices stay finite', () {
    expect(
      () => WalkSimulation(const TrackPolyline(id: 'empty', points: [])),
      throwsArgumentError,
    );
    expect(
      () => WalkSimulation(
        const TrackPolyline(
          id: 'invalid',
          points: [GeoPoint(95, 146), GeoPoint(94, 146)],
        ),
      ),
      throwsArgumentError,
    );
    final simulation = WalkSimulation(
      const TrackPolyline(
        id: 'repeated',
        points: [
          GeoPoint(-19, 146),
          GeoPoint(-19, 146),
          GeoPoint(-19, 146.001),
          GeoPoint(-19, 146.001),
        ],
      ),
    );
    addTearDown(simulation.dispose);
    simulation.advance(const Duration(days: 1));
    expect(simulation.position.longitude, 146.001);
    expect(simulation.position.heading.isFinite, isTrue);
  });

  test(
    'suspending a real walk preserves its total without counting the gap',
    () {
      final walk = WalkTracker();
      walk.add(const GeoPoint(-19, 146));
      walk.add(const GeoPoint(-18.999, 146));
      final before = walk.metres;
      walk.pause();
      walk.add(const GeoPoint(-18, 146));
      expect(walk.metres, before);
      walk.add(const GeoPoint(-17.999, 146));
      expect(walk.metres, closeTo(before * 2, 0.01));
    },
  );

  test(
    'location service consumes mock fixes without a platform plugin',
    () async {
      final simulation = WalkSimulation(track);
      final location = LocationService(driver: simulation);
      await location.start();
      await Future<void>.delayed(Duration.zero);
      expect(location.fix.value!.position.lon, 146);
      expect(location.fix.value!.bearingDeg, closeTo(90, 0.1));
      expect(location.fix.value!.speedMps, 1.2);
      simulation.advance(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(simulation.metres, greaterThan(0));
      simulation.togglePause();
      final paused = simulation.metres;
      simulation.advance(const Duration(seconds: 2));
      expect(simulation.metres, paused);
      simulation.restart();
      await Future<void>.delayed(Duration.zero);
      expect(location.fix.value!.position.lon, 146);
      simulation.advance(const Duration(days: 1));
      await Future<void>.delayed(Duration.zero);
      expect(location.fix.value!.position.lat, closeTo(-18.999, 1e-9));
      await location.stop();
      location.dispose();
      simulation.dispose();
    },
  );

  testWidgets('controls stay labelled and usable at 320 px and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final simulation = WalkSimulation(track);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: WalkPreviewControls(
              simulation: simulation,
              onRestart: simulation.restart,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Simulated position · GPS off'), findsOneWidget);
    expect(find.bySemanticsLabel('Pause'), findsOneWidget);
    expect(find.bySemanticsLabel('Restart'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(find.text('Preview playing'), findsOneWidget);
    await tester.tap(find.text('Restart'));
    await tester.pump();
    simulation.advance(const Duration(days: 1));
    await tester.pump();
    expect(find.text('Preview complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
    simulation.dispose();
  });
}
