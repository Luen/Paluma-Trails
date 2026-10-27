import 'package:flutter/widgets.dart';

import 'poi_groups.dart';

/// Display choices that change how the map looks and how often the GPS runs.
///
/// Deliberately session-only: they are preferences, not content, and the app
/// should not grow a storage dependency just to remember a toggle.
class MapOptions extends ChangeNotifier {
  var _sunlight = false;
  var _batterySaver = false;
  final Set<PoiGroup> _hiddenPoiGroups = {};

  /// High-contrast colours and heavier map lines for bright, direct light.
  bool get sunlight => _sunlight;

  set sunlight(bool value) {
    if (value == _sunlight) return;
    _sunlight = value;
    notifyListeners();
  }

  /// Coarser, less frequent location fixes and no compass puck.
  bool get batterySaver => _batterySaver;

  set batterySaver(bool value) {
    if (value == _batterySaver) return;
    _batterySaver = value;
    notifyListeners();
  }

  /// Whether [group]'s markers are drawn. Every group starts visible.
  bool isPoiGroupVisible(PoiGroup group) => !_hiddenPoiGroups.contains(group);

  void setPoiGroupVisible(PoiGroup group, bool visible) {
    final changed = visible
        ? _hiddenPoiGroups.remove(group)
        : _hiddenPoiGroups.add(group);
    if (changed) notifyListeners();
  }

  /// Whether no group has been hidden.
  bool get allPoiGroupsVisible => _hiddenPoiGroups.isEmpty;

  /// Draws every group again, for when a walker hides one too many.
  void showAllPoiGroups() {
    if (_hiddenPoiGroups.isEmpty) return;
    _hiddenPoiGroups.clear();
    notifyListeners();
  }

  /// The content categories hidden by the current choices, for the map filter.
  Set<String> get hiddenPoiCategories => {
    for (final group in _hiddenPoiGroups) ...group.categories,
  };
}

/// Makes [MapOptions] available to the map screen, rebuilding it on changes.
class MapOptionsScope extends InheritedNotifier<MapOptions> {
  const MapOptionsScope({
    super.key,
    required MapOptions options,
    required super.child,
  }) : super(notifier: options);

  static MapOptions of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MapOptionsScope>();
    assert(scope != null, 'MapOptionsScope is missing above this widget');
    return scope!.notifier!;
  }
}
