import 'package:flutter/material.dart';

import 'app_version.dart';
import 'brand/brand.dart';
import 'content/bundle_repository.dart';
import 'location/location_service.dart';
import 'map/source_link.dart';
import 'safety_screen.dart';

/// Park facts, attributions and the licence/disclaimer notes that should stay
/// one tap away from the map.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.bundle, this.location});

  final LoadedBundle bundle;

  /// When the map supplies its location service, the safety page can show the
  /// walker's coordinates without starting a second GPS stream.
  final LocationService? location;

  @override
  Widget build(BuildContext context) {
    final park = bundle.park;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        children: [
          _AboutHeader(parkName: park.name, region: park.region),
          Padding(padding: const EdgeInsets.all(16), child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final park = bundle.park;
    final manifest = bundle.manifest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (location != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    SafetyScreen(bundle: bundle, location: location!),
              ),
            ),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Safety and emergency information'),
          ),
        ],
        const SizedBox(height: 24),
        const _SectionTitle('App'),
        const _KeyValue('Version', kAppVersion),
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
        const _SectionTitle('Walking guides'),
        const SourceLink(
          label: 'Paluma trails and history — Wanderstories',
          url: 'https://wanderstories.space/hiking-at-paluma-range-national-park/',
        ),
        const SourceLink(
          label: 'Paluma maps — Wanderstories',
          url: 'https://wanderstories.space/paluma-maps/',
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Credits'),
        for (final attribution in park.attributions)
          _KeyValue(attribution.label, attribution.licence),
        const _KeyValue('Typeface', 'Atkinson Hyperlegible Next, SIL OFL 1.1'),
        const SizedBox(height: 8),
        Text(
          'Trail data collected and edited by the Wanderstories project; '
          'content is unverified until checked against the tracks and '
          'Queensland Parks sources. Source: github.com/Luen/Paluma-Trails',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: BrandText.name,
              applicationIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: TrailPinMark(
                  height: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            icon: const Icon(Icons.article_outlined),
            label: const Text('Open-source licences'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  static String _formatBytes(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(2)} MiB';
}

/// The brand lockup and the park, on the same rainforest field as the app bar.
class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.parkName, required this.region});

  final String parkName;
  final String region;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ColoredBox(
      color: BrandColors.rainforest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandLockup(fontSize: 30),
            const SizedBox(height: 8),
            Text(
              BrandText.tagline,
              style: textTheme.titleMedium?.copyWith(
                color: BrandColors.paleMist,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: BrandColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              parkName,
              style: textTheme.titleLarge?.copyWith(color: BrandColors.cream),
            ),
            Text(
              region,
              style: textTheme.bodyMedium?.copyWith(color: BrandColors.mist),
            ),
          ],
        ),
      ),
    );
  }
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
