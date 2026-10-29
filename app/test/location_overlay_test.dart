import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/content/models.dart';
import 'package:paluma_trails/src/location/location_service.dart';
import 'package:paluma_trails/src/location/trail_locator.dart';
import 'package:paluma_trails/src/map/location_overlay.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Junction _junction(int number, {String? name}) => Junction(
  id: 'j$number',
  number: number,
  name: name,
  location: const GeoPoint(-19, 146),
);

final _gpsFix = GpsFix(
  position: const GeoPoint(-19, 146),
  accuracyM: 8,
  timestamp: DateTime(2026, 10, 20),
);

TrailFix _trail(NextJunction? next, {NextPoi? water}) => TrailFix(
  track: const TrackPolyline(
    id: 'track',
    name: 'Paluma Track Circuit 5',
    points: [GeoPoint(-19, 146), GeoPoint(-19.01, 146.01)],
  ),
  snapped: const GeoPoint(-19, 146),
  offTrackM: 4,
  next: next,
  nextWater: water,
);

NextPoi _water({
  String name = 'Swimming hole',
  double distanceM = 240,
  int walkMinutes = 4,
  bool ahead = true,
  bool directionKnown = true,
  bool unverified = false,
}) => NextPoi(
  poi: Poi(
    id: 'swimming-hole',
    name: name,
    category: 'water',
    location: const GeoPoint(-19.005, 146.005),
    unverified: unverified,
  ),
  distanceM: distanceM,
  walkMinutes: walkMinutes,
  ahead: ahead,
  directionKnown: directionKnown,
);

NextJunction _next({
  int number = 12,
  String? name,
  double distanceM = 340,
  int walkMinutes = 5,
  bool ahead = true,
  bool directionKnown = true,
}) => NextJunction(
  junction: _junction(number, name: name),
  distanceM: distanceM,
  walkMinutes: walkMinutes,
  ahead: ahead,
  directionKnown: directionKnown,
);

