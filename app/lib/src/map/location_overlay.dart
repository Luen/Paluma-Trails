import 'package:flutter/material.dart';

import '../content/models.dart';
import '../location/location_service.dart';
import '../location/trail_locator.dart';
import 'format.dart';

/// A round map control sized for gloved, one-handed use (48 px minimum).
class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.highlighted = false,
    this.foregroundColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool highlighted;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onPressed == null;
    final background = disabled
        ? theme.colorScheme.surface.withValues(alpha: 0.6)
        : highlighted
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surface;
    final foreground = disabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
        : foregroundColor ??
              (highlighted
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        elevation: disabled ? 0 : 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, size: 26, color: foreground),
          ),
        ),
      ),
    );
  }
}

/// The floating "where am I" button.
///
/// Off means nothing has been asked for yet; a tap starts location. Once
/// tracking, a tap toggles whether the camera follows the walker.
class LocateButton extends StatelessWidget {
  const LocateButton({
    super.key,
    required this.status,
    required this.following,
    required this.onPressed,
  });

  final LocationStatus status;
  final bool following;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tracking =
        status == LocationStatus.starting || status == LocationStatus.tracking;

    final (icon, tooltip) = switch (status) {
      LocationStatus.off => (Icons.location_searching, 'Show my location'),
      LocationStatus.starting => (
        Icons.location_searching,
        'Finding your location…',
      ),
      LocationStatus.tracking => (
        Icons.my_location,
        following ? 'Stop following me' : 'Follow me',
      ),
      LocationStatus.failed => (
        Icons.location_disabled,
        'Location failed — tap to retry',
      ),
      LocationStatus.servicesDisabled => (
        Icons.location_disabled,
        'Location services are off — tap to fix',
      ),
      LocationStatus.permissionDenied => (
        Icons.location_disabled,
        'Location permission needed — tap to fix',
      ),
      LocationStatus.permissionDeniedForever => (
        Icons.location_disabled,
        'Grant location permission in the app settings',
      ),
    };

    return MapControlButton(
      icon: icon,
      tooltip: tooltip,
      highlighted: tracking && following,
      onPressed: onPressed,
    );
  }
}

/// A compact readout of where the walker is and how far the next junction is.
///
/// Tapping it opens the junction's sheet; the card is only interactive when
/// there is a junction to open.
class LocationCard extends StatelessWidget {
  const LocationCard({
    super.key,
    required this.status,
    required this.fix,
    required this.trail,
    this.onJunctionTap,
  });

  final LocationStatus status;
  final GpsFix? fix;
  final TrailFix? trail;
  final void Function(Junction junction)? onJunctionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, detail, junction) = _content();
    final accuracy =
        status != LocationStatus.tracking || fix == null || fix!.accuracyM <= 0
        ? null
        : '±${fix!.accuracyM.round()} m';

    final onTap = junction == null ? null : () => onJunctionTap?.call(junction);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (accuracy != null) ...[
                    const SizedBox(width: 8),
                    Text(accuracy, style: theme.textTheme.labelMedium),
                  ],
                ],
              ),
              if (detail != null)
                Text(detail, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  /// Title, optional second line and the junction the card would open.
  (String, String?, Junction?) _content() {
    switch (status) {
      case LocationStatus.starting:
        return ('Finding your location…', null, null);
      case LocationStatus.tracking:
        break;
      case LocationStatus.failed:
        return ('Location stopped', null, null);
      default:
        return ('Location off', null, null);
    }

    final trail = this.trail;
    if (trail == null) return ('Off the mapped tracks', null, null);

    final trackName = trail.track.name;
    final title = trackName == null ? 'On an unnamed track' : 'On $trackName';
    final next = trail.next;
    if (next == null) return (title, null, null);

    final lead = !next.directionKnown
        ? 'Nearest'
        : (next.ahead ? 'Next' : 'Behind you');
    return (
      title,
      '$lead: ${next.junction.label} · ${formatDistance(next.distanceM)} · '
          '~${formatDuration(next.walkMinutes)}',
      next.junction,
    );
  }
}
