import 'package:flutter/material.dart';

/// Points of interest grouped the way a walker plans a day: water to fill up,
/// somewhere to look out from, somewhere to sleep, and the history of the
/// place.
///
/// The bundle keeps the finer `category` on each POI; these groups are what the
/// map's display options toggle. Keep the categories in step with
/// `content/schema/pois.schema.json`; a test checks the shipped content.
///
/// Hazards are deliberately in no group, so a warning can never be hidden by a
/// display choice: the map filter only hides the categories listed here.
enum PoiGroup {
  water(
    label: 'Water',
    description: 'Creeks, waterfalls and swimming holes',
    icon: Icons.water_drop_outlined,
    categories: ['water', 'waterfall', 'swimming'],
  ),
  lookouts(
    label: 'Lookouts',
    description: 'Views over the range and the coast',
    icon: Icons.visibility_outlined,
    categories: ['lookout'],
  ),
  camping(
    label: 'Camping',
    description: 'Campsites and huts',
    icon: Icons.nights_stay_outlined,
    categories: ['campsite', 'hut'],
  ),
  history(
    label: 'History',
    description: 'Mines, artworks and historic sites',
    icon: Icons.history_edu_outlined,
    categories: ['mine', 'history', 'art'],
  ),
  other(
    label: 'Other markers',
    description: 'Everything else, including places still to check',
    icon: Icons.place_outlined,
    categories: ['junction', 'other'],
  );

  const PoiGroup({
    required this.label,
    required this.description,
    required this.icon,
    required this.categories,
  });

  /// Short name for the toggle and the map key.
  final String label;

  /// One line explaining what the group covers.
  final String description;

  final IconData icon;

  /// The content categories in this group.
  final List<String> categories;

  /// The group [category] belongs to, or null when the content has a category
  /// this app does not know about yet.
  static PoiGroup? forCategory(String category) {
    for (final group in values) {
      if (group.categories.contains(category)) return group;
    }
    return null;
  }

  /// Every category the map can draw, for filters and tests.
  static List<String> get allCategories => [
    for (final group in values) ...group.categories,
  ];
}
