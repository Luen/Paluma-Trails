import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/map/poi_link_sheet.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showPoiLinkNotFoundSheet(context, poiId: 'retired-lookout'),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names the id and explains the missing entry', (tester) async {
    await _open(tester);

    expect(
      find.text('That code points to a place this map does not have'),
      findsOneWidget,
    );
    expect(find.textContaining('retired-lookout'), findsOneWidget);
    expect(find.textContaining('offline map still works'), findsOneWidget);
  });

  testWidgets('leaves the walker on the map', (tester) async {
    await _open(tester);

    await tester.tap(find.text('Show the map'));
    await tester.pumpAndSettle();

    expect(find.byType(PoiLinkNotFoundSheet), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
