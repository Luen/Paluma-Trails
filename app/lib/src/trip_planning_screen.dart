import 'package:flutter/material.dart';

import 'brand/brand.dart';
import 'content/bundle_repository.dart';
import 'map/poi_photo_card.dart';
import 'map/sheets.dart';
import 'map/source_link.dart';

/// Pre-visit information and credited photographs from the offline bundle.
class TripPlanningScreen extends StatelessWidget {
  const TripPlanningScreen({super.key, required this.bundle});

  final LoadedBundle bundle;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Trip planning'),
        bottom: const TabBar(
          labelColor: BrandColors.cream,
          unselectedLabelColor: BrandColors.mist,
          indicatorColor: BrandColors.sand,
          tabs: [
            Tab(text: 'Plan'),
            Tab(text: 'Photos'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: TabBarView(children: [_plan(context), _photos(context)]),
        ),
      ),
    ),
  );

  Widget _plan(BuildContext context) {
    final content = bundle.tripPlanning;
    final theme = Theme.of(context);
    if (content == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'This older bundle has no trip-planning notes. The offline map and '
          'any bundled photographs remain available.',
        ),
      );
    }
    return ListView(
      key: const PageStorageKey('trip-plan'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Offline notes · checked ${content.checked}',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(content.intro),
        for (final section in content.sections) ...[
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(section.title, style: theme.textTheme.titleLarge),
          ),
          for (final paragraph in section.paragraphs)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(paragraph),
            ),
          for (final source in section.sources)
            SourceLink(label: source.label, url: source.url),
        ],
      ],
    );
  }

  Widget _photos(BuildContext context) {
    final pois =
        bundle.pois.values.where((poi) => poi.photos.isNotEmpty).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final count = pois.fold<int>(0, (sum, poi) => sum + poi.photos.length);
    final theme = Theme.of(context);
    return ListView(
      key: const PageStorageKey('trip-photos'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('$count offline photographs', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Historic photographs and place context from the POI collection. '
          'Dates and limitations are in each caption; these images do not show '
          'current track conditions. Copyright and permission credits stay '
          'with each photograph.',
        ),
        if (pois.isEmpty) ...[
          const SizedBox(height: 16),
          const Text('This bundle has no photographs yet.'),
        ],
        for (final poi in pois) ...[
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(poi.name, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          for (final photo in poi.photos)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PoiPhotoCard(photo: photo),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              key: ValueKey('history-${poi.id}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => showPoiSheet(context, bundle: bundle, poi: poi),
              child: const Text('Read place history'),
            ),
          ),
        ],
      ],
    );
  }
}
