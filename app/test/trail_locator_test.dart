import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/content/models.dart';
import 'package:paluma_trails/src/location/trail_locator.dart';

const _earthRadius = 6371008.8;
const _mPerDegLat = math.pi * _earthRadius / 180;

double _mPerDegLon(double lat) => _mPerDegLat * math.cos(lat * math.pi / 180);

/// A point [metres] north of the origin.
GeoPoint _northOf(double metres) => GeoPoint(metres / _mPerDegLat, 0);

void main() {
  group('TrailLocator on a straight track', () {
    // 222 m of track running north, with junctions at 55.6 m and 166.8 m.
    const track = TrackPolyline(
      id: 'straight',
      name: 'Straight Track',
      points: [GeoPoint(0, 0), GeoPoint(0.002, 0)],
    );
    const junctions = <String, Junction>{
      'j1': Junction(id: 'j1', number: 1, location: GeoPoint(0.0005, 0)),
      'j2': Junction(id: 'j2', number: 2, location: GeoPoint(0.0015, 0)),
    };

    TrailLocator build() => TrailLocator(
      origin: const GeoPoint(0, 0),
      tracks: const [track],
      junctions: junctions,
      paceKmh: 4,
    );

    test('picks the junction ahead in the direction of travel', () {
      final fix = build().locate(_northOf(88.96), bearingDeg: 0, speedMps: 1.4);

      expect(fix, isNotNull);
      expect(fix!.track.id, 'straight');
      expect(fix.offTrackM, lessThan(0.5));
      expect(fix.next!.junction.id, 'j2');
      expect(fix.next!.ahead, isTrue);
      expect(fix.next!.directionKnown, isTrue);
      expect(fix.next!.distanceM, closeTo(77.8, 1));
      expect(fix.next!.walkMinutes, 1);
    });

    test('follows the bearing, not the nearest junction', () {
      final fix = build().locate(
        _northOf(88.96),
        bearingDeg: 180,
        speedMps: 1.4,
      )!;

      expect(fix.next!.junction.id, 'j1');
      expect(fix.next!.ahead, isTrue);
      expect(fix.next!.distanceM, closeTo(33.4, 1));
    });

    test('is honest about direction when standing still', () {
      final fix = build().locate(_northOf(88.96), bearingDeg: 0, speedMps: 0)!;

      expect(fix.next!.junction.id, 'j1'); // nearest either way
      expect(fix.next!.directionKnown, isFalse);
      expect(fix.next!.ahead, isFalse);
    });

    test('reports the junction behind when past the last one', () {
      final fix = build().locate(_northOf(200), bearingDeg: 0, speedMps: 1.4)!;

      expect(fix.next!.junction.id, 'j2');
      expect(fix.next!.ahead, isFalse);
      expect(fix.next!.directionKnown, isTrue);
      expect(fix.next!.distanceM, closeTo(33.4, 1));
    });

    test('returns null when the fix is nowhere near a track', () {
      expect(build().locate(const GeoPoint(0.001, 0.01)), isNull);
    });

    test('has no junction answer for a track without junctions', () {
      final locator = TrailLocator(
        origin: const GeoPoint(0, 0),
        tracks: const [track],
        junctions: const {},
        paceKmh: 4,
      );

      final fix = locator.locate(_northOf(50))!;
      expect(fix.next, isNull);
    });

    test('snaps the fix onto the track', () {
      final fix = build().locate(const GeoPoint(0.001, 0.0002))!;

      // 22 m east of the line: still on the track, snapped back onto it.
      expect(fix.offTrackM, closeTo(22.2, 0.5));
      expect(fix.snapped.lon, closeTo(0, 1e-6));
    });
  });

  group('TrailLocator track switching', () {
    // Two parallel tracks 40 m apart; the walker starts on the west one.
    const tracks = [
      TrackPolyline(id: 'west', points: [GeoPoint(0, 0), GeoPoint(0.002, 0)]),
      TrackPolyline(
        id: 'east',
        points: [GeoPoint(0, 0.00036), GeoPoint(0.002, 0.00036)],
      ),
    ];

    TrailLocator build() => TrailLocator(
      origin: const GeoPoint(0, 0),
      tracks: tracks,
      junctions: const {},
      paceKmh: 4,
    );

    test('sticks to the current track within the switching margin', () {
      final locator = build();

      expect(locator.locate(const GeoPoint(0.001, 0))!.track.id, 'west');
      // 25 m east: only 15 m from the east track, but close enough to stay.
      expect(locator.locate(const GeoPoint(0.001, 0.000225))!.track.id, 'west');
    });

    test('switches once the walker is clearly on the other track', () {
      final locator = build();

      expect(locator.locate(const GeoPoint(0.001, 0))!.track.id, 'west');
      // 50 m east: 10 m from the east track, well past the margin.
      expect(locator.locate(const GeoPoint(0.001, 0.00045))!.track.id, 'east');
    });

    test('forgets the previous track once off the network', () {
      final locator = build();

      expect(locator.locate(const GeoPoint(0.001, 0))!.track.id, 'west');
      expect(locator.locate(const GeoPoint(0.001, 0.01)), isNull);
      // Back on the far track: no hysteresis against a stale track.
      expect(locator.locate(const GeoPoint(0.001, 0.00045))!.track.id, 'east');
    });
  });

  group('trackPolylinesFromGeoJson', () {
    test('reads LineStrings and MultiLineStrings', () {
      const source = '''
      {"type":"FeatureCollection","features":[
        {"type":"Feature","properties":{"id":"line","name":"Line"},
         "geometry":{"type":"LineString","coordinates":[[146.1,-18.9],[146.2,-18.8]]}},
        {"type":"Feature","properties":{"id":"multi"},
         "geometry":{"type":"MultiLineString","coordinates":[
           [[146.1,-18.9],[146.15,-18.85]],[[146.2,-18.8],[146.25,-18.75]]]}},
        {"type":"Feature","properties":{"id":"with-height"},
         "geometry":{"type":"LineString","coordinates":[[146.1,-18.9,812],[146.2,-18.8,830]]}}
      ]}
      ''';

      final tracks = trackPolylinesFromGeoJson(source);

      expect(tracks.map((t) => t.id), ['line', 'multi', 'with-height']);
      expect(tracks.first.name, 'Line');
      expect(tracks.first.points, hasLength(2));
      expect(tracks.first.points.first.lat, closeTo(-18.9, 1e-9));
      expect(tracks.first.points.first.lon, closeTo(146.1, 1e-9));
      expect(tracks.first.points.last.lat, closeTo(-18.8, 1e-9));
      expect(tracks[1].points, hasLength(4));
      expect(tracks[2].points, hasLength(2));
    });

    test('skips features that cannot be walked', () {
      const source = '''
      {"type":"FeatureCollection","features":[
        {"type":"Feature","properties":{"number":7},
         "geometry":{"type":"LineString","coordinates":[[146.1,-18.9],[146.2,-18.8]]}},
        {"type":"Feature","properties":{"id":"single-point"},
         "geometry":{"type":"LineString","coordinates":[[146.1,-18.9]]}},
        {"type":"Feature","properties":{"id":"point"},
         "geometry":{"type":"Point","coordinates":[146.1,-18.9]}},
        {"type":"Feature","properties":{"id":"bad-pair"},
         "geometry":{"type":"LineString","coordinates":[[146.1,-18.9],["x",-18.8]]}}
      ]}
      ''';

      expect(trackPolylinesFromGeoJson(source), isEmpty);
    });
  });

  group('TrailLocator against the shipped Paluma content', () {
    late List<TrackPolyline> tracks;
    late Map<String, Junction> junctions;
    late TrailLocator locator;

    setUpAll(() {
      const root = '../content/data/paluma';
      tracks = trackPolylinesFromGeoJson(
        File('$root/tracks.geojson').readAsStringSync(),
      );
      final junctionsJson = jsonDecode(
        File('$root/junctions.json').readAsStringSync(),
      ) as Map<String, Object?>;
      junctions = {
        for (final junction
            in (junctionsJson['junctions'] as List)
                .cast<Map<String, Object?>>())
          junction['id']! as String: Junction.fromJson(junction),
      };
      final park = jsonDecode(
        File('$root/park.json').readAsStringSync(),
      ) as Map<String, Object?>;
      locator = TrailLocator(
        origin: GeoPoint.fromJson(park['center']! as Map<String, Object?>),
        tracks: tracks,
        junctions: junctions,
        paceKmh: 4,
      );
    });

    test('every junction sits on the network', () {
      for (final junction in junctions.values) {
        final fix = locator.locate(junction.location);
        expect(fix, isNotNull, reason: '${junction.id} is off every track');
        expect(fix!.offTrackM, lessThanOrEqualTo(30), reason: junction.id);
      }
    });

    test('walks a real track and counts down to the next junction', () {
      // paluma-track-circuit-5 runs 903 m; j1 sits at 378 m along it, and the
      // vertex a third of the way in is at 247 m.
      final track = tracks.firstWhere((t) => t.id == 'paluma-track-circuit-5');
      final index = track.points.length ~/ 3;
      final start = track.points[index];
      final bearing = _bearingBetween(start, track.points[index + 1]);

      final first = locator.locate(start, bearingDeg: bearing, speedMps: 1.4)!;
      expect(first.track.id, 'paluma-track-circuit-5');
      expect(first.next!.junction.id, 'j1');
      expect(first.next!.directionKnown, isTrue);
      expect(first.next!.ahead, isTrue);
      expect(first.next!.distanceM, closeTo(130, 3));
      expect(first.next!.walkMinutes, 2);

      // 50 m further along the same track: 50 m less to walk.
      final ahead = _pointAlong(
        track.points,
        _cumulativeAt(track.points, index) + 50,
      );
      final second = locator.locate(ahead, bearingDeg: bearing, speedMps: 1.4)!;
      expect(second.track.id, 'paluma-track-circuit-5');
      expect(second.next!.junction.id, 'j1');
      expect(second.next!.distanceM, closeTo(80, 3));
    });
  });
}

