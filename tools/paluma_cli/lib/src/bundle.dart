import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'repo.dart';

/// Assembles the offline bundle the app loads, and writes its manifest.
///
/// The bundle is deterministic: no timestamps, files sorted by path, hashes of
/// the content. CI rebuilds it and diffs against what is committed.
class BundleBuilder {
  BundleBuilder(this.repo);

  final Repo repo;

  static const schemaVersion = 1;
  static const generator = 'paluma_cli 0.1.0';

  /// Builds into [outDir] (defaults to `app/assets/bundle`) and returns the
  /// manifest.
  Map<String, Object?> build({String? outDir}) {
    final target = Directory(outDir ?? repo.bundleDir);
    if (target.existsSync()) target.deleteSync(recursive: true);
    target.createSync(recursive: true);

    _copyData(
        Directory(repo.dataDir), Directory(p.join(target.path, 'content')));
    _copyBasemap(
        Directory(repo.basemapDir), Directory(p.join(target.path, 'basemap')));

    final manifest = _manifestFor(target);
    File(p.join(target.path, 'manifest.json')).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
    return manifest;
  }

  void _copyData(Directory from, Directory to) {
    to.createSync(recursive: true);
    final files = from
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json') || f.path.endsWith('.geojson'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      File(p.join(to.path, p.basename(file.path)))
          .writeAsBytesSync(file.readAsBytesSync());
    }
  }

  void _copyBasemap(Directory from, Directory to) {
    if (!from.existsSync()) return;
    for (final entity in from.listSync(recursive: true)) {
      final relative = p.relative(entity.path, from: from.path);
      if (p.basename(entity.path).startsWith('.')) continue;
      if (entity.path.endsWith('.md')) continue;
      final destination = File(p.join(to.path, relative));
      if (entity is File) {
        destination.parent.createSync(recursive: true);
        destination.writeAsBytesSync(entity.readAsBytesSync());
      }
    }
  }

  Map<String, Object?> _manifestFor(Directory bundle) {
    final files = bundle
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => p.basename(f.path) != 'manifest.json')
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final entries = <Map<String, Object?>>[];
    final versionDigest = AccumulatorSink<Digest>();
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      final digest = sha256.convert(bytes);
      versionDigest.add(digest);
      entries.add({
        'path':
            p.posix.joinAll(p.split(p.relative(file.path, from: bundle.path))),
        'bytes': bytes.length,
        'sha256': digest.toString(),
      });
    }

    final park = jsonDecode(
      File(p.join(bundle.path, 'content', 'park.json')).readAsStringSync(),
    ) as Map<String, Object?>;
    final contentDigest = sha256.convert(versionDigest.digest.bytes);
    final bundleVersion =
        '${park['updated']}-${contentDigest.toString().substring(0, 8)}';

    return {
      'schema_version': schemaVersion,
      'bundle_version': bundleVersion,
      'generator': generator,
      'park': park['id'],
      'files': entries,
      'totals': {
        'files': entries.length,
        'bytes': entries.fold<int>(0, (sum, e) => sum + (e['bytes']! as int)),
      },
    };
  }
}

/// Minimal sink so digests can be fed into another digest without rebuilding
/// a list of bytes.
class AccumulatorSink<T> {
  final _bytes = <int>[];

  void add(T item) {
    if (item is Digest) _bytes.addAll(item.bytes);
  }

  Digest get digest => sha256.convert(_bytes);
}
