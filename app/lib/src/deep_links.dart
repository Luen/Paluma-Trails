import 'package:flutter/foundation.dart';

/// Where a printed QR code or a shared link asks the app to open.
///
/// The scheme is deliberately dull so a code printed on a sign never has to
/// change:
///
/// - `https://<host>/poi/<id>` — the usual form, and the one a QR code encodes;
/// - `https://<host>/?poi=<id>` — for hosts that cannot rewrite paths to the
///   app's `index.html`;
/// - `paluma://poi/<id>` — accepted now so a native app link can be added
///   without reprinting anything.
///
/// Only the path and the id matter: the host is whatever serves the web build,
/// so moving the site or changing the domain leaves the codes working.
@immutable
class DeepLink {
  const DeepLink.poi(this.poiId);

  /// The content id of a point of interest, e.g. `gold-creek-falls`.
  final String poiId;
}

/// Reads a POI out of a launch URL, or null when the link is not one we know.
///
/// Unknown paths and ids are ignored rather than guessed at: a mistyped code
/// should open the map, not the nearest thing that happens to share a prefix.
DeepLink? parseDeepLink(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'paluma') {
    if (uri.host.toLowerCase() != 'poi') return null;
    return _poiLink(uri.pathSegments.isEmpty ? null : uri.pathSegments.first);
  }

  if (scheme != 'http' && scheme != 'https') return null;

  final segments = [...uri.pathSegments];
  while (segments.isNotEmpty && segments.last.isEmpty) {
    segments.removeLast();
  }
  if (segments.length == 2 && segments.first.toLowerCase() == 'poi') {
    return _poiLink(segments.last);
  }

  // A query form, for static hosts without a rewrite rule. Only used when the
  // path itself says nothing else.
  if (segments.isEmpty) {
    return _poiLink(uri.queryParameters['poi']);
  }
  return null;
}

DeepLink? _poiLink(String? raw) {
  final id = raw?.trim().toLowerCase();
  if (id == null || id.isEmpty) return null;
  if (!_poiId.hasMatch(id)) return null;
  return DeepLink.poi(id);
}

/// Lowercase slugs, the same shape `content/data/paluma/pois.json` uses. The
/// strict pattern also keeps `..` and slashes from ever reaching a file path.
final _poiId = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
