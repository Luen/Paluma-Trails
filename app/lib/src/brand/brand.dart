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

/// The trail-pin mark, drawn from the same geometry as
/// `app/assets/icon/icon.svg` so it stays sharp at any size and needs no SVG
/// dependency.
///
/// The circle and mountain are cut out of the pin, so whatever is behind the
/// mark shows through them, exactly as in the source artwork. Below 28 logical
/// pixels the mountain is too small to read, so the small-size mark (a larger
/// hole and no mountain, `icon_small.svg`) is drawn instead.
class TrailPinMark extends StatelessWidget {
  const TrailPinMark({
    super.key,
    this.height = 48,
    this.color = BrandColors.cream,
    this.semanticLabel,
  });

  /// Height of the pin; the width follows the mark's proportions.
  final double height;
  final Color color;

  /// Read by screen readers; the mark is decorative when this is null.
  final String? semanticLabel;

  static const _aspectRatio = 504 / 688;

  /// Below this height the small-size mark is used.
  static const smallSizeThreshold = 28.0;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size(height * _aspectRatio, height),
      painter: _TrailPinPainter(
        color: color,
        simplified: height < smallSizeThreshold,
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: mark);
    return Semantics(label: semanticLabel, image: true, child: mark);
  }
}

class _TrailPinPainter extends CustomPainter {
  const _TrailPinPainter({required this.color, required this.simplified});

  final Color color;
  final bool simplified;

  @override
  void paint(Canvas canvas, Size size) {
    // Coordinates are the 1024-unit grid of icon.svg; the pin spans
    // x 260–764 and y 176–864.
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(512, 176)
      ..cubicTo(373, 176, 260, 289, 260, 428)
      ..cubicTo(260, 624, 512, 864, 512, 864)
      ..cubicTo(512, 864, 764, 624, 764, 428)
      ..cubicTo(764, 289, 651, 176, 512, 176)
      ..close();
    if (simplified) {
      path.addOval(
        Rect.fromCircle(center: const Offset(512, 424), radius: 158),
      );
    } else {
      path
        ..addOval(Rect.fromCircle(center: const Offset(512, 422), radius: 140))
        ..moveTo(396, 470)
        ..lineTo(466, 356)
        ..lineTo(512, 414)
        ..lineTo(556, 348)
        ..lineTo(628, 470)
        ..close();
    }

    final scale = size.height / 688;
    canvas
      ..save()
      ..scale(scale)
      ..translate(-260, -176)
      ..drawPath(path, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_TrailPinPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.simplified != simplified;
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
  });

  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: BrandText.name,
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TrailPinMark(height: fontSize * 1.2, color: color),
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
