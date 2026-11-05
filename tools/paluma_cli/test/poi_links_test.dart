import 'package:paluma_cli/src/poi_links.dart';
import 'package:paluma_cli/src/repo.dart';
import 'package:test/test.dart';

void main() {
  group('poiLinksInText', () {
    test('finds printed links with their 1-based line number', () {
      final links = poiLinksInText(
        'intro\n'
        'see `/poi/gardes-lookout` and\n'
        '/poi/Shays-Clearing.\n',
      );

      expect(
        links.map((link) => '${link.line}:${link.id}').toList(),
        ['2:gardes-lookout', '3:shays-clearing'],
      );
    });

    test('accepts a trailing slash and a query string', () {
      expect(
        poiLinksInText('/poi/buttercup-lookout/?utm_source=sign')
            .map((link) => link.id)
            .toList(),
        ['buttercup-lookout'],
      );
    });

    test('skips placeholders that describe the form', () {
      expect(poiLinksInText('https://<origin>/poi/<poi-id>'), isEmpty);
      expect(poiLinksInText('not redirect it to `/?poi=<id>`'), isEmpty);
      expect(poiLinksInText('the path is `/poi/<id>`'), isEmpty);
    });

    test('skips paths that are not the printed single-segment form', () {
      expect(poiLinksInText('the basemap below `/poi/assets/...`'), isEmpty);
      expect(poiLinksInText('/poi/a/b'), isEmpty);
      expect(poiLinksInText('/poi/'), isEmpty);
    });
  });

  test('a dead example is reported with its file and line', () {
    final problems = brokenPoiLinksIn(const [
      PoiLinkReference('docs/qr-codes.md', 2, 'ghost-lookout'),
      PoiLinkReference('docs/qr-codes.md', 9, 'gardes-lookout'),
    ], const {
      'gardes-lookout'
    });

    expect(problems, hasLength(1));
    expect(problems.single, startsWith('docs/qr-codes.md:2:'));
    expect(problems.single, contains('/poi/ghost-lookout'));
    expect(problems.single, contains('ADR 0009'));
  });

  test('every documented /poi/<id> exists in the content source', () {
    final repo = Repo.locate();
    final links = documentedPoiLinks(repo);

    // Guard against a silent no-op if the extractor stops finding examples.
    expect(links, isNotEmpty, reason: 'no documented POI links were found');

    final problems = brokenPoiLinks(repo);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
