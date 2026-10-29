import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'content/bundle_repository.dart';
import 'location/emergency_planner.dart';
import 'location/location_prompts.dart';
import 'location/location_service.dart';
import 'map/source_link.dart';
import 'map/format.dart';

/// What to do when something goes wrong, and where the walker is right now.
///
/// Everything except the phone call itself comes from the offline bundle, so
/// the page works in a gully with no signal. Coordinates are shown to five
/// decimals (about a metre) because that is what a search team asks for.
class SafetyScreen extends StatefulWidget {
  const SafetyScreen({
    super.key,
    required this.bundle,
    required this.location,
    this.launch = launchUrl,
  });

  final LoadedBundle bundle;

  /// The map's location service, so opening this page does not start a second
  /// GPS stream.
  final LocationService location;

  /// Injected in tests; the app uses [launchUrl] to open the dialler.
  final Future<bool> Function(Uri url) launch;

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  late final EmergencyPlanner _planner;

  @override
  void initState() {
    super.initState();
    _planner = EmergencyPlanner.fromGeoJson(
      tracksGeoJson: widget.bundle.tracksGeoJson,
      origin: widget.bundle.park.center,
      junctions: widget.bundle.junctions,
    );
    widget.location.status.addListener(_onLocationChanged);
    widget.location.fix.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    widget.location.status.removeListener(_onLocationChanged);
    widget.location.fix.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safety = widget.bundle.safety;

    return Scaffold(
      appBar: AppBar(title: const Text('Safety & emergency')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _EmergencyCard(bundle: widget.bundle, launch: widget.launch),
          const SizedBox(height: 16),
          _positionCard(context),
          if (safety.intro.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(safety.intro, style: theme.textTheme.bodyLarge),
          ],
          for (final section in safety.sections) ...[
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final item in section.items) _Bullet(item),
          ],
          const SizedBox(height: 24),
          Text(
            safety.updated.isEmpty
                ? 'This page works offline.'
                : 'This page works offline. Safety guidance updated '
                      '${safety.updated}.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Check the Queensland Parks and Wildlife Service park alerts for '
            'closures and current conditions before you set out.',
            style: theme.textTheme.bodySmall,
          ),
          if (safety.sources.isNotEmpty) ...[
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                'Emergency contact sources',
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final source in safety.sources)
              SourceLink(label: source.label, url: source.url),
          ],
        ],
      ),
    );
  }

  Widget _positionCard(BuildContext context) {
    final status = widget.location.status.value;
    final fix = widget.location.fix.value;

    if (status == LocationStatus.tracking && fix != null) {
      return _FixCard(fix: fix, plan: _planner.planFor(fix.position));
    }

    final (message, actionLabel, action) = _promptFor(status);
    return _PromptCard(
      message: message,
      busy:
          status == LocationStatus.starting ||
          (status == LocationStatus.tracking && fix == null),
      actionLabel: actionLabel,
      action: action,
    );
  }

  /// The sentence and the one action that gets location working.
  (String, String?, Future<void> Function()?) _promptFor(
    LocationStatus status,
  ) {
    switch (status) {
      case LocationStatus.off:
        return (
          'Location is off. Turn it on to show your coordinates, the nearest '
              'junction and the nearest mapped road.',
          'Use my location',
          () => startLocationWithPrompts(context, widget.location),
        );
      case LocationStatus.starting:
      case LocationStatus.tracking:
        return ('Waiting for the first GPS fix…', null, null);
      case LocationStatus.failed:
        return (
          'The device did not report a position. Try again.',
          'Try again',
          () => startLocationWithPrompts(context, widget.location),
        );
      case LocationStatus.servicesDisabled:
        return (
          'Location services are off on this device.',
          'Open location settings',
          widget.location.openLocationSettings,
        );
      case LocationStatus.permissionDenied:
        return (
          'Location permission is needed to show where you are.',
          'Allow location',
          () => startLocationWithPrompts(context, widget.location),
        );
      case LocationStatus.permissionDeniedForever:
        if (kIsWeb) {
          return (
            'Location permission was denied. Allow it in your browser site '
                'settings, then try again.',
            'Try again',
            () => startLocationWithPrompts(context, widget.location),
          );
        }
        return (
          'Location permission was denied. Grant it in the app settings.',
          'Open app settings',
          widget.location.openAppSettings,
        );
    }
  }
}

