import 'dart:async';

import 'package:flutter/material.dart';

import '../content/bundle_repository.dart';
import '../content/models.dart';
import '../planning/trail_route.dart';
import 'format.dart';
import 'map_key.dart';
import 'sheets.dart';

/// Opens the route planner: pick junctions, see the distance and estimated
/// time, and walk the itinerary junction by junction.
Future<void> showRoutePlanSheet(
  BuildContext context, {
  required LoadedBundle bundle,
  String? initialFromId,
  required Future<void> Function(Junction junction) onFocus,
}) => showMapSheet(
  context,
  RoutePlanSheet(
    bundle: bundle,
    initialFromId: initialFromId,
    onFocus: onFocus,
  ),
);

/// The planner itself. Everything it shows comes from the offline bundle; it
/// neither asks the network nor guesses a connection the content does not have.
class RoutePlanSheet extends StatefulWidget {
  const RoutePlanSheet({
    super.key,
    required this.bundle,
    this.initialFromId,
    required this.onFocus,
  });

  final LoadedBundle bundle;

  /// The junction the walker is heading to, when tracking has a fix.
  final String? initialFromId;
  final Future<void> Function(Junction junction) onFocus;

  @override
  State<RoutePlanSheet> createState() => _RoutePlanSheetState();
}

class _RoutePlanSheetState extends State<RoutePlanSheet> {
  WalkShape _shape = WalkShape.oneWay;
  String? _fromId;
  String? _toId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFromId;
    if (initial != null && widget.bundle.junctions.containsKey(initial)) {
      _fromId = initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final junctions = widget.bundle.junctions.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final route = _plan();

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text('Plan a walk', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Adds up the mapped junction distances so you can judge a walk '
          'before you set out. Works offline.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SegmentedButton<WalkShape>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, 48)),
          ),
          segments: const [
            ButtonSegment(value: WalkShape.oneWay, label: Text('One way')),
            ButtonSegment(
              value: WalkShape.outAndBack,
              label: Text('Out and back'),
            ),
            ButtonSegment(value: WalkShape.loop, label: Text('Loop')),
          ],
          selected: {_shape},
          onSelectionChanged: (selection) =>
              setState(() => _shape = selection.single),
        ),
        const SizedBox(height: 16),
        _JunctionField(
          label: _shape == WalkShape.loop ? 'Start and finish' : 'From',
          value: _fromId,
          junctions: junctions,
          onChanged: (value) => setState(() => _fromId = value),
        ),
        if (_shape != WalkShape.loop) ...[
          const SizedBox(height: 12),
          _JunctionField(
            label: 'To',
            value: _toId,
            junctions: junctions,
            onChanged: (value) => setState(() => _toId = value),
          ),
        ],
        const SizedBox(height: 16),
        if (route == null)
          _RoutePlaceholder(shape: _shape, ready: _ready)
        else
          _RouteSummary(bundle: widget.bundle, route: route, onFocus: _focus),
      ],
    );
  }

  /// Whether the walker has picked enough junctions for a route to exist.
  bool get _ready => _shape == WalkShape.loop
      ? _fromId != null
      : _fromId != null && _toId != null;

  TrailRoute? _plan() {
    final from = _fromId;
    if (from == null) return null;
    if (_shape == WalkShape.loop) {
      return planWalk(
        widget.bundle,
        fromId: from,
        toId: from,
        shape: WalkShape.loop,
      );
    }
    final to = _toId;
    if (to == null) return null;
    return planWalk(widget.bundle, fromId: from, toId: to, shape: _shape);
  }

  void _focus(Junction junction) {
    Navigator.of(context).pop();
    unawaited(widget.onFocus(junction));
  }
}

String _junctionOptionLabel(Junction junction) =>
    junction.name == null || junction.name!.isEmpty
    ? 'Junction ${junction.number}'
    : '${junction.number} · ${junction.name}';

class _JunctionField extends StatelessWidget {
  const _JunctionField({
    required this.label,
    required this.value,
    required this.junctions,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<Junction> junctions;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      hint: const Text('Choose a junction'),
      items: [
        for (final junction in junctions)
          DropdownMenuItem(
            value: junction.id,
            child: Text(
              _junctionOptionLabel(junction),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _RoutePlaceholder extends StatelessWidget {
  const _RoutePlaceholder({required this.shape, required this.ready});

  final WalkShape shape;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, detail) = switch ((ready, shape)) {
      (false, WalkShape.loop) => (
        'Pick a start',
        'Choose the junction you want to leave from and come back to.',
      ),
      (false, _) => (
        'Pick two junctions',
        'Choose where you start and where you want to finish.',
      ),
      (true, WalkShape.loop) => (
        'No mapped loop from here',
        'The park data has no other way back to this junction yet.',
      ),
      (true, _) => (
        'No mapped route between these junctions',
        'The park data has no connected tracks in that direction yet.',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(detail, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.bundle,
    required this.route,
    required this.onFocus,
  });

  final LoadedBundle bundle;
  final TrailRoute route;
  final void Function(Junction junction) onFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = bundle.junctions[route.startId];
    final end = bundle.junctions[route.endId];

    final shapeNote = switch (route.shape) {
      WalkShape.loop => 'Loop from ${start?.label ?? 'the start'} and back',
      WalkShape.outAndBack =>
        '${start?.label ?? 'Start'} to ${end?.label ?? 'the end'}, there and '
            'back',
      WalkShape.oneWay =>
        '${start?.label ?? 'Start'} to ${end?.label ?? 'the end'}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shapeNote, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                formatDistance(route.distanceM),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '~${formatDuration(route.walkMinutes)} walking',
                style: theme.textTheme.titleMedium,
              ),
              if (route.returnsSameWay) ...[
                const SizedBox(height: 4),
                Text(
                  '${formatDistance(route.oneWayDistanceM)} each way',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Junctions in order', style: theme.textTheme.titleSmall),
        for (final leg in route.legs)
          _LegTile(
            leg: leg,
            junction: bundle.junctions[leg.to],
            onTap: () {
              final junction = bundle.junctions[leg.to];
              if (junction != null) onFocus(junction);
            },
          ),
        if (route.returnsSameWay)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: JunctionBadge(number: start?.number, size: 36),
            title: const Text('Back to the start'),
            subtitle: Text(
              'The same way · ${formatDistance(route.oneWayDistanceM)} · '
              '~${formatDuration(route.oneWayWalkMinutes)}',
            ),
          ),
        const SizedBox(height: 8),
        Text(bundle.estimate.label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          'Totals follow the mapped tracks only. A closed or flooded track is '
          'not known to the app — check park alerts before you go.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _LegTile extends StatelessWidget {
  const _LegTile({required this.leg, required this.junction, this.onTap});

  final RouteLeg leg;
  final Junction? junction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      'via ${leg.trackName}',
      formatDistance(leg.distanceM),
      '~${formatDuration(leg.walkMinutes)}',
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: JunctionBadge(number: junction?.number, size: 36),
      title: Text(junction?.label ?? leg.to),
      subtitle: Text(details, style: theme.textTheme.bodySmall),
      trailing: const Icon(Icons.center_focus_strong_outlined),
      onTap: onTap,
    );
  }
}
