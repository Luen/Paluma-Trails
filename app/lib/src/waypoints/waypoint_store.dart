import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../content/models.dart';
import 'waypoint.dart';
import 'waypoint_storage.dart';

/// The walker's own pins, kept on the device.
///
/// Reads once at start-up, then writes the whole list after every change. A
/// corrupt or unreadable store is skipped rather than blocking the map; the
/// next save replaces it.
class WaypointStore extends ChangeNotifier {
  WaypointStore({WaypointStorage? storage, DateTime Function()? clock})
    : _storage = storage ?? const SharedPreferencesWaypointStorage(),
      _clock = clock ?? DateTime.now;

  final WaypointStorage _storage;
  final DateTime Function() _clock;
  final List<Waypoint> _waypoints = [];
  var _loaded = false;

  /// Chains mutating writes so two quick taps cannot overwrite each other.
  Future<void> _queue = Future<void>.value();

  /// Whether [load] has finished, successfully or not.
  bool get loaded => _loaded;

  /// Oldest first, in the order they were saved.
  List<Waypoint> get waypoints => List.unmodifiable(_waypoints);

  /// One saved pin, or null when it has been deleted.
  Waypoint? byId(String id) {
    for (final waypoint in _waypoints) {
      if (waypoint.id == id) return waypoint;
    }
    return null;
  }

  /// Reads the saved list. Safe to call twice; the second call is a no-op.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await _storage.read();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is! Map) continue;
            try {
              _waypoints.add(Waypoint.fromJson(entry.cast<String, Object?>()));
            } catch (error) {
              debugPrint('Skipping a saved waypoint: $error');
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Could not read saved waypoints: $error');
    }
    _loaded = true;
    notifyListeners();
  }

  /// Saves a new pin at [location]. Without a [name], the next free
  /// "Waypoint N" is used so a pin added in a hurry still makes sense later.
  Future<Waypoint> add({required GeoPoint location, String? name}) {
    return _enqueue(() async {
      final now = _clock();
      final trimmed = name?.trim();
      final waypoint = Waypoint(
        id: _newId(now),
        name: trimmed == null || trimmed.isEmpty ? _nextName() : trimmed,
        location: location,
        createdAt: now,
      );
      _waypoints.add(waypoint);
      notifyListeners();
      try {
        await _save();
      } catch (error) {
        _waypoints.removeWhere((entry) => entry.id == waypoint.id);
        notifyListeners();
        rethrow;
      }
      return waypoint;
    });
  }

  /// Removes one pin. Returns whether it was there.
  Future<bool> remove(String id) {
    return _enqueue(() async {
      final index = _waypoints.indexWhere((waypoint) => waypoint.id == id);
      if (index < 0) return false;
      final removed = _waypoints.removeAt(index);
      notifyListeners();
      try {
        await _save();
      } catch (error) {
        _waypoints.insert(index, removed);
        notifyListeners();
        rethrow;
      }
      return true;
    });
  }

  /// Renames one pin. A blank name is refused rather than leaving a nameless
  /// marker on the map.
  Future<bool> rename(String id, String name) {
    return _enqueue(() async {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return false;
      final index = _waypoints.indexWhere((waypoint) => waypoint.id == id);
      if (index < 0) return false;
      if (_waypoints[index].name == trimmed) return true;
      final previous = _waypoints[index];
      _waypoints[index] = previous.renamed(trimmed);
      notifyListeners();
      try {
        await _save();
      } catch (error) {
        _waypoints[index] = previous;
        notifyListeners();
        rethrow;
      }
      return true;
    });
  }

  /// Runs [action] after any in-flight mutation, so overlapping saves cannot
  /// leave an older list on disk.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  String _newId(DateTime now) {
    var id = 'w${now.microsecondsSinceEpoch}';
    var suffix = 1;
    while (_waypoints.any((waypoint) => waypoint.id == id)) {
      id = 'w${now.microsecondsSinceEpoch}-${suffix++}';
    }
    return id;
  }

  /// The lowest unused "Waypoint N", so deleting pin 2 and adding another does
  /// not produce a duplicate name.
  String _nextName() {
    var number = 1;
    while (_waypoints.any((waypoint) => waypoint.name == 'Waypoint $number')) {
      number++;
    }
    return 'Waypoint $number';
  }

  Future<void> _save() async {
    final data = jsonEncode([
      for (final waypoint in _waypoints) waypoint.toJson(),
    ]);
    try {
      await _storage.write(data);
    } catch (error) {
      debugPrint('Could not save waypoints: $error');
      rethrow;
    }
  }
}
