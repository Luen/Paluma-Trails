import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as p;

import 'repo.dart';

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
    final qrIds = <String>{};
    for (final poi
        in (data['pois.json']!['pois'] as List).cast<Map<String, Object?>>()) {
      final id = poi['id']! as String;
      if (!poiIds.add(id)) problems.add('duplicate poi id: $id');
      final qr = poi['qr_id'];
      if (qr is String && !qrIds.add(qr)) {
        problems.add('duplicate poi qr_id: $qr');
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
