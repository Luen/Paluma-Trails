import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/map/map_options.dart';
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
}
