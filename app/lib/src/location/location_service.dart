/// Location tracking for the map: permissions, the fix stream and the single
/// place the rest of the app reads GPS state from.
///
/// The map's puck is driven by these fixes (MapLibre's `ManualLocationSource`),
/// so the same code path works on Android, iOS and the web, and the app never
/// depends on Google Play Services at runtime.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../content/models.dart';

/// Where the location feature stands, as far as the UI needs to know.
enum LocationStatus {
  /// Not started: no fixes, permission not asked for yet.
  off,

  /// The device's location services are switched off.
  servicesDisabled,

  /// Permission was refused; asking again may still show a prompt.
  permissionDenied,

  /// Permission was refused permanently; only the app settings can grant it.
  permissionDeniedForever,

  /// Permission is granted and the first fix is on its way.
  starting,

  /// Fixes are arriving.
  tracking,

  /// The location stream itself reported a failure.
  failed,
}

/// One GPS fix, in the units the rest of the app works in.
@immutable
class GpsFix {
  const GpsFix({
    required this.position,
    required this.accuracyM,
    required this.timestamp,
    this.bearingDeg,
    this.speedMps,
    this.altitudeM,
  });

  factory GpsFix.fromPosition(Position position) => GpsFix(
    position: GeoPoint(position.latitude, position.longitude),
    accuracyM: position.hasAccuracy && position.accuracy.isFinite
        ? position.accuracy
        : 0,
    timestamp: position.timestamp,
    bearingDeg: position.hasHeading && position.heading.isFinite
        ? position.heading
        : null,
    speedMps: position.hasSpeed && position.speed.isFinite
        ? position.speed
        : null,
    altitudeM: position.hasAltitude && position.altitude.isFinite
        ? position.altitude
        : null,
  );

  final GeoPoint position;

  /// Radius of uncertainty of [position], metres (0 when unknown).
  final double accuracyM;
  final DateTime timestamp;

  /// Direction of travel in degrees clockwise from north, when the fix knows.
  final double? bearingDeg;

  /// Speed over ground, metres per second.
  final double? speedMps;
  final double? altitudeM;
}

/// The slice of the geolocator plugin [LocationService] uses, so tests can
/// drive every state without a device.
abstract class LocationDriver {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Stream<Position> positions({LocationSettings? settings});
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

/// [LocationDriver] backed by the geolocator plugin.
class GeolocatorDriver implements LocationDriver {
  const GeolocatorDriver();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Stream<Position> positions({LocationSettings? settings}) =>
      Geolocator.getPositionStream(locationSettings: settings);

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Owns the permission conversation and the fix stream for the map screen.
///
/// Nothing starts on its own: [start] is called when the walker taps the
/// locate button, so GPS never runs behind their back.
class LocationService {
  LocationService({LocationDriver? driver, this.settings})
    : _driver = driver ?? const GeolocatorDriver();

  final LocationDriver _driver;

  /// Overrides the platform's default location settings; tests use this to
  /// keep the service away from real device behaviour.
  final LocationSettings? settings;

  final ValueNotifier<LocationStatus> status = ValueNotifier(
    LocationStatus.off,
  );
  final ValueNotifier<GpsFix?> fix = ValueNotifier(null);

  StreamSubscription<Position>? _subscription;
  var _disposed = false;

  bool get isTracking => _subscription != null;

  /// Asks for permission when needed, then starts reporting fixes.
  ///
  /// The returned status is the same value [status] holds when it settles.
  Future<LocationStatus> start() async {
    if (_subscription != null) return status.value;

    if (!await _driver.isLocationServiceEnabled()) {
      return status.value = LocationStatus.servicesDisabled;
    }

    var permission = await _driver.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _driver.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return status.value = LocationStatus.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return status.value = LocationStatus.permissionDeniedForever;
    }

    status.value = LocationStatus.starting;
    late final StreamSubscription<Position> subscription;
    subscription = _driver
        .positions(settings: _settingsFor())
        .listen(
          _onPosition,
          onError: (Object _) {
            // Drop the dead stream so the next tap can start a fresh one.
            if (identical(_subscription, subscription)) _subscription = null;
            subscription.cancel();
            fix.value = null;
            status.value = LocationStatus.failed;
          },
        );
    _subscription = subscription;
    return status.value;
  }

  /// Stops reporting fixes; the map's puck disappears with them.
  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    fix.value = null;
    status.value = LocationStatus.off;
  }

  /// Opens the app settings where the platform supports it (not on web).
  Future<bool> openAppSettings() async {
    try {
      return await _driver.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Opens the location settings where the platform supports it (not on web).
  Future<bool> openLocationSettings() async {
    try {
      return await _driver.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  void _onPosition(Position position) {
    if (_disposed) return;
    status.value = LocationStatus.tracking;
    fix.value = GpsFix.fromPosition(position);
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    status.dispose();
    fix.dispose();
  }

  /// Walking wants accuracy, not the power-hungry `best`; five metres between
  /// updates keeps the countdown moving without a fix storm.
  ///
  /// Android goes through the platform's own `LocationManager` rather than the
  /// fused provider, so the app keeps working on devices without Google Play
  /// Services and never wakes them up.
  LocationSettings _settingsFor() {
    final settings = this.settings;
    if (settings != null) return settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        forceLocationManager: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }
}
