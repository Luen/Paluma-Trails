import 'package:flutter/material.dart';

import '../content/bundle_repository.dart';
import '../location/trail_locator.dart';
import '../location/walk_simulation.dart';

/// Choose recorded geometry without starting GPS or claiming a navigable route.
class WalkPreviewPicker extends StatefulWidget {
  const WalkPreviewPicker({super.key, required this.bundle});
  final LoadedBundle bundle;

  @override
  State<WalkPreviewPicker> createState() => _WalkPreviewPickerState();
}

class _WalkPreviewPickerState extends State<WalkPreviewPicker> {
  late final _tracks =
      trackPolylinesFromGeoJson(widget.bundle.tracksGeoJson)
          .where(WalkSimulation.isUsable)
          .toList()
        ..sort((a, b) => (a.name ?? a.id).compareTo(b.name ?? b.id));
  TrackPolyline? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preview a walk', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'See the map and junction countdown along bundled track geometry. Positions are simulated; GPS stays off. This is not evidence of current access or track conditions.',
            ),
            const SizedBox(height: 8),
            const Text(
              'If live tracking is running, it pauses during the preview and resumes when you leave. The existing walked total is retained; movement during the pause is not counted.',
            ),
            const SizedBox(height: 16),
            if (_tracks.isEmpty)
              const Text('No track geometry is available for a preview.')
            else
              DropdownButtonFormField<TrackPolyline>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Track'),
                items: [
                  for (final track in _tracks)
                    DropdownMenuItem(
                      value: track,
                      child: Text(
                        '${track.name ?? track.id} · ${track.id}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (track) => setState(() => _selected = track),
              ),
            const SizedBox(height: 16),
            const Text(
              'Preview waypoints are unavailable. No simulated coordinates can be sent to the emergency screen.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, _selected),
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('Start simulated walk'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Persistent, explicit simulation controls above the normal map interface.
class WalkPreviewControls extends StatelessWidget {
  const WalkPreviewControls({
    super.key,
    required this.simulation,
    required this.onRestart,
  });
  final WalkSimulation simulation;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: simulation,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Simulated position · GPS off',
                style: theme.textTheme.titleSmall,
              ),
              Text(simulation.track.name ?? simulation.track.id),
              Text(
                simulation.complete
                    ? 'Preview complete'
                    : simulation.paused
                    ? 'Paused'
                    : 'Preview playing',
              ),
              const SizedBox(height: 8),
              Semantics(
                container: true,
                child: LinearProgressIndicator(
                  value: simulation.progress,
                  semanticsLabel: 'Simulated track progress',
                ),
              ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: simulation.complete
                        ? null
                        : simulation.togglePause,
                    icon: Icon(
                      simulation.paused
                          ? Icons.play_arrow_outlined
                          : Icons.pause,
                    ),
                    label: Text(simulation.paused ? 'Resume' : 'Pause'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: onRestart,
                    icon: const Icon(Icons.replay),
                    label: const Text('Restart'),
                  ),
                  const Text('Speed:'),
                  Semantics(
                    container: true,
                    label: 'Simulated preview speed',
                    child: DropdownButton<int>(
                      value: simulation.speed,
                      itemHeight: 48,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final speed in [20, 40, 80])
                          DropdownMenuItem(
                            value: speed,
                            child: Text('$speed×'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) simulation.speed = value;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
