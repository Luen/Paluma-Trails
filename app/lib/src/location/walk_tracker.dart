import 'dart:math' as math;

import '../content/models.dart';

/// Accumulates how far the walker has moved since tracking started.
///
/// This is distance travelled, not along-track distance: it keeps counting
/// across track switches and when the walker steps off the mapped network, and
/// it never goes down. Hops shorter than [minMovementM] are treated as GPS
/// jitter while standing still, so the total does not creep upwards at a
/// lunch stop.
///
/// Kept free of Flutter and plugins so it can be unit-tested directly.
class WalkTracker {
  WalkTracker({this.minMovementM = 4});

  /// Hops below this many metres are ignored as jitter.
  final double minMovementM;

  GeoPoint? _last;
  double _metres = 0;

  /// Metres walked since the last [reset].
  double get metres => _metres;

  /// Keeps the total but starts a new span after an explicit tracking pause.
  void pause() => _last = null;

  /// Forgets the walk: used when tracking stops, so the next walk starts at
  /// zero rather than adding a bus trip to yesterday's walk.
  void reset() {
    _last = null;
    _metres = 0;
  }

  /// Adds one fix. The first fix only sets the starting point.
  void add(GeoPoint position) {
    final last = _last;
    _last = position;
    if (last == null) return;

    final metres = _metresBetween(last, position);
    if (metres < minMovementM) return;
    _metres += metres;
  }
}

/// A local equirectangular distance: accurate to well under a metre over the
/// few hundred metres a walker covers between fixes.
double _metresBetween(GeoPoint a, GeoPoint b) {
  const metresPerDegree = 111194.9;
  final midLat = (a.lat + b.lat) * math.pi / 360;
  final dLat = (b.lat - a.lat) * metresPerDegree;
  final dLon = (b.lon - a.lon) * metresPerDegree * math.cos(midLat);
  return math.sqrt(dLat * dLat + dLon * dLon);
}
