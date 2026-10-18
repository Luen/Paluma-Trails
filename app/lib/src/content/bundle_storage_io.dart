import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Copies the packaged bundle into `<documents>/bundle/<version>/` on first run
/// so MapLibre can read the basemap files from disk.
///
/// Returns the directory, or null if it could not be written (the app then
/// falls back to reading assets directly).
Future<String?> materialiseBundle(BundleManifest manifest) async {
  final documents = await getApplicationDocumentsDirectory();
  final directory = Directory(
    p.join(documents.path, 'bundle', manifest.bundleVersion),
  );
  final marker = File(p.join(directory.path, '.complete'));
  if (marker.existsSync()) return directory.path;

  try {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    directory.createSync(recursive: true);
    for (final file in manifest.files) {
      final data = await rootBundle.load('assets/bundle/${file.path}');
      final target = File(
        p.joinAll([directory.path, ...p.posix.split(file.path)]),
      );
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: false,
      );
    }
    marker.writeAsStringSync(manifest.bundleVersion);
    _pruneOldBundles(directory.parent, keep: directory.path);
  } on FileSystemException catch (error) {
    debugPrint('Could not materialise the bundle: $error');
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    return null;
  }
  return directory.path;
}

void _pruneOldBundles(Directory bundlesDir, {required String keep}) {
  if (!bundlesDir.existsSync()) return;
  for (final entity in bundlesDir.listSync()) {
    if (entity is Directory && entity.path != keep) {
      try {
        entity.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort: a stale bundle is not worth failing startup over.
      }
    }
  }
}
