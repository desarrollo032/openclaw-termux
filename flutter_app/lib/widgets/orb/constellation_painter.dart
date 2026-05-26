import 'dart:math' show sin, sqrt;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'constellation_star.dart';

/// CustomPainter that renders the constellation banner background.
///
/// Paints:
///   1. Pure black background (#000000) filling the entire canvas
///   2. Thin constellation lines connecting nearby stars
///   3. Star particles with radial glow halo + bright core + optional white highlight
///
/// Stars are provided from outside and only their screen position is
/// calculated here (no star creation occurs in paint).
class ConstellationPainter extends CustomPainter {
  /// Pre-generated list of stars (never created in paint).
  final List<ConstellationStar> stars;

  /// Global animation tick (increments each frame).
  final int tick;

  /// Color used for star glow cores and highlights.
  final Color starColor;

  /// Color used for constellation connection lines.
  final Color lineColor;

  /// Audio level (0.0–1.0) for subtle reactive pulsing.
  final double audioLevel;

  /// Pre-computed list of line connections (indices pair + pixel distance squared).
  /// Recalculated in [ConstellationBannerController] every 90 ticks for performance.
  final List<ActiveLine> activeLines;

  /// Maximum distance for constellation line connections in pixels.
  static const double _maxConnDist = 70.0;

  /// Maximum alpha for constellation lines.
  static const double _lineMaxAlpha = 0.38;

  ConstellationPainter({
    required this.stars,
    required this.tick,
    required this.starColor,
    required this.lineColor,
    required this.audioLevel,
    required this.activeLines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Full black background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000),
    );

    final audioFactor = 1.0 + audioLevel * 0.15;

    // 2. Constellation lines (using pre-computed active connections)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (final line in activeLines) {
      final a = stars[line.i];
      final b = stars[line.j];

      final ax = a.x * size.width;
      final ay = a.y * size.height;
      final bx = b.x * size.width;
      final by = b.y * size.height;

      final dx = ax - bx;
      final dy = ay - by;
      final dist = sqrt(dx * dx + dy * dy);

      final opacity = _lineMaxAlpha *
          (1 - dist / _maxConnDist) *
          a.brightness *
          b.brightness;
      final alpha = (opacity).clamp(0.0, 0.38);

      linePaint.color = lineColor.withValues(alpha: alpha);
      canvas.drawLine(
        Offset(ax, ay),
        Offset(bx, by),
        linePaint,
      );
    }

    // 3. Star particles with glow
    for (final star in stars) {
      final twinkle =
          0.55 + 0.45 * sin(tick * star.twinkleSpeed + star.phase);
      final sx = star.x * size.width;
      final sy = star.y * size.height;
      final pos = Offset(sx, sy);
      final glowRadius = star.size * 4 * audioFactor;

      // a) Outer glow halo (RadialGradient)
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          pos,
          glowRadius,
          [
            starColor.withValues(alpha: twinkle * 0.5),
            starColor.withValues(alpha: twinkle * 0.15),
            starColor.withValues(alpha: 0),
          ],
          [0.0, 0.5, 1.0],
        );
      canvas.drawCircle(pos, glowRadius, glowPaint);

      // b) Core point
      final coreAlpha = (twinkle * 1.2).clamp(0.0, 1.0);
      canvas.drawCircle(
        pos,
        star.size,
        Paint()..color = starColor.withValues(alpha: coreAlpha),
      );

      // c) White highlight (only for bright, high-twinkle stars)
      if (star.brightness > 0.75 && twinkle > 0.8) {
        canvas.drawCircle(
          pos,
          star.size * 0.4,
          Paint()
            ..color = Colors.white.withValues(alpha: twinkle * 0.6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) => true;
}

/// A pre-computed active connection line between star [i] and star [j].
class ActiveLine {
  final int i;
  final int j;
  const ActiveLine(this.i, this.j);
}
