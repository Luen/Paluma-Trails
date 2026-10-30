import 'package:flutter/foundation.dart';

/// Where a printed QR code or a shared link asks the app to open.
///
/// One printed form, as decided in `docs/decisions/0009-poi-urls.md`:
///
/// ```
/// https://<origin>/poi/<poi-id>
/// ```
///
/// The origin is a deployment input, never part of the contract: only the path
/// and the id are read, so moving the site leaves printed codes working.
@immutable
class DeepLink {
  const DeepLink.poi(this.poiId);

  /// The content id of a point of interest, e.g. `buttercup-lookout`.
  final String poiId;
}

/// Reads a POI out of a launch URL, or null when the link is not one we know.
///
/// Deliberately strict, per ADR 0009: exactly one `poi` segment and one id,
/// no query-based identity, no app-only scheme, no traversal and no encoded
/// separators. A mistyped or obsolete code shows the not-found sheet rather
/// than opening the nearest thing that happens to share a prefix.
DeepLink? parseDeepLink(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;

  // A trailing slash is harmless; anything else is not the printed form.
  final segments = [...uri.pathSegments];
  while (segments.isNotEmpty && segments.last.isEmpty) {
    segments.removeLast();
  }
  if (segments.length != 2) return null;
  if (segments.first.toLowerCase() != 'poi') return null;

  return _poiLink(segments.last);
}

DeepLink? _poiLink(String raw) {
  // Ids are stored lowercase, so a hand-typed link with capitals still works.
  // This cannot collide with another POI: the grammar has no case variants.
  final id = raw.trim().toLowerCase();
  if (!_poiId.hasMatch(id)) return null;
  return DeepLink.poi(id);
}

/// Lowercase slugs, the same shape `content/data/paluma/pois.json` uses. The
/// strict pattern also keeps `..`, slashes and percent-escapes from ever
/// reaching a file path.
final _poiId = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
