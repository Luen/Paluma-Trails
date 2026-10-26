/// Trail geometry: turns a raw GPS fix into "where am I on the network" and
/// answers the question that matters on the track — how far to the next
/// junction, measured *along* the track rather than as the crow flies.
///
/// Kept free of Flutter and plugins so it can be unit-tested directly, and
/// against the real Paluma content.
library;

import 'dart:math' as math;

import '../content/models.dart';

/// Mean Earth radius, metres (IUGG).
const _earthRadius = 6371008.8;
const _metresPerDegreeLat = math.pi * _earthRadius / 180;

/// A track polyline in WGS84, ready for nearest-point queries.
class TrackPolyline {
  const TrackPolyline({
    required this.id,
    this.name,
    this.trackClass = 'track',
    required this.points,
  });

  final String id;
  final String? name;

  /// The bundle's track `class`: `track`, `walk`, `road`, `mtb`, `connector`
  /// or `other`.
  final String trackClass;
  final List<GeoPoint> points;
}

/// The junction the walker reaches next along the track they are on.
class NextJunction {
  const NextJunction({
    required this.junction,
    required this.distanceM,
    required this.walkMinutes,
    required this.ahead,
    required this.directionKnown,
  });

  final Junction junction;

  /// Metres of track between the walker and the junction.
  final double distanceM;

  /// Walking time at the bundle's flat-terrain pace, rounded to whole minutes
  /// and never below one.
  final int walkMinutes;

  /// Whether the junction lies in front along the direction of travel. Only
  /// meaningful when [directionKnown] is true.
  final bool ahead;

  /// Whether the fix carried a trustworthy direction of travel. A stationary
  /// walker has none, so the app then says "nearest" rather than "next".
  final bool directionKnown;
}

/// Where a GPS fix sits on the trail network.
class TrailFix {
  const TrailFix({
    required this.track,
    required this.snapped,
    required this.offTrackM,
    this.next,
  });

  final TrackPolyline track;

  /// The fix projected onto the track, in WGS84.
  final GeoPoint snapped;

  /// How far the fix is from [track].
  final double offTrackM;

  /// The next junction, or null when the track carries none.
  final NextJunction? next;
}

/// Matches fixes to tracks and computes the remaining walk to the next
/// junction.
///
/// All distances are computed in a local equirectangular frame centred on
/// [origin] — accurate to well under a metre over a park-sized area, and cheap
/// enough to run on every fix.
class TrailLocator {
  TrailLocator({
    required GeoPoint origin,
    required List<TrackPolyline> tracks,
    required Map<String, Junction> junctions,
    required this.paceKmh,
    this.maxOffTrackM = 150,
    this.minWalkingSpeedMps = 0.7,
    this.junctionOnTrackM = 25,
    this.switchTrackMarginM = 20,
    this.aheadEpsilonM = 10,
  }) : _origin = origin,
       _tracks = [
         for (final track in tracks)
           if (track.points.length >= 2) _ProjectedTrack(track, origin),
       ] {
    // Attach every junction to the tracks it sits on, once.
    for (final track in _tracks) {
      for (final junction in junctions.values) {
        final near = track.nearest(_toLocal(junction.location, origin));
        if (near != null && near.distanceM <= junctionOnTrackM) {
          track.junctions.add(_TrackJunction(junction, near.s));
        }
      }
      track.junctions.sort((a, b) => a.s.compareTo(b.s));
    }
  }

  /// Builds a locator from the bundle's raw track FeatureCollection.
  factory TrailLocator.fromGeoJson({
    required String tracksGeoJson,
    required GeoPoint origin,
    required Map<String, Junction> junctions,
    required double paceKmh,
  }) => TrailLocator(
    origin: origin,
    tracks: trackPolylinesFromGeoJson(tracksGeoJson),
    junctions: junctions,
    paceKmh: paceKmh,
  );

  final GeoPoint _origin;
  final List<_ProjectedTrack> _tracks;

  /// The flat-terrain pace the bundle's walk times are based on.
  final double paceKmh;

  /// Fixes further than this from every track are "off the network" and get no
  /// junction answer.
  final double maxOffTrackM;

  /// Above this speed a bearing is trusted as the direction of travel, m/s.
  final double minWalkingSpeedMps;

  /// A junction counts as being on a track within this distance, metres.
  final double junctionOnTrackM;

