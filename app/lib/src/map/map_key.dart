import 'package:flutter/material.dart';

import 'format.dart';
import 'map_palette.dart';

/// What the lines and markers on the map mean. Every entry pairs the symbol
/// with words, so nothing relies on colour alone.
class MapKey extends StatelessWidget {
  const MapKey({super.key});

  static const _trackClasses = ['track', 'other', 'mtb', 'road', 'connector'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Map key',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        for (final trackClass in _trackClasses)
          _KeyRow(
            symbol: TrackClassSwatch(trackClass: trackClass),
            label: trackClass == 'other'
                ? 'Informal or unclassified track'
                : formatTrackClass(trackClass),
          ),
        const _KeyRow(
          symbol: JunctionBadge(number: 12, size: 28),
          label: 'Numbered junction',
        ),
        const _KeyRow(symbol: PoiDot(), label: 'Point of interest'),
        const _KeyRow(symbol: WaypointDot(), label: 'Your waypoint'),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.symbol, required this.label});

  final Widget symbol;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 48, child: Center(child: symbol)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

/// A short sample of a track line, drawn as on the map: casing, then the
/// class colour, dashed for informal tracks.
class TrackClassSwatch extends StatelessWidget {
  const TrackClassSwatch({super.key, required this.trackClass});

  final String trackClass;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size(40, 12),
      painter: _TrackSwatchPainter(
        color: MapPalette.color(MapPalette.trackColour(trackClass)),
        dashed: MapPalette.isDashed(trackClass),
      ),
    ),
  );
}

class _TrackSwatchPainter extends CustomPainter {
  const _TrackSwatchPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const width = 4.0;
    final casing = Paint()
      ..color = MapPalette.color(MapPalette.casing).withValues(alpha: 0.35)
      ..strokeWidth = width + 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), casing);

    final line = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = dashed ? StrokeCap.butt : StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), line);
      return;
    }
    // Matches MapPalette.informalDash, which is in line widths.
    final dash = MapPalette.informalDash[0] * width;
    final gap = MapPalette.informalDash[1] * width;
    for (var x = 4.0; x < size.width - 4; x += dash + gap) {
      final end = (x + dash).clamp(0, size.width - 4).toDouble();
      canvas.drawLine(Offset(x, y), Offset(end, y), line);
    }
  }

  @override
  bool shouldRepaint(_TrackSwatchPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

/// A junction number styled like its marker on the map, so the sheet and the
/// map are easy to match up.
class JunctionBadge extends StatelessWidget {
  const JunctionBadge({super.key, required this.number, this.size = 40});

  final int? number;
  final double size;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: MapPalette.color(MapPalette.junctionLabel),
      fontWeight: FontWeight.w700,
      fontSize: size * 0.4,
      height: 1,
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MapPalette.color(MapPalette.junctionFill),
        border: Border.all(
          color: MapPalette.color(MapPalette.junctionStroke),
          width: size / 14,
        ),
      ),
      child: Text(
        number == null ? '?' : '$number',
        style: textStyle,
        maxLines: 1,
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}

/// A point-of-interest marker as drawn on the map.
class PoiDot extends StatelessWidget {
  const PoiDot({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: MapPalette.color(MapPalette.poi),
      border: Border.all(
        color: MapPalette.color(MapPalette.poiStroke),
        width: 2,
      ),
    ),
  );
}

/// A walker-saved pin as drawn on the map: larger than a content POI and a
/// deep plum so it stays distinct from junctions and park markers.
class WaypointDot extends StatelessWidget {
  const WaypointDot({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: MapPalette.color(MapPalette.waypoint),
      border: Border.all(
        color: MapPalette.color(MapPalette.poiStroke),
        width: 2.5,
      ),
    ),
  );
}
