import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/deep_links.dart';

void main() {
  group('parseDeepLink', () {
    test('reads a POI from the usual path', () {
      final link = parseDeepLink(
        Uri.parse('https://paluma.example/poi/gold-creek-falls'),
      );

      expect(link?.poiId, 'gold-creek-falls');
    });

    test('ignores the host, so moving the site keeps old codes working', () {
      final link = parseDeepLink(
        Uri.parse('https://some-other-host.example/poi/gold-creek-falls'),
      );

      expect(link?.poiId, 'gold-creek-falls');
    });

    test('accepts the query form for hosts without a rewrite rule', () {
      final link = parseDeepLink(
        Uri.parse('https://paluma.example/?poi=gold-creek-falls'),
      );

      expect(link?.poiId, 'gold-creek-falls');
    });

    test('accepts a trailing slash and campaign parameters', () {
      expect(
        parseDeepLink(Uri.parse('https://paluma.example/poi/gold-creek-falls/'))
            ?.poiId,
        'gold-creek-falls',
      );
      expect(
        parseDeepLink(
          Uri.parse(
            'https://paluma.example/poi/gold-creek-falls?utm_source=sign',
          ),
        )?.poiId,
        'gold-creek-falls',
      );
    });

    test('accepts the app scheme so native links need no new codes', () {
      expect(
        parseDeepLink(Uri.parse('paluma://poi/gold-creek-falls'))?.poiId,
        'gold-creek-falls',
      );
    });

    test('normalises case', () {
      expect(
        parseDeepLink(Uri.parse('https://paluma.example/poi/Gold-Creek-Falls'))
            ?.poiId,
        'gold-creek-falls',
      );
    });

    test('ignores paths and schemes that are not POI links', () {
      for (final uri in [
        'https://paluma.example/',
        'https://paluma.example/about',
        'https://paluma.example/other?poi=gold-creek-falls',
        'https://paluma.example/poi/',
        'https://paluma.example/poi',
        'https://paluma.example/poi/a/b',
        'paluma://junction/7',
        'file:///C:/notes.txt',
        'mailto:someone@example.com',
      ]) {
        expect(parseDeepLink(Uri.parse(uri)), isNull, reason: uri);
      }
    });

    test('rejects ids that could escape a path or a lookup', () {
      for (final id in [
        '..',
        '%2E%2E',
        'gold%2Fcreek',
        'gold creek',
        'gold_creek',
        '-gold',
        'gold-',
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