  /// Stay on the current track while it is within this much of the nearest
  /// one, so fixes near two tracks do not flicker between them.
  final double switchTrackMarginM;

  /// Junctions closer than this in front are treated as the one underfoot.
  final double aheadEpsilonM;

  _ProjectedTrack? _lastTrack;

  /// Locates [position] on the network, or returns null when it is not near
  /// any track.
  ///
  /// [bearingDeg] and [speedMps] come from the GPS fix; a bearing is only used
  /// as the direction of travel when the walker is actually moving.
  TrailFix? locate(GeoPoint position, {double? bearingDeg, double? speedMps}) {
    final local = _toLocal(position, _origin);

    _ProjectedTrack? best;
    _Nearest? bestNear;
    for (final track in _tracks) {
      final near = track.nearest(local);
      if (near == null) continue;
      if (bestNear == null || near.distanceM < bestNear.distanceM) {
        best = track;
        bestNear = near;
      }
    }
    if (best == null || bestNear == null) {
      _lastTrack = null;
      return null;
    }

    // Hysteresis: stay on the track we were on while it still fits well, so
    // track switches only happen when the walker really moves across.
    final last = _lastTrack;
    if (last != null && last != best) {
      final lastNear = last.nearest(local);
      if (lastNear != null &&
          lastNear.distanceM <= maxOffTrackM &&
          lastNear.distanceM <= bestNear.distanceM + switchTrackMarginM) {
        best = last;
        bestNear = lastNear;
      }
    }

    if (bestNear.distanceM > maxOffTrackM) {
      _lastTrack = null;
      return null;
    }
    _lastTrack = best;

    return TrailFix(
      track: best.track,
      snapped: _toGeo(bestNear.point, _origin),
      offTrackM: bestNear.distanceM,
      next: _nextAlong(best, bestNear.s, bearingDeg, speedMps),
    );
  }

  NextJunction? _nextAlong(
    _ProjectedTrack track,
    double s,
    double? bearingDeg,
    double? speedMps,
  ) {
    if (track.junctions.isEmpty) return null;

    final heading = _headingOf(bearingDeg, speedMps);
    final directionKnown = heading != null;
    final direction = heading == null
        ? 0
        : (track.tangentAt(s).dot(heading) >= 0 ? 1 : -1);

    _TrackJunction? chosen;
    var ahead = false;
    if (direction == 0) {
      chosen = _nearestTo(track.junctions, s);
    } else {
      for (final candidate in track.junctions) {
        if ((candidate.s - s) * direction > aheadEpsilonM) {
          chosen = candidate;
          ahead = true;
          break;
        }
      }
      // Past every junction on this track — report the closest one behind, so
      // a dead-end walk still shows the way back.
      chosen ??= _nearestTo(track.junctions, s);
    }
    if (chosen == null) return null;

    final distanceM = (chosen.s - s).abs();
    return NextJunction(
      junction: chosen.junction,
      distanceM: distanceM,
      walkMinutes: math.max(1, (distanceM / (paceKmh * 1000 / 60)).round()),
      ahead: ahead,
      directionKnown: directionKnown,
    );
  }

  _Vec? _headingOf(double? bearingDeg, double? speedMps) {
    if (bearingDeg == null || !bearingDeg.isFinite) return null;
    if ((speedMps ?? 0) < minWalkingSpeedMps) return null;
    final radians = bearingDeg * math.pi / 180;
    return _Vec(math.sin(radians), math.cos(radians));
  }

  static _TrackJunction? _nearestTo(List<_TrackJunction> junctions, double s) {
    _TrackJunction? best;
    for (final candidate in junctions) {
      if (best == null || (candidate.s - s).abs() < (best.s - s).abs()) {
        best = candidate;
      }
    }
    return best;
  }
}

