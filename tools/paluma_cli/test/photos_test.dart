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
    for (final directory in ['data', 'schema', 'photos']) {
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
}
