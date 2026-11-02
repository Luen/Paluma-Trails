import 'dart:convert';
import 'dart:io';

import 'package:paluma_cli/src/repo.dart';
import 'package:paluma_cli/src/validate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('rejects a POI that still carries the retired qr_id field', () {
    final source = Repo.locate();
    final temp = Directory.systemTemp.createTempSync('paluma-qr-id-');
    addTearDown(() => temp.deleteSync(recursive: true));
    _copyDir(
      Directory(source.path('content/schema')),
      Directory(p.join(temp.path, 'content', 'schema')),
    );
    _copyDir(
      Directory(source.path('content/data')),
      Directory(p.join(temp.path, 'content', 'data')),
    );

    final poisFile = File(
      p.join(temp.path, 'content', 'data', 'paluma', 'pois.json'),
    );
    final json =
        jsonDecode(poisFile.readAsStringSync()) as Map<String, Object?>;
    final first = (json['pois'] as List).cast<Map<String, Object?>>().first;
    first['qr_id'] = 'sign-001';
    poisFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(json)}\n',
    );

    final problems = ContentValidator(Repo(temp.path)).validate();

    expect(problems, hasLength(1));
    expect(problems.single, contains('poi ${first['id']}'));
    expect(problems.single, contains('"qr_id"'));
    expect(problems.single, contains('/poi/<id>'));
    expect(problems.single, contains('ADR 0009'));
  });

  test('the content source no longer carries qr_id', () {
    final repo = Repo.locate();
    final json =
        jsonDecode(File(p.join(repo.dataDir, 'pois.json')).readAsStringSync())
            as Map<String, Object?>;

    for (final poi in (json['pois'] as List).cast<Map<String, Object?>>()) {
      expect(poi.containsKey('qr_id'), isFalse, reason: 'poi ${poi['id']}');
    }
  });
}

void _copyDir(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(recursive: true)) {
    final destination =
        p.join(to.path, p.relative(entity.path, from: from.path));
    if (entity is Directory) {
      Directory(destination).createSync(recursive: true);
    } else if (entity is File) {
      File(destination).parent.createSync(recursive: true);
      entity.copySync(destination);
    }
  }
}
