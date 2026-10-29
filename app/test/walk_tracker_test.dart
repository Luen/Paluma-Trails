import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/content/models.dart';
import 'package:paluma_trails/src/location/walk_tracker.dart';

/// A point [metres] north of the origin, good enough at this scale.
GeoPoint _northOf(double metres) => GeoPoint(metres / 111194.9, 0);

void main() {
  test('counts the distance between fixes, not the first fix itself', () {
    final tracker = WalkTracker();

    tracker.add(_northOf(0));
    expect(tracker.metres, 0);

    tracker.add(_northOf(10));
    expect(tracker.metres, closeTo(10, 0.1));

    tracker.add(_northOf(25));
    expect(tracker.metres, closeTo(25, 0.1));
  });

  test('ignores jitter while standing still', () {
    final tracker = WalkTracker();

    tracker.add(_northOf(0));
    for (var i = 0; i < 20; i++) {
      tracker.add(_northOf(i.isEven ? 1.5 : 0));
    }

    expect(tracker.metres, 0);
  });

  test('counts a real step after a run of jitter', () {
    final tracker = WalkTracker();

    tracker.add(_northOf(0));
    tracker.add(_northOf(2));
    tracker.add(_northOf(20));

    expect(tracker.metres, closeTo(18, 0.1));
  });

  test('reset starts a new walk', () {
    final tracker = WalkTracker();

    tracker.add(_northOf(0));
    tracker.add(_northOf(100));
    expect(tracker.metres, greaterThan(0));

    tracker.reset();
    expect(tracker.metres, 0);

    // The first fix after a reset is a new starting point, not a hop from the
    // old one.
    tracker.add(_northOf(5000));
    expect(tracker.metres, 0);
  });
}
