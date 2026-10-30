import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../web_resources.dart';
import 'bundle_storage.dart';
import 'models.dart';
import 'trip_planning.dart';

/// Everything the app needs from the offline bundle, resolved for this device.
class LoadedBundle {
  const LoadedBundle({
    required this.manifest,
    required this.park,
    required this.safety,
    required this.tracks,
    required this.tracksById,
    required this.junctions,
    required this.pois,
    required this.segments,
    required this.estimate,
    required this.tracksGeoJson,
    required this.styleTemplate,
    required this.pmtilesUri,
    required this.assetsBaseUri,
    required this.storageDirectory,
    this.tripPlanning,
  });

  final BundleManifest manifest;
  final Park park;
  final SafetyContent safety;
  final TripPlanningContent? tripPlanning;
  final List<TrackSummary> tracks;
  final Map<String, TrackSummary> tracksById;
  final Map<String, Junction> junctions;
  final Map<String, Poi> pois;
  final List<Segment> segments;
  final EstimateInfo estimate;

  /// Raw track GeoJSON; see [mapGeoJson] for the map-ready version.
  final String tracksGeoJson;

  /// MapLibre style with the `PALUMA_PMTILES` / `PALUMA_ASSETS` placeholders
  /// still in place; [resolveStyle] substitutes device-specific URLs.
  final String styleTemplate;
  final String pmtilesUri;
  final String assetsBaseUri;

  /// Where the bundle lives on this device, or null on web (the browser serves
  /// the assets directly).
  final String? storageDirectory;

  /// Segments that touch [junctionId], with the other end resolved.
  List<Segment> segmentsAt(String junctionId) => segments
      .where((s) => s.otherEnd(junctionId) != null)
      .toList(growable: false);

  /// MapLibre-ready GeoJSON for the numbered junctions.
  ///
  /// Junctions and POIs live in the content model as typed JSON, so their
  /// features are built here rather than parsed from a FeatureCollection.
  Map<String, dynamic> junctionsFeatureCollection() => {
    'type': 'FeatureCollection',
    'features': [
      for (final junction in junctions.values)
        {
          'type': 'Feature',
          'id': junction.id,
          'properties': {
            'id': junction.id,
            'number': junction.number,
            if (junction.name != null) 'name': junction.name,
            if (junction.water != null) 'water': junction.water,
            if (junction.reception != null) 'reception': junction.reception,
            if (junction.unverified) 'unverified': true,
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [junction.location.lon, junction.location.lat],
          },
        },
    ],
  };

  /// MapLibre-ready GeoJSON for the points of interest.
  ///
  /// [hiddenCategories] leaves out markers the walker has hidden with the map's
  /// display options; the content itself is unchanged.
  Map<String, dynamic> poisFeatureCollection({
    Set<String> hiddenCategories = const {},
  }) => {
    'type': 'FeatureCollection',
    'features': [
      for (final poi in pois.values)
        if (!hiddenCategories.contains(poi.category))
          {
            'type': 'Feature',
            'id': poi.id,
            'properties': {
              'id': poi.id,
              'name': poi.name,
              'category': poi.category,
              if (poi.unverified) 'unverified': true,
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [poi.location.lon, poi.location.lat],
            },
          },
    ],
  };

  String resolveStyle() => styleTemplate
      .replaceAll('PALUMA_PMTILES', pmtilesUri)
      .replaceAll('PALUMA_ASSETS', assetsBaseUri);

  /// Rebuilds a GeoJSON FeatureCollection with a top-level `id` on each
  /// feature, keeping only [properties].
  ///
  /// MapLibre Native requires the top-level id to report tap events; the
  /// content keeps the id in `properties` because that is friendlier to edit.
  static Map<String, dynamic> mapGeoJson(
    String source,
    List<String> properties,
  ) {
    final decoded = jsonDecode(source) as Map<String, Object?>;
    final features = (decoded['features'] as List).cast<Map<String, Object?>>();
    final out = <Map<String, Object?>>[];
    for (final feature in features) {
      final props = feature['properties'] as Map<String, Object?>? ?? const {};
      final id = props['id'];
      if (id is! String) continue;
      final kept = <String, Object?>{'id': id};
      for (final key in properties) {
        if (props.containsKey(key)) kept[key] = props[key];
      }
      out.add({
        'type': 'Feature',
        'id': id,
        'properties': kept,
        'geometry': feature['geometry'],
      });
    }
    return {'type': 'FeatureCollection', 'features': out};
  }
}

