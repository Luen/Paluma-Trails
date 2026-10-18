import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'bundle.dart';
import 'graph.dart';
import 'import_umap.dart';
import 'repo.dart';
import 'validate.dart';

/// Entry point for the content tooling.
class PalumaCli {
  Future<int> run(List<String> args) async {
    final runner = CommandRunner<int>(
      'paluma_cli',
      'Paluma Trails content tooling: import, validate, graph, bundle.',
    )
      ..addCommand(_ContentCommand())
      ..addCommand(_BundleCommand());
    try {
      return await runner.run(args) ?? 0;
    } on UsageException catch (error) {
      stderr
        ..writeln(error.message)
        ..writeln()
        ..writeln(error.usage);
      return 64;
    }
  }
}

class _ContentCommand extends Command<int> {
  _ContentCommand() {
    addSubcommand(_ValidateCommand());
    addSubcommand(_GraphCommand());
    addSubcommand(_ImportUmapCommand());
  }

  @override
  String get name => 'content';

  @override
  String get description => 'Work with the source content in content/data.';
}

class _ValidateCommand extends Command<int> {
  @override
  String get name => 'validate';

  @override
  String get description =>
      'Validate every content file against its JSON Schema and check references.';

  @override
  Future<int> run() async {
    final repo = Repo.locate();
    final problems = ContentValidator(repo).validate();
    if (problems.isEmpty) {
      stdout.writeln('Content is valid.');
      return 0;
    }
    stderr.writeln('Content has ${problems.length} problem(s):');
    for (final problem in problems) {
      stderr.writeln('  - $problem');
    }
    return 1;
  }
}

class _GraphCommand extends Command<int> {
  @override
  String get name => 'graph';

  @override
  String get description =>
      'Recompute segments.json (junction-to-junction distances and times).';

  @override
  Future<int> run() async {
    final repo = Repo.locate();
    final segments = _buildSegments(repo);
    writeJson(File(p.join(repo.dataDir, 'segments.json')), segments);

    final list = (segments['segments'] as List).cast<Map<String, Object?>>();
    final totalM = list.fold<int>(
      0,
      (sum, s) => sum + (s['distance_m']! as int),
    );
    stdout
      ..writeln('Wrote ${list.length} segments.')
      ..writeln(
        'Total track covered between junctions: '
        '${(totalM / 1000).toStringAsFixed(1)} km.',
      );
    return 0;
  }

  Map<String, Object?> _buildSegments(Repo repo) {
    final tracks = _read(repo, 'tracks.geojson');
    final junctions = _read(repo, 'junctions.json');
    return buildSegments(tracks: tracks, junctions: junctions);
  }
}

class _ImportUmapCommand extends Command<int> {
  _ImportUmapCommand() {
    argParser.addOption(
      'source',
      defaultsTo: 'content/sources/umap-264617.geojson',
      help: 'Path to the raw uMap export, relative to the repo root.',
    );
  }

  @override
  String get name => 'import-umap';

  @override
  String get description =>
      'Regenerate tracks/junctions/pois from the raw uMap export.';

  @override
  Future<int> run() async {
    final repo = Repo.locate();
    final sourcePath = p.join(repo.root, argResults!['source'] as String);
    final source = jsonDecode(readTextWithBom(sourcePath));
    if (source is! Map<String, Object?>) {
      stderr.writeln('$sourcePath is not a GeoJSON FeatureCollection.');
      return 1;
    }
    final import = UmapImport(source);
    final tracks = import.tracks();
    final junctions = import.junctions();
    final pois = import.pois();

    writeJson(File(p.join(repo.dataDir, 'tracks.geojson')), tracks);
    writeJson(File(p.join(repo.dataDir, 'junctions.json')), junctions);
    writeJson(File(p.join(repo.dataDir, 'pois.json')), pois);

    final segments = buildSegments(tracks: tracks, junctions: junctions);
    writeJson(File(p.join(repo.dataDir, 'segments.json')), segments);

    stdout
      ..writeln('Imported from ${p.basename(sourcePath)}:')
      ..writeln('  tracks:     ${(tracks['features'] as List).length}')
      ..writeln('  junctions:  ${(junctions['junctions'] as List).length}')
      ..writeln('  pois:       ${(pois['pois'] as List).length}')
      ..writeln('  segments:   ${(segments['segments'] as List).length}');
    return 0;
  }
}

class _BundleCommand extends Command<int> {
  _BundleCommand() {
    addSubcommand(_BundleBuildCommand());
  }

  @override
  String get name => 'bundle';

  @override
  String get description => 'Build the offline bundle the app loads.';
}

class _BundleBuildCommand extends Command<int> {
  _BundleBuildCommand() {
    argParser.addOption(
      'out',
      help: 'Output directory (defaults to app/assets/bundle).',
    );
  }

  @override
  String get name => 'build';

  @override
  String get description =>
      'Assemble content + basemap + manifest into the bundle directory.';

  @override
  Future<int> run() async {
    final repo = Repo.locate();
    final problems = ContentValidator(repo).validate();
    if (problems.isNotEmpty) {
      stderr.writeln('Refusing to build a bundle from invalid content:');
      for (final problem in problems) {
        stderr.writeln('  - $problem');
      }
      return 1;
    }

    final manifest =
        BundleBuilder(repo).build(outDir: argResults!['out'] as String?);
    final totals = manifest['totals']! as Map<String, Object?>;
    stdout
      ..writeln('Bundle ${manifest['bundle_version']}')
      ..writeln('  files: ${totals['files']}')
      ..writeln(
        '  size:  ${((totals['bytes']! as int) / 1024 / 1024).toStringAsFixed(2)} MiB',
      );
    return 0;
  }
}

Map<String, Object?> _read(Repo repo, String name) {
  final file = File(p.join(repo.dataDir, name));
  if (!file.existsSync()) {
    throw StateError('${file.path} does not exist. Run content import first.');
  }
  return jsonDecode(readTextWithBom(file.path)) as Map<String, Object?>;
}
