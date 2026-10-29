import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/content/bundle_repository.dart';
import 'package:paluma_trails/src/content/models.dart';
import 'package:paluma_trails/src/planning/trail_route.dart';

import 'support/bundle_fixture.dart';

/// A triangle (j1 - j2 - j3 - j1), a spur to j4, and j5 off the network.
///
/// j1 -> j3 is 700 m direct, and 1500 m the long way round, so the shortest
/// path is unambiguous. The full loop is 1000 + 500 + 700 = 2200 m.
LoadedBundle _network() => testBundle(
  junctions: const {
    'j1': Junction(id: 'j1', number: 1, location: GeoPoint(-18.94, 146.18)),
    'j2': Junction(
      id: 'j2',
      number: 2,
      name: 'Creek Junction',
      location: GeoPoint(-18.945, 146.19),
    ),
    'j3': Junction(id: 'j3', number: 3, location: GeoPoint(-18.95, 146.2)),
    'j4': Junction(
      id: 'j4',
      number: 4,
      name: 'Lookout',
      location: GeoPoint(-18.955, 146.21),
    ),
    'j5': Junction(id: 'j5', number: 5, location: GeoPoint(-18.96, 146.22)),
  },
  segments: const [
    Segment(
      from: 'j1',
      to: 'j2',
      trackId: 'ridge',
      trackName: 'Ridge Track',
      distanceM: 1000,
      walkMinutes: 20,
      bearingDeg: 90,
    ),
    Segment(
      from: 'j2',
      to: 'j3',
      trackId: 'creek',
      trackName: 'Creek Track',
      distanceM: 500,
      walkMinutes: 10,
      bearingDeg: 120,
    ),
    Segment(
      from: 'j3',
      to: 'j1',
      trackId: 'gully',
      trackName: 'Gully Track',
      distanceM: 700,
      walkMinutes: 14,
      bearingDeg: 240,
    ),
    Segment(
      from: 'j3',
      to: 'j4',
      trackId: 'spur',
      trackName: 'Spur Track',
      distanceM: 300,
      walkMinutes: 6,
      bearingDeg: 300,
    ),
  ],
);

void main() {
  group('planWalk', () {
    test('takes the shortest path between two junctions', () {
      final route = planWalk(_network(), fromId: 'j1', toId: 'j3');

      expect(route, isNotNull);
      expect(route!.distanceM, 700);
      expect(route.walkMinutes, 14);
      expect(route.shape, WalkShape.oneWay);
      expect(route.junctionIds, ['j1', 'j3']);
      expect(route.legs.single.trackName, 'Gully Track');
    });

    test('walks through a junction rather than inventing a shortcut', () {
      final route = planWalk(_network(), fromId: 'j1', toId: 'j4');

      expect(route!.distanceM, 1000);
      expect(route.walkMinutes, 20);
      expect(route.junctionIds, ['j1', 'j3', 'j4']);
      expect(route.legs.map((leg) => leg.trackName), [
        'Gully Track',
        'Spur Track',
      ]);
    });

    test('an out and back doubles the distance and the time', () {
      final route = planWalk(
        _network(),
        fromId: 'j1',
        toId: 'j3',
        shape: WalkShape.outAndBack,
      );

      expect(route!.returnsSameWay, isTrue);
      expect(route.distanceM, 1400);
      expect(route.walkMinutes, 28);
      expect(route.oneWayDistanceM, 700);
      expect(route.oneWayWalkMinutes, 14);
      expect(route.junctionIds, ['j1', 'j3']);
    });

    test('a loop comes back to its start by a different way', () {
      final route = planWalk(
        _network(),
        fromId: 'j1',
        toId: 'j1',
        shape: WalkShape.loop,
      );

      expect(route, isNotNull);
      expect(route!.isLoop, isTrue);
      expect(route.distanceM, 2200);
      expect(route.walkMinutes, 44);
      expect(route.junctionIds, ['j1', 'j2', 'j3', 'j1']);
      expect(route.legs.map((leg) => leg.from), ['j1', 'j2', 'j3']);
      expect(route.legs.map((leg) => leg.to), ['j2', 'j3', 'j1']);
    });

    test('a spur cannot loop back to itself', () {
      expect(
        planWalk(_network(), fromId: 'j4', toId: 'j4', shape: WalkShape.loop),
        isNull,
      );
      expect(
        planWalk(_network(), fromId: 'j5', toId: 'j5', shape: WalkShape.loop),
        isNull,
      );
    });

    test('returns null when the junctions are not connected', () {
      expect(planWalk(_network(), fromId: 'j1', toId: 'j5'), isNull);
    });

    test('returns null for a junction that is not in the bundle', () {
      expect(planWalk(_network(), fromId: 'nope', toId: 'j1'), isNull);
      expect(planWalk(_network(), fromId: 'j1', toId: 'nope'), isNull);
    });

    test('returns null for a walk that starts and ends at the same place', () {
      expect(planWalk(_network(), fromId: 'j1', toId: 'j1'), isNull);
    });

    test('returns null when the bundle has no segments', () {
      final bundle = testBundle(withSegment: false);

      expect(planWalk(bundle, fromId: 'j1', toId: 'j2'), isNull);
      expect(
        planWalk(bundle, fromId: 'j1', toId: 'j1', shape: WalkShape.loop),
        isNull,
      );
    });

    test('ignores a segment whose junction is missing from the content', () {
      final bundle = testBundle(
        junctions: const {
          'j1': Junction(
            id: 'j1',
            number: 1,
            location: GeoPoint(-18.94, 146.18),
          ),
        },
        segments: const [
          Segment(
            from: 'j1',
            to: 'ghost',
            trackId: 'mixup',
            trackName: 'Mixup Track',
            distanceM: 400,
            walkMinutes: 8,
            bearingDeg: 0,
          ),
        ],
      );

      expect(planWalk(bundle, fromId: 'j1', toId: 'j1'), isNull);
      expect(
        planWalk(bundle, fromId: 'j1', toId: 'j1', shape: WalkShape.loop),
        isNull,
      );
    });

    test('names an unnamed segment Connector', () {
      final bundle = testBundle(
        junctions: const {
          'j1': Junction(
            id: 'j1',
            number: 1,
            location: GeoPoint(-18.94, 146.18),
          ),
          'j2': Junction(
            id: 'j2',
            number: 2,
            location: GeoPoint(-18.95, 146.19),
          ),
        },
        segments: const [
          Segment(
            from: 'j1',
            to: 'j2',
            trackId: 'link',
            trackName: '',
            distanceM: 120,
            walkMinutes: 2,
            bearingDeg: 45,
          ),
        ],
      );

      final route = planWalk(bundle, fromId: 'j1', toId: 'j2');

      expect(route!.legs.single.trackName, 'Connector');
    });
  });
}