void main() {
  group('LocationCard', () {
    testWidgets('shows the next junction, distance and walk time', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.tracking,
            fix: _gpsFix,
            trail: _trail(_next()),
          ),
        ),
      );

      expect(find.text('On Paluma Track Circuit 5'), findsOneWidget);
      expect(find.text('Next: Junction 12 · 340 m · ~5 min'), findsOneWidget);
      expect(find.text('±8 m'), findsOneWidget);
    });

    testWidgets('uses the junction name when it has one', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.tracking,
            fix: _gpsFix,
            trail: _trail(_next(name: 'Big Crystal Creek junction')),
          ),
        ),
      );

      expect(
        find.text('Next: Big Crystal Creek junction · 340 m · ~5 min'),
        findsOneWidget,
      );
    });

    testWidgets('says nearest when the walker is not moving', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.tracking,
            fix: _gpsFix,
            trail: _trail(_next(directionKnown: false)),
          ),
        ),
      );

      expect(
        find.text('Nearest: Junction 12 · 340 m · ~5 min'),
        findsOneWidget,
      );
    });

    testWidgets('says behind when every junction is behind', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.tracking,
            fix: _gpsFix,
            trail: _trail(_next(ahead: false)),
          ),
        ),
      );

      expect(
        find.text('Behind you: Junction 12 · 340 m · ~5 min'),
        findsOneWidget,
      );
    });

    testWidgets('explains when the fix is off the network', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.tracking,
            fix: _gpsFix,
            trail: null,
          ),
        ),
      );

      expect(find.text('Off the mapped tracks'), findsOneWidget);
      expect(find.text('±8 m'), findsOneWidget);
    });

    testWidgets('hides the accuracy when the fix does not know it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.tracking,
            fix: GpsFix(
              position: const GeoPoint(-19, 146),
              accuracyM: 0,
              timestamp: DateTime(2026, 10, 20),
            ),
            trail: _trail(_next()),
          ),
        ),
      );

      expect(find.textContaining('±'), findsNothing);
    });

    testWidgets('waits for the first fix', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(status: LocationStatus.starting, fix: null, trail: null),
        ),
      );

      expect(find.text('Finding your location…'), findsOneWidget);
    });

    testWidgets('says when the stream stopped', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.failed,
            fix: _gpsFix,
            trail: _trail(_next()),
          ),
        ),
      );

      expect(find.text('Location stopped'), findsOneWidget);
      expect(find.textContaining('Junction'), findsNothing);
      expect(find.textContaining('±'), findsNothing);
    });

    testWidgets('opens the junction when tapped', (tester) async {
      Junction? opened;
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.tracking,
            fix: _gpsFix,
            trail: _trail(_next()),
            onJunctionTap: (junction) => opened = junction,
          ),
        ),
      );

      await tester.tap(find.byType(LocationCard));
      expect(opened?.id, 'j12');
    });

    testWidgets('is not tappable without a junction', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.tracking,
            fix: _gpsFix,
            trail: _trail(null),
            onJunctionTap: (_) => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(LocationCard));
      await tester.pump();

      expect(taps, 0);
    });

    testWidgets('shows the distance walked and the next water', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.tracking,
            fix: _gpsFix,
            trail: _trail(_next(), water: _water()),
            walkedM: 1200,
          ),
        ),
      );

      expect(find.text('Walked 1.2 km'), findsOneWidget);
      expect(find.text('Next water 240 m · ~4 min'), findsOneWidget);
    });

    testWidgets('marks unverified water and says when it is behind', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.tracking,
            fix: _gpsFix,
            trail: _trail(
              _next(),
              water: _water(ahead: false, unverified: true),
            ),
            walkedM: 80,
          ),
        ),
      );

      expect(
        find.text('Water behind 240 m · ~4 min (unverified)'),
        findsOneWidget,
      );
    });

    testWidgets('says nearest water when the walker is standing still', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.tracking,
            fix: _gpsFix,
            trail: _trail(_next(), water: _water(directionKnown: false)),
          ),
        ),
      );

      expect(find.text('Nearest water 240 m · ~4 min'), findsOneWidget);
    });

    testWidgets('hides walked distance before the first fix', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationCard(
            status: LocationStatus.starting,
            fix: null,
            trail: null,
            walkedM: 500,
          ),
        ),
      );

      expect(find.textContaining('Walked'), findsNothing);
    });
  });

  group('LocateButton', () {
    Future<void> pumpButton(
      WidgetTester tester, {
      required LocationStatus status,
      bool following = false,
      VoidCallback? onPressed,
    }) => tester.pumpWidget(
      _wrap(
        Center(
          child: LocateButton(
            status: status,
            following: following,
            onPressed: onPressed ?? () {},
          ),
        ),
      ),
    );

    testWidgets('invites a tap before location is on', (tester) async {
      await pumpButton(tester, status: LocationStatus.off);
      expect(find.byIcon(Icons.location_searching), findsOneWidget);
    });

    testWidgets('shows the puck state once tracking', (tester) async {
      await pumpButton(tester, status: LocationStatus.tracking);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets('shows that location needs attention when denied', (
      tester,
    ) async {
      await pumpButton(tester, status: LocationStatus.permissionDenied);
      expect(find.byIcon(Icons.location_disabled), findsOneWidget);
    });

    testWidgets('forwards taps', (tester) async {
      var taps = 0;
      await pumpButton(
        tester,
        status: LocationStatus.off,
        onPressed: () => taps++,
      );
      await tester.tap(find.byType(LocateButton));
      expect(taps, 1);
    });
  });

  group('MapControlButton', () {
    testWidgets('forwards taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          Center(
            child: MapControlButton(
              icon: Icons.tune,
              tooltip: 'Options',
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(MapControlButton));
      expect(taps, 1);
    });

    testWidgets('is at least a 48 px target, even when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: MapControlButton(icon: Icons.tune, tooltip: 'Options'),
          ),
        ),
      );

      final size = tester.getSize(find.byType(MapControlButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
