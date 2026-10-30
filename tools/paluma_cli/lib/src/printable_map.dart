import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'repo.dart';

/// Generates a self-contained, printable planning map from validated content.
///
/// No basemap, web fonts, scripts or network assets are needed to read the saved
/// file. The page's print button invokes the browser's own print/PDF dialogue.
class PrintableMap {
  PrintableMap(this.repo);

  final Repo repo;

  /// Returns deterministic HTML; source dates replace wall-clock timestamps.
  String render() {
    final inputs = <String, String>{
      for (final name in [
        'park.json',
        'tracks.geojson',
        'junctions.json',
        'pois.json',
        'segments.json',
      ])
        name: File(p.join(repo.dataDir, name)).readAsStringSync(),
    };
    Map<String, dynamic> data(String name) =>
        jsonDecode(inputs[name]!) as Map<String, dynamic>;
    final park = data('park.json');
    final tracks = (data('tracks.geojson')['features'] as List)
        .cast<Map<String, dynamic>>();
    final junctions = (data('junctions.json')['junctions'] as List)
        .cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    // Restrict overview markers to researched POIs to keep the small-scale
    // paper map readable. P-numbers belong to this revision, not to QR signs.
    final pois = (data('pois.json')['pois'] as List)
        .cast<Map<String, dynamic>>()
        .where((poi) => (poi['sources'] as List? ?? []).isNotEmpty)
        .toList()
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final segmentData = data('segments.json');
    final segments =
        (segmentData['segments'] as List).cast<Map<String, dynamic>>();
    final numbers = {
      for (final j in junctions) j['id'] as String: j['number'] as int,
    };
    segments.sort((a, b) {
      final order = numbers[a['from']]!.compareTo(numbers[b['from']]!);
      return order != 0
          ? order
          : numbers[a['to']]!.compareTo(numbers[b['to']]!);
    });
    final coordinates = <List<num>>[
      for (final track in tracks)
        for (final c in track['geometry']['coordinates'] as List)
          (c as List).cast<num>(),
      for (final marker in [...junctions, ...pois])
        [marker['location']['lon'] as num, marker['location']['lat'] as num],
    ];
    final projection = PrintProjection(coordinates);
    final paletteFile =
        File(repo.path('app/lib/src/map/map_palette.dart')).readAsStringSync();
    String colour(String token) => RegExp(
          "static const $token = '(#[0-9A-Fa-f]{6})';",
        ).firstMatch(paletteFile)!.group(1)!;
    final ink = colour('casing');
    final poiColour = colour('poi');
    final revision = sha256
        .convert(utf8.encode(jsonEncode(inputs)))
        .toString()
        .substring(0, 12);
    String drawMap(PrintProjection projection, {bool detail = false}) {
      final svg = StringBuffer('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1020" role="img" aria-labelledby="map-title-${detail ? 'detail' : 'overview'} map-desc-${detail ? 'detail' : 'overview'}">
<title id="map-title-${detail ? 'detail' : 'overview'}">${_escape(park['name'])} ${detail ? 'village junction detail' : 'planning overview'}</title>
<desc id="map-desc-${detail ? 'detail' : 'overview'}">North-up trail network with numbered junctions and selected researched points of interest. Coordinates and estimated distances and times are listed below. No terrain or road basemap is included.</desc>
<rect x="1" y="1" width="998" height="1018" fill="white" stroke="$ink"/>
''');
      for (final track in tracks) {
        final properties = track['properties'] as Map;
        final trackClass = properties['class'];
        final stroke = colour(switch (trackClass) {
          'mtb' => 'mtbTrack',
          'road' => 'road',
          'connector' => 'connector',
          _ => 'walkingTrack',
        });
        final points = (track['geometry']['coordinates'] as List).map((c) {
          final xy = projection.project(c[0] as num, c[1] as num);
          return '${_n(xy.$1)},${_n(xy.$2)}';
        }).join(' ');
        final dashed =
            !['walk', 'track', 'mtb', 'road', 'connector'].contains(trackClass);
        svg.writeln('<polyline data-track="${_escape(properties['id'])}" '
            'points="$points" fill="none" stroke="$stroke" stroke-width="3" '
            '${dashed ? 'stroke-dasharray="7 5"' : ''}>'
            '<title>${_escape(properties['name'] ?? properties['id'])} '
            '(${_escape(trackClass)})</title></polyline>');
      }
      // Labels use separate, collision-aware slots with leader lines. Exact
      // coordinates stay at the original marker, never at the shifted label.
      final occupied = <(double, double)>[];
      void marker(Map<String, dynamic> item, String label, bool junction) {
        final location = item['location'] as Map;
        final xy =
            projection.project(location['lon'] as num, location['lat'] as num);
        if (xy.$1 < 40 || xy.$1 > 960 || xy.$2 < 40 || xy.$2 > 930) return;
        final showLabel = detail || !junction || (item['number'] as int) > 26;
        var labelX = xy.$1 + 16;
        var labelY = xy.$2 - 16;
        if (showLabel) {
          search:
          for (var ring = 0; ring < 20; ring++) {
            final radius = 20.0 + ring * 10;
            for (var step = 0; step < 16; step++) {
              final angle = -math.pi / 4 + step * math.pi / 8;
              final x = xy.$1 + radius * math.cos(angle);
              final y = xy.$2 + radius * math.sin(angle);
              if (x < 25 || x > 975 || y < 25 || y > 930) continue;
              if (occupied.every((other) =>
                  (other.$1 - x).abs() > 34 || (other.$2 - y).abs() > 21)) {
                labelX = x;
                labelY = y;
                break search;
              }
            }
          }
          occupied.add((labelX, labelY));
        }
        final stroke = junction ? ink : poiColour;
        if (!showLabel) {
          labelX = xy.$1;
          labelY = xy.$2;
        }
        svg.writeln('<g data-marker="${_escape(item['id'])}"><title>'
            '${_escape(item['name'] ?? 'Junction $label')}</title>'
            '<path d="M${_n(xy.$1)},${_n(xy.$2)} '
            'L${_n(labelX)},${_n(labelY)}" stroke="$stroke" stroke-width="1"/>'
            '<${junction ? 'circle' : 'rect'} '
            '${junction ? 'cx="${_n(xy.$1)}" cy="${_n(xy.$2)}" r="4"' : 'x="${_n(xy.$1 - 4)}" y="${_n(xy.$2 - 4)}" width="8" height="8"'} '
            'fill="white" stroke="$stroke" stroke-width="2"/>'
            '<text x="${_n(labelX)}" y="${_n(labelY)}" fill="$stroke" '
            'font-size="16" font-weight="bold" text-anchor="middle" '
            'stroke="white" stroke-width="4">'
            '${showLabel ? _escape(label) : ''}</text>'
            '<text x="${_n(labelX)}" y="${_n(labelY)}" fill="$stroke" '
            'font-size="16" font-weight="bold" text-anchor="middle">'
            '${showLabel ? _escape(label) : ''}</text></g>');
      }

      for (final j in junctions) {
        marker(j, '${j['number']}', true);
      }
      for (var i = 0; i < pois.length; i++) {
        marker(pois[i], 'P${i + 1}', false);
      }
      final scaleWidth = 1000 / projection.metresPerPixel;
      svg.writeln('''
<rect x="2" y="938" width="996" height="80" fill="white"/>
<rect x="905" y="2" width="65" height="100" fill="white"/>
<g fill="$ink" font-size="16">
<text x="930" y="35" text-anchor="middle">N</text>
<path d="M930,45 L922,65 L938,65 Z"/>
<path d="M930,45 V95" stroke="$ink" stroke-width="3"/>
<path d="M55,970 v-8 m0,8 h${_n(scaleWidth)} v-8" fill="none" stroke="$ink" stroke-width="3"/>
<text x="55" y="947">1 km (approx.)</text><text x="55" y="997">0</text>
<text x="945" y="997" text-anchor="end">WGS84 · north up · no terrain basemap</text>
</g></svg>''');
      return svg.toString();
    }

    final overviewSvg = drawMap(projection);
    final detailSvg = drawMap(
        PrintProjection([
          for (final j in junctions.where((j) => (j['number'] as int) <= 26))
            [j['location']['lon'] as num, j['location']['lat'] as num],
        ]),
        detail: true);
    final junctionRows = junctions.map((j) {
      final location = j['location'] as Map;
      return '<tr><th scope="row">${j['number']}</th>'
          '<td>${_escape(j['name'] ?? 'Junction ${j['number']}')}</td>'
          '<td>${(location['lat'] as num).toStringAsFixed(6)}, '
          '${(location['lon'] as num).toStringAsFixed(6)}</td></tr>';
    }).join('\n');
    final poiRows = <String>[
      for (var i = 0; i < pois.length; i++)
        '<tr><th scope="row">P${i + 1}</th><td>${_escape(pois[i]['name'])}</td>'
            '<td>${_escape(pois[i]['id'])}</td></tr>',
    ].join('\n');
    final segmentRows = segments
        .map((s) => '<tr>'
            '<td>${numbers[s['from']]}–${numbers[s['to']]}</td>'
            '<td>${_escape(s['track_name'] ?? s['track_id'])}</td>'
            '<td>${s['distance_m']} m</td><td>${s['walk_minutes']} min estimated</td>'
            '</tr>')
        .join('\n');
    final attribution = (park['attribution'] as List)
        .cast<Map<String, dynamic>>()
        .where((a) => (a['label'] as String).startsWith('Track network'))
        .map((a) => '${_escape(a['label'])} — ${_escape(a['licence'])}')
        .join('; ');
    return '''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light">
<title>Paluma Trails — printable planning map</title>
<style>
body{font-family:Arial,Helvetica,sans-serif;color:$ink;background:white;margin:0;line-height:1.45}
main{max-width:1000px;margin:auto;padding:24px}h1{font-size:1.8rem;margin:0}h2{margin-top:24px}
.toolbar{display:flex;flex-wrap:wrap;gap:16px;align-items:center;margin-bottom:16px}
button,.toolbar a{min-height:48px;box-sizing:border-box;font:inherit;padding:12px;border:2px solid $ink;background:white;color:$ink;border-radius:4px}
button{cursor:pointer}button:focus-visible,a:focus-visible{outline:3px solid $poiColour;outline-offset:3px}
.notice{border-left:4px solid $ink;padding-left:12px}.meta{font-size:.9rem}.map{margin:16px 0}
svg{display:block;width:100%;height:auto}table{border-collapse:collapse;width:100%;margin:12px 0 24px}
th,td{text-align:left;border-bottom:1px solid $ink;padding:6px;vertical-align:top;overflow-wrap:anywhere}thead{display:table-header-group}tr{break-inside:avoid}
caption{text-align:left;font-weight:bold}.key{display:flex;gap:12px;flex-wrap:wrap}.key span{white-space:nowrap}
@page{size:A4 portrait;margin:12mm}
@media print{body{font-size:10pt}main{max-width:none;padding:0}.toolbar{display:none}h1{font-size:18pt}.map-sheet{break-after:page}.map{margin:6mm 0}h2{break-after:avoid}a{color:inherit}.meta{font-size:9pt}}
</style></head><body><main>
<div class="toolbar"><button type="button" onclick="window.print()">Print / save as PDF</button><a href="./">Open the interactive map</a></div>
<section class="map-sheet"><h1>Paluma Trails</h1><strong>${_escape(park['name'])} · planning overview</strong>
<p class="meta">Content updated ${_escape(park['updated'])} · map revision $revision</p>
<p class="notice">Track data is unverified. This overview has no terrain basemap or current closures.
Check official park advice and carry an appropriate navigation map. ${_escape(park['disclaimer'])}</p>
<div class="map">$overviewSvg</div>
<div class="key"><span>○ Number: junction</span><span>□ P-number: researched POI</span><span>Solid: classified track/road</span><span>Dashed: informal/unclassified</span></div>
<p class="meta">$attribution. Line colours match the app. Core junction numbers are enlarged on the next map. Reference tables follow.
P-numbers apply to this revision only; they are not permanent QR codes.</p></section>
<section class="map-sheet"><h2>Village junction detail</h2>
<p class="meta">Content updated ${_escape(park['updated'])} · map revision $revision · north up</p>
<p>Enlarged central junction network. Same unverified content and map key as the overview; this is not a terrain or closures map.</p>
<div class="map">$detailSvg</div></section>
<section><h2>Junction-to-junction distances</h2>
<p>${_escape(segmentData['estimate']['label'])}. Times exclude breaks and are not guarantees.
These are individual segments, not complete suggested walks; do not add disconnected segments.</p>
<table><caption>${segments.length} mapped segments</caption><thead><tr><th>Junctions</th><th>Track</th><th>Distance</th><th>Estimated time</th></tr></thead><tbody>$segmentRows</tbody></table></section>
<section><h2>Junction reference</h2><p>Coordinates are latitude, longitude in WGS84; mapped positions remain unverified.</p>
<table><caption>${junctions.length} junctions</caption><thead><tr><th>Number</th><th>Name</th><th>Coordinates</th></tr></thead><tbody>$junctionRows</tbody></table></section>
<section><h2>Selected points of interest</h2><p>The overview includes POIs with researched source records, not every POI in the app. Markers do not establish current access or surviving structures.</p>
<table><caption>${pois.length} researched POIs</caption><thead><tr><th>Marker</th><th>Name</th><th>Permanent content ID</th></tr></thead><tbody>$poiRows</tbody></table></section>
</main></body></html>
''';
  }
}

/// Local equirectangular map projection, centred on the supplied WGS84 points.
///
/// A uniform scale preserves the local aspect ratio and provides an approximate
/// scale bar. The planning overview is not a surveyed navigation chart.
class PrintProjection {
  PrintProjection(List<List<num>> coordinates) {
    if (coordinates.isEmpty) throw ArgumentError('A map needs coordinates');
    west = coordinates.map((c) => c[0].toDouble()).reduce(math.min);
    east = coordinates.map((c) => c[0].toDouble()).reduce(math.max);
    south = coordinates.map((c) => c[1].toDouble()).reduce(math.min);
    north = coordinates.map((c) => c[1].toDouble()).reduce(math.max);
    _longitudeMetres =
        111195.08 * math.cos((north + south) / 2 * math.pi / 180);
    final widthM = (east - west) * _longitudeMetres;
    final heightM = (north - south) * 111195.08;
    metresPerPixel = math.max(math.max(widthM / 850, heightM / 850), 1);
    _left = (1000 - widthM / metresPerPixel) / 2;
    _top = (960 - heightM / metresPerPixel) / 2;
  }

  late final double west, east, south, north;
  late final double metresPerPixel;
  late final double _longitudeMetres, _left, _top;

  /// Projects longitude/latitude into the SVG's north-up drawing area.
  (double, double) project(num longitude, num latitude) => (
        _left + (longitude - west) * _longitudeMetres / metresPerPixel,
        _top + (north - latitude) * 111195.08 / metresPerPixel,
      );
}

String _escape(Object? value) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert('$value');
String _n(num value) => value.toStringAsFixed(2);