/// The track polylines inside a bundle's `tracks.geojson`.
///
/// Malformed features are skipped: the bundle is validated by the CLI, and a
/// broken geometry should degrade to "no track answer", not crash the map.
List<TrackPolyline> trackPolylinesFromGeoJson(String source) {
  final decoded = decodeJsonObject(source);
  final features = (decoded['features'] as List?) ?? const [];
  final tracks = <TrackPolyline>[];
  for (final feature in features.cast<Map<String, Object?>>()) {
    final properties =
        (feature['properties'] as Map<String, Object?>?) ?? const {};
    final id = properties['id'];
    if (id is! String) continue;
    final geometry = (feature['geometry'] as Map<String, Object?>?) ?? const {};
    final coordinates = geometry['coordinates'];
    final points = <GeoPoint>[];
    switch (geometry['type']) {
      case 'LineString':
        if (coordinates is List) {
          for (final pair in coordinates) {
            final point = _pointFromPair(pair);
            if (point != null) points.add(point);
          }
        }
      case 'MultiLineString':
        if (coordinates is List) {
          for (final part in coordinates) {
            if (part is! List) continue;
            for (final pair in part) {
              final point = _pointFromPair(pair);
              if (point != null) points.add(point);
            }
          }
        }
      default:
        continue;
    }
    if (points.length < 2) continue;
    tracks.add(
      TrackPolyline(
        id: id,
        name: properties['name'] as String?,
        trackClass: (properties['class'] as String?) ?? 'track',
        points: points,
      ),
    );
  }
  return tracks;
}

/// GeoJSON pairs are `[lon, lat]`.
GeoPoint? _pointFromPair(Object? pair) {
  if (pair is! List || pair.length < 2) return null;
  final lon = pair[0];
  final lat = pair[1];
  if (lat is! num || lon is! num) return null;
  return GeoPoint(lat.toDouble(), lon.toDouble());
}

/// A point in the locator's local metre frame (x east, y north).
class _Vec {
  const _Vec(this.x, this.y);

  final double x;
  final double y;

  double get length => math.sqrt(x * x + y * y);

  double dot(_Vec other) => x * other.x + y * other.y;

  _Vec operator -(_Vec other) => _Vec(x - other.x, y - other.y);
  _Vec operator +(_Vec other) => _Vec(x + other.x, y + other.y);
  _Vec operator *(double factor) => _Vec(x * factor, y * factor);
}

class _Nearest {
  const _Nearest(this.point, this.s, this.distanceM);

  final _Vec point;
  final double s;
  final double distanceM;
}

class _TrackJunction {
  const _TrackJunction(this.junction, this.s);

  final Junction junction;
  final double s;
}

class _ProjectedTrack {
  _ProjectedTrack(this.track, GeoPoint origin)
    : points = [for (final point in track.points) _toLocal(point, origin)] {
    var total = 0.0;
    cumulative.add(0);
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).length;
      cumulative.add(total);
    }
  }

  final TrackPolyline track;
  final List<_Vec> points;

  /// Distance from the start of the polyline to each vertex, metres.
  final List<double> cumulative = [];
  final List<_TrackJunction> junctions = [];

  double get lengthM => cumulative.isEmpty ? 0 : cumulative.last;

  /// The closest point on the polyline to [p], with its along-track distance.
  _Nearest? nearest(_Vec p) {
    _Nearest? best;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final ab = b - a;
      final lengthSq = ab.dot(ab);
      final t = lengthSq <= 0
          ? 0.0
          : ((p - a).dot(ab) / lengthSq).clamp(0.0, 1.0).toDouble();
      final closest = a + ab * t;
      final distance = (p - closest).length;
      if (best == null || distance < best.distanceM) {
        best = _Nearest(
          closest,
          cumulative[i] + t * (cumulative[i + 1] - cumulative[i]),
          distance,
        );
      }
    }
    return best;
  }

  /// The unit tangent of the edge that contains along-track distance [s].
  _Vec tangentAt(double s) {
    for (var i = 0; i < points.length - 1; i++) {
      if (s <= cumulative[i + 1] || i == points.length - 2) {
        final vector = points[i + 1] - points[i];
        final length = vector.length;
        if (length > 0) return vector * (1 / length);
      }
    }
    return const _Vec(0, 0);
  }
}

_Vec _toLocal(GeoPoint point, GeoPoint origin) {
  final metresPerDegreeLon =
      _metresPerDegreeLat * math.cos(origin.lat * math.pi / 180);
  return _Vec(
    (point.lon - origin.lon) * metresPerDegreeLon,
    (point.lat - origin.lat) * _metresPerDegreeLat,
  );
}

GeoPoint _toGeo(_Vec point, GeoPoint origin) {
  final metresPerDegreeLon =
      _metresPerDegreeLat * math.cos(origin.lat * math.pi / 180);
  return GeoPoint(
    origin.lat + point.y / _metresPerDegreeLat,
    origin.lon + point.x / metresPerDegreeLon,
  );
}