/// Compass bearing from [a] to [b], degrees clockwise from north.
double _bearingBetween(GeoPoint a, GeoPoint b) {
  final dx = (b.lon - a.lon) * _mPerDegLon((a.lat + b.lat) / 2);
  final dy = (b.lat - a.lat) * _mPerDegLat;
  return (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
}

/// Distance covered by [points] up to vertex [index], metres.
double _cumulativeAt(List<GeoPoint> points, int index) {
  var total = 0.0;
  for (var i = 0; i < index; i++) {
    total += _distanceBetween(points[i], points[i + 1]);
  }
  return total;
}

/// The point [metres] from the start of [points].
GeoPoint _pointAlong(List<GeoPoint> points, double metres) {
  var travelled = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final edge = _distanceBetween(a, b);
    if (travelled + edge >= metres) {
      final t = edge <= 0 ? 0.0 : (metres - travelled) / edge;
      return GeoPoint(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t);
    }
    travelled += edge;
  }
  return points.last;
}

double _distanceBetween(GeoPoint a, GeoPoint b) {
  final dx = (b.lon - a.lon) * _mPerDegLon((a.lat + b.lat) / 2);
  final dy = (b.lat - a.lat) * _mPerDegLat;
  return math.sqrt(dx * dx + dy * dy);
}
