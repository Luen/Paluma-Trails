import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/brand/theme.dart';
import 'package:paluma_trails/src/content/models.dart';
import 'package:paluma_trails/src/map/poi_photo_card.dart';
import 'package:paluma_trails/src/map/sheets.dart';

void main() {
  final data = jsonDecode(
    File('assets/bundle/content/pois.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final poi = Poi.fromJson(
    (data['pois'] as List).cast<Map<String, Object?>>().firstWhere(
      (p) => p['id'] == 'johnstones-hut',
    ),
  );

  test('packaged POI preserves photo attribution and offline source', () {
    expect(poi.photos.single.file, 'johnstones-hut-1911.jpg');
    expect(poi.photos.single.credit, contains('Hinchinbrook Collection'));
    expect(poi.photos.single.licence, contains('Luen Warneke'));
    expect(poi.sources.single.label, contains('Linda Venn'));
    expect(poi.unverified, isTrue);
  });

  for (final mode in ['light', 'dark', 'sunlight', 'large-text']) {
    testWidgets('offline photo and credits fit $mode at narrow width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPalumaTheme(
            mode == 'dark' ? Brightness.dark : Brightness.light,
            sunlight: mode == 'sunlight',
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(mode == 'large-text' ? 2 : 1),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PoiPhotoCard(photo: poi.photos.single),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        'assets/bundle/photos/johnstones-hut-1911.jpg',
      );
      expect(image.semanticLabel, poi.photos.single.caption);
      expect(find.text(poi.photos.single.caption), findsOneWidget);
      expect(find.text(poi.photos.single.credit), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(poi.photos.single.licence),
        200,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing image keeps caption and attribution readable', (
    tester,
  ) async {
    const photo = PoiPhoto(
      file: 'missing.jpg',
      caption: 'Historic hut',
      credit: 'Collection credit',
      licence: 'Used with permission',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PoiPhotoCard(photo: photo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Photograph unavailable.'), findsOneWidget);
    expect(find.text(photo.caption), findsOneWidget);
    expect(find.text(photo.credit), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('POI sheet includes the historical photograph', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PoiSheet(poi: poi)),
      ),
    );
    await tester.scrollUntilVisible(find.byType(PoiPhotoCard), 300);
    await tester.pumpAndSettle();
    expect(find.byType(PoiPhotoCard), findsOneWidget);
    expect(find.text(poi.photos.single.caption), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
