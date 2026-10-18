import 'dart:math' as math;

import 'geo.dart';

/// Builds the junction-to-junction graph from tracks and junctions.
///
/// A segment is the stretch of a single track between two junctions that lie on
/// it. Junctions are snapped to a track when they are within [snapToleranceM] of
/// the polyline; in practice the numbered markers sit on the track.
///
/// Output shape matches `content/schema/segments.schema.json`.
Map<String, Object?> buildSegments({
  required Map<String, Object?> tracks,
  required Map<String, Object?> junctions,
  double snapToleranceM = 40,
  double paceKmh = 4.0,
  String estimateLabel = 'Estimate — flat-terrain pace, elevation not included',
}) {
  final junctionPoints = <String, LatLon>{};
  for (final j
      in (junctions['junctions'] as List).cast<Map<String, Object?>>()) {
    final loc = j['location'] as Map<String, Object?>;
    junctionPoints[j['id'] as String] =
        LatLon((loc['lat'] as num).toDouble(), (loc['lon'] as num).toDouble());
  }

  final segments = <_Segment>[];
  final seen = <String>{};

  for (final feature
      in (tracks['features'] as List).cast<Map<String, Object?>>()) {
    final props = feature['properties'] as Map<String, Object?>;
    final trackId = props['id'] as String;
    final trackName = props['name'] as String? ?? trackId;
    final geometry = feature['geometry'] as Map<String, Object?>;
    final rawCoordinates =
        (geometry['coordinates'] as List).cast<List<Object?>>();
    final line = <LatLon>[];
    final elevations = <double?>[];
    for (final coordinate in rawCoordinates) {
      line.add(LatLon(
        (coordinate[1]! as num).toDouble(),
        (coordinate[0]! as num).toDouble(),
      ));
      // Some exports carry a placeholder 0 for missing elevation; the park sits
      // between roughly 400 m and 1200 m, so treat non-positive as unknown.
      final elevation = coordinate.length > 2 && coordinate[2] is num
          ? (coordinate[2]! as num).toDouble()
          : null;
      elevations.add(elevation != null && elevation > 0 ? elevation : null);
    }
    final cumulative = cumulativeDistances(line);

    final onLine = <_Snapped>[];
    for (final entry in junctionPoints.entries) {
      final projection = projectOntoPolyline(line, entry.value);
      if (projection == null) continue;
      if (projection.distanceFromM > snapToleranceM) continue;
      onLine.add(_Snapped(entry.key, projection.distanceAlongM));
    }
    onLine.sort((a, b) => a.alongM.compareTo(b.alongM));

    for (var i = 1; i < onLine.length; i++) {
      final from = onLine[i - 1];
      final to = onLine[i];
      final distance = to.alongM - from.alongM;
      if (distance < 25) continue; // noise: two markers essentially together
      final key = '${from.junctionId}|${to.junctionId}|$trackId';
      if (!seen.add(key)) continue;

      // Bearing along the segment, measured across its middle half so a
      // single wiggly vertex does not define the direction.
      final bearingFrom = interpolate(line, from.alongM + distance * 0.25);
      final bearingTo = interpolate(line, from.alongM + distance * 0.75);
      final climb = _climbBetween(
        cumulative,
        elevations,
        from.alongM,
        to.alongM,
      );
      segments.add(
        _Segment(
          from: from.junctionId,
          to: to.junctionId,
          trackId: trackId,
          trackName: trackName,
          distanceM: distance,
          bearing: initialBearingDegrees(bearingFrom, bearingTo),
          ascentM: climb?.ascentM,
          descentM: climb?.descentM,
        ),
      );
    }
  }

  segments.sort((a, b) {
    final byFrom = a.from.compareTo(b.from);
    if (byFrom != 0) return byFrom;
    final byTo = a.to.compareTo(b.to);
    if (byTo != 0) return byTo;
    return a.trackId.compareTo(b.trackId);
  });

  final trackIds = (tracks['features'] as List)
      .cast<Map<String, Object?>>()
      .map((f) => (f['properties'] as Map)['id'] as String)
      .toList()
    ..sort();

  return {
    'generator': {
      'tool': 'paluma_cli',
      'schema_version': 1,
      'generated_from': [
        'tracks.geojson',
        'junctions.json',
      ],
    },
    'estimate': {
      'method': 'naismith-flat',
      'pace_kmh': paceKmh,
      'includes_elevation': false,
      'label': estimateLabel,
    },
    'segments': [
      for (final s in segments)
        {
          'from': s.from,
          'to': s.to,
          'track_id': s.trackId,
          'track_name': s.trackName,
          'distance_m': s.distanceM.round(),
          'walk_minutes': walkMinutes(s.distanceM, paceKmh),
          if (s.ascentM != null) 'ascent_m': s.ascentM!.round(),
          if (s.descentM != null) 'descent_m': s.descentM!.round(),
          'bearing_deg': double.parse(s.bearing.toStringAsFixed(1)),
        },
    ],
    'tracks_considered': trackIds.length,
  };
}

/// Sums of the rises and drops between two positions along a track, walking
/// from [fromM] towards [toM]. Walking the other way swaps the two.
///
/// Returns null when the track has no usable elevation data for that stretch.
({double ascentM, double descentM})? _climbBetween(
  List<double> cumulative,
  List<double?> elevations,
  double fromM,
  double toM,
) {
  var ascent = 0.0;
  var descent = 0.0;
  var samples = 0;
  for (var i = 1; i < elevations.length; i++) {
    if (cumulative[i] < fromM || cumulative[i - 1] > toM) continue;
    final before = elevations[i - 1];
    final after = elevations[i];
    if (before == null || after == null) continue;
    samples++;
    final delta = after - before;
    if (delta > 0) {
      ascent += delta;
    } else {
      descent -= delta;
    }
  }
  return samples >= 2 ? (ascentM: ascent, descentM: descent) : null;
}

/// Naismith on the flat, rounded up to the next five minutes.
int walkMinutes(double distanceM, double paceKmh) {
  final rawMinutes = distanceM / 1000.0 / paceKmh * 60.0;
  final rounded = (rawMinutes / 5).ceil() * 5;
  return math.max(5, rounded);
}

class _Snapped {
  _Snapped(this.junctionId, this.alongM);

  final String junctionId;
  final double alongM;
}

class _Segment {
  _Segment({
    required this.from,
    required this.to,
    required this.trackId,
    required this.trackName,
    required this.distanceM,
    required this.bearing,
    this.ascentM,
    this.descentM,
  });

  final String from;
  final String to;
  final String trackId;
  final String trackName;
  final double distanceM;
  final double bearing;
  final double? ascentM;
  final double? descentM;
}
