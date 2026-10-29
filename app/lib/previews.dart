import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'src/brand/theme.dart';
import 'src/content/models.dart';
import 'src/map/poi_photo_card.dart';
import 'src/map/source_link.dart';

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
