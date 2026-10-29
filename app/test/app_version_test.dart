import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/app_version.dart';

void main() {
  test('kAppVersion is a dotted release name', () {
    expect(kAppVersion, matches(RegExp(r'^\d+\.\d+\.\d+')));
  });
}
