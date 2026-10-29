import 'package:flutter_test/flutter_test.dart';
import 'package:paluma_trails/src/content/models.dart';
import 'package:paluma_trails/src/waypoints/waypoint.dart';
import 'package:paluma_trails/src/waypoints/waypoint_store.dart';

import 'support/waypoint_fixture.dart';

const _falls = GeoPoint(-18.966587, 146.18883);
const _clearing = GeoPoint(-18.958, 146.19);

WaypointStore _store(MemoryWaypointStorage storage) =>
    testWaypointStore(storage);

void main() {
  group('WaypointStore', () {
    test('starts empty when nothing is saved', () async {
      final store = _store(MemoryWaypointStorage());
      await store.load();

      expect(store.loaded, isTrue);
      expect(store.waypoints, isEmpty);
    });

    test('reads the saved list back', () async {
      final storage = MemoryWaypointStorage(
        '[{"id":"w1","name":"Camp","location":{"lat":-18.958,"lon":146.19},'
        '"created_at":${DateTime.utc(2026, 10, 27).millisecondsSinceEpoch}}]',
      );
      final store = _store(storage);
      await store.load();

      expect(store.waypoints, hasLength(1));
      expect(store.waypoints.single.name, 'Camp');
      expect(store.waypoints.single.location.lat, closeTo(-18.958, 1e-9));
      expect(store.byId('w1')?.name, 'Camp');
      expect(store.byId('nope'), isNull);
    });

    test('skips unreadable entries without losing the good ones', () async {
      final storage = MemoryWaypointStorage(
        '[{"id":"w1","name":"Camp","location":{"lat":-18.958,"lon":146.19},'
        '"created_at":0},{"id":"broken"},null]',
      );
      final store = _store(storage);
      await store.load();

      expect(store.waypoints, hasLength(1));
      expect(store.waypoints.single.id, 'w1');
    });

    test('survives a corrupt store instead of failing the map', () async {
      final store = _store(MemoryWaypointStorage('not json at all'));
      await store.load();

      expect(store.loaded, isTrue);
      expect(store.waypoints, isEmpty);
    });

    test('names a new pin and writes it straight away', () async {
      final storage = MemoryWaypointStorage();
      final store = _store(storage);
      await store.load();

      final waypoint = await store.add(location: _falls);

      expect(waypoint.name, 'Waypoint 1');
      expect(store.waypoints, hasLength(1));
      expect(storage.writes, 1);
      expect(storage.data, contains('Waypoint 1'));
    });

    test('the saved list survives a restart', () async {
      final storage = MemoryWaypointStorage();
      final first = _store(storage);
      await first.load();
      await first.add(location: _falls, name: 'Falls photo');
      await first.add(location: _clearing);

      final second = _store(storage);
      await second.load();

      expect(second.waypoints.map((waypoint) => waypoint.name), [
        'Falls photo',
        'Waypoint 1',
      ]);
    });

    test('takes the lowest free default name', () async {
      final store = _store(MemoryWaypointStorage());
      await store.load();

      final first = await store.add(location: _falls);
      await store.add(location: _clearing);
      await store.remove(first.id);

      final third = await store.add(location: _falls);

      expect(third.name, 'Waypoint 1');
    });

    test('trims a given name and ignores a blank one', () async {
      final store = _store(MemoryWaypointStorage());
      await store.load();

      final named = await store.add(location: _falls, name: '  Lookout  ');
      final blank = await store.add(location: _clearing, name: '   ');

      expect(named.name, 'Lookout');
      expect(blank.name, 'Waypoint 1');
    });

    test('gives pins added at the same instant distinct ids', () async {
      final store = _store(MemoryWaypointStorage());
      await store.load();

      final first = await store.add(location: _falls);
      final second = await store.add(location: _clearing);

      expect(first.id, isNot(second.id));
      expect(store.byId(first.id)?.id, first.id);
      expect(store.byId(second.id)?.id, second.id);
    });

    test('renames a pin, refusing a blank name', () async {
      final storage = MemoryWaypointStorage();
      final store = _store(storage);
      await store.load();
      final waypoint = await store.add(location: _falls);

      expect(await store.rename(waypoint.id, 'Swimming hole'), isTrue);
      expect(store.byId(waypoint.id)!.name, 'Swimming hole');
      expect(storage.data, contains('Swimming hole'));

      expect(await store.rename(waypoint.id, '  '), isFalse);
      expect(store.byId(waypoint.id)!.name, 'Swimming hole');

      expect(await store.rename('missing', 'Anything'), isFalse);
    });

    test('deletes a pin and saves the shorter list', () async {
      final storage = MemoryWaypointStorage();
      final store = _store(storage);
      await store.load();
      final waypoint = await store.add(location: _falls);

      expect(await store.remove(waypoint.id), isTrue);
      expect(store.waypoints, isEmpty);
      expect(storage.data, '[]');

      expect(await store.remove(waypoint.id), isFalse);
    });

    test('keeps overlapping adds instead of losing the later pin', () async {
      final storage = MemoryWaypointStorage()..delayWrites = true;
      final store = _store(storage);
      await store.load();

      final first = store.add(location: _falls, name: 'First');
      final second = store.add(location: _clearing, name: 'Second');
      await Future.wait([first, second]);

      expect(store.waypoints.map((waypoint) => waypoint.name), [
        'First',
        'Second',
      ]);
      expect(storage.writes, 2);

      final restarted = _store(storage);
      await restarted.load();
      expect(restarted.waypoints.map((waypoint) => waypoint.name), [
        'First',
        'Second',
      ]);
    });

    test('rolls back an add when the store refuses the write', () async {
      final storage = MemoryWaypointStorage()..failWrites = true;
      final store = _store(storage);
      await store.load();

      await expectLater(store.add(location: _falls), throwsStateError);
      expect(store.waypoints, isEmpty);
      expect(storage.data, isNull);
    });

    test('rolls back a rename when the store refuses the write', () async {
      final storage = MemoryWaypointStorage();
      final store = _store(storage);
      await store.load();
      final waypoint = await store.add(location: _falls, name: 'Camp');
      storage.failWrites = true;

      await expectLater(store.rename(waypoint.id, 'Lookout'), throwsStateError);
      expect(store.byId(waypoint.id)!.name, 'Camp');
      expect(storage.data, contains('Camp'));
    });
  });

  group('waypointsFeatureCollection', () {
    test('turns pins into named point features', () {
      final waypoint = Waypoint(
        id: 'w1',
        name: 'Swimming hole',
        location: _falls,
        createdAt: DateTime(2026, 10, 28),
      );

      final collection = waypointsFeatureCollection([waypoint]);
      final features = (collection['features'] as List)
          .cast<Map<String, Object?>>();

      expect(features, hasLength(1));
      expect(features.single['id'], 'w1');
      final properties = features.single['properties']! as Map<String, Object?>;
      expect(properties['name'], 'Swimming hole');
      final geometry = features.single['geometry']! as Map<String, Object?>;
      expect(geometry['type'], 'Point');
      expect(geometry['coordinates'], [146.18883, -18.966587]);
    });

    test('an empty list is still a valid collection', () {
      final collection = waypointsFeatureCollection(const []);

      expect(collection['type'], 'FeatureCollection');
      expect(collection['features'], isEmpty);
    });
  });
}
