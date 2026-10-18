import 'package:paluma_cli/paluma_cli.dart';
import 'package:test/test.dart';

Map<String, Object?> _tracks(List<Map<String, Object?>> features) => {
      'type': 'FeatureCollection',
      'features': features,
    };

Map<String, Object?> _track(
  String id,
  String? name,
  List<List<num>> coordinates,
) =>
    {
      'type': 'Feature',
      'properties': {'id': id, 'name': name},
      'geometry': {'type': 'LineString', 'coordinates': coordinates},
    };

Map<String, Object?> _junctions(List<Map<String, Object?>> items) => {
      'junctions': items,
    };

Map<String, Object?> _junction(String id, int number, double lat, double lon) =>
    {
      'id': id,
      'number': number,
      'location': {'lat': lat, 'lon': lon},
    };

void main() {
  group('buildSegments', () {
    test('splits a track at the junctions sitting on it', () {
      final result = buildSegments(
        tracks: _tracks([
          _track('test-track', 'Test Track', [
            [146.00, -18.90],
            [146.01, -18.90],
            [146.02, -18.90],
          ]),
        ]),
        junctions: _junctions([
          _junction('j2', 2, -18.90, 146.01),
          _junction('j1', 1, -18.90, 146.00),
          _junction('j3', 3, -18.90, 146.02),
        ]),
      );

      final segments =
          (result['segments'] as List).cast<Map<String, Object?>>();
      expect(segments, hasLength(2));
      expect(segments[0]['from'], 'j1');
      expect(segments[0]['to'], 'j2');
      expect(segments[0]['track_id'], 'test-track');
      expect(segments[0]['track_name'], 'Test Track');
      expect(segments[0]['distance_m'], inInclusiveRange(1040, 1070));
      expect(segments[0]['bearing_deg'], closeTo(90, 1));
      expect(segments[0]['walk_minutes'], 20);
      expect(segments[0], isNot(contains('ascent_m')));
      expect(segments[1]['from'], 'j2');
      expect(segments[1]['to'], 'j3');
    });

    test('ignores junctions that are off the track', () {
      final result = buildSegments(
        tracks: _tracks([
          _track('test-track', 'Test Track', [
            [146.00, -18.90],
            [146.02, -18.90],
          ]),
        ]),
        junctions: _junctions([
          _junction('j1', 1, -18.90, 146.00),
          // ~55 m south of the line, beyond the 40 m snap tolerance.
          _junction('j2', 2, -18.9005, 146.02),
        ]),
      );

      expect(result['segments'], isEmpty);
    });

    test('does not merge the same stretch across different tracks', () {
      final result = buildSegments(
        tracks: _tracks([
          _track('a-track', 'A Track', [
            [146.00, -18.90],
            [146.02, -18.90],
          ]),
          // ~22 m north, well inside the snap tolerance of the junctions.
          _track('b-track', 'B Track', [
            [146.00, -18.8998],
            [146.02, -18.8998],
          ]),
        ]),
        junctions: _junctions([
          _junction('j1', 1, -18.90, 146.00),
          _junction('j2', 2, -18.90, 146.02),
        ]),
      );

      final segments =
          (result['segments'] as List).cast<Map<String, Object?>>();
      expect(segments, hasLength(2));
      expect(
        segments.map((s) => s['track_id']).toSet(),
        {'a-track', 'b-track'},
      );
    });

    test('reports ascent when the track carries elevations', () {
      final result = buildSegments(
        tracks: _tracks([
          _track('test-track', 'Test Track', [
            [146.00, -18.90, 100],
            [146.01, -18.90, 120],
            [146.02, -18.90, 160],
          ]),
        ]),
        junctions: _junctions([
          _junction('j1', 1, -18.90, 146.00),
          _junction('j2', 2, -18.90, 146.02),
        ]),
      );

      final segment =
          (result['segments'] as List).single as Map<String, Object?>;
      expect(segment['ascent_m'], 60);
    });

    test('labels the estimate with the pace that was used', () {
      final result = buildSegments(
        tracks: _tracks([]),
        junctions: _junctions([]),
        paceKmh: 4.5,
      );

      final estimate = result['estimate']! as Map<String, Object?>;
      expect(estimate['pace_kmh'], 4.5);
      expect(estimate['includes_elevation'], isFalse);
      expect(result['tracks_considered'], 0);
    });
  });

  group('walkMinutes', () {
    test('rounds up to the next five minutes', () {
      expect(walkMinutes(1000, 4.0), 15);
      expect(walkMinutes(400, 4.0), 10);
      expect(walkMinutes(4000, 4.0), 60);
    });

    test('never returns less than five minutes', () {
      expect(walkMinutes(10, 4.0), 5);
    });
  });
}
