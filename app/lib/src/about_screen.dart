import 'package:flutter/material.dart';

import 'content/bundle_repository.dart';

/// Park facts, attributions and the licence/disclaimer notes that should stay
/// one tap away from the map.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.bundle});

  final LoadedBundle bundle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final park = bundle.park;
    final manifest = bundle.manifest;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(park.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(park.region, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Content updated ${park.updated}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.emergency_outlined,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'In an emergency call ${park.emergencyPhone}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        if (park.emergencyNotes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            park.emergencyNotes,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (park.disclaimer.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(park.disclaimer, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('Offline bundle'),
          _KeyValue('Version', manifest.bundleVersion),
          _KeyValue('Size', _formatBytes(manifest.totalBytes)),
          _KeyValue('Files', '${manifest.files.length}'),
          _KeyValue('Content schema', 'v${manifest.schemaVersion}'),
          const SizedBox(height: 8),
          Text(
            'Includes the basemap and all trail content, so the map works in '
            'flight mode. Map detail is provided to zoom 15; zooming further '
            'stretches the tiles.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Walking times'),
          Text(bundle.estimate.label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          const _SectionTitle('Credits'),
          for (final attribution in park.attributions)
            _KeyValue(attribution.label, attribution.licence),
          const SizedBox(height: 8),
          Text(
            'Trail data collected and edited by the Wanderstories project; '
            'content is unverified until checked against the tracks and '
            'Queensland Parks sources. Source: github.com/Luen/Paluma-Trails',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(2)} MiB';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
