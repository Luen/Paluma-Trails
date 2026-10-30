import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/web_resources.dart';

void main() {
  test('POI launches keep basemap resources and the printable map at root', () {
    const resources = [
      'assets/assets/bundle/basemap/paluma.pmtiles',
      'assets/assets/bundle/basemap/fonts/Noto-Sans-Regular/0-255.pbf',
      'assets/assets/bundle/basemap/sprites/light.png',
      'printable-map.html',
    ];
    for (final launch in [
      'https://paluma.example/',
      'https://paluma.example/poi/gardes-lookout',
      'https://paluma.example/poi/gardes-lookout/',
      'https://paluma.example/poi/unknown?utm_source=sign#details',
      'http://localhost:8098/poi/shays-clearing',
    ]) {
      final uri = Uri.parse(launch);
      for (final resource in resources) {
        expect(
          siteResourceUri(resource, launchUri: uri).toString(),
          '${uri.origin}/$resource',
          reason: '$launch → $resource',
        );
      }
    }
  });
}
