import 'dart:async';

import 'package:flutter/material.dart';

import '../content/models.dart';
import '../waypoints/waypoint.dart';
import '../waypoints/waypoint_store.dart';
import 'format.dart';
import 'sheets.dart';

/// The list of the walker's own pins: add one at the map centre, or open an
/// existing one.
Future<void> showWaypointsSheet(
  BuildContext context, {
  required WaypointStore store,
  required GeoPoint mapCentre,
  required Future<void> Function(Waypoint waypoint) onFocus,
}) => showMapSheet(
  context,
  WaypointsSheet(store: store, mapCentre: mapCentre, onFocus: onFocus),
);

/// One saved pin: where it is, and what can be done with it.
Future<void> showWaypointSheet(
  BuildContext context, {
  required WaypointStore store,
  required Waypoint waypoint,
  required Future<void> Function(Waypoint waypoint) onFocus,
}) => showMapSheet(
  context,
  WaypointSheet(store: store, waypoint: waypoint, onFocus: onFocus),
);

class WaypointsSheet extends StatefulWidget {
  const WaypointsSheet({
    super.key,
    required this.store,
    required this.mapCentre,
    required this.onFocus,
  });

  final WaypointStore store;

  /// Where "Save a waypoint here" puts the pin: wherever the walker is looking.
  final GeoPoint mapCentre;
  final Future<void> Function(Waypoint waypoint) onFocus;

  @override
  State<WaypointsSheet> createState() => _WaypointsSheetState();
}

class _WaypointsSheetState extends State<WaypointsSheet> {
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final waypoints = widget.store.waypoints.reversed.toList(
          growable: false,
        );
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('Your waypoints', style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Text(
                'Saved on this device and available offline. They are private '
                'to you and never added to the park map for anyone else.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _add(context),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Save a waypoint here'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatCoordinates(widget.mapCentre),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            if (waypoints.isEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Nothing saved yet. Pan the map to the spot you want, then '
                  'tap the button above.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            for (final waypoint in waypoints)
              _WaypointTile(
                name: waypoint.name,
                location: waypoint.location,
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(widget.onFocus(waypoint));
                },
                trailing: IconButton(
                  tooltip: 'Delete ${waypoint.name}',
                  onPressed: () => _delete(context, waypoint),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _add(BuildContext context) async {
    setState(() => _saving = true);
    try {
      final waypoint = await widget.store.add(location: widget.mapCentre);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved ${waypoint.name}')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The waypoint could not be saved on this device.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(BuildContext context, Waypoint waypoint) async {
    final removed = await confirmDeleteWaypoint(context, waypoint);
    if (!removed) return;
    try {
      await widget.store.remove(waypoint.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The waypoint could not be deleted.')),
      );
    }
  }
}

/// One pin on its own: coordinates, and a way to centre the map, rename or
/// delete it.
class WaypointSheet extends StatelessWidget {
  const WaypointSheet({
    super.key,
    required this.store,
    required this.waypoint,
    required this.onFocus,
  });

  final WaypointStore store;
  final Waypoint waypoint;
  final Future<void> Function(Waypoint waypoint) onFocus;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final current = store.byId(waypoint.id);
        if (current == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Icon(Icons.push_pin, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.name,
                          style: theme.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          formatCoordinates(current.location),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.center_focus_strong_outlined),
              title: const Text('Show on the map'),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(onFocus(current));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => renameWaypoint(context, store, current),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () async {
                final removed = await confirmDeleteWaypoint(context, current);
                if (!removed || !context.mounted) return;
                try {
                  await store.remove(current.id);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('The waypoint could not be deleted.'),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _WaypointTile extends StatelessWidget {
  const _WaypointTile({
    required this.name,
    required this.location,
    required this.onTap,
    this.trailing,
  });

  final String name;
  final GeoPoint location;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      leading: const Icon(Icons.push_pin_outlined),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatCoordinates(location)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Asks before deleting: a pin may be the only record of a spot the walker
/// found, and there is no undo.
Future<bool> confirmDeleteWaypoint(
  BuildContext context,
  Waypoint waypoint,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this waypoint?'),
      content: Text(
        '"${waypoint.name}" is only on this device, and deleting it cannot be '
        'undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep it'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Renames a saved pin, refusing a blank name.
Future<void> renameWaypoint(
  BuildContext context,
  WaypointStore store,
  Waypoint waypoint,
) async {
  final controller = TextEditingController(text: waypoint.name);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename waypoint'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  final trimmed = name?.trim() ?? '';
  controller.dispose();
  if (trimmed.isEmpty) return;
  try {
    await store.rename(waypoint.id, trimmed);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The waypoint could not be renamed.')),
    );
  }
}
