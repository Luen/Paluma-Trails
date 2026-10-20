import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../about_screen.dart';
import '../content/bundle_repository.dart';
import '../content/models.dart';
import '../location/location_service.dart';
import '../location/trail_locator.dart';
import 'location_overlay.dart';
import 'sheets.dart';

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

  static const _tracksCasingLayer = 'paluma-tracks-casing';
  static const _tracksLayer = 'paluma-tracks';
  static const _junctionsLayer = 'paluma-junctions';
  static const _junctionsLabelLayer = 'paluma-junctions-label';
  static const _poisLayer = 'paluma-pois';
  static const _poisLabelLayer = 'paluma-pois-label';

  static const _lineWidth = [
    'interpolate',
    ['linear'],
    ['zoom'],
    8,
    2.0,
    12,
    3.5,
    16,
    6.0,
  ];

  MapLibreMapController? _controller;
  var _layersAdded = false;

  late final LocationService _location;
  late final TrailLocator _trailLocator;
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
    _trailLocator = TrailLocator.fromGeoJson(
      tracksGeoJson: widget.bundle.tracksGeoJson,
      origin: widget.bundle.park.center,
      junctions: widget.bundle.junctions,
      paceKmh: widget.bundle.estimate.paceKmh,
    );
    _location.fix.addListener(_onFix);
    _location.status.addListener(_onLocationStatusChanged);
  }

  @override
  void dispose() {
    _location.fix.removeListener(_onFix);
    _location.status.removeListener(_onLocationStatusChanged);
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = widget.bundle;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(bundle.park.name),
        actions: [
          IconButton(
            tooltip: 'Show the whole park',
            onPressed: _layersAdded ? _fitPark : null,
            icon: const Icon(Icons.fit_screen_outlined),
          ),
          IconButton(
            tooltip: 'About this app',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AboutScreen(bundle: bundle),
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
            // it is only requested once tracking starts.
            myLocationRenderMode: _locationEnabled
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
                    onJunctionTap: _openJunction,
                  ),
                  const SizedBox(height: 6),
                ],
                _BundleChip(version: bundle.manifest.bundleVersion),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 64,
            child: LocateButton(
              status: _location.status.value,
              following: _following,
              onPressed: _onLocatePressed,
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
        const LineLayerProperties(
          lineColor: '#0B3D2E',
          lineOpacity: 0.35,
          lineWidth: [
            'interpolate',
            ['linear'],
            ['zoom'],
            8,
            4.5,
            12,
            6.5,
            16,
            10.0,
          ],
        ),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        _tracksSource,
        _tracksLayer,
        const LineLayerProperties(
          lineColor: [
            'match',
            ['get', 'class'],
            'walk',
            '#2E7D32',
            'track',
            '#2E7D32',
            'mtb',
            '#6A1B9A',
            'road',
            '#607D8B',
            'connector',
            '#8D6E63',
            '#455A64',
          ],
          lineWidth: _lineWidth,
        ),
      );
      await controller.addCircleLayer(
        _junctionsSource,
        _junctionsLayer,
        const CircleLayerProperties(
          circleRadius: [
            'interpolate',
            ['linear'],
            ['zoom'],
            8,
            4.0,
            14,
            7.0,
          ],
          circleColor: '#FFF8E1',
          circleStrokeColor: '#BF360C',
          circleStrokeWidth: 2.0,
        ),
      );
      await controller.addSymbolLayer(
        _junctionsSource,
        _junctionsLabelLayer,
        const SymbolLayerProperties(
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
            9.0,
            14,
            12.0,
          ],
          textColor: '#3E2723',
          textAllowOverlap: false,
        ),
        minzoom: 9.5,
      );
      await controller.addCircleLayer(
        _poisSource,
        _poisLayer,
        const CircleLayerProperties(
          circleRadius: [
            'interpolate',
            ['linear'],
            ['zoom'],
            8,
            3.0,
            14,
            6.5,
          ],
          circleColor: '#0277BD',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 1.5,
        ),
      );
      await controller.addSymbolLayer(
        _poisSource,
        _poisLabelLayer,
        const SymbolLayerProperties(
          textField: ['get', 'name'],
          textFont: ['Noto-Sans-Regular'],
          textSize: 10.5,
          textColor: '#0D47A1',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.5,
          textAnchor: 'top',
          textOffset: [0, 0.6],
        ),
        minzoom: 13.5,
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
        final track = widget.bundle.tracksById[featureId];
        if (track != null) {
          showTrackSheet(context, bundle: widget.bundle, track: track);
        }
    }
  }

  void _onLocationStatusChanged() {
    if (!mounted) return;
    setState(() {
      // A stopped stream must not leave a stale junction on the card.
      if (!_location.isTracking) _trailFix = null;
    });
  }

  Future<void> _onFix() async {
    final fix = _location.fix.value;
    if (fix == null) return;

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

    final status = await _location.start();
    if (!mounted) return;

    if (status == LocationStatus.servicesDisabled) {
      _notify(
        'Location services are off — turn them on to see your position.',
        actionLabel: 'Settings',
        onAction: _location.openLocationSettings,
      );
      return;
    }
    if (status == LocationStatus.permissionDenied) {
      _notify(
        'Location permission is needed to show where you are.',
        actionLabel: 'Ask again',
        onAction: _onLocatePressed,
      );
      return;
    }
    if (status == LocationStatus.permissionDeniedForever) {
      if (kIsWeb) {
        _notify(
          'Location permission was denied — allow it in the browser site '
          'settings.',
        );
      } else {
        _notify(
          'Location permission was denied — grant it in the app settings.',
          actionLabel: 'Settings',
          onAction: _location.openAppSettings,
        );
      }
      return;
    }
    if (status == LocationStatus.failed) {
      _notify('The device did not report a position — tap again to retry.');
      return;
    }

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

  void _notify(String message, {String? actionLabel, VoidCallback? onAction}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
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

class _BundleChip extends StatelessWidget {
  const _BundleChip({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'Offline bundle $version',
          style: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}
