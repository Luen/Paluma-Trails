/// Display formatting for content values. Kept free of Flutter imports so it
/// can be unit-tested directly.
library;

/// Formats a distance in metres the way walkers write it: metres under a
/// kilometre, one decimal up to 10 km, whole kilometres above that.
String formatDistance(num meters) {
  final metres = meters.round();
  if (metres < 1000) return '$metres m';
  // Round to tenths first so 9.96 km reads `10 km`, not `10.0 km`.
  final tenths = (metres / 100).round();
  return tenths < 100
      ? '${(tenths / 10).toStringAsFixed(1)} km'
      : '${(metres / 1000).round()} km';
}

/// Formats minutes as walkers write them: `45 min`, `1 h`, `2 h 15 min`.
String formatDuration(num minutes) {
  final total = minutes.round();
  if (total < 60) return '$total min';
  final hours = total ~/ 60;
  final rest = total % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// Formats a bearing as a 16-point compass direction.
String formatBearing(double degrees) {
  const points = [
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW',
  ];
  final normalised = (degrees % 360 + 360) % 360;
  final index = (normalised + 11.25) % 360 ~/ 22.5;
  return points[index];
}

/// Human label for a track's `class`.
String formatTrackClass(String value) => switch (value) {
  'track' => 'Walking track',
  'walk' => 'Short walk',
  'road' => 'Road',
  'mtb' => 'Mountain bike',
  'connector' => 'Connector',
  _ => 'Other',
};

/// Human label for a POI's `category`.
String formatPoiCategory(String value) => switch (value) {
  'waterfall' => 'Waterfall',
  'lookout' => 'Lookout',
  'swimming' => 'Swimming',
  'water' => 'Water',
  'campsite' => 'Campsite',
  'hut' => 'Hut',
  'mine' => 'Mine',
  'history' => 'History',
  'art' => 'Rock art',
  'junction' => 'Junction',
  _ => 'Point of interest',
};

/// Formats an ascent, or null when the source has no elevation data.
String? formatAscent(double? ascentM) {
  if (ascentM == null || ascentM <= 0) return null;
  return '↑ ${ascentM.round()} m';
}
