/// The one place the app asks for location and explains a refusal.
///
/// The map and the safety screen both need coordinates, and both need to say
/// the same plain thing when the platform will not provide them.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'location_service.dart';

/// Starts [location] when needed, prompting and explaining as required.
///
/// Returns true when the stream is starting or already delivering fixes. A
/// refusal is reported with an action that retries or opens the right settings,
/// so the walker is never left guessing why the button did nothing.
Future<bool> startLocationWithPrompts(
  BuildContext context,
  LocationService location,
) async {
  if (location.isTracking) return true;

  final status = await location.start();
  if (!context.mounted) return false;

  switch (status) {
    case LocationStatus.starting:
    case LocationStatus.tracking:
      return true;
    case LocationStatus.servicesDisabled:
      _notify(
        context,
        'Location services are off — turn them on to see your position.',
        actionLabel: 'Settings',
        onAction: location.openLocationSettings,
      );
    case LocationStatus.permissionDenied:
      _notify(
        context,
        'Location permission is needed to show where you are.',
        actionLabel: 'Ask again',
        onAction: () => startLocationWithPrompts(context, location),
      );
    case LocationStatus.permissionDeniedForever:
      if (kIsWeb) {
        _notify(
          context,
          'Location permission was denied — allow it in the browser site '
          'settings.',
        );
      } else {
        _notify(
          context,
          'Location permission was denied — grant it in the app settings.',
          actionLabel: 'Settings',
          onAction: location.openAppSettings,
        );
      }
    case LocationStatus.failed:
      _notify(
        context,
        'The device did not report a position — tap again to retry.',
      );
    case LocationStatus.off:
      break;
  }
  return false;
}

void _notify(
  BuildContext context,
  String message, {
  String? actionLabel,
  FutureOr<void> Function()? onAction,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: () => onAction()),
    ),
  );
}
