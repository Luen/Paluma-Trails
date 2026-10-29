import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:paluma_cli/src/bundle.dart';
import 'package:paluma_cli/src/repo.dart';
import 'package:paluma_cli/src/validate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory scratch;
  late Repo repo;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('paluma-photos-');
    repo = Repo(scratch.path);
    final source = Repo.locate();
    for (final directory in ['data', 'schema', 'photos', 'research']) {
      final from = Directory(p.join(source.contentDir, directory));
      for (final file in from.listSync(recursive: true).whereType<File>()) {
        final target = File(p.join(
          repo.contentDir,
          directory,
          p.relative(file.path, from: from.path),
        ));
        target.parent.createSync(recursive: true);
        file.copySync(target.path);
      }
    }
  });
  tearDown(() => scratch.deleteSync(recursive: true));

  void changeFirstPhoto(void Function(Map<String, dynamic>) change) {
    final file = File(p.join(repo.dataDir, 'pois.json'));
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final poi = (data['pois'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((poi) => (poi['photos'] as List).isNotEmpty);
    change((poi['photos'] as List).first as Map<String, dynamic>);
    file.writeAsStringSync(jsonEncode(data));
  }

  test('referenced photos ship byte-for-byte with manifest hashes', () {
    expect(ContentValidator(repo).validate(), isEmpty);
    final out = p.join(scratch.path, 'bundle');
    final manifest = BundleBuilder(repo).build(outDir: out);
    final files = (manifest['files'] as List).cast<Map<String, Object?>>();
    final photos = files
        .where((entry) =>
            p.posix.split(entry['path']! as String).first == 'photos')
        .toList();
    expect(photos, hasLength(5));
    for (final entry in photos) {
      final relative = entry['path']! as String;
      final bytes =
          File(p.joinAll([out, ...p.posix.split(relative)])).readAsBytesSync();
      expect(
          bytes,
          File(p.join(repo.contentDir, 'photos', p.posix.basename(relative)))
              .readAsBytesSync());
      expect(entry['bytes'], bytes.length);
      expect(entry['sha256'], sha256.convert(bytes).toString());
    }
    expect(File(p.join(out, 'photos', 'catalogue.json')).existsSync(), isFalse);
    expect(File(p.join(out, 'photos', 'README.md')).existsSync(), isFalse);
    expect(BundleBuilder(repo).build(outDir: out), manifest);
  });

  test('missing photo fails content validation', () {
    changeFirstPhoto((photo) => photo['file'] = 'missing.jpg');
    expect(ContentValidator(repo).validate(),
        contains(contains('references missing photo: missing.jpg')));
  });

  test('photo paths cannot escape the source photo directory', () {
    for (final name in [
      '../park.json',
      '/tmp/photo.jpg',
      'https://example.com/photo.jpg',
      r'..\photo.jpg'
    ]) {
      changeFirstPhoto((photo) => photo['file'] = name);
      expect(ContentValidator(repo).validate(), isNotEmpty, reason: name);
    }
  });

  test('photo attribution and licence are required', () {
    changeFirstPhoto((photo) {
      photo.remove('credit');
      photo['licence'] = '';
    });
    expect(ContentValidator(repo).validate(), isNotEmpty);
  });

  void changeCatalogue(void Function(List<dynamic>) change) {
    final file = File(p.join(repo.contentDir, 'photos', 'catalogue.json'));
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    change(data['images'] as List);
    file.writeAsStringSync(jsonEncode(data));
  }

  test('every published photo needs a catalogue record for its POI', () {
    changeCatalogue((images) => images.removeAt(0));
    expect(ContentValidator(repo).validate(),
        contains(contains('has no catalogue record')));
  });

  test('a record for a different POI cannot silently reassign a photograph',
      () {
    changeCatalogue((images) => images.first['poi_id'] = 'another-site');
    expect(ContentValidator(repo).validate(),
        contains(contains('johnstones-hut has no catalogue record')));
  });

  test('changed image bytes invalidate the recorded provenance hash', () {
    final file =
        File(p.join(repo.contentDir, 'photos', 'johnstones-hut-1911.jpg'));
    file.writeAsBytesSync([0], mode: FileMode.append);
    expect(ContentValidator(repo).validate(),
        contains(contains('SHA-256 mismatch: johnstones-hut-1911.jpg')));
  });

  test('duplicate provenance records are rejected', () {
    changeCatalogue((images) => images.add(images.first));
    expect(ContentValidator(repo).validate(),
        contains(contains('duplicate photo catalogue record')));
  });

  test('original collection credit and caption must remain in the catalogue',
      () {
    changeCatalogue((images) {
      images.first['original_credit'] = ' ';
      images.first.remove('caption');
    });
    final problems = ContentValidator(repo).validate();
    expect(problems, contains(contains('needs original_credit')));
    expect(problems, contains(contains('needs caption')));
  });

  test('permission records must exist inside the content directory', () {
    for (final reference in [
      '',
      '../research/missing.md',
      '../../../AGENTS.md',
      '/tmp/permission.md'
    ]) {
      changeCatalogue(
          (images) => images.first['permission_record'] = reference);
      expect(ContentValidator(repo).validate(),
          contains(contains('permission_record')),
          reason: reference);
    }
  });

  test('missing or malformed catalogue gives a validation error, not a crash',
      () {
    final file = File(p.join(repo.contentDir, 'photos', 'catalogue.json'));
    file.deleteSync();
    expect(ContentValidator(repo).validate(),
        contains(contains('missing or unreadable')));
    file.writeAsStringSync('{broken');
    expect(ContentValidator(repo).validate(),
        contains('photo catalogue is not valid JSON'));
    file.writeAsStringSync('{"images": {}}');
    expect(ContentValidator(repo).validate(),
        contains('photo catalogue must contain an images array'));
  });
}
