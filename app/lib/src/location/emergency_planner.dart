/// Offline answers for the safety screen: the nearest junction, the nearest
/// mapped road and any junctions with recorded phone reception.
///
/// Kept free of Flutter and plugins so the distance and bearing rules can be
/// unit-tested against synthetic geometry and the real Paluma content.
library;

import 'dart:math' as math;

import '../content/models.dart';
import 'trail_locator.dart';

/// A junction and how to reach it from a point, as the crow flies.
class NearbyJunction {
  const NearbyJunction({
    required this.junction,
    required this.distanceM,
    required this.bearingDeg,
  });

  final Junction junction;

  /// Straight-line distance from the query point, metres.
  final double distanceM;

  /// Compass bearing from the query point to the junction.
  final double bearingDeg;
}

/// The closest point on a mapped road.
class NearbyRoad {
  const NearbyRoad({
    required this.label,
    required this.distanceM,
    required this.bearingDeg,
  });

  final String label;

  /// Straight-line distance from the query point to the road, metres.
  final double distanceM;

  /// Compass bearing from the query point to the closest point on the road.
  final double bearingDeg;
}

/// Everything the safety screen can say about one position without a network.
class EmergencyPlan {
  const EmergencyPlan({
    required this.at,
    required this.nearestJunction,
    required this.nearestRoad,
    required this.receptionPoints,
  });

  final GeoPoint at;
  final NearbyJunction? nearestJunction;
  final NearbyRoad? nearestRoad;

  /// Junctions with `reception: true`, nearest first.
  final List<NearbyJunction> receptionPoints;
}

/// Builds emergency plans from the bundle's track geometry and junctions.
class EmergencyPlanner {
  EmergencyPlanner({
    required GeoPoint origin,
    required List<TrackPolyline> tracks,
    required Map<String, Junction> junctions,
  }) : _origin = origin,
       _junctions = junctions.values.toList(growable: false),
       _roads = [
         for (final track in tracks)
           if (track.trackClass == 'road' && track.points.length >= 2)
             _ProjectedRoad(track, origin),
       ];

  /// Builds a planner from the bundle's raw track FeatureCollection.
  factory EmergencyPlanner.fromGeoJson({
    required String tracksGeoJson,
    required GeoPoint origin,
    required Map<String, Junction> junctions,
  }) => EmergencyPlanner(
    origin: origin,
    tracks: trackPolylinesFromGeoJson(tracksGeoJson),
    junctions: junctions,
  );

  final GeoPoint _origin;
  final List<Junction> _junctions;
  final List<_ProjectedRoad> _roads;

  /// The nearest junction, road and recorded reception points for [position].
  EmergencyPlan planFor(GeoPoint position) {
    final frame = _LocalFrame(_origin);
    final local = frame.toLocal(position);

    NearbyJunction? nearestJunction;
    for (final junction in _junctions) {
      final other = frame.toLocal(junction.location);
      final offset = other - local;
      if (nearestJunction == null ||
          offset.length < nearestJunction.distanceM) {
        nearestJunction = NearbyJunction(
          junction: junction,
          distanceM: offset.length,
          bearingDeg: _bearingOf(offset),
        );
      }
    }

    NearbyRoad? nearestRoad;
    for (final road in _roads) {
      final near = road.nearest(local);
      if (near == null) continue;
      if (nearestRoad == null || near.distanceM < nearestRoad.distanceM) {
        nearestRoad = NearbyRoad(
          label: road.track.name ?? 'Mapped road',
          distanceM: near.distanceM,
          bearingDeg: _bearingOf(near.point - local),
        );
      }
    }

    final reception = <NearbyJunction>[];
    for (final junction in _junctions) {
      if (junction.reception != true) continue;
      final offset = frame.toLocal(junction.location) - local;
      reception.add(
        NearbyJunction(
          junction: junction,
          distanceM: offset.length,
          bearingDeg: _bearingOf(offset),
        ),
      );
    }
    reception.sort((a, b) => a.distanceM.compareTo(b.distanceM));

    return EmergencyPlan(
      at: position,
      nearestJunction: nearestJunction,
      nearestRoad: nearestRoad,
      receptionPoints: reception,
    );
  }
}

/// Compass bearing walking from [from] to [to], degrees clockwise from north.
double bearingBetween(GeoPoint from, GeoPoint to) {
  final frame = _LocalFrame(from);
  return _bearingOf(frame.toLocal(to));
}

double _bearingOf(_Vec vector) {
  if (vector.length == 0) return 0;
  // atan2(east, north) is already clockwise from north.
  final degrees = math.atan2(vector.x, vector.y) * 180 / math.pi;
  return (degrees % 360 + 360) % 360;
}

class _Vec {
  const _Vec(this.x, this.y);

  final double x;
  final double y;

  double get length => math.sqrt(x * x + y * y);

  _Vec operator -(_Vec other) => _Vec(x - other.x, y - other.y);
}

class _Nearest {
  const _Nearest(this.point, this.distanceM);

  final _Vec point;
  final double distanceM;
}

class _ProjectedRoad {
  _ProjectedRoad(this.track, GeoPoint origin) {
    final frame = _LocalFrame(origin);
    for (final point in track.points) {
      points.add(frame.toLocal(point));
    }
  }

  final TrackPolyline track;
  final List<_Vec> points = [];

  /// The closest point on the road to [p], or null when it has no vertices.
  _Nearest? nearest(_Vec p) {
    _Nearest? best;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final ab = b - a;
      final lengthSq = ab.x * ab.x + ab.y * ab.y;
      final t = lengthSq <= 0
          ? 0.0
          : (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / lengthSq)
                .clamp(0.0, 1.0)
                .toDouble();
      final closest = _Vec(a.x + ab.x * t, a.y + ab.y * t);
      final distance = (p - closest).length;
      if (best == null || distance < best.distanceM) {
        best = _Nearest(closest, distance);
      }
    }
    return best;
  }
}

/// A local equirectangular metre frame, accurate well under a metre over the
/// park-sized distances this screen reports.
class _LocalFrame {
  _LocalFrame(GeoPoint origin)
    : _origin = origin,
      _metresPerDegreeLon =
          _metresPerDegreeLat * math.cos(origin.lat * math.pi / 180);

  static const _metresPerDegreeLat = math.pi * 6371008.8 / 180;

  final GeoPoint _origin;
  final double _metresPerDegreeLon;

  _Vec toLocal(GeoPoint point) => _Vec(
    (point.lon - _origin.lon) * _metresPerDegreeLon,
    (point.lat - _origin.lat) * _metresPerDegreeLat,
  );
}
