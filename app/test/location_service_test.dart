import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:paluma_trails/src/location/location_service.dart';

/// A location engine driven by the test instead of a device.
class _FakeDriver implements LocationDriver {
  _FakeDriver({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestResult,
    this.settingsThrow = false,
  });

  bool serviceEnabled;
  LocationPermission permission;
  LocationPermission? requestResult;

  int permissionRequests = 0;
  bool appSettingsOpened = false;
  bool locationSettingsOpened = false;
  bool settingsThrow = false;
  LocationSettings? lastSettings;

  final StreamController<Position> positionsController =
      StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    permission = requestResult ?? permission;
    return permission;
  }

  @override
  Stream<Position> positions({LocationSettings? settings}) {
    lastSettings = settings;
    return positionsController.stream;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened = true;
    if (settingsThrow) throw UnsupportedError('openAppSettings');
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened = true;
    if (settingsThrow) throw UnsupportedError('openLocationSettings');
    return true;
  }
}

Position _position({
  double latitude = -18.95,
  double longitude = 146.15,
  double? accuracy = 8,
  double? heading,
  double? speed,
  double? altitude,
}) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime(2026, 10, 20),
  accuracy: accuracy ?? 0,
  altitude: altitude ?? 0,
  altitudeAccuracy: 0,
  heading: heading ?? 0,
  headingAccuracy: 0,
  speed: speed ?? 0,
  speedAccuracy: 0,
  hasAccuracy: accuracy != null,
  hasHeading: heading != null,
  hasSpeed: speed != null,
  hasAltitude: altitude != null,
);

void main() {
  test('reports switched-off services without asking for permission', () async {
    final driver = _FakeDriver(serviceEnabled: false);
    final service = LocationService(driver: driver);

    expect(await service.start(), LocationStatus.servicesDisabled);
    expect(driver.permissionRequests, 0);
    expect(service.isTracking, isFalse);
  });

  test('asks once after a first refusal, then reports denied', () async {
    final driver = _FakeDriver(
      permission: LocationPermission.denied,
      requestResult: LocationPermission.denied,
    );
    final service = LocationService(driver: driver);

    expect(await service.start(), LocationStatus.permissionDenied);
    expect(driver.permissionRequests, 1);
    expect(service.isTracking, isFalse);
  });

  test('does not re-ask when permission is permanently denied', () async {
    final driver = _FakeDriver(permission: LocationPermission.deniedForever);
    final service = LocationService(driver: driver);

    expect(await service.start(), LocationStatus.permissionDeniedForever);
    expect(driver.permissionRequests, 0);
  });

  test('waits for the first fix, then reports tracking', () async {
    final driver = _FakeDriver();
    final service = LocationService(driver: driver);

    expect(await service.start(), LocationStatus.starting);
    expect(service.fix.value, isNull);

    driver.positionsController.add(
      _position(accuracy: 7, heading: 95, speed: 1.3, altitude: 812),
    );
    await pumpEventQueue();

    expect(service.status.value, LocationStatus.tracking);
    final fix = service.fix.value!;
    expect(fix.position.lat, closeTo(-18.95, 1e-9));
    expect(fix.position.lon, closeTo(146.15, 1e-9));
    expect(fix.accuracyM, 7);
    expect(fix.bearingDeg, 95);
    expect(fix.speedMps, 1.3);
    expect(fix.altitudeM, 812);
  });

  test('leaves heading and speed unknown when the fix does not know', () async {
    final driver = _FakeDriver();
    final service = LocationService(driver: driver);

    await service.start();
    driver.positionsController.add(_position(accuracy: null));
    await pumpEventQueue();

    final fix = service.fix.value!;
    expect(fix.bearingDeg, isNull);
    expect(fix.speedMps, isNull);
    expect(fix.accuracyM, 0);
    expect(fix.altitudeM, isNull);
  });

  test('reports a failure from the location stream', () async {
    final driver = _FakeDriver();
    final service = LocationService(driver: driver);

    await service.start();
    driver.positionsController.add(_position());
    await pumpEventQueue();
    expect(service.fix.value, isNotNull);

    driver.positionsController.addError(StateError('gps lost'));
    await pumpEventQueue();

    expect(service.status.value, LocationStatus.failed);
    expect(service.isTracking, isFalse);
    expect(service.fix.value, isNull);
  });

  test('starts a fresh stream after a failure', () async {
    final driver = _FakeDriver();
    final service = LocationService(driver: driver);

    await service.start();
    driver.positionsController.addError(StateError('gps lost'));
    await pumpEventQueue();

    expect(await service.start(), LocationStatus.starting);
    expect(driver.positionsController.hasListener, isTrue);

    driver.positionsController.add(_position());
    await pumpEventQueue();

    expect(service.status.value, LocationStatus.tracking);
  });

  test('starting while tracking does not ask or subscribe again', () async {
    final driver = _FakeDriver(
      permission: LocationPermission.denied,
      requestResult: LocationPermission.whileInUse,
    );
    final service = LocationService(driver: driver);

    expect(await service.start(), LocationStatus.starting);
    await service.start();

    expect(driver.permissionRequests, 1);
    expect(driver.positionsController.hasListener, isTrue);
  });

  test('stop clears the fix and returns to off', () async {
    final driver = _FakeDriver();
    final service = LocationService(driver: driver);

    await service.start();
    driver.positionsController.add(_position(heading: 90, speed: 1.2));
    await pumpEventQueue();
    await service.stop();

    expect(service.status.value, LocationStatus.off);
    expect(service.fix.value, isNull);
    expect(service.isTracking, isFalse);
  });

  test(
    'battery saver restarts with a coarser fix and no loss of tracking',
    () async {
      final driver = _FakeDriver();
      final service = LocationService(driver: driver);

      await service.start();
      expect(driver.lastSettings?.accuracy, LocationAccuracy.high);
      expect(driver.lastSettings?.distanceFilter, 5);

      service.batterySaver = true;
      await pumpEventQueue();

      expect(driver.lastSettings?.accuracy, LocationAccuracy.medium);
      expect(driver.lastSettings?.distanceFilter, 20);
      expect(service.isTracking, isTrue);
      expect(driver.positionsController.hasListener, isTrue);
    },
  );

  test('settings requests reach the driver', () async {
    final driver = _FakeDriver();
    final service = LocationService(driver: driver);

    await service.openAppSettings();
    await service.openLocationSettings();

    expect(driver.appSettingsOpened, isTrue);
    expect(driver.locationSettingsOpened, isTrue);
  });

  test('settings requests stay quiet where the platform has none', () async {
    final driver = _FakeDriver(settingsThrow: true);
    final service = LocationService(driver: driver);

    expect(await service.openAppSettings(), isFalse);
    expect(await service.openLocationSettings(), isFalse);
  });
}
