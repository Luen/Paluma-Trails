import 'package:paluma_trails/src/waypoints/waypoint_storage.dart';
import 'package:paluma_trails/src/waypoints/waypoint_store.dart';

/// Keeps the saved string in memory, so tests never touch a plugin.
class MemoryWaypointStorage implements WaypointStorage {
  MemoryWaypointStorage([this.data]);

  String? data;
  var writes = 0;
  var failWrites = false;
  var delayWrites = false;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String value) async {
    if (delayWrites) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (failWrites) {
      throw StateError('The waypoint store refused the write');
    }
    data = value;
    writes++;
  }
}

/// A store with a fixed clock, so ids and default names are predictable.
WaypointStore testWaypointStore([WaypointStorage? storage]) => WaypointStore(
  storage: storage ?? MemoryWaypointStorage(),
  clock: () => DateTime(2026, 10, 28, 9),
);
