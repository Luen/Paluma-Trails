import 'package:flutter/material.dart';

import '../content/bundle_repository.dart';
import '../content/models.dart';
import 'format.dart';
import 'map_key.dart';
import 'map_options.dart';
import 'map_palette.dart';
import 'poi_groups.dart';
import 'poi_photo_card.dart';
import 'source_link.dart';

/// Bottom sheets for the map's tappable features: junctions, POIs and tracks.

Future<void> showJunctionSheet(
  BuildContext context, {
  required LoadedBundle bundle,
  required Junction junction,
}) => showMapSheet(context, JunctionSheet(bundle: bundle, junction: junction));

Future<void> showPoiSheet(
  BuildContext context, {
  required LoadedBundle bundle,
  required Poi poi,
}) => showMapSheet(context, PoiSheet(poi: poi));

Future<void> showTrackSheet(
  BuildContext context, {
  required LoadedBundle bundle,
  required TrackSummary track,
}) => showMapSheet(context, TrackSheet(bundle: bundle, track: track));

/// Outdoor display choices (sunlight mode and battery saver), then the map
/// key.
Future<void> showDisplaySettingsSheet(
  BuildContext context, {
  required MapOptions options,
}) => showMapSheet(
  context,
  ListenableBuilder(
    listenable: options,
    builder: (context, _) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        SwitchListTile(
          value: options.sunlight,
          onChanged: (value) => options.sunlight = value,
          secondary: const Icon(Icons.wb_sunny_outlined),
          title: const Text('Sunlight mode'),
          subtitle: const Text(
            'High-contrast colours and heavier map lines for bright days.',
          ),
        ),
        SwitchListTile(
          value: options.batterySaver,
          onChanged: (value) => options.batterySaver = value,
          secondary: const Icon(Icons.battery_saver_outlined),
          title: const Text('Battery saver'),
          subtitle: const Text(
            'Fewer GPS updates and no compass; distances stay approximate.',
          ),
        ),
        const Divider(height: 24),
        _PoiGroupToggles(options: options),
        const Divider(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: MapKey(),
        ),
      ],
    ),
  ),
);

/// Points of interest grouped by what a walker needs: water, lookouts,
/// camping, history and everything else. Hiding a group is a display choice,
/// not a content change.
class _PoiGroupToggles extends StatelessWidget {
  const _PoiGroupToggles({required this.options});

  final MapOptions options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Points of interest',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (!options.allPoiGroupsVisible)
                TextButton(
                  onPressed: options.showAllPoiGroups,
                  child: const Text('Show all'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Hide the markers you do not need today. Everything stays in the '
            'offline map; only the drawing changes.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        for (final group in PoiGroup.values)
          SwitchListTile(
            value: options.isPoiGroupVisible(group),
            onChanged: (value) => options.setPoiGroupVisible(group, value),
            secondary: Icon(group.icon),
            title: Text(group.label),
            subtitle: Text(group.description),
          ),
      ],
    );
  }
}

/// Opens one of the map's bottom sheets: dragging handle, safe area and a cap
/// at 70% of the screen so the map stays visible behind it.
Future<void> showMapSheet(BuildContext context, Widget child) =>
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
            JunctionBadge(number: junction.number),
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
            if (junction.unverified) const UnverifiedChip(),
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
      leading: JunctionBadge(number: other?.number, size: 36),
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
            // The same blue as the POI dot on the map.
            CircleAvatar(
              backgroundColor: MapPalette.color(MapPalette.poi),
              foregroundColor: MapPalette.color(MapPalette.poiStroke),
              child: Icon(_iconForCategory(poi.category)),
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
            if (poi.unverified) const UnverifiedChip(),
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
        for (final photo in poi.photos) ...[
          const SizedBox(height: 16),
          PoiPhotoCard(photo: photo),
        ],
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionTitle('Sources'),
          for (final source in sources)
            SourceLink(label: source.label, url: source.url),
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
            SizedBox(
              width: 40,
              child: Center(
                child: TrackClassSwatch(trackClass: track.trackClass),
              ),
            ),
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
            if (track.unverified) const UnverifiedChip(),
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

/// Marks content that has not been checked on the ground or against official
/// maps. Words, not just a colour, so it survives sunlight and colour vision.
class UnverifiedChip extends StatelessWidget {
  const UnverifiedChip({super.key});

  @override
  Widget build(BuildContext context) => const Tooltip(
    message: 'Not yet checked against the tracks or official maps',
    child: Chip(
      avatar: Icon(Icons.help_outline, size: 18),
      label: Text('Unverified'),
      visualDensity: VisualDensity.compact,
    ),
  );
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
