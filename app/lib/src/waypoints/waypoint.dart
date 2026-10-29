import 'package:flutter/foundation.dart';

import '../content/models.dart';

/// A pin the walker saved themselves.
///
/// Waypoints belong to the device, not to the content bundle: they are never
/// uploaded, never checked against the park data, and they survive a bundle
/// update.
@immutable
class Waypoint {
  const Waypoint({
    required this.id,
    required this.name,
    required this.location,
    required this.createdAt,
  });

  factory Waypoint.fromJson(Map<String, Object?> json) => Waypoint(
    id: json['id']! as String,
    name: json['name']! as String,
    location: GeoPoint.fromJson(json['location']! as Map<String, Object?>),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['created_at']! as num).toInt(),
      isUtc: true,
    ).toLocal(),
  );

  final String id;
  final String name;
  final GeoPoint location;
  final DateTime createdAt;

  Waypoint renamed(String name) =>
      Waypoint(id: id, name: name, location: location, createdAt: createdAt);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'location': {'lat': location.lat, 'lon': location.lon},
    'created_at': createdAt.toUtc().millisecondsSinceEpoch,
  };
}

/// MapLibre-ready GeoJSON for the walker's pins.
Map<String, Object?> waypointsFeatureCollection(List<Waypoint> waypoints) => {
  'type': 'FeatureCollection',
  'features': [
    for (final waypoint in waypoints)
      {
        'type': 'Feature',
        'id': waypoint.id,
        'properties': {'id': waypoint.id, 'name': waypoint.name},
        'geometry': {
          'type': 'Point',
          'coordinates': [waypoint.location.lon, waypoint.location.lat],
        },
      },
  ],
};
