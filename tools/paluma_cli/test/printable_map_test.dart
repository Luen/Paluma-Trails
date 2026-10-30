import 'dart:convert';
import 'dart:io';

import 'package:paluma_cli/src/geo.dart';
import 'package:paluma_cli/src/printable_map.dart';
import 'package:paluma_cli/src/repo.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('projection is north-up and has a uniform approximate metre scale', () {
    final projection = PrintProjection([
      [146.1, -19.0],
      [146.3, -18.8],
    ]);
    final southWest = projection.project(146.1, -19.0);
    final northEast = projection.project(146.3, -18.8);
    expect(southWest.$1, lessThan(northEast.$1));
    expect(southWest.$2, greaterThan(northEast.$2));
    final a = projection.project(146.15, -18.9);
    final b = projection.project(146.16, -18.9);
    final projectedM = (b.$1 - a.$1) * projection.metresPerPixel;
    expect(
        projectedM,
        closeTo(
            haversineMeters(
                const LatLon(-18.9, 146.15), const LatLon(-18.9, 146.16)),
            1));
    expect(southWest.$1, greaterThanOrEqualTo(50));
    expect(northEast.$1, lessThanOrEqualTo(950));
    expect(northEast.$2, greaterThanOrEqualTo(50));
    expect(southWest.$2, lessThanOrEqualTo(950));
  });

  test('a single coordinate stays finite; empty input is rejected', () {
    final projection = PrintProjection([
      [146, -19]
    ]);
    final point = projection.project(146, -19);
    expect(point.$1.isFinite && point.$2.isFinite, isTrue);
    expect(() => PrintProjection([]), throwsArgumentError);
  });

  test('real export covers all tracks, junctions and segment references', () {
    final repo = Repo.locate();
    final html = PrintableMap(repo).render();
    Map<String, dynamic> data(String name) =>
        jsonDecode(File(p.join(repo.dataDir, name)).readAsStringSync())
            as Map<String, dynamic>;
    final tracks = data('tracks.geojson')['features'] as List;
    final junctions = data('junctions.json')['junctions'] as List;
    final segments = data('segments.json')['segments'] as List;
    for (final track in tracks) {
      expect(html, contains('data-track="${track['properties']['id']}"'));
    }
    for (final junction in junctions) {
      expect(html, contains('data-marker="${junction['id']}"'));
      expect(html,
          contains((junction['location']['lat'] as num).toStringAsFixed(6)));
    }
    expect(html, contains('${segments.length} mapped segments'));
    expect(RegExp('min estimated</td>').allMatches(html),
        hasLength(segments.length));
    expect(html, contains('Track data is unverified'));
    expect(html, contains('no terrain basemap'));
    expect(html, contains('elevation not included'));
    expect(html, contains('Wanderstories'));
    expect(html, contains("Used with the author's permission"));
  });

  test('saved map is self-contained and deterministic', () {
    final builder = PrintableMap(Repo.locate());
    final html = builder.render();
    expect(builder.render(), html);
    for (final networkAsset in [
      '<script',
      '<img',
      '<link',
      '@import',
      'url('
    ]) {
      expect(html, isNot(contains(networkAsset)));
    }
    expect(html, contains('onclick="window.print()"'));
    expect(html, contains('@media print'));
  });

  test('content cannot inject markup and corrections change the revision', () {
    final scratch = Directory.systemTemp.createTempSync('paluma-print-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final original = Repo.locate();
    final repo = Repo(scratch.path);
    for (final name in [
      'park.json',
      'tracks.geojson',
      'junctions.json',
      'pois.json',
      'segments.json'
    ]) {
      final target = File(p.join(repo.dataDir, name));
      target.parent.createSync(recursive: true);
      File(p.join(original.dataDir, name)).copySync(target.path);
    }
    final palette = File(repo.path('app/lib/src/map/map_palette.dart'));
    palette.parent.createSync(recursive: true);
    File(original.path('app/lib/src/map/map_palette.dart'))
        .copySync(palette.path);
    final before = PrintableMap(repo).render();
    final file = File(p.join(repo.dataDir, 'junctions.json'));
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    (data['junctions'] as List).first['name'] =
        '<script>alert("test")</script>&';
    file.writeAsStringSync(jsonEncode(data));
    final after = PrintableMap(repo).render();
    expect(after, isNot(contains('<script>')));
    expect(after, contains('&lt;script&gt;'));
    final revision = RegExp('map revision ([a-f0-9]{12})');
    expect(revision.firstMatch(before)!.group(1),
        isNot(revision.firstMatch(after)!.group(1)));
  });
}
