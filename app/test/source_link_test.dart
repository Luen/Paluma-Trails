import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/map/source_link.dart';

void main() {
  testWidgets('shows attribution offline and opens only after a tap', (
    tester,
  ) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceLink(
            label: 'Wanderstories Paluma guide',
            url: 'https://wanderstories.space/paluma-maps/',
            launch: (uri) async {
              opened = uri;
              return true;
            },
          ),
        ),
      ),
    );
    expect(opened, isNull);
    expect(find.text('Wanderstories Paluma guide'), findsOneWidget);
    expect(find.text('Read online · wanderstories.space'), findsOneWidget);
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(opened.toString(), 'https://wanderstories.space/paluma-maps/');
  });

  for (final url in [
    null,
    'javascript:alert(1)',
    'file:///tmp/book',
    'https://user:pass@example.com',
  ]) {
    testWidgets(
      'non-web or credential-bearing reference stays plain text: $url',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SourceLink(label: 'Offline citation', url: url),
            ),
          ),
        );
        expect(find.text('Offline citation'), findsOneWidget);
        expect(find.byType(TextButton), findsNothing);
      },
    );
  }

  testWidgets('browser failure is explained without losing offline content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceLink(
            label: 'Offline citation',
            url: 'https://wanderstories.space/',
            launch: (_) async => throw StateError('No browser'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open the source.'), findsOneWidget);
    expect(find.text('Offline citation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long source labels wrap at large text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: SourceLink(
              label: 'Luen Warneke and Wilfred Karnoll, Paluma trails and history, Wanderstories',
              url: 'https://wanderstories.space/hiking-at-paluma-range-national-park/',
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
