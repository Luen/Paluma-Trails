import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The Paluma Trails brand palette. docs/branding.md explains where each
/// colour may be used; widgets should normally reach these through the theme
/// (`Theme.of(context).colorScheme`, the app bar theme) rather than directly.
abstract final class BrandColors {
  /// Brand anchor: the icon tile, splash, app bar and loading screen.
  static const rainforest = Color(0xFF14532D);

  /// Seed for the generated Material colour scheme.
  static const trailGreen = Color(0xFF2E6B4F);

  /// The mark, and text on rainforest.
  static const cream = Color(0xFFF4ECD8);

  /// Short accent rules and progress on rainforest; never body text on light
  /// surfaces.
  static const sand = Color(0xFFE9C46A);

  /// Secondary text on rainforest (4.6:1).
  static const mist = Color(0xFF9CC3A6);

  /// Supporting text on rainforest, such as the tagline (6.3:1).
  static const paleMist = Color(0xFFC9DDCB);
}

/// Names and lines that appear in more than one place.
abstract final class BrandText {
  static const name = 'Paluma Trails';

  /// The primary tagline; see docs/branding.md#tagline.
  static const tagline = 'Every track and junction, offline.';

  /// The bundled interface typeface (SIL Open Font License 1.1).
  static const fontFamily = 'AtkinsonHyperlegibleNext';
}

/// The junction-pin mark, drawn from the same geometry as the generated icon
/// sources (`tools/brand/build_brand.py`) so it stays sharp at any size and
/// needs no SVG dependency.
///
/// The pin's hole is a junction ring, like the junction markers on the map,
/// with one trail leaving it towards the tip and a branch to the upper left.
/// The ring and trails are cut out, so whatever is behind the mark shows
/// through them. The same mark works from 16 pixels up; there is no separate
/// small-size version.
class TrailPinMark extends StatelessWidget {
  const TrailPinMark({
    super.key,
    this.height = 48,
    this.color = BrandColors.cream,
    this.accentColor,
    this.semanticLabel,
  });

  /// Height of the pin; the width follows the mark's proportions.
  final double height;
  final Color color;

  /// Fills the disc inside the junction ring. Use [BrandColors.sand] on
  /// rainforest; leave null elsewhere, so the disc is the mark's own colour.
  final Color? accentColor;

  /// Read by screen readers; the mark is decorative when this is null.
  final String? semanticLabel;

  static const _aspectRatio = 504 / 688;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size(height * _aspectRatio, height),
      painter: _TrailPinPainter(color: color, accentColor: accentColor),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: mark);
    return Semantics(label: semanticLabel, image: true, child: mark);
  }
}

class _TrailPinPainter extends CustomPainter {
  const _TrailPinPainter({required this.color, required this.accentColor});

  final Color color;
  final Color? accentColor;

  // The 1024-unit grid of the icon sources: the pin spans x 260–764 and
  // y 176–864. Keep in step with tools/brand/build_brand.py.
  static const _junction = Offset(512, 430);
  static const _ringRadius = 96.0;
  static const _cutWidth = 68.0;

  @override
  void paint(Canvas canvas, Size size) {
    final pin = Path()
      ..moveTo(512, 176)
      ..cubicTo(373, 176, 260, 289, 260, 428)
      ..cubicTo(260, 624, 512, 864, 512, 864)
      ..cubicTo(512, 864, 764, 624, 764, 428)
      ..cubicTo(764, 289, 651, 176, 512, 176)
      ..close();
    final trails = Path()
      // Towards the tip.
      ..moveTo(512, 540)
      ..cubicTo(536, 590, 498, 628, 510, 676)
      // The branch, upper left.
      ..moveTo(446, 366)
      ..cubicTo(414, 334, 390, 320, 362, 316);
    final cut = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = _cutWidth
      ..strokeCap = StrokeCap.round;

    final scale = size.height / 688;
    canvas
      ..save()
      ..scale(scale)
      ..translate(-260, -176)
      // A layer so the cuts clear only the pin, not what is behind it.
      ..saveLayer(const Rect.fromLTWH(250, 166, 524, 708), Paint())
      ..drawPath(pin, Paint()..color = color)
      ..drawCircle(_junction, _ringRadius, cut)
      ..drawPath(trails, cut)
      ..restore();
    if (accentColor != null) {
      canvas.drawCircle(
        _junction,
        _ringRadius - _cutWidth / 2,
        Paint()..color = accentColor!,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrailPinPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accentColor != accentColor;
}

/// “Paluma Trails” set as the wordmark: the bundled typeface at bold weight
/// with slightly tightened tracking. Outside the app, use the outlined
/// artwork in `docs/brand/`.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 28, this.color});

  final double fontSize;

  /// Defaults to the surrounding text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    BrandText.name,
    maxLines: 1,
    softWrap: false,
    style: TextStyle(
      fontFamily: BrandText.fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      height: 1.1,
      letterSpacing: -0.015 * fontSize,
      color: color,
    ),
  );
}

/// The horizontal lockup: the pin beside the wordmark, as in
/// `docs/brand/lockup-horizontal*.svg`.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.fontSize = 28,
    this.color = BrandColors.cream,
    this.accentColor = BrandColors.sand,
  });

  final double fontSize;
  final Color color;

  /// The junction accent; sand on rainforest, null on light fields.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) => Semantics(
    label: BrandText.name,
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TrailPinMark(
          height: fontSize * 1.2,
          color: color,
          accentColor: accentColor,
        ),
        SizedBox(width: fontSize * 0.36),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Wordmark(fontSize: fontSize, color: color),
          ),
        ),
      ],
    ),
  );
}

/// Adds the bundled typeface's licence to the app's licence page.
void registerBrandLicences() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/fonts/atkinson_hyperlegible_next/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['Atkinson Hyperlegible Next'], text);
  });
}
