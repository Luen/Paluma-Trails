import 'package:flutter/material.dart';

import '../content/bundle_repository.dart';
import '../content/models.dart';
import 'format.dart';

/// Bottom sheets for the map's tappable features: junctions, POIs and tracks.

Future<void> showJunctionSheet(
  BuildContext context, {
  required LoadedBundle bundle,
  required Junction junction,
}) => _show(context, JunctionSheet(bundle: bundle, junction: junction));

Future<void> showPoiSheet(
  BuildContext context, {
  required LoadedBundle bundle,
  required Poi poi,
}) => _show(context, PoiSheet(poi: poi));

Future<void> showTrackSheet(
  BuildContext context, {
  required LoadedBundle bundle,
  required TrackSummary track,
}) => _show(context, TrackSheet(bundle: bundle, track: track));

Future<void> _show(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: child,
        ),
      ),
    );

/// One junction: identity, facilities, and where you can walk from here.
class JunctionSheet extends StatelessWidget {
  const JunctionSheet({
    super.key,
    required this.bundle,
    required this.junction,
  });

  final LoadedBundle bundle;
  final Junction junction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = bundle.segmentsAt(junction.id)
      ..sort((a, b) => a.walkMinutes.compareTo(b.walkMinutes));

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: Text('${junction.number}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(junction.label, style: theme.textTheme.titleLarge),
                  Text(
                    'Junction ${junction.number} · ${formatCoordinates(junction.location)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (junction.unverified)
              const Tooltip(
                message: 'Not yet checked against the tracks or official maps',
                child: Chip(
                  label: Text('Unverified'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        if (junction.notes != null) ...[
          const SizedBox(height: 12),
          Text(junction.notes!, style: theme.textTheme.bodyMedium),
        ],
        if (junction.water == true || junction.reception == true) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (junction.water == true)
                const _Fact(icon: Icons.water_drop_outlined, label: 'Water'),
              if (junction.reception == true)
                const _Fact(
                  icon: Icons.signal_cellular_alt,
                  label: 'Reception',
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _SectionTitle(
          segments.isEmpty
              ? 'No mapped tracks connect here yet'
              : 'Tracks from here',
        ),
        for (final segment in segments)
          _SegmentTile(bundle: bundle, junction: junction, segment: segment),
        if (segments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(bundle.estimate.label, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.bundle,
    required this.junction,
    required this.segment,
  });

  final LoadedBundle bundle;
  final Junction junction;
  final Segment segment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final other = bundle.junctions[segment.otherEnd(junction.id)!];
    final track = segment.trackName.isEmpty ? 'Connector' : segment.trackName;
    final details = [
      track,
      formatDistance(segment.distanceM),
      formatDuration(segment.walkMinutes),
      ?formatAscent(segment.ascentFrom(junction.id)),
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        child: Text('${other?.number ?? '?'}'),
      ),
      title: Text(other?.label ?? segment.otherEnd(junction.id)!),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details),
          Text(
            'Out and back ${formatDuration(segment.walkMinutes * 2)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      trailing: Text(
        formatBearing(segment.bearingFrom(junction.id)),
        style: theme.textTheme.titleSmall,
      ),
    );
  }
}

/// One point of interest: what it is, why it is worth the walk, and where the
/// record came from.
class PoiSheet extends StatelessWidget {
  const PoiSheet({super.key, required this.poi});

  final Poi poi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = poi.sources;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Row(
          children: [
            Icon(
              _iconForCategory(poi.category),
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(poi.name, style: theme.textTheme.titleLarge),
                  Text(
                    '${formatPoiCategory(poi.category)} · '
                    '${formatCoordinates(poi.location)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (poi.unverified)
              const Tooltip(
                message: 'Not yet checked against the tracks or official maps',
                child: Chip(
                  label: Text('Unverified'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        if (poi.summary != null) ...[
          const SizedBox(height: 16),
          Text(poi.summary!, style: theme.textTheme.titleMedium),
        ],
        if (poi.description != null) ...[
          const SizedBox(height: 8),
          Text(poi.description!, style: theme.textTheme.bodyMedium),
        ],
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionTitle('Sources'),
          for (final source in sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                source.url == null
                    ? source.label
                    : '${source.label} — ${source.url}',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }

  static IconData _iconForCategory(String category) => switch (category) {
    'waterfall' => Icons.water_drop,
    'lookout' => Icons.visibility_outlined,
    'swimming' => Icons.pool,
    'water' => Icons.opacity,
    'campsite' => Icons.nights_stay_outlined,
    'hut' => Icons.cabin_outlined,
    'mine' => Icons.terrain_outlined,
    'history' => Icons.history_edu_outlined,
    'art' => Icons.palette_outlined,
    'junction' => Icons.signpost_outlined,
    _ => Icons.place_outlined,
  };
}

/// One track polyline, summarised from the junction graph.
class TrackSheet extends StatelessWidget {
  const TrackSheet({super.key, required this.bundle, required this.track});

  final LoadedBundle bundle;
  final TrackSummary track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = bundle.segments
        .where((s) => s.trackId == track.id)
        .toList(growable: false);
    final walkMinutes = segments.fold<int>(0, (sum, s) => sum + s.walkMinutes);
    final junctions = <String>{
      for (final segment in segments) ...{segment.from, segment.to},
    };

    final facts = <String>[
      formatTrackClass(track.trackClass),
      formatDistance(track.lengthM),
      if (segments.isNotEmpty) formatDuration(walkMinutes),
      if (junctions.isNotEmpty) '${junctions.length} junctions',
    ];

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Row(
          children: [
            Icon(Icons.route_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.label, style: theme.textTheme.titleLarge),
                  Text(facts.join(' · '), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (track.unverified)
              const Tooltip(
                message: 'Not yet checked against the tracks or official maps',
                child: Chip(
                  label: Text('Unverified'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        if (segments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(bundle.estimate.label, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    visualDensity: VisualDensity.compact,
  );
}

/// `-18.941853, 146.188682` → `18.9419° S, 146.1887° E`.
String formatCoordinates(GeoPoint point) {
  final lat = point.lat.abs().toStringAsFixed(4);
  final lon = point.lon.abs().toStringAsFixed(4);
  return '$lat° ${point.lat >= 0 ? 'N' : 'S'}, $lon° ${point.lon >= 0 ? 'E' : 'W'}';
}
