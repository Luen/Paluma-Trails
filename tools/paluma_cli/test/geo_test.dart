import 'package:paluma_cli/paluma_cli.dart';
import 'package:test/test.dart';

void main() {
  group('haversineMeters', () {
    test('measures a longitude degree at park latitude within a few metres',
        () {
      // 0.01° of longitude at 18.9° S: 111.32 km × cos(18.9°) ≈ 1053 m.
      final distance = haversineMeters(
          const LatLon(-18.9, 146.0), const LatLon(-18.9, 146.01));
      expect(distance, closeTo(1053, 5));
    });

    test('is zero for identical points', () {
      expect(
        haversineMeters(const LatLon(-18.9, 146.0), const LatLon(-18.9, 146.0)),
        closeTo(0, 1e-9),
      );
    });
  });

  group('initialBearingDegrees', () {
    const origin = LatLon(-18.9, 146.0);

    test('points along the cardinals', () {
      expect(initialBearingDegrees(origin, const LatLon(-18.8, 146.0)),
          closeTo(0, 0.5));
      expect(initialBearingDegrees(origin, const LatLon(-18.9, 146.1)),
          closeTo(90, 0.5));
      expect(initialBearingDegrees(origin, const LatLon(-19.0, 146.0)),
          closeTo(180, 0.5));
      expect(initialBearingDegrees(origin, const LatLon(-18.9, 145.9)),
          closeTo(270, 0.5));
    });
  });

  group('polylineLength', () {
    test('sums the legs', () {
      const points = [
        LatLon(-18.9, 146.0),
        LatLon(-18.9, 146.01),
        LatLon(-18.9, 146.02)
      ];
      expect(polylineLength(points), closeTo(2106, 10));
    });
  });

  group('projectOntoPolyline', () {
    const line = [LatLon(-18.9, 146.0), LatLon(-18.9, 146.02)];

    test('projecting a point beside the line gives the distance along it', () {
      final projection =
          projectOntoPolyline(line, const LatLon(-18.899, 146.01));
      expect(projection, isNotNull);
      expect(projection!.distanceAlongM, closeTo(1053, 10));
      expect(projection.distanceFromM, closeTo(111, 5));
    });

    test('returns null for a degenerate line', () {
      expect(projectOntoPolyline(const [LatLon(-18.9, 146.0)], line.first),
          isNull);
    });
  });

  group('interpolate', () {
    test('returns the midpoint halfway along', () {
      const line = [LatLon(-18.9, 146.0), LatLon(-18.9, 146.02)];
      final middle = interpolate(line, polylineLength(line) / 2);
      expect(middle.lat, closeTo(-18.9, 1e-9));
      expect(middle.lon, closeTo(146.01, 1e-6));
    });

    test('clamps to the ends', () {
      const line = [LatLon(-18.9, 146.0), LatLon(-18.9, 146.02)];
      expect(interpolate(line, -10).lon, 146.0);
      expect(interpolate(line, 9e9).lon, 146.02);
    });
  });
}
