import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/map/route_sheet.dart';
import 'package:paluma_trails/src/map/location_overlay.dart';

import 'support/bundle_fixture.dart';

void main() {
  testWidgets('planner remains usable at 320 px with double-size text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: RoutePlanSheet(bundle: testBundle(), onFocus: (_) async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Out and back'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Loop'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });
  testWidgets('map controls expose a named button role to screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapControlButton(
            icon: Icons.fit_screen,
            tooltip: 'Show the whole park',
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Show the whole park')),
      matchesSemantics(
        label: 'Show the whole park',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });
}
