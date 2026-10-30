import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/deep_links.dart';

void main() {
  group('parseDeepLink', () {
    test('reads a POI from the printed form', () {
      final link = parseDeepLink(
        Uri.parse('https://paluma.example/poi/buttercup-lookout'),
      );

      expect(link?.poiId, 'buttercup-lookout');
    });

    test('ignores the origin, so moving the site keeps old codes working', () {
      for (final origin in [
        'https://paluma.example',
        'https://some-other-host.example',
        'http://localhost:8080',
      ]) {
        final link = parseDeepLink(Uri.parse('$origin/poi/buttercup-lookout'));
        expect(link?.poiId, 'buttercup-lookout', reason: origin);
      }
    });

    test('accepts path capitals and a trailing slash', () {
      expect(
        parseDeepLink(
          Uri.parse('https://paluma.example/poi/Buttercup-Lookout/'),
        )?.poiId,
        'buttercup-lookout',
      );
    });

    test('ignores campaign parameters', () {
      expect(
        parseDeepLink(
          Uri.parse(
            'https://paluma.example/poi/buttercup-lookout?utm_source=sign',
          ),
        )?.poiId,
        'buttercup-lookout',
      );
    });

    test('rejects the query form: the printed path must be served', () {
      expect(
        parseDeepLink(
          Uri.parse('https://paluma.example/?poi=buttercup-lookout'),
        ),
        isNull,
      );
      expect(
        parseDeepLink(
          Uri.parse('https://paluma.example/other?poi=buttercup-lookout'),
        ),
        isNull,
      );
    });

    test('rejects app-only schemes and non-web schemes', () {
      for (final uri in [
        'paluma://poi/buttercup-lookout',
        'file:///C:/notes.txt',
        'mailto:someone@example.com',
        'https://paluma.example/about',
        'https://paluma.example/poi/',
        'https://paluma.example/poi',
        'https://paluma.example/poi/a/b',
      ]) {
        expect(parseDeepLink(Uri.parse(uri)), isNull, reason: uri);
      }
    });

    test('rejects ids that could escape a path or a lookup', () {
      for (final id in [
        '..',
        '%2E%2E',
        '%252E%252E',
        'gold%2Fcreek',
        'gold creek',
        'gold_creek',
        '-gold',
        'gold-',
        'gold--creek',
      ]) {
        expect(
          parseDeepLink(Uri.parse('https://paluma.example/poi/$id')),
          isNull,
          reason: id,
        );
      }
    });
  });
}
