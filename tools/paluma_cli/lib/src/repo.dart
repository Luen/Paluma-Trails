import 'dart:io';

import 'package:path/path.dart' as p;

/// Locates the repository root and the directories the tool works with.
///
/// The root is the nearest ancestor of either the current directory or the
/// script location that contains both `content/schema` and `tools/paluma_cli`.
class Repo {
  Repo(this.root);

  final String root;

  static Repo locate() {
    final candidates = <Directory>[
      Directory.current,
      if (Platform.script.scheme == 'file')
        File.fromUri(Platform.script).parent,
    ];
    for (final start in candidates) {
      var dir = start.absolute;
      for (var i = 0; i < 8; i++) {
        if (Directory(p.join(dir.path, 'content', 'schema')).existsSync() &&
            Directory(p.join(dir.path, 'tools', 'paluma_cli')).existsSync()) {
          return Repo(dir.path);
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    throw StateError(
      'Could not locate the repository root from ${Directory.current.path}. '
      'Run this tool from inside the Paluma-Trails repository.',
    );
  }

  String path(String relative) => p.join(root, relative);

  String get contentDir => path('content');
  String get dataDir => path('content/data/paluma');
  String get schemaDir => path('content/schema');
  String get basemapDir => path('content/basemap');
  String get bundleDir => path('app/assets/bundle');
}
