import 'package:shared_preferences/shared_preferences.dart';

/// Where saved waypoints live between launches.
///
/// Behind an interface so the tests (and any future GPX export) never touch the
/// plugin, and so a platform can swap the store without changing the model.
abstract interface class WaypointStorage {
  Future<String?> read();
  Future<void> write(String data);
}

/// Keeps the waypoint list in the platform's own preference store: shared
/// preferences on Android and iOS, localStorage on the web.
///
/// One JSON string rather than one key per waypoint, so a save is a single
/// write and can never leave half a list behind.
class SharedPreferencesWaypointStorage implements WaypointStorage {
  const SharedPreferencesWaypointStorage();

  static const _key = 'waypoints.v1';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key);
  }

  @override
  Future<void> write(String data) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_key, data);
    if (!saved) {
      throw StateError('The waypoint store refused the write');
    }
  }
}
