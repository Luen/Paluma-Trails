import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../content/models.dart';
import 'location_service.dart';
import 'trail_locator.dart';

/// A disposable, offline location driver for an explicitly labelled preview.
///
/// Never reads GPS, permissions or platform settings. The map owns this driver
/// for one preview route; none of its positions are persisted.
class WalkSimulation extends ChangeNotifier implements LocationDriver {
  WalkSimulation(this.track) {
    if (!isUsable(track)) throw ArgumentError('Preview needs a non-zero track');
    _distances = [0];
    for (var i = 1; i < track.points.length; i++) {
      _distances.add(
        _distances.last + _distance(track.points[i - 1], track.points[i]),
      );
    }
    _positions = StreamController<Position>.broadcast(
      onListen: () {
        _emit();
        _startTimer();
      },
      onCancel: () => _timer?.cancel(),
    );
  }

  final TrackPolyline track;
  late final List<double> _distances;
  late final StreamController<Position> _positions;
  Timer? _timer;
  double _metres = 0;
  int _speed = 40;
  bool _paused = false;
  bool _disposed = false;

  static bool isUsable(TrackPolyline track) =>
      track.points.length >= 2 &&
      track.points.every(
        (p) =>
            p.lat.isFinite &&
            p.lon.isFinite &&
            p.lat.abs() <= 90 &&
            p.lon.abs() <= 180,
      ) &&
      track.points.skip(1).any((p) => _distance(track.points.first, p) > 1);

  double get totalM => _distances.last;
  double get metres => _metres;
  double get progress => _metres / totalM;
  int get speed => _speed;
  bool get paused => _paused;
  bool get complete => _metres >= totalM;

  set speed(int value) {
    if (![20, 40, 80].contains(value)) {
      throw ArgumentError.value(value, 'speed');
    }
    _speed = value;
    notifyListeners();
  }

  void togglePause() {
    if (_disposed || complete) return;
    _paused = !_paused;
    _timer?.cancel();
    if (!_paused) {
      _emit();
      _startTimer();
    }
    notifyListeners();
  }

  /// Advances virtual walking time; also permits deterministic geometry tests.
  void advance(Duration elapsed) {
    if (_disposed || _paused || complete || elapsed.isNegative) return;
    _metres = math.min(
      totalM,
      _metres + elapsed.inMicroseconds / 1000000 * 1.2 * speed,
    );
    _emit();
    if (complete) _timer?.cancel();
    notifyListeners();
  }

  void restart() {
    if (_disposed) return;
    _metres = 0;
    _paused = false;
    _emit();
    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_disposed || paused || complete || !_positions.hasListener) return;
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      advance(const Duration(milliseconds: 500));
    });
  }

  /// Current interpolated position, explicitly marked as mock data.
  Position get position {
    var end = 1;
    while (end < _distances.length - 1 && _distances[end] <= _metres) {
      end++;
    }
    final a = track.points[end - 1];
    final b = track.points[end];
    final length = _distances[end] - _distances[end - 1];
    final fraction = length == 0
        ? 0.0
        : ((_metres - _distances[end - 1]) / length).clamp(0.0, 1.0);
    final midLat = (a.lat + b.lat) * math.pi / 360;
    final bearing =
        (math.atan2((b.lon - a.lon) * math.cos(midLat), b.lat - a.lat) *
                180 /
                math.pi +
            360) %
        360;
    return Position(
      longitude: a.lon + (b.lon - a.lon) * fraction,
      latitude: a.lat + (b.lat - a.lat) * fraction,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: bearing,
      headingAccuracy: 0,
      speed: 1.2,
      speedAccuracy: 0,
      isMocked: true,
      hasHeading: true,
      hasSpeed: true,
    );
  }

  void _emit() {
    if (!_disposed && _positions.hasListener) _positions.add(position);
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
  @override
  Stream<Position> positions({LocationSettings? settings}) => _positions.stream;
  @override
  Future<bool> openAppSettings() async => false;
  @override
  Future<bool> openLocationSettings() async => false;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_positions.close());
    super.dispose();
  }
}

double _distance(GeoPoint a, GeoPoint b) {
  const metresPerDegree = 111195.08;
  final x =
      (b.lon - a.lon) *
      metresPerDegree *
      math.cos((a.lat + b.lat) * math.pi / 360);
  final y = (b.lat - a.lat) * metresPerDegree;
  return math.sqrt(x * x + y * y);
}
