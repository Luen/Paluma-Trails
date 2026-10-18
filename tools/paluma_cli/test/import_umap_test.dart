import 'package:paluma_cli/src/import_umap.dart';
import 'package:test/test.dart';

Map<String, Object?> _line(List<List<num>> coordinates) => {
      'type': 'LineString',
      'coordinates': coordinates,
    };

Map<String, Object?> _point(double lon, double lat) => {
      'type': 'Point',
      'coordinates': [lon, lat],
    };

Map<String, Object?> _feature(
  String? name,
  String? description,
  Map<String, Object?> geometry,
) =>
    {
      'type': 'Feature',
      'properties': {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      },
      'geometry': geometry,
    };

const _description = 'A nice walk<br>Distance: 2.1 km<br>Total climb: 100 m<br>'
    'Statistics computed from imported data';

void main() {
  final umap = UmapImport({
    'type': 'FeatureCollection',
    'features': [
      _feature(
          'Creek Walk',
          _description,
          _line([
            [146.00, -18.90],
            [146.02, -18.90],
          ])),
      // Exact duplicate of the walk, as the source map contains twice.
      _feature(
          'Creek Walk',
          _description,
          _line([
            [146.00, -18.90],
            [146.02, -18.90],
          ])),
      // Unnamed polyline: a connector between tracks.
      _feature(
          null,
          null,
          _line([
            [146.00, -18.91],
            [146.01, -18.91],
          ])),
      _feature('3', null, _point(146.01, -18.90)),
      _feature('Fancy Lookout', 'Great views', _point(146.015, -18.905)),
    ],
  });

  group('tracks', () {
    test('dedupes repeated polylines and names the unnamed ones', () {
      final tracks =
          (umap.tracks()['features'] as List).cast<Map<String, Object?>>();
      expect(tracks, hasLength(2));
      expect(
        tracks.map((f) => (f['properties']! as Map)['id']).toList(),
        ['creek-walk', 'connector-1'],
      );
    });

    test('computes the properties the app draws and labels with', () {
      final tracks =
          (umap.tracks()['features'] as List).cast<Map<String, Object?>>();
      final properties = tracks.first['properties']! as Map<String, Object?>;

      expect(properties['name'], 'Creek Walk');
      expect(properties['class'], 'walk');
      expect(properties['length_m'], inInclusiveRange(2090, 2120));
      expect(properties['unverified'], isTrue);
      expect(properties['source'], UmapImport.sourceId);
      expect(properties['notes'], 'A nice walk');
    });
  });

  group('junctions', () {
    test('takes numbered point markers', () {
      final junctions =
          (umap.junctions()['junctions'] as List).cast<Map<String, Object?>>();
      expect(junctions, hasLength(1));
      expect(junctions.single['id'], 'j3');
      expect(junctions.single['number'], 3);
      expect(
        (junctions.single['location']! as Map<String, Object?>)['lat'],
        -18.90,
      );
    });
  });

  group('pois', () {
    test('takes named points and guesses the category', () {
      final pois = (umap.pois()['pois'] as List).cast<Map<String, Object?>>();
      expect(pois, hasLength(1));
      expect(pois.single['id'], 'fancy-lookout');
      expect(pois.single['name'], 'Fancy Lookout');
      expect(pois.single['category'], 'lookout');
      expect(pois.single['description'], 'Great views');
      expect(pois.single['unverified'], isTrue);
    });
  });
}
