import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/content/bundle_repository.dart';
import 'package:paluma_trails/src/content/models.dart';

import 'support/bundle_fixture.dart';

void main() {
  group('mapGeoJson', () {
    const source = '''
    {"type":"FeatureCollection","features":[
      {"type":"Feature","properties":{"id":"j1","number":1,"water":null},
       "geometry":{"type":"Point","coordinates":[146.1,-18.9]}},
      {"type":"Feature","properties":{"number":2},
       "geometry":{"type":"Point","coordinates":[146.2,-18.8]}}
    ]}
    ''';

    test('promotes the content id to a top-level id', () {
      final mapped = LoadedBundle.mapGeoJson(source, const ['number']);

      final features = (mapped['features'] as List)
          .cast<Map<String, Object?>>();
      expect(features, hasLength(1));
      expect(features.single['id'], 'j1');
      expect(jsonDecode(jsonEncode(features.single['geometry'])), {
        'type': 'Point',
        'coordinates': [146.1, -18.9],
      });
    });

    test('keeps only the requested properties, plus the id', () {
      final mapped = LoadedBundle.mapGeoJson(source, const ['number']);
      final feature =
          (mapped['features'] as List).single as Map<String, Object?>;

      expect(feature['properties'], {'id': 'j1', 'number': 1});
    });
  });

  group('feature collections built from the content model', () {
    test('junctions become point features with lon/lat coordinates', () {
      final bundle = testBundle();
      final collection = bundle.junctionsFeatureCollection();
      final features = (collection['features'] as List)
          .cast<Map<String, Object?>>();

      expect(features, hasLength(2));
      final j1 = features.firstWhere((f) => f['id'] == 'j1');
      expect(j1['type'], 'Feature');
      expect(jsonDecode(jsonEncode(j1['geometry'])), {
        'type': 'Point',
        'coordinates': [146.188682, -18.941853],
      });
      final properties = j1['properties']! as Map<String, Object?>;
      expect(properties['number'], 1);
      expect(properties, isNot(contains('name')));

      final j2 = features.firstWhere((f) => f['id'] == 'j2');
      expect(
        (j2['properties']! as Map<String, Object?>)['name'],
        'Big Crystal Creek junction',
      );
    });

    test('POIs become point features with name and category', () {
      final bundle = testBundle();
      final collection = bundle.poisFeatureCollection();
      final features = (collection['features'] as List)
          .cast<Map<String, Object?>>();

      expect(features, hasLength(1));
      final properties = features.single['properties']! as Map<String, Object?>;
      expect(properties['name'], 'Little Crystal Creek Falls');
      expect(properties['category'], 'waterfall');
      expect(properties['unverified'], isTrue);
      expect(features.single['id'], 'little-crystal-creek-falls');
    });
  });

  group('Junction', () {
    test('parses the bundle shape', () {
      final junction = Junction.fromJson({
        'id': 'j5',
        'number': 5,
        'name': 'Windy Corner',
        'location': {'lat': -18.94, 'lon': 146.18},
        'notes': 'Very windy after the saddle.',
        'water': true,
        'reception': null,
        'unverified': true,
      });

      expect(junction.label, 'Windy Corner');
      expect(junction.location.lat, -18.94);
      expect(junction.water, isTrue);
      expect(junction.reception, isNull);
      expect(junction.unverified, isTrue);
    });

    test('labels unnamed junctions by number', () {
      final junction = Junction.fromJson({
        'id': 'j5',
        'number': 5,
        'name': null,
        'location': {'lat': -18.94, 'lon': 146.18},
      });

      expect(junction.label, 'Junction 5');
    });
  });

  group('Segment', () {
    const segment = Segment(
      from: 'j1',
      to: 'j2',
      trackId: 'tāngaroa-walking-track',
      trackName: 'Tāngaroa Walking Track',
      distanceM: 1200,
      walkMinutes: 20,
      bearingDeg: 90,
      ascentM: 80,
      descentM: 30,
    );

    test('otherEnd finds the far end from either side', () {
      expect(segment.otherEnd('j1'), 'j2');
      expect(segment.otherEnd('j2'), 'j1');
      expect(segment.otherEnd('j3'), isNull);
    });

    test('bearingFrom points away from the starting junction', () {
      expect(segment.bearingFrom('j1'), 90);
      expect(segment.bearingFrom('j2'), 270);
    });

    test('ascentFrom is the climb in the direction walked', () {
      expect(segment.ascentFrom('j1'), 80);
      expect(segment.ascentFrom('j2'), 30);
    });

    test('parses descent_m', () {
      final parsed = Segment.fromJson(const {
        'from': 'j1',
        'to': 'j2',
        'track_id': 't',
        'distance_m': 100,
        'walk_minutes': 5,
        'bearing_deg': 0,
        'ascent_m': 12,
        'descent_m': 4,
      });
      expect(parsed.ascentFrom('j1'), 12);
      expect(parsed.ascentFrom('j2'), 4);
    });
  });

  group('Park', () {
    test('parses metadata with defaults for optional fields', () {
      final park = Park.fromJson({
        'id': 'paluma',
        'name': 'Paluma Range National Park',
        'region': 'Townsville, Queensland',
        'center': {'lat': -18.95, 'lon': 146.15},
        'bounds': {
          'north': -18.8,
          'south': -19.1,
          'east': 146.3,
          'west': 146.05,
        },
        'updated': '2026-10-16',
      });

      expect(park.defaultZoom, 12);
      expect(park.emergencyPhone, '000');
      expect(park.attributions, isEmpty);
    });
  });
}
