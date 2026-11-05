import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'repo.dart';

/// A `/poi/<id>` reference found in a documentation or content file.
class PoiLinkReference {
  const PoiLinkReference(this.file, this.line, this.id);

  /// Path relative to the repository root, with forward slashes.
  final String file;

  /// 1-based line number.
  final int line;

  /// The id as written, lowercased because the app normalises case.
  final String id;

  @override
  String toString() => '$file:$line: /poi/$id';
}

/// Extracts the `/poi/<id>` references in [text].
///
/// Only the printed single-segment form from ADR 0009 counts. A deeper path
/// such as the broken `/poi/assets/...` request in the QA notes is a different
/// URL, not a POI link. Documentation placeholders (`<id>`, `<poi-id>`) are
/// skipped too: they describe the form instead of claiming an id exists.
List<PoiLinkReference> poiLinksInText(String text, {String file = ''}) {
  final references = <PoiLinkReference>[];
  final lines = text.split('\n');
  for (var index = 0; index < lines.length; index++) {
    for (final match in _poiPath.allMatches(lines[index])) {
      final id = _idFrom(match.group(1)!);
      if (id == null) continue;
      references.add(PoiLinkReference(file, index + 1, id));
    }
  }
  return references;
}

/// Reads every `/poi/<id>` under `docs/` and `content/`.
List<PoiLinkReference> documentedPoiLinks(Repo repo) {
  final references = <PoiLinkReference>[];
  for (final dir in const ['docs', 'content']) {
    final root = Directory(repo.path(dir));
    if (!root.existsSync()) continue;
    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => _readable.hasMatch(p.basename(file.path)))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final relative =
          p.relative(file.path, from: repo.root).replaceAll(p.separator, '/');
      references.addAll(
        poiLinksInText(file.readAsStringSync(), file: relative),
      );
    }
  }
  return references;
}

/// Documented links whose id is not in `content/data/paluma/pois.json`.
///
/// A rename or removal that leaves a documented example behind would otherwise
/// point future sign copy at a dead link.
List<String> brokenPoiLinks(Repo repo) =>
    brokenPoiLinksIn(documentedPoiLinks(repo), contentPoiIds(repo));

/// The problems for [links], naming the file and line so the fix is a one-line
/// correction.
List<String> brokenPoiLinksIn(
  Iterable<PoiLinkReference> links,
  Set<String> poiIds,
) =>
    [
      for (final link in links)
        if (!poiIds.contains(link.id))
          '${link.file}:${link.line}: /poi/${link.id} does not match any POI id '
              'in content/data/paluma/pois.json (printed ids are permanent, '
              'ADR 0009).',
    ];

/// The POI ids defined by the content source of truth.
Set<String> contentPoiIds(Repo repo) {
  final poiFile = File(p.join(repo.dataDir, 'pois.json'));
  final json = jsonDecode(poiFile.readAsStringSync()) as Map<String, Object?>;
  return {
    for (final poi in (json['pois'] as List).cast<Map<String, Object?>>())
      if (poi['id'] case final String id) id,
  };
}

/// Everything after `/poi/` up to a delimiter; placeholders and deeper paths
/// are rejected in [_idFrom].
final _poiPath = RegExp(r'''/poi/([^\s`"'()\[\]{}?#;,]+)''');

final _poiId = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

final _readable = RegExp(r'\.(md|json|geojson|txt|html|ya?ml)$');

final _trailingPunctuation = RegExp(r'[.,;:!?]+$');

/// The id in a `/poi/<token>` reference, or null when it is not the printed
/// form.
String? _idFrom(String raw) {
  var token = raw;
  // A trailing slash is harmless to the app's parser; a path with more
  // segments is a different request.
  if (token.endsWith('/')) token = token.substring(0, token.length - 1);
  if (token.isEmpty || token.contains('/')) return null;
  token = token.replaceFirst(_trailingPunctuation, '');
  if (token.isEmpty) return null;
  if (token.contains('<') || token.contains('>')) return null;
  // The app normalises case, so a hand-written `Buttercup-Lookout` still
  // resolves to the lowercase stored id.
  token = token.toLowerCase();
  if (!_poiId.hasMatch(token)) return null;
  return token;
}
