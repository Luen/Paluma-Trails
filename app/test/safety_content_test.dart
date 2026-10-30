import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/brand/theme.dart';
import 'package:paluma_trails/src/content/models.dart';
import 'package:paluma_trails/src/location/location_service.dart';
import 'package:paluma_trails/src/safety_screen.dart';

import 'support/bundle_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SafetyContent safety;
  setUpAll(() async {
    final raw = await rootBundle.loadString(
      'assets/bundle/content/safety.json',
    );
    safety = SafetyContent.fromJson(jsonDecode(raw) as Map<String, Object?>);
  });

  test(
    'bundled emergency guidance does not suggest direct SMS or extra coverage',
    () {
      expect(safety.emergencyHeadline, contains('same emergency service'));
      final steps = safety.emergencySteps.join(' ');
      expect(steps, contains('Do not send an SMS directly to 000 or 112'));
      expect(steps, contains('does not create reception'));
      expect(steps, isNot(contains('it may leave when a call cannot')));
      expect(
        safety.sources.map((s) => Uri.parse(s.url).host),
        contains('www.acma.gov.au'),
      );
      expect(
        safety.sources.map((s) => Uri.parse(s.url).host),
        contains('www.infrastructure.gov.au'),
      );
    },
  );

  test('older bundles without references still decode', () {
    expect(SafetyContent.fromJson({}).sources, isEmpty);
  });

  for (final (name, brightness, sunlight, scale) in [
    ('light', Brightness.light, false, 1.0),
    ('dark', Brightness.dark, false, 1.0),
    ('sunlight', Brightness.light, true, 1.0),
    ('large text', Brightness.light, false, 2.0),
  ]) {
    testWidgets('actual offline guidance and sources render at 320 px: $name', (
      tester,
    ) async {
      final location = LocationService();
      addTearDown(location.dispose);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPalumaTheme(brightness, sunlight: sunlight),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: SafetyScreen(
            bundle: testBundle(safety: safety),
            location: location,
          ),
        ),
      );
      expect(
        find.textContaining('Do not send an SMS directly'),
        findsOneWidget,
      );
      expect(find.text('Call 000'), findsOneWidget);
      expect(find.text('Call 112'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Emergency contact sources'),
        500,
      );
      expect(find.textContaining('ACMA — Emergency calls'), findsOneWidget);
      expect(location.fix.value, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
