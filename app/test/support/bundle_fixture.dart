import 'package:paluma_trails/src/content/bundle_repository.dart';
import 'package:paluma_trails/src/content/models.dart';

/// A small hand-built bundle for widget tests: two junctions, one segment,
/// one track and one POI.
LoadedBundle testBundle({
  bool withSegment = true,
  String tracksGeoJson = '{"type":"FeatureCollection","features":[]}',
}) => LoadedBundle(
  manifest: const BundleManifest(
    schemaVersion: 1,
    bundleVersion: 'test-0000',
    generator: 'test',
    park: 'paluma',
    files: [],
    totalBytes: 3171942,
  ),
  park: const Park(
    id: 'paluma',
    name: 'Paluma Range National Park',
    region: 'Townsville, Queensland',
    center: GeoPoint(-18.95, 146.15),
    bounds: ParkBounds(north: -18.8, south: -19.1, east: 146.3, west: 146.05),
    defaultZoom: 12,
    updated: '2026-10-16',
    disclaimer: 'Test disclaimer.',
    emergencyPhone: '000',
    emergencyAlternativePhone: '112',
    emergencyNotes: 'Ask for Queensland Ambulance Service.',
    attributions: [Attribution(label: 'OpenStreetMap', licence: 'ODbL')],
  ),
  safety: const SafetyContent(
    updated: '2026-10-26',
    intro: 'Test safety intro.',
    emergencyHeadline:
        'In an emergency, call 000. If the call does not connect, try 112.',
    emergencySteps: ['Give your coordinates.', 'Stay where you are.'],
    sections: [
      SafetySection(
        title: 'Before you set out',
        items: ['Tell someone where you are going.'],
      ),
    ],
  ),
  tracks: const [
    TrackSummary(
      id: 'tāngaroa-walking-track',
      name: 'Tāngaroa Walking Track',
      trackClass: 'track',
      lengthM: 5400,
    ),
  ],
  tracksById: const {
    'tāngaroa-walking-track': TrackSummary(
      id: 'tāngaroa-walking-track',
      name: 'Tāngaroa Walking Track',
      trackClass: 'track',
      lengthM: 5400,
    ),
  },
  junctions: const {
    'j1': Junction(
      id: 'j1',
      number: 1,
      location: GeoPoint(-18.941853, 146.188682),
    ),
    'j2': Junction(
      id: 'j2',
      number: 2,
      name: 'Big Crystal Creek junction',
      location: GeoPoint(-18.945, 146.19),
    ),
  },
  pois: const {
    'little-crystal-creek-falls': Poi(
      id: 'little-crystal-creek-falls',
      name: 'Little Crystal Creek Falls',
      category: 'waterfall',
      location: GeoPoint(-18.99, 146.24),
      description: 'A short steep walk to the falls.',
      unverified: true,
    ),
  },
  segments: withSegment
      ? const [
          Segment(
            from: 'j1',
            to: 'j2',
            trackId: 'tāngaroa-walking-track',
            trackName: 'Tāngaroa Walking Track',
            distanceM: 1200,
            walkMinutes: 20,
            bearingDeg: 90,
            ascentM: 80,
            descentM: 30,
          ),
        ]
      : const [],
  estimate: const EstimateInfo(
    method: 'naismith-flat',
    paceKmh: 4,
    includesElevation: false,
    label: 'Estimate — flat-terrain pace, elevation not included',
  ),
  tracksGeoJson: tracksGeoJson,
  styleTemplate: '{}',
  pmtilesUri: 'file:///tmp/paluma.pmtiles',
  assetsBaseUri: 'file:///tmp',
  storageDirectory: '/tmp',
);
