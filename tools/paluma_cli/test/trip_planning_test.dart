import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:paluma_cli/src/repo.dart';
import 'package:test/test.dart';

void main() {
  final repo = Repo.locate();
  final source = File(repo.path('content/data/paluma/trip-planning.json'));
  final schema = JsonSchema.create(File(
    repo.path('content/schema/trip-planning.schema.json'),
  ).readAsStringSync());

  test('planning notes require a check date, text and attributed HTTPS sources',
      () {
    Map<String, dynamic> read() =>
        jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
    expect(schema.validate(read()).isValid, isTrue);
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (data) => data.remove('checked'),
      (data) => data['sections'][0]['paragraphs'] = [],
      (data) => data['sections'][0]['sources'] = [],
      (data) => data['sections'][0]['sources'][0]['label'] = '',
      (data) =>
          data['sections'][0]['sources'][0]['url'] = 'javascript:alert(1)',
    ]) {
      final data = read();
      mutate(data);
      expect(schema.validate(data).isValid, isFalse);
    }
  });
}
