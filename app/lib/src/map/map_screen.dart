import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../about_screen.dart';
import '../content/bundle_repository.dart';
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
            bottom: 12,
            child: _BundleChip(version: bundle.manifest.bundleVersion),
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