/// Loads the bundle packaged with the app and materialises it on disk where the
/// platform needs that (see [materialiseBundle]). On Android and iOS a failure
/// to materialise is an error: MapLibre Native can only read the basemap from
/// disk, so there is no working asset fallback.
class BundleRepository {
  static const _assetRoot = 'assets/bundle';

  LoadedBundle? _cached;

  Future<LoadedBundle> load() async {
    final existing = _cached;
    if (existing != null) return existing;

    final manifest = BundleManifest.fromJson(
      decodeJsonObject(
        await rootBundle.loadString('$_assetRoot/manifest.json'),
      ),
    );
    final storageDirectory = await materialiseBundle(manifest);

    Future<String> read(String relative) async {
      final directory = storageDirectory;
      if (directory != null) {
        final file = File(p.joinAll([directory, ...p.posix.split(relative)]));
        return file.readAsString();
      }
      return rootBundle.loadString('$_assetRoot/$relative');
    }

    final park = Park.fromJson(
      decodeJsonObject(await read('content/park.json')),
    );
    final safety = SafetyContent.fromJson(
      decodeJsonObject(await read('content/safety.json')),
    );
    // Older packaged bundles predate the hub. A declared but unreadable file
    // remains a bundle error rather than silently hiding damaged content.
    final tripPlanning =
        manifest.files.any((file) => file.path == 'content/trip-planning.json')
        ? TripPlanningContent.fromJson(
            decodeJsonObject(await read('content/trip-planning.json')),
          )
        : null;
    final junctionsJson = decodeJsonObject(
      await read('content/junctions.json'),
    );
    final poisJson = decodeJsonObject(await read('content/pois.json'));
    final segmentsJson = decodeJsonObject(await read('content/segments.json'));
    final tracksGeoJson = await read('content/tracks.geojson');
    final styleTemplate = await read('basemap/style.json');

    final trackFeatures = (decodeJsonObject(tracksGeoJson)['features'] as List)
        .cast<Map<String, Object?>>();
    final tracks = trackFeatures
        .map(
          (f) =>
              TrackSummary.fromJson(f['properties']! as Map<String, Object?>),
        )
        .toList(growable: false);

    final bundle = LoadedBundle(
      manifest: manifest,
      park: park,
      safety: safety,
      tripPlanning: tripPlanning,
      tracks: tracks,
      tracksById: {for (final track in tracks) track.id: track},
      junctions: {
        for (final junction
            in (junctionsJson['junctions'] as List)
                .cast<Map<String, Object?>>())
          (junction['id']! as String): Junction.fromJson(junction),
      },
      pois: {
        for (final poi
            in (poisJson['pois'] as List).cast<Map<String, Object?>>())
          (poi['id']! as String): Poi.fromJson(poi),
      },
      segments: (segmentsJson['segments'] as List)
          .cast<Map<String, Object?>>()
          .map(Segment.fromJson)
          .toList(growable: false),
      estimate: EstimateInfo.fromJson(
        segmentsJson['estimate']! as Map<String, Object?>,
      ),
      tracksGeoJson: tracksGeoJson,
      styleTemplate: styleTemplate,
      pmtilesUri: _assetUris(storageDirectory).pmtilesUri,
      assetsBaseUri: _assetUris(storageDirectory).assetsBaseUri,
      storageDirectory: storageDirectory,
    );
    _cached = bundle;
    return bundle;
  }

  /// Where MapLibre should read the basemap from on this platform.
  ({String pmtilesUri, String assetsBaseUri}) _assetUris(
    String? storageDirectory,
  ) {
    if (storageDirectory != null) {
      final basemap = Uri.directory(p.join(storageDirectory, 'basemap'));
      return (
        pmtilesUri: basemap.resolve('paluma.pmtiles').toString(),
        // The style appends `/fonts/...` and `/sprites/...` itself.
        assetsBaseUri: basemap.toString().replaceFirst(RegExp(r'/$'), ''),
      );
    }
    final base = siteResourceUri('assets/$_assetRoot/basemap').toString();
    return (pmtilesUri: '$base/paluma.pmtiles', assetsBaseUri: base);
  }
}
