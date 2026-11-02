import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as p;

import 'repo.dart';
import 'photo_catalogue.dart';

/// Validates every content file against its JSON Schema and checks the
/// references between files.
class ContentValidator {
  ContentValidator(this.repo);

  final Repo repo;

  static const _schemaForFile = {
    'park.json': 'park.schema.json',
    'tracks.geojson': 'tracks.schema.json',
    'junctions.json': 'junctions.schema.json',
    'pois.json': 'pois.schema.json',
    'segments.json': 'segments.schema.json',
    'sources.json': 'sources.schema.json',
    'safety.json': 'safety.schema.json',
    'trip-planning.json': 'trip-planning.schema.json',
  };

  /// Returns a list of human-readable problems; empty means valid.
  List<String> validate() {
    final problems = <String>[];
    final data = <String, Map<String, Object?>>{};

    for (final entry in _schemaForFile.entries) {
      final dataFile = File(p.join(repo.dataDir, entry.key));
      final schemaFile = File(p.join(repo.schemaDir, entry.value));
      if (!dataFile.existsSync()) {
        problems.add('missing content file: ${entry.key}');
        continue;
      }
      if (!schemaFile.existsSync()) {
        problems.add('missing schema file: ${entry.value}');
        continue;
      }
      final json = jsonDecode(dataFile.readAsStringSync());
      if (json is! Map<String, Object?>) {
        problems.add('${entry.key}: expected a JSON object at the top level');
        continue;
      }
      data[entry.key] = json;

      if (entry.key == 'pois.json') {
        problems.addAll(_retiredPoiFields(json));
      }

      final schema = JsonSchema.create(schemaFile.readAsStringSync());
      final result = schema.validate(json);
      if (!result.isValid) {
        for (final error in result.errors) {
          final path =
              error.instancePath.isEmpty ? '(root)' : error.instancePath;
          problems.add('${entry.key} $path: ${error.message}');
        }
      }
    }

    if (problems.isNotEmpty) return problems;

    problems.addAll(_referentialChecks(data));
    problems.addAll(validatePhotoCatalogue(
      repo,
      (data['pois.json']!['pois'] as List).cast<Map<String, Object?>>(),
    ));
    return problems;
  }

  /// `qr_id` was retired in #139: the stable POI id *is* the printed code
  /// (ADR 0009), so a second sequence must not exist. Remove it before schema
  /// validation so the failure names the replacement instead of only reporting
  /// an unknown property.
  List<String> _retiredPoiFields(Map<String, Object?> poisFile) {
    final problems = <String>[];
    final pois = (poisFile['pois'] as List?) ?? const [];
    for (var i = 0; i < pois.length; i++) {
      final poi = pois[i];
      if (poi is! Map<String, Object?> || !poi.containsKey('qr_id')) continue;
      poi.remove('qr_id');
      final id = poi['id'];
      final label = id is String ? 'poi $id' : 'poi #${i + 1}';
      problems.add(
        'pois.json /pois/$i: $label carries "qr_id", which is retired. '
        'The stable POI id is the printed /poi/<id> code (ADR 0009); '
        'remove qr_id instead of adding a second sequence.',
      );
    }
    return problems;
  }

  List<String> _referentialChecks(Map<String, Map<String, Object?>> data) {
    final problems = <String>[];

    final junctionIds = <String>{};
    for (final junction in (data['junctions.json']!['junctions'] as List)
        .cast<Map<String, Object?>>()) {
      final id = junction['id']! as String;
      if (!junctionIds.add(id)) problems.add('duplicate junction id: $id');
    }

    final trackIds = <String>{};
    for (final feature in (data['tracks.geojson']!['features'] as List)
        .cast<Map<String, Object?>>()) {
      final props = feature['properties'] as Map<String, Object?>;
      final id = props['id']! as String;
      if (!trackIds.add(id)) problems.add('duplicate track id: $id');
    }

    final poiIds = <String>{};
    for (final poi
        in (data['pois.json']!['pois'] as List).cast<Map<String, Object?>>()) {
      final id = poi['id']! as String;
      if (!poiIds.add(id)) problems.add('duplicate poi id: $id');
      for (final photo in (poi['photos'] as List? ?? const [])
          .cast<Map<String, Object?>>()) {
        final file = photo['file']! as String;
        if (!File(p.join(repo.contentDir, 'photos', file)).existsSync()) {
          problems.add('poi $id references missing photo: $file');
        }
      }
    }

    for (final segment in (data['segments.json']!['segments'] as List)
        .cast<Map<String, Object?>>()) {
      final from = segment['from']! as String;
      final to = segment['to']! as String;
      final track = segment['track_id']! as String;
      if (from == to) problems.add('segment from and to are the same: $from');
      if (!junctionIds.contains(from)) {
        problems.add('segment references unknown junction: $from');
      }
      if (!junctionIds.contains(to)) {
        problems.add('segment references unknown junction: $to');
      }
      if (!trackIds.contains(track)) {
        problems.add('segment references unknown track: $track');
      }
    }

    return problems;
  }
}

/// Small helper so other commands can print consistent results.
void writeJson(File file, Object? json) {
  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(json)}\n');
}

/// Reads a file as UTF-8 bytes, ignoring a BOM if present.
String readTextWithBom(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = Uint8List.fromList(bytes);
  var start = 0;
  if (data.length >= 3 &&
      data[0] == 0xEF &&
      data[1] == 0xBB &&
      data[2] == 0xBF) {
    start = 3;
  }
  return utf8.decode(data.sublist(start));
}
