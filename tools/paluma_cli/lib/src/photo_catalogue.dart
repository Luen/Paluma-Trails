import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'repo.dart';

/// Checks that every published photo has matching source and permission records.
///
/// This verifies provenance integrity, not whether a permission is legally
/// sufficient. Maintainers still review the source and permission wording.
List<String> validatePhotoCatalogue(
  Repo repo,
  List<Map<String, Object?>> pois,
) {
  final references = <(String, String)>{
    for (final poi in pois)
      for (final photo
          in (poi['photos'] as List? ?? const []).cast<Map<String, Object?>>())
        (photo['file']! as String, poi['id']! as String),
  };
  if (references.isEmpty) return [];
  final problems = <String>[];
  final file = File(p.join(repo.contentDir, 'photos', 'catalogue.json'));
  Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FileSystemException {
    return ['photo catalogue is missing or unreadable: ${file.path}'];
  } on FormatException {
    return ['photo catalogue is not valid JSON'];
  }
  if (decoded is! Map || decoded['images'] is! List) {
    return ['photo catalogue must contain an images array'];
  }
  final recorded = <(String, String)>{};
  final hashes = <String, String>{};
  for (final entry in decoded['images'] as List) {
    if (entry is! Map ||
        entry['file'] is! String ||
        entry['poi_id'] is! String) {
      problems.add('photo catalogue entry needs file and poi_id strings');
      continue;
    }
    final name = entry['file'] as String;
    final poiId = entry['poi_id'] as String;
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*\.(?:jpg|jpeg|png|webp)$')
        .hasMatch(name)) {
      problems.add('unsafe photo catalogue filename: $name');
      continue;
    }
    if (!recorded.add((name, poiId))) {
      problems.add('duplicate photo catalogue record: $name for $poiId');
    }
    for (final key in ['caption', 'original_credit']) {
      if (entry[key] is! String || (entry[key] as String).trim().isEmpty) {
        problems.add('photo catalogue $name needs $key');
      }
    }
    final permission = entry['permission_record'];
    if (permission is! String || permission.trim().isEmpty) {
      problems.add('photo catalogue $name needs permission_record');
    } else {
      final recordPath = p.normalize(p.join(file.parent.path, permission));
      if (p.isAbsolute(permission) ||
          !p.isWithin(repo.contentDir, recordPath) ||
          p.extension(recordPath) != '.md' ||
          !File(recordPath).existsSync()) {
        problems.add(
            'photo catalogue $name has missing or unsafe permission_record');
      }
    }
    final expected = entry['sha256'];
    if (expected is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(expected)) {
      problems.add('photo catalogue $name needs a SHA-256 digest');
      continue;
    }
    final image = File(p.join(file.parent.path, name));
    if (!image.existsSync()) {
      problems.add('photo catalogue references missing image: $name');
      continue;
    }
    try {
      final actual = hashes.putIfAbsent(
        name,
        () => sha256.convert(image.readAsBytesSync()).toString(),
      );
      if (actual != expected) {
        problems.add('photo catalogue SHA-256 mismatch: $name');
      }
    } on FileSystemException {
      problems.add('photo catalogue cannot read image: $name');
    }
  }
  for (final reference in references.difference(recorded)) {
    problems.add(
        'photo ${reference.$1} for ${reference.$2} has no catalogue record');
  }
  return problems;
}
