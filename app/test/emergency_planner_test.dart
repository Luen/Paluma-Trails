import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/content/models.dart';
import 'package:paluma_trails/src/location/emergency_planner.dart';
import 'package:paluma_trails/src/location/trail_locator.dart';

const _here = GeoPoint(-18.95, 146.15);

EmergencyPlanner _planner({
  List<Junction> junctions = const [],
  List<TrackPolyline> tracks = const [],
}) => EmergencyPlanner(
  origin: _here,
  junctions: {for (final junction in junctions) junction.id: junction},
  tracks: tracks,
);

TrackPolyline _line(
  String id, {
  String name = 'Track',
  String trackClass = 'track',
  List<GeoPoint> points = const [],
}) => TrackPolyline(id: id, name: name, trackClass: trackClass, points: points);

void main() {
  test('the nearest junction wins and reports a straight-line bearing', () {
    final plan = _planner(
      junctions: const [
        Junction(id: 'near', number: 1, location: GeoPoint(-18.949, 146.15)),
        Junction(id: 'far', number: 2, location: GeoPoint(-18.940, 146.15)),
      ],
    ).planFor(_here);

    expect(plan.nearestJunction!.junction.id, 'near');
    expect(plan.nearestJunction!.distanceM, closeTo(111.2, 2));
    expect(plan.nearestJunction!.bearingDeg, closeTo(0, 1));
  });

  test('the nearest point on a road, not just its vertices, is measured', () {
    final plan = _planner(
      tracks: [
        _line(
          'road',
          name: 'Dam Road',
          trackClass: 'road',
          points: const [GeoPoint(-18.96, 146.16), GeoPoint(-18.94, 146.16)],
        ),
      ],
    ).planFor(_here);

    // A degree of longitude at this latitude is about 1053 m.
    expect(plan.nearestRoad!.label, 'Dam Road');
    expect(plan.nearestRoad!.distanceM, closeTo(1053, 20));
    expect(plan.nearestRoad!.bearingDeg, closeTo(90, 1));
  });

  test('walking tracks are not counted as a way out', () {
    final plan = _planner(
      tracks: [
        _line(
          'walk',
          trackClass: 'track',
          points: const [
            GeoPoint(-18.96, 146.15001),
            GeoPoint(-18.94, 146.15001),
          ],
        ),
      ],
    ).planFor(_here);

    expect(plan.nearestRoad, isNull);
  });

  test('only junctions recorded as having reception are listed', () {
    final plan = _planner(
      junctions: const [
        Junction(
          id: 'no-reception',
          number: 1,
          location: GeoPoint(-18.949, 146.15),
        ),
        Junction(
          id: 'reception',
          number: 2,
          location: GeoPoint(-18.948, 146.15),
          reception: true,
        ),
      ],
    ).planFor(_here);

    expect(plan.receptionPoints, hasLength(1));
    expect(plan.receptionPoints.single.junction.id, 'reception');
    expect(plan.receptionPoints.single.distanceM, closeTo(222.4, 2));
  });

  test('bearingBetween points the way a walker would', () {
    expect(
      bearingBetween(
        const GeoPoint(-18.95, 146.15),
        const GeoPoint(-18.94, 146.15),
      ),
      closeTo(0, 0.5),
    );
    expect(
      bearingBetween(
        const GeoPoint(-18.95, 146.15),
        const GeoPoint(-18.95, 146.16),
      ),
      closeTo(90, 0.5),
    );
    expect(
      bearingBetween(
        const GeoPoint(-18.95, 146.15),
        const GeoPoint(-18.96, 146.15),
      ),
      closeTo(180, 0.5),
    );
  });

  test('the shipped Paluma content has a road to point at', () {
    final bundle = _bundleFile('assets/bundle/content/tracks.geojson');
    final junctions = {
      for (final json in _jsonList(
        _bundleFile('assets/bundle/content/junctions.json'),
        'junctions',
      ))
        (json['id']! as String): Junction.fromJson(json),
    };

    final plan = EmergencyPlanner.fromGeoJson(
      tracksGeoJson: bundle,
      origin: const GeoPoint(-18.9566, 146.1886),
      junctions: junctions,
    ).planFor(const GeoPoint(-18.9566, 146.1886));

    expect(plan.nearestJunction, isNotNull);
    expect(plan.nearestRoad, isNotNull);
    expect(junctions.length, greaterThan(30));
  });
}

String _bundleFile(String path) => File(path).readAsStringSync();

List<Map<String, Object?>> _jsonList(String source, String key) =>
    (decodeJsonObject(source)[key]! as List).cast<Map<String, Object?>>();
