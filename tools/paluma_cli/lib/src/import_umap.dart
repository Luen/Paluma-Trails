import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'geo.dart';

/// Converts the project's uMap export into the content model.
///
/// The export mixes numbered junction markers, points of interest and track
/// polylines in one FeatureCollection. Numbered points become junctions;
/// remaining points become POIs; polylines become tracks. Duplicate polylines
/// (the same track mapped twice) are dropped.
class UmapImport {
  const UmapImport(this.source);

  final Map<String, Object?> source;

  static const sourceId = 'wanderstories-umap-264617';

  /// HTML junk that uMap adds to imported descriptions.
  static final _noise = RegExp(
    r'^(Statistics computed from imported data|Distance:|Minimum Elevation:|'
    r'Maximum Elevation:|Total climb:|Total descent:).*$',
    multiLine: true,
  );

  Map<String, Object?> tracks() {
    final features = <Map<String, Object?>>[];
    final seenGeometry = <String>{};
    final usedIds = <String>{};
    var unnamedConnector = 0;

    for (final feature in _features) {
      final geometry = feature['geometry'];
      if (geometry is! Map || geometry['type'] != 'LineString') continue;
      final rawName = _cleanName(feature['properties']);
      final dedupeKey = _geometryKey(
        rawName ?? '',
        (geometry['coordinates'] as List),
      );
      if (!seenGeometry.add(dedupeKey)) continue;

      String id;
      String? name = rawName;
      var class_ = _classFor(rawName);
      if (rawName == null) {
        unnamedConnector++;
        id = 'connector-$unnamedConnector';
      } else {
        id = _uniqueSlug(rawName, usedIds);
      }

      final properties = <String, Object?>{
        'id': id,
        'name': name,
        'class': class_,
        'length_m': _lengthOf(geometry),
        'maintenance': 'unknown',
        'difficulty': 'unknown',
        'surface': 'unknown',
        'unverified': true,
        'source': sourceId,
      };
      final notes = _cleanDescription(feature['properties']);
      if (notes != null) properties['notes'] = notes;

      features.add({
        'type': 'Feature',
        'properties': properties,
        'geometry': geometry,
      });
    }

    return {'type': 'FeatureCollection', 'features': features};
  }

  Map<String, Object?> junctions() {
    final junctions = <Map<String, Object?>>[];
    for (final feature in _features) {
      final geometry = feature['geometry'];
      if (geometry is! Map || geometry['type'] != 'Point') continue;
      final name = _cleanName(feature['properties']);
      final number = int.tryParse(name ?? '');
      if (number == null) continue;

      final notes = _cleanDescription(feature['properties']);
      junctions.add({
        'id': 'j$number',
        'number': number,
        'name': null,
        'location': _locationOf(geometry),
        'notes': notes,
        'water': null,
        'reception': null,
        'unverified': true,
        'source': sourceId,
      });
    }
    junctions.sort(
      (a, b) => (a['number']! as int).compareTo(b['number']! as int),
    );
    return {'junctions': junctions};
  }

  Map<String, Object?> pois() {
    final pois = <Map<String, Object?>>[];
    final usedIds = <String>{};
    for (final feature in _features) {
      final geometry = feature['geometry'];
      if (geometry is! Map || geometry['type'] != 'Point') continue;
      final name = _cleanName(feature['properties']);
      if (name == null || int.tryParse(name) != null) continue;

      final id = _uniqueSlug(name, usedIds);
      final description = _cleanDescription(feature['properties']);
      pois.add({
        'id': id,
        'name': name,
        'category': _categoryFor(name),
        'location': _locationOf(geometry),
        'summary': null,
        'description': description,
        'qr_id': null,
        'photos': <Object?>[],
        'sources': <Object?>[],
        'unverified': true,
        'source': sourceId,
      });
    }
    pois.sort((a, b) => (a['name']! as String).compareTo(b['name']! as String));
    return {'pois': pois};
  }

  List<Map<String, Object?>> get _features =>
      ((source['features'] as List?) ?? const []).cast<Map<String, Object?>>();

  static String? _cleanName(Object? properties) {
    if (properties is! Map) return null;
    final name = properties['name'];
    if (name is! String) return null;
    final cleaned = _decodeEntities(name).trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static String? _cleanDescription(Object? properties) {
    if (properties is! Map) return null;
    final raw = properties['description'] ?? properties['desc'];
    if (raw is! String) return null;
    var text = _decodeEntities(raw).replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text.replaceAll(_noise, '').trim();
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text.isEmpty ? null : text;
  }

  static String _decodeEntities(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');

  /// 2D length of a LineString geometry in metres, rounded to whole metres.
  static int _lengthOf(Map<Object?, Object?> geometry) {
    final points = (geometry['coordinates'] as List)
        .map((c) => c as List)
        .map(
            (c) => LatLon((c[1]! as num).toDouble(), (c[0]! as num).toDouble()))
        .toList(growable: false);
    return polylineLength(points).round();
  }

  static Map<String, Object?> _locationOf(Map<Object?, Object?> geometry) {
    final coordinates = geometry['coordinates'] as List;
    return {
      'lat': (coordinates[1]! as num).toDouble(),
      'lon': (coordinates[0]! as num).toDouble(),
    };
  }

  static String _classFor(String? name) {
    if (name == null) return 'connector';
    final lower = name.toLowerCase();
    if (lower.contains('mountain bike') || lower.contains('mtb')) return 'mtb';
    if (lower.contains('road')) return 'road';
    if (lower.contains('walk')) return 'walk';
    if (lower.contains('track') || lower.contains('circuit')) return 'track';
    return 'other';
  }

  static String _categoryFor(String name) {
    final lower = name.toLowerCase();
    bool has(List<String> needles) => needles.any(lower.contains);

    if (has(['mine', 'shaft', 'tunnel', 'battery'])) return 'mine';
    if (has(['falls', 'waterfall'])) return 'waterfall';
    if (has(['lookout'])) return 'lookout';
    if (has(['hut'])) return 'hut';
    if (has(['camp'])) return 'campsite';
    if (has(['swimming', 'bathing'])) return 'swimming';
    if (has(['creek', 'water', 'crossing', 'culvert', 'hole', 'pool'])) {
      return 'water';
    }
    if (has(['art', 'cave', 'rock garden'])) return 'art';
    if (has(['junction', 'turnoff', 'turn-off'])) return 'junction';
    if (has(['clearing', 'mill'])) return 'history';
    return 'other';
  }

  static String _uniqueSlug(String name, Set<String> used) {
    var slug = _slugify(name);
    if (slug.isEmpty) slug = 'poi';
    var candidate = slug;
    var n = 2;
    while (!used.add(candidate)) {
      candidate = '$slug-$n';
      n++;
    }
    return candidate;
  }

  /// `Garde's Clearing` → `gardes-clearing`
  static String _slugify(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static String _geometryKey(String name, List<Object?> coordinates) {
    // Only lon/lat participate: some features carry a third elevation value and
    // otherwise-duplicate lines would survive the dedupe.
    final normalised = coordinates
        .map((c) => (c as List)
            .take(2)
            .map((n) => (n as num).toStringAsFixed(5))
            .join(','))
        .join(';');
    return sha256.convert(utf8.encode('$name|$normalised')).toString();
  }
}
