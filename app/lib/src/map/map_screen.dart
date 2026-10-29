import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../about_screen.dart';
import '../brand/brand.dart';
import '../content/bundle_repository.dart';
import '../content/models.dart';
import '../location/location_prompts.dart';
import '../location/location_service.dart';
import '../location/trail_locator.dart';
import '../location/walk_tracker.dart';
import '../safety_screen.dart';
import '../waypoints/waypoint.dart';
import '../waypoints/waypoint_store.dart';
import 'location_overlay.dart';
import 'map_options.dart';
import 'map_palette.dart';
import 'poi_groups.dart';
import 'sheets.dart';
import 'waypoint_sheets.dart';

/// The offline map: basemap from the bundled PMTiles archive, trail content
/// from the bundled GeoJSON, and tap-to-inspect sheets on top.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.bundle});

  final LoadedBundle bundle;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _tracksSource = 'paluma-tracks-source';
  static const _junctionsSource = 'paluma-junctions-source';
  static const _poisSource = 'paluma-pois-source';
  static const _waypointsSource = 'paluma-waypoints-source';

  static const _tracksCasingLayer = 'paluma-tracks-casing';
  static const _tracksLayer = 'paluma-tracks';
  static const _informalTracksLayer = 'paluma-tracks-informal';
  static const _junctionsLayer = 'paluma-junctions';
  static const _junctionsLabelLayer = 'paluma-junctions-label';
  static const _poisLayer = 'paluma-pois';
  static const _poisLabelLayer = 'paluma-pois-label';
  static const _waypointsLayer = 'paluma-waypoints';
  static const _waypointsLabelLayer = 'paluma-waypoints-label';

  MapLibreMapController? _controller;
  var _layersAdded = false;

  MapOptions? _options;
  var _sunlight = false;

  /// The POI categories hidden by the current display options, so the map
  /// filter is only rebuilt when the choice actually changes.
  Set<String> _hiddenPoiCategories = const {};

  late final LocationService _location;
  late final TrailLocator _trailLocator;
  late final WaypointStore _waypoints;
  late final WalkTracker _walk;
  TrailFix? _trailFix;

  /// Whether the camera should follow the walker's fixes.
  var _following = false;

  /// Set when the camera should jump to the next fix (after starting location
  /// or tapping "follow me" again).
  var _needsCentre = false;

  bool get _locationEnabled => _location.isTracking;

  @override
  void initState() {
    super.initState();
    _location = LocationService();
    _walk = WalkTracker();
    _trailLocator = TrailLocator.fromGeoJson(
      tracksGeoJson: widget.bundle.tracksGeoJson,
      origin: widget.bundle.park.center,
      junctions: widget.bundle.junctions,
      pois: widget.bundle.pois,
      waterCategories: PoiGroup.water.categories.toSet(),
      paceKmh: widget.bundle.estimate.paceKmh,
    );
    _location.fix.addListener(_onFix);
    _location.status.addListener(_onLocationStatusChanged);
    _waypoints = WaypointStore()..addListener(_onWaypointsChanged);
    unawaited(_waypoints.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final options = MapOptionsScope.of(context);
    _options = options;
    _location.batterySaver = options.batterySaver;
    if (_sunlight != options.sunlight) {
      _sunlight = options.sunlight;
      if (_layersAdded) unawaited(_applyLayerStyle());
    }
    if (!setEquals(_hiddenPoiCategories, options.hiddenPoiCategories)) {
      _hiddenPoiCategories = options.hiddenPoiCategories;
      if (_layersAdded) unawaited(_applyPoiVisibility());
    }
  }

  @override
  void dispose() {
    _location.fix.removeListener(_onFix);
    _location.status.removeListener(_onLocationStatusChanged);
    _location.dispose();
    _waypoints.removeListener(_onWaypointsChanged);
    _waypoints.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = widget.bundle;
    final theme = Theme.of(context);
    final options = MapOptionsScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const TrailPinMark(
              height: 30,
              accentColor: BrandColors.sand,
              semanticLabel: BrandText.name,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(bundle.park.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Safety and emergency information',
            onPressed: _openSafety,
            icon: const Icon(Icons.health_and_safety_outlined),
          ),
          IconButton(
            tooltip: 'About this app',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AboutScreen(bundle: bundle, location: _location),
              ),
            ),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: bundle.resolveStyle(),
            initialCameraPosition: CameraPosition(
              target: LatLng(bundle.park.center.lat, bundle.park.center.lon),
              zoom: bundle.park.defaultZoom,
            ),
            onMapCreated: (controller) {
              _controller = controller;
              controller.onFeatureTapped.add(_onFeatureTapped);
            },
            onStyleLoadedCallback: _onStyleLoaded,
            compassEnabled: true,
            attributionButtonPosition: AttributionButtonPosition.bottomRight,
            logoEnabled: true,
            // The app feeds the puck from its own fixes, so the same path
            // works on Android, iOS and the web; see LocationService.
            locationSource: const ManualLocationSource(),
            myLocationEnabled: _locationEnabled,
            myLocationTrackingMode: _following
                ? MyLocationTrackingMode.tracking
                : MyLocationTrackingMode.none,
            // A compass puck requires the location component to be enabled, so
            // it is only requested once tracking starts; battery saver skips
            // it too, since the magnetometer is a constant drain.
            myLocationRenderMode: _locationEnabled && !options.batterySaver
                ? MyLocationRenderMode.compass
                : MyLocationRenderMode.normal,
            onCameraIdle: _onCameraIdle,
            onCameraTrackingDismissed: _onCameraTrackingDismissed,
          ),
          if (!_layersAdded)
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.85),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          Positioned(
            left: 12,
            right: 64,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_location.status.value != LocationStatus.off) ...[
                  LocationCard(
                    status: _location.status.value,
                    fix: _location.fix.value,
                    trail: _trailFix,
                    walkedM: _walk.metres,
                    onJunctionTap: _openJunction,
                  ),
                  const SizedBox(height: 6),
                ],
                _OfflineChip(version: bundle.manifest.bundleVersion),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MapControlButton(
                  icon: Icons.fit_screen_outlined,
                  tooltip: 'Show the whole park',
                  onPressed: _layersAdded ? _fitPark : null,
                ),
                const SizedBox(height: 10),
                MapControlButton(
                  icon: Icons.tune,
                  tooltip: 'Map key and display options',
                  highlighted:
                      options.sunlight ||
                      options.batterySaver ||
                      !options.allPoiGroupsVisible,
                  onPressed: _openDisplaySettings,
                ),
                const SizedBox(height: 10),
                MapControlButton(
                  icon: Icons.push_pin_outlined,
                  tooltip: 'Your waypoints',
                  onPressed: _layersAdded ? _openWaypoints : null,
                ),
                const SizedBox(height: 10),
                LocateButton(
                  status: _location.status.value,
                  following: _following,
                  onPressed: _onLocatePressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Adds the trail sources and layers once MapLibre reports the style ready.
  Future<void> _onStyleLoaded() async {
    if (_layersAdded) return;
    final controller = _controller;
    if (controller == null) return;
    final bundle = widget.bundle;

    try {
      await controller.addGeoJsonSource(
        _tracksSource,
        LoadedBundle.mapGeoJson(bundle.tracksGeoJson, const [
          'id',
          'name',
          'class',
          'length_m',
          'unverified',
        ]),
        promoteId: 'id',
      );
      await controller.addGeoJsonSource(
        _junctionsSource,
        bundle.junctionsFeatureCollection(),
        promoteId: 'id',
      );
      await controller.addGeoJsonSource(
        _poisSource,
        bundle.poisFeatureCollection(),
        promoteId: 'id',
      );

      await controller.addLineLayer(
        _tracksSource,
        _tracksCasingLayer,
        _tracksCasingProperties(_sunlight),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        _tracksSource,
        _tracksLayer,
        _tracksProperties(_sunlight),
        filter: _solidTracksFilter,
      );
      await controller.addLineLayer(
        _tracksSource,
        _informalTracksLayer,
        _informalTracksProperties(_sunlight),
        filter: _informalTracksFilter,
      );
      await controller.addCircleLayer(
        _junctionsSource,
        _junctionsLayer,
        _junctionProperties(_sunlight),
      );
      await controller.addSymbolLayer(
        _junctionsSource,
        _junctionsLabelLayer,
        _junctionLabelProperties(_sunlight),
        minzoom: 9.5,
      );
      await controller.addCircleLayer(
        _poisSource,
        _poisLayer,
        _poiProperties(_sunlight),
      );
      await controller.addSymbolLayer(
        _poisSource,
        _poisLabelLayer,
        _poiLabelProperties(_sunlight),
        minzoom: 13.5,
      );
      await controller.addGeoJsonSource(
        _waypointsSource,
        waypointsFeatureCollection(_waypoints.waypoints),
        promoteId: 'id',
      );
      await controller.addCircleLayer(
        _waypointsSource,
        _waypointsLayer,
        _waypointProperties(_sunlight),
      );
      await controller.addSymbolLayer(
        _waypointsSource,
        _waypointsLabelLayer,
        _waypointLabelProperties(_sunlight),
        minzoom: 14,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not draw the trail overlay: $error')),
        );
      }
    }
    if (mounted) setState(() => _layersAdded = true);
  }

  /// Re-paints the overlay with the current display options once the layers
  /// exist; a style reload goes through [_onStyleLoaded] instead.
  Future<void> _applyLayerStyle() async {
    final controller = _controller;
    if (controller == null || !_layersAdded) return;
    try {
      await controller.setLayerProperties(
        _tracksCasingLayer,
        _tracksCasingProperties(_sunlight),
      );
      await controller.setLayerProperties(
        _tracksLayer,
        _tracksProperties(_sunlight),
      );
      await controller.setLayerProperties(
        _informalTracksLayer,
        _informalTracksProperties(_sunlight),
      );
      await controller.setLayerProperties(
        _junctionsLayer,
        _junctionProperties(_sunlight),
      );
      await controller.setLayerProperties(
        _junctionsLabelLayer,
        _junctionLabelProperties(_sunlight),
      );
      await controller.setLayerProperties(
        _poisLayer,
        _poiProperties(_sunlight),
      );
      await controller.setLayerProperties(
        _poisLabelLayer,
        _poiLabelProperties(_sunlight),
      );
      await controller.setLayerProperties(
        _waypointsLayer,
        _waypointProperties(_sunlight),
      );
      await controller.setLayerProperties(
        _waypointsLabelLayer,
        _waypointLabelProperties(_sunlight),
      );
    } catch (_) {
      // The map may already be gone; the next style load adds the layers
      // again with the current colours.
    }
  }

  /// Rebuilds the POI source after a display option changed.
  ///
  /// Layers keep their style and interaction; only the features handed to
  /// MapLibre change. A layer filter would be cheaper, but the web plugin does
  /// not convert a Dart filter list for `setFilter`, and this works the same on
  /// every platform.
  Future<void> _applyPoiVisibility() async {
    final controller = _controller;
    if (controller == null || !_layersAdded) return;
    try {
      await controller.setGeoJsonSource(
        _poisSource,
        widget.bundle.poisFeatureCollection(
          hiddenCategories: _hiddenPoiCategories,
        ),
      );
    } catch (_) {
      // The map may already be gone; the next style load builds the source
      // with the current choice.
    }
  }

  /// Rebuilds the waypoint source after a pin is added, renamed or deleted.
  Future<void> _applyWaypoints() async {
    final controller = _controller;
    if (controller == null || !_layersAdded) return;
    try {
      await controller.setGeoJsonSource(
        _waypointsSource,
        waypointsFeatureCollection(_waypoints.waypoints),
      );
    } catch (_) {
      // The map may already be gone; the next style load builds the source
      // with the saved pins.
    }
  }

  void _onWaypointsChanged() => unawaited(_applyWaypoints());

  static List<Object> _casingWidth(bool sunlight) => [
    'interpolate',
    ['linear'],
    ['zoom'],
    8,
    sunlight ? 6.5 : 4.5,
    12,
    sunlight ? 9.0 : 6.5,
    16,
    sunlight ? 13.0 : 10.0,
  ];

  static List<Object> _trackWidth(bool sunlight) => [
    'interpolate',
    ['linear'],
    ['zoom'],
    8,
    sunlight ? 3.5 : 2.0,
    12,
    sunlight ? 5.5 : 3.5,
    16,
    sunlight ? 9.0 : 6.0,
  ];

  static LineLayerProperties _tracksCasingProperties(bool sunlight) =>
      LineLayerProperties(
        lineColor: MapPalette.casing,
        lineOpacity: sunlight ? 0.6 : 0.35,
        lineWidth: _casingWidth(sunlight),
      );

  /// Solid classes on one layer, informal tracks dashed on another: a filter
  /// split rather than a data-driven dash array, which not every MapLibre
  /// platform supports.
  static const List<Object> _solidTracksFilter = [
    'match',
    ['get', 'class'],
    MapPalette.solidClasses,
    true,
    false,
  ];

  static const List<Object> _informalTracksFilter = [
    'match',
    ['get', 'class'],
    MapPalette.solidClasses,
    false,
    true,
  ];

  static LineLayerProperties _tracksProperties(bool sunlight) =>
      LineLayerProperties(
        lineColor: [
          'match',
          ['get', 'class'],
          'mtb',
          MapPalette.mtbTrack,
          'road',
          MapPalette.road,
          'connector',
          MapPalette.connector,
          MapPalette.walkingTrack,
        ],
        lineWidth: _trackWidth(sunlight),
      );

  static LineLayerProperties _informalTracksProperties(bool sunlight) =>
      LineLayerProperties(
        lineColor: MapPalette.walkingTrack,
        lineWidth: _trackWidth(sunlight),
        lineDasharray: MapPalette.informalDash,
      );

  static CircleLayerProperties _junctionProperties(bool sunlight) =>
      CircleLayerProperties(
        circleRadius: [
          'interpolate',
          ['linear'],
          ['zoom'],
          8,
          sunlight ? 6.0 : 4.0,
          14,
          sunlight ? 10.0 : 7.0,
        ],
        circleColor: sunlight
            ? MapPalette.sunlightJunctionFill
            : MapPalette.junctionFill,
        circleStrokeColor: sunlight
            ? MapPalette.sunlightJunctionStroke
            : MapPalette.junctionStroke,
        circleStrokeWidth: sunlight ? 3.0 : 2.0,
      );

  static SymbolLayerProperties _junctionLabelProperties(bool sunlight) =>
      SymbolLayerProperties(
        textField: [
          'to-string',
          ['get', 'number'],
        ],
        textFont: ['Noto-Sans-Medium'],
        textSize: [
          'interpolate',
          ['linear'],
          ['zoom'],
          8,
          sunlight ? 12.0 : 9.0,
          14,
          sunlight ? 16.0 : 12.0,
        ],
        textColor: sunlight
            ? MapPalette.sunlightLabel
            : MapPalette.junctionLabel,
        textHaloColor: MapPalette.labelHalo,
        textHaloWidth: sunlight ? 2.0 : 0.0,
        textAllowOverlap: false,
      );

  static CircleLayerProperties _poiProperties(bool sunlight) =>
      CircleLayerProperties(
        circleRadius: [
          'interpolate',
          ['linear'],
          ['zoom'],
          8,
          sunlight ? 5.0 : 3.0,
          14,
          sunlight ? 9.0 : 6.5,
        ],
        circleColor: sunlight ? MapPalette.sunlightPoi : MapPalette.poi,
        circleStrokeColor: MapPalette.poiStroke,
        circleStrokeWidth: sunlight ? 2.5 : 1.5,
      );

  static SymbolLayerProperties _poiLabelProperties(bool sunlight) =>
      SymbolLayerProperties(
        textField: ['get', 'name'],
        textFont: ['Noto-Sans-Regular'],
        textSize: sunlight ? 13.5 : 10.5,
        textColor: sunlight ? MapPalette.sunlightLabel : MapPalette.poiLabel,
        textHaloColor: MapPalette.labelHalo,
        textHaloWidth: 2.0,
        textAnchor: 'top',
        textOffset: const [0, 0.6],
      );

  /// The walker's pins are drawn a size larger than content POIs and named at a
  /// lower zoom, so "mine" never has to be guessed from the colour alone.
  static CircleLayerProperties _waypointProperties(bool sunlight) =>
      CircleLayerProperties(
        circleRadius: [
          'interpolate',
          ['linear'],
          ['zoom'],
          8,
          sunlight ? 6.5 : 4.5,
          14,
          sunlight ? 11.0 : 8.0,
        ],
        circleColor: sunlight
            ? MapPalette.sunlightWaypoint
            : MapPalette.waypoint,
        circleStrokeColor: MapPalette.poiStroke,
        circleStrokeWidth: sunlight ? 3.0 : 2.5,
      );

  static SymbolLayerProperties _waypointLabelProperties(bool sunlight) =>
      SymbolLayerProperties(
        textField: ['get', 'name'],
        textFont: ['Noto-Sans-Medium'],
        textSize: sunlight ? 14.0 : 11.0,
        textColor: sunlight
            ? MapPalette.sunlightLabel
            : MapPalette.waypointLabel,
        textHaloColor: MapPalette.labelHalo,
        textHaloWidth: 2.0,
        textAnchor: 'top',
        textOffset: const [0, 0.6],
      );

  void _openDisplaySettings() {
    final options = _options;
    if (options != null) showDisplaySettingsSheet(context, options: options);
  }

  void _onFeatureTapped(
    math.Point<double> point,
    LatLng latLng,
    dynamic id,
    String layerId,
    Annotation? annotation,
  ) {
    final featureId = '$id';
    switch (layerId) {
      case _junctionsLayer:
      case _junctionsLabelLayer:
        final junction = widget.bundle.junctions[featureId];
        if (junction != null) {
          showJunctionSheet(context, bundle: widget.bundle, junction: junction);
        }
      case _poisLayer:
      case _poisLabelLayer:
        final poi = widget.bundle.pois[featureId];
        if (poi != null) {
          showPoiSheet(context, bundle: widget.bundle, poi: poi);
        }
      case _tracksLayer:
      case _informalTracksLayer:
        final track = widget.bundle.tracksById[featureId];
        if (track != null) {
          showTrackSheet(context, bundle: widget.bundle, track: track);
        }
      case _waypointsLayer:
      case _waypointsLabelLayer:
        final waypoint = _waypoints.byId(featureId);
        if (waypoint != null) {
          showWaypointSheet(
            context,
            store: _waypoints,
            waypoint: waypoint,
            onFocus: _focusOn,
          );
        }
    }
  }

  void _onLocationStatusChanged() {
    if (!mounted) return;
    setState(() {
      // A stopped stream must not leave a stale junction on the card.
      if (!_location.isTracking) {
        _trailFix = null;
        _walk.reset();
      }
    });
  }

  Future<void> _onFix() async {
    final fix = _location.fix.value;
    if (fix == null) return;

    _walk.add(fix.position);
    final trailFix = _trailLocator.locate(
      fix.position,
      bearingDeg: fix.bearingDeg,
      speedMps: fix.speedMps,
    );
    if (mounted) setState(() => _trailFix = trailFix);

    // Push first: on web the manual puck recentres on every fix and would
    // cancel a camera animation that started before it.
    await _pushFixToMap(fix);
    if (_needsCentre) {
      _needsCentre = false;
      await _centreOn(fix);
    }
  }

  /// Centres on the latest fix once a rebuild has applied the tracking mode.
  ///
  /// Enabling the tracking mode also recentres (the web manual puck does it on
  /// every fix), so centring in the same frame would be undone by it. Without
  /// a fix yet, the next one centres instead.
  void _centreAfterFollowingStarts() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_following) return;
      final fix = _location.fix.value;
      if (fix == null) {
        _needsCentre = true;
      } else {
        _centreOn(fix);
      }
    });
  }

  /// Drives the map's location puck from the fix.
  Future<void> _pushFixToMap(GpsFix fix) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.updateManualLocation(
        ManualLocationUpdate(
          target: LatLng(fix.position.lat, fix.position.lon),
          horizontalAccuracy: fix.accuracyM > 0 ? fix.accuracyM : null,
          bearing: fix.bearingDeg,
          speed: fix.speedMps,
          altitude: fix.altitudeM,
          timestamp: fix.timestamp,
        ),
      );
    } catch (_) {
      // The map may still be initialising or already gone; the next fix is
      // along in a few seconds.
    }
  }

  /// Jumps to the walker at a walking zoom.
  ///
  /// A jump rather than an animation on purpose: while the tracking mode is on,
  /// the web manual puck recentres on every fix and would cancel an animation
  /// that has not finished. A jump keeps its zoom when that happens.
  Future<void> _centreOn(GpsFix fix) =>
      _controller?.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(fix.position.lat, fix.position.lon),
          15,
        ),
      ) ??
      Future<void>.value();

  Future<void> _onLocatePressed() async {
    if (_location.isTracking) {
      setState(() => _following = !_following);
      if (_following) _centreAfterFollowingStarts();
      return;
    }

    final started = await startLocationWithPrompts(context, _location);
    if (!mounted || !started) return;

    setState(() => _following = true);
    _centreAfterFollowingStarts();
  }

  void _onCameraTrackingDismissed() {
    if (_following) setState(() => _following = false);
  }

  /// Stops following when the camera settles away from the walker.
  ///
  /// Android and iOS report a tracking dismissal for a pan; the web manual
  /// puck does not, so the same intent is inferred from where the camera
  /// ended up. Programmatic moves land on the fix and keep following.
  void _onCameraIdle() {
    if (!_following || _controller == null) return;
    final fix = _location.fix.value;
    final target = _controller!.cameraPosition?.target;
    if (fix == null || target == null) return;
    if (_metresBetween(fix.position, target) > 40) {
      setState(() => _following = false);
    }
  }

  /// A quick local equirectangular distance, accurate enough for a gesture
  /// threshold.
  static double _metresBetween(GeoPoint a, LatLng b) {
    const metresPerDegree = 111194.9;
    final midLat = (a.lat + b.latitude) * math.pi / 360;
    final dLat = (b.latitude - a.lat) * metresPerDegree;
    final dLon = (b.longitude - a.lon) * metresPerDegree * math.cos(midLat);
    return math.sqrt(dLat * dLat + dLon * dLon);
  }

  void _openJunction(Junction junction) {
    showJunctionSheet(context, bundle: widget.bundle, junction: junction);
  }

  /// Opens the walker's pins, saving new ones where the map is looking.
  void _openWaypoints() {
    final target = _controller?.cameraPosition?.target;
    final centre = target == null
        ? widget.bundle.park.center
        : GeoPoint(target.latitude, target.longitude);
    showWaypointsSheet(
      context,
      store: _waypoints,
      mapCentre: centre,
      onFocus: _focusOn,
    );
  }

  /// Jumps to a saved pin at a walking zoom, leaving follow mode so the camera
  /// does not spring back on the next fix.
  Future<void> _focusOn(Waypoint waypoint) async {
    if (_following) setState(() => _following = false);
    await _controller?.moveCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(waypoint.location.lat, waypoint.location.lon),
        15,
      ),
    );
  }

  void _openSafety() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SafetyScreen(bundle: widget.bundle, location: _location),
      ),
    );
  }

  Future<void> _fitPark() async {
    final bounds = widget.bundle.park.bounds;
    await _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(bounds.south, bounds.west),
          northeast: LatLng(bounds.north, bounds.east),
        ),
        left: 24,
        right: 24,
        top: 24,
        bottom: 24,
      ),
    );
  }
}

/// Says the map works without reception, and which bundle is on the device.
class _OfflineChip extends StatelessWidget {
  const _OfflineChip({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.offline_pin_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Offline map ready · bundle $version',
                style: theme.textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