/// The phone call, the numbers and the four steps that matter.
class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.bundle, required this.launch});

  final LoadedBundle bundle;
  final Future<bool> Function(Uri url) launch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final park = bundle.park;
    final safety = bundle.safety;
    final headline = safety.emergencyHeadline.isEmpty
        ? 'In an emergency, call ${park.emergencyPhone}.'
        : safety.emergencyHeadline;

    return Card(
      color: scheme.errorContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.emergency_outlined,
                  color: scheme.onErrorContainer,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (park.emergencyNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                park.emergencyNotes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => _call(context, park.emergencyPhone),
                  icon: const Icon(Icons.call),
                  label: Text('Call ${park.emergencyPhone}'),
                ),
                if (park.emergencyAlternativePhone.isNotEmpty &&
                    park.emergencyAlternativePhone != park.emergencyPhone)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onErrorContainer,
                      side: BorderSide(color: scheme.onErrorContainer),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () =>
                        _call(context, park.emergencyAlternativePhone),
                    icon: const Icon(Icons.phone_in_talk_outlined),
                    label: Text('Call ${park.emergencyAlternativePhone}'),
                  ),
              ],
            ),
            if (safety.emergencySteps.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final step in safety.emergencySteps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $step',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context, String number) async {
    var opened = false;
    try {
      opened = await launch(Uri(scheme: 'tel', path: number));
    } catch (_) {
      opened = false;
    }
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open the dialler. Call $number.')),
    );
  }
}

/// Coordinates and the nearest way out, once there is a fix.
class _FixCard extends StatelessWidget {
  const _FixCard({required this.fix, required this.plan});

  final GpsFix fix;
  final EmergencyPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accuracy = fix.accuracyM > 0 ? '±${fix.accuracyM.round()} m' : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your position',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (accuracy != null)
                  Chip(
                    label: Text(accuracy),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              formatCoordinates(fix.position, decimals: 5),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Updated ${_clock(fix.timestamp)} · tap and hold to select',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => _copyCoordinates(context),
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copy coordinates'),
            ),
            const Divider(height: 24),
            _NearbyRow(
              icon: Icons.signpost_outlined,
              label: 'Nearest junction',
              value: plan.nearestJunction == null
                  ? 'No junctions in this bundle'
                  : '${plan.nearestJunction!.junction.label} · '
                        '${formatDistance(plan.nearestJunction!.distanceM)} '
                        '${formatBearing(plan.nearestJunction!.bearingDeg)}',
            ),
            const SizedBox(height: 12),
            _NearbyRow(
              icon: Icons.route_outlined,
              label: 'Nearest mapped road',
              value: plan.nearestRoad == null
                  ? 'No road is mapped in this bundle'
                  : '${plan.nearestRoad!.label} · '
                        '${formatDistance(plan.nearestRoad!.distanceM)} '
                        '${formatBearing(plan.nearestRoad!.bearingDeg)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Distances are straight line, not walking distance. Follow the '
              'track to a junction or road you know.',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Text(
              'Recorded reception',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            if (plan.receptionPoints.isEmpty)
              Text(
                'No reception points have been verified for this park yet. '
                'Assume there is no mobile signal.',
                style: theme.textTheme.bodyMedium,
              )
            else
              for (final point in plan.receptionPoints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${point.junction.label} · '
                    '${formatDistance(point.distanceM)} '
                    '${formatBearing(point.bearingDeg)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCoordinates(BuildContext context) async {
    final position = fix.position;
    final text =
        '${position.lat.toStringAsFixed(5)}, '
        '${position.lon.toStringAsFixed(5)}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Coordinates copied: $text')));
  }

  static String _clock(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              Text(value, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

/// The state before a fix: what is wrong and the one button that helps.
class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.message,
    required this.busy,
    required this.actionLabel,
    required this.action,
  });

  final String message;
  final bool busy;
  final String? actionLabel;
  final Future<void> Function()? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your position', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: Text(message, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            if (actionLabel != null && action != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: action,
                icon: const Icon(Icons.my_location),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 10),
            child: Icon(
              Icons.circle,
              size: 6,
              color: theme.colorScheme.primary,
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
