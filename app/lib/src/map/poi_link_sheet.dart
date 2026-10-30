import 'package:flutter/material.dart';

import 'sheets.dart';

/// Shown when a QR code or shared link asks for a POI this bundle does not
/// have.
///
/// ADR 0009 requires an understandable not-found view that still leaves the
/// walker on the map, offline: a sign must never lead to a blank page. The id
/// stays visible so the number on the sign can be read out or typed later.
Future<void> showPoiLinkNotFoundSheet(
  BuildContext context, {
  required String poiId,
}) => showMapSheet(context, PoiLinkNotFoundSheet(poiId: poiId));

class PoiLinkNotFoundSheet extends StatelessWidget {
  const PoiLinkNotFoundSheet({super.key, required this.poiId});

  /// The id the link asked for, shown as it appears in the code.
  final String poiId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              child: const Icon(Icons.link_off),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'That code points to a place this map does not have',
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'The link asks for “$poiId”. It may have been added after this copy '
          'of the map was downloaded, or renamed since the sign was printed.',
        ),
        const SizedBox(height: 12),
        Text(
          'The offline map still works. Look for the nearest junction sign and '
          'use the map to find your way.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          // 48 dp, and no hidden gesture: the only action leaves the walker on
          // the map.
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Show the map'),
        ),
      ],
    );
  }
}
