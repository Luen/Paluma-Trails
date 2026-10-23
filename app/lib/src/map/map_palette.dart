import 'package:flutter/painting.dart';

/// Colours of the trail overlay. They are data encodings, not brand accents:
/// use them for the map and for keys or badges that stand for a map feature,
/// never for buttons or status.
///
/// Each line colour has at least 3:1 contrast with the park and earth fills,
/// and the classes stay distinguishable under simulated deuteranopia,
/// protanopia and tritanopia; `tools/brand/colour_check.py` reads this file and
/// checks both. Track class is never colour alone: informal tracks are dashed,
/// and every sheet names the class in words.
abstract final class MapPalette {
  /// Walking tracks and short walks; informal tracks use it dashed.
  static const walkingTrack = '#2E7D32';
  static const mtbTrack = '#8E24AA';
  static const road = '#455A64';
  static const connector = '#5D4037';

  /// Under every track line, so a track stays visible on any fill.
  static const casing = '#0B3D2E';

  static const junctionFill = '#FFF8E1';
  static const junctionStroke = '#BF360C';
  static const junctionLabel = '#3E2723';

  static const poi = '#01579B';
  static const poiLabel = '#0D47A1';
  static const poiStroke = '#FFFFFF';
  static const labelHalo = '#FFFFFF';

  // Sunlight mode: the same hues where they already pass, pushed to black and
  // white where a marker needs more contrast.
  static const sunlightJunctionFill = '#FFFFFF';
  static const sunlightJunctionStroke = '#000000';
  static const sunlightLabel = '#000000';
  static const sunlightPoi = '#0D47A1';

  /// Track classes drawn as a solid line. Anything else (today, the `other`
  /// class of informal or unclassified tracks) is drawn dashed.
  static const solidClasses = ['walk', 'track', 'mtb', 'road', 'connector'];

  /// The MapLibre `line-dasharray` for informal tracks, in line widths.
  static const informalDash = [2.0, 1.5];

  /// Line colour for a track class.
  static String trackColour(String trackClass) => switch (trackClass) {
    'mtb' => mtbTrack,
    'road' => road,
    'connector' => connector,
    _ => walkingTrack,
  };

  /// Whether a track class is drawn dashed.
  static bool isDashed(String trackClass) => !solidClasses.contains(trackClass);

  /// Parses one of the `#RRGGBB` constants for a widget.
  static Color color(String hex) =>
      Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
