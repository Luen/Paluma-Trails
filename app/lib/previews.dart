import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'src/brand/theme.dart';
import 'src/content/models.dart';
import 'src/content/bundle_repository.dart';
import 'src/trip_planning_screen.dart';
import 'src/map/poi_photo_card.dart';
import 'src/map/source_link.dart';
import 'src/location/trail_locator.dart';
import 'src/location/walk_simulation.dart';
import 'src/map/walk_preview.dart';

Widget _tripPreview(
  Brightness brightness, {
  bool sunlight = false,
  double scale = 1,
}) => MaterialApp(
  theme: buildPalumaTheme(brightness, sunlight: sunlight),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: FutureBuilder<LoadedBundle>(
    future: BundleRepository().load(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text('Preview unavailable: ${snapshot.error}');
      }
      final bundle = snapshot.data;
      return bundle == null
          ? const Center(child: CircularProgressIndicator())
          : TripPlanningScreen(bundle: bundle);
    },
  ),
);

@Preview(name: 'Trip planning — light', size: Size(360, 800))
Widget tripLightPreview() => _tripPreview(Brightness.light);

@Preview(name: 'Trip planning — dark', size: Size(360, 800))
Widget tripDarkPreview() => _tripPreview(Brightness.dark);

@Preview(name: 'Trip planning — sunlight', size: Size(360, 800))
Widget tripSunlightPreview() => _tripPreview(Brightness.light, sunlight: true);

@Preview(name: 'Trip planning — large text', size: Size(360, 800))
Widget tripLargePreview() => _tripPreview(Brightness.light, scale: 2);

const _photo = PoiPhoto(
  file: 'johnstones-hut-1911.jpg',
  caption: 'Jack Johnstone’s maple-slab hut at Mt Spec, 1911.',
  credit:
      'Hinchinbrook Shire, Hinchinbrook Collection. '
      'Paluma: The First Eighty Years 1870s–1950s; Linda Venn; '
      'Thuringowa City Council, February 2002, p. 15.',
  licence:
      'Used with permission given to Luen Warneke of Wanderstories. '
      'Copyright retained; no onward licence granted.',
);

Widget _preview(
  Brightness brightness, {
  bool sunlight = false,
  double scale = 1,
}) => MaterialApp(
  theme: buildPalumaTheme(brightness, sunlight: sunlight),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: const Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: PoiPhotoCard(photo: _photo),
          ),
        ),
      ),
    ),
  ),
);

@Preview(name: 'Historic photo — light', size: Size(360, 800))
Widget poiPhotoLightPreview() => _preview(Brightness.light);

@Preview(name: 'Historic photo — dark', size: Size(360, 800))
Widget poiPhotoDarkPreview() => _preview(Brightness.dark);

@Preview(name: 'Historic photo — sunlight', size: Size(360, 800))
Widget poiPhotoSunlightPreview() => _preview(Brightness.light, sunlight: true);

@Preview(name: 'Historic photo — large text', size: Size(360, 800))
Widget poiPhotoLargeTextPreview() => _preview(Brightness.light, scale: 2);

Widget _sourcePreview(
  Brightness brightness, {
  bool sunlight = false,
  double scale = 1,
}) => MaterialApp(
  theme: buildPalumaTheme(brightness, sunlight: sunlight),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: const Scaffold(
        body: SingleChildScrollView(
          child: SourceLink(
            label: 'Luen Warneke and Wilfred Karnoll, Paluma walking guides — Wanderstories',
            url: 'https://wanderstories.space/hiking-at-paluma-range-national-park/',
          ),
        ),
      ),
    ),
  ),
);

@Preview(name: 'Source link — light', size: Size(360, 500))
Widget sourceLinkPreview() => _sourcePreview(Brightness.light);

@Preview(name: 'Source link — dark', size: Size(360, 500))
Widget sourceLinkDarkPreview() => _sourcePreview(Brightness.dark);

@Preview(name: 'Source link — sunlight', size: Size(360, 500))
Widget sourceLinkSunlightPreview() =>
    _sourcePreview(Brightness.light, sunlight: true);

@Preview(name: 'Source link — large text', size: Size(360, 500))
Widget sourceLinkLargePreview() => _sourcePreview(Brightness.light, scale: 2);

class _WalkControlsPreview extends StatefulWidget {
  const _WalkControlsPreview({
    required this.brightness,
    this.sunlight = false,
    this.scale = 1,
  });
  final Brightness brightness;
  final bool sunlight;
  final double scale;

  @override
  State<_WalkControlsPreview> createState() => _WalkControlsPreviewState();
}

class _WalkControlsPreviewState extends State<_WalkControlsPreview> {
  final simulation = WalkSimulation(
    const TrackPolyline(
      id: 'preview-example',
      name: 'Simulated preview example',
      points: [GeoPoint(-19, 146), GeoPoint(-18.99, 146.01)],
    ),
  );

  @override
  void dispose() {
    simulation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildPalumaTheme(widget.brightness, sunlight: widget.sunlight),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(widget.scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: WalkPreviewControls(
              simulation: simulation,
              onRestart: simulation.restart,
            ),
          ),
        ),
      ),
    ),
  );
}

@Preview(name: 'Walk preview — light', size: Size(360, 500))
Widget walkControlsLight() =>
    const _WalkControlsPreview(brightness: Brightness.light);
@Preview(name: 'Walk preview — dark', size: Size(360, 500))
Widget walkControlsDark() =>
    const _WalkControlsPreview(brightness: Brightness.dark);
@Preview(name: 'Walk preview — sunlight', size: Size(360, 500))
Widget walkControlsSunlight() =>
    const _WalkControlsPreview(brightness: Brightness.light, sunlight: true);
@Preview(name: 'Walk preview — large text', size: Size(320, 700))
Widget walkControlsLarge() =>
    const _WalkControlsPreview(brightness: Brightness.light, scale: 2);
