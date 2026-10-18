import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/map/format.dart';

void main() {
  group('formatDistance', () {
    test('uses metres under a kilometre', () {
      expect(formatDistance(15), '15 m');
      expect(formatDistance(999), '999 m');
    });

    test('uses one decimal up to 10 km', () {
      expect(formatDistance(1000), '1.0 km');
      expect(formatDistance(1234), '1.2 km');
      expect(formatDistance(9300), '9.3 km');
    });

    test('rounds whole kilometres above 10 km', () {
      expect(formatDistance(12340), '12 km');
      expect(formatDistance(19999), '20 km');
    });
  });

  group('formatDuration', () {
    test('uses minutes under an hour', () {
      expect(formatDuration(45), '45 min');
      expect(formatDuration(59), '59 min');
    });

    test('uses hours and minutes', () {
      expect(formatDuration(60), '1 h');
      expect(formatDuration(125), '2 h 5 min');
      expect(formatDuration(600), '10 h');
    });
  });

  group('formatBearing', () {
    test('maps the cardinals', () {
      expect(formatBearing(0), 'N');
      expect(formatBearing(90), 'E');
      expect(formatBearing(180), 'S');
      expect(formatBearing(270), 'W');
    });

    test('maps the intercardinals', () {
      expect(formatBearing(45), 'NE');
      expect(formatBearing(135), 'SE');
      expect(formatBearing(225), 'SW');
      expect(formatBearing(315), 'NW');
    });

    test('wraps around north', () {
      expect(formatBearing(350), 'N');
      expect(formatBearing(360), 'N');
      expect(formatBearing(-10), 'N');
    });
  });

  group('labels', () {
    test('formatTrackClass', () {
      expect(formatTrackClass('track'), 'Walking track');
      expect(formatTrackClass('connector'), 'Connector');
      expect(formatTrackClass('something-else'), 'Other');
    });

    test('formatPoiCategory', () {
      expect(formatPoiCategory('waterfall'), 'Waterfall');
      expect(formatPoiCategory('lookout'), 'Lookout');
      expect(formatPoiCategory('something-else'), 'Point of interest');
    });

    test('formatAscent hides missing or non-positive values', () {
      expect(formatAscent(null), isNull);
      expect(formatAscent(0), isNull);
      expect(formatAscent(120.4), '↑ 120 m');
    });
  });
}
