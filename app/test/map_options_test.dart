import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/map/map_options.dart';
import 'package:paluma_trails/src/map/poi_groups.dart';
import 'package:paluma_trails/src/map/sheets.dart';

void main() {
  test('notifies when a display option changes', () {
    final options = MapOptions();
    var notifications = 0;
    options.addListener(() => notifications++);

    options.sunlight = true;
    expect(options.sunlight, isTrue);
    expect(notifications, 1);

    options.batterySaver = true;
    expect(options.batterySaver, isTrue);
    expect(notifications, 2);

    options.dispose();
  });

  test('ignores a value that is already set', () {
    final options = MapOptions();
    var notifications = 0;
    options.addListener(() => notifications++);

    options.sunlight = false;
    options.batterySaver = false;

    expect(notifications, 0);
    options.dispose();
  });

  test('hides a POI group and reports the categories to filter', () {
    final options = MapOptions();
    var notifications = 0;
    options.addListener(() => notifications++);

    expect(options.allPoiGroupsVisible, isTrue);
    expect(options.hiddenPoiCategories, isEmpty);

    options.setPoiGroupVisible(PoiGroup.water, false);
    expect(options.isPoiGroupVisible(PoiGroup.water), isFalse);
    expect(options.isPoiGroupVisible(PoiGroup.lookouts), isTrue);
    expect(
      options.hiddenPoiCategories,
      containsAll(<String>['water', 'waterfall', 'swimming']),
    );
    expect(notifications, 1);

    options.setPoiGroupVisible(PoiGroup.water, false);
    expect(notifications, 1, reason: 'no change, no notification');

    options.showAllPoiGroups();
    expect(options.allPoiGroupsVisible, isTrue);
    expect(options.hiddenPoiCategories, isEmpty);
    expect(notifications, 2);

    options.dispose();
  });

  testWidgets('the display sheet toggles both options', (tester) async {
    final options = MapOptions();
    addTearDown(options.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showDisplaySettingsSheet(context, options: options),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sunlight mode'));
    await tester.pumpAndSettle();
    expect(options.sunlight, isTrue);

    await tester.tap(find.text('Battery saver'));
    await tester.pumpAndSettle();
    expect(options.batterySaver, isTrue);

    await tester.tap(find.text('Sunlight mode'));
    await tester.pumpAndSettle();
    expect(options.sunlight, isFalse);
  });

  testWidgets('the display sheet hides a POI group and offers to show all', (
    tester,
  ) async {
    // Tall enough for the POI toggles and the header to be on screen at once,
    // so the test does not depend on the sheet's scroll offset.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final options = MapOptions();
    addTearDown(options.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showDisplaySettingsSheet(context, options: options),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Show all'), findsNothing);

    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();

    expect(options.isPoiGroupVisible(PoiGroup.water), isFalse);
    expect(find.text('Show all'), findsOneWidget);

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();

    expect(options.isPoiGroupVisible(PoiGroup.water), isTrue);
    expect(find.text('Show all'), findsNothing);
  });
}
