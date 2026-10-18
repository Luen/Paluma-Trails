import 'dart:math' as math;

/// Geographic helpers. All coordinates are WGS84, `lat`/`lon` in degrees.
///
/// At the scale of a national park, an equirectangular projection is accurate
/// to well under a metre for the distances we care about, so we use it for
/// local maths and haversine where a spherical answer is good enough.
class LatLon {
  const LatLon(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  String toString() => '($lat, $lon)';
}

const double _earthRadiusM = 6371008.8;

/// Great-circle distance in metres.
double haversineMeters(LatLon a, LatLon b) {
  final lat1 = _rad(a.lat);
  final lat2 = _rad(b.lat);
  final dLat = lat2 - lat1;
  final dLon = _rad(b.lon - a.lon);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

/// Initial bearing from [a] to [b], degrees clockwise from north [0, 360).
double initialBearingDegrees(LatLon a, LatLon b) {
  final lat1 = _rad(a.lat);
  final lat2 = _rad(b.lat);
  final dLon = _rad(b.lon - a.lon);
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final deg = _deg(math.atan2(y, x));
  return (deg + 360) % 360;
}

/// Total length of a polyline in metres.
double polylineLength(List<LatLon> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += haversineMeters(points[i - 1], points[i]);
  }
  return total;
}

/// Cumulative distance along a polyline at each vertex; first entry is zero.
List<double> cumulativeDistances(List<LatLon> points) {
  final out = List<double>.filled(points.length, 0);
  for (var i = 1; i < points.length; i++) {
    out[i] = out[i - 1] + haversineMeters(points[i - 1], points[i]);
  }
  return out;
}

/// A point projected onto a polyline.
class Projection {
  const Projection(this.distanceAlongM, this.distanceFromM, this.point);

  /// Distance from the start of the polyline to the projected point.
  final double distanceAlongM;

  /// Distance from [point] to the polyline.
  final double distanceFromM;

  final LatLon point;
}

/// Projects [target] onto the polyline [line] and returns the closest position.
///
/// Uses a local equirectangular projection around [target]. Returns `null` for
/// polylines with fewer than two points.
Projection? projectOntoPolyline(List<LatLon> line, LatLon target) {
  if (line.length < 2) return null;

  final latScale = math.cos(_rad(target.lat)) * 111320.0;
  const lonToMeter = 111320.0; // metres per degree of latitude
  double x(LatLon p) => (p.lon - target.lon) * latScale;
  double y(LatLon p) => (p.lat - target.lat) * lonToMeter;

  final cum = cumulativeDistances(line);
  var best = Projection(double.infinity, double.infinity, target);

  for (var i = 1; i < line.length; i++) {
    final ax = x(line[i - 1]), ay = y(line[i - 1]);
    final bx = x(line[i]), by = y(line[i]);
    final dx = bx - ax, dy = by - ay;
    final segLengthSq = dx * dx + dy * dy;
    var t = 0.0;
    if (segLengthSq > 0) {
      t = ((-ax) * dx + (-ay) * dy) / segLengthSq;
      t = t.clamp(0.0, 1.0);
    }
    final px = ax + t * dx, py = ay + t * dy;
    final distanceFrom = math.sqrt(px * px + py * py);
    if (distanceFrom < best.distanceFromM) {
      final segLength = haversineMeters(line[i - 1], line[i]);
      best = Projection(
        cum[i - 1] + segLength * t,
        distanceFrom,
        LatLon(
          line[i - 1].lat + (line[i].lat - line[i - 1].lat) * t,
          line[i - 1].lon + (line[i].lon - line[i - 1].lon) * t,
        ),
      );
    }
  }
  return best;
}

/// Interpolates the point [distanceAlongM] metres along [line].
LatLon interpolate(List<LatLon> line, double distanceAlongM) {
  if (line.isEmpty) throw ArgumentError('empty line');
  if (distanceAlongM <= 0) return line.first;
  final cum = cumulativeDistances(line);
  if (distanceAlongM >= cum.last) return line.last;
  for (var i = 1; i < line.length; i++) {
    if (cum[i] >= distanceAlongM) {
      final segLength = cum[i] - cum[i - 1];
      final t =
          segLength == 0 ? 0.0 : (distanceAlongM - cum[i - 1]) / segLength;
      return LatLon(
        line[i - 1].lat + (line[i].lat - line[i - 1].lat) * t,
        line[i - 1].lon + (line[i].lon - line[i - 1].lon) * t,
      );
    }
  }
  return line.last;
}

double _rad(double degrees) => degrees * math.pi / 180.0;
double _deg(double radians) => radians * 180.0 / math.pi;
