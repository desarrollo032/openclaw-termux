import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'constellation_particle.dart';

/// CustomPainter that renders the "Constellation" visual for
/// [AiEmotion.thinking].
///
/// Features:
///   - Dark cosmic background (#061520 → #020C12 radial)
///   - 3-layer teal halo (outer diffuse glow, inner ellipse, rim)
///   - 110 star particles with individual twinkle + slow orbit
///   - Constellation lines connecting nearby particles
///   - Per-particle glow (radial gradient halo)
///   - Circular clipping for particles/lines
///   - Smooth transition in/out via [transitionValue]
///
/// Particles are provided externally and only updated (not created) in paint().
class ThinkingConstellationPainter extends CustomPainter {
  /// Global animation tick in milliseconds (continuous, never reset).
  final double tick;

  /// Transition opacity 0.0–1.0.
  ///  - On entry: animated 0.0 → 1.0
  ///  - On exit:  animated 1.0 → 0.0
  final double transitionValue;

  /// Whether the orb is transitioning *into* thinking (true) or *out of* it.
  final bool isEntering;

  /// Base radius of the orb (before pulse scale).
  final double orbRadius;

  /// Pulse scale factor (0.95–1.05) from the orb's breathing animation.
  final double pulseScale;

  /// Pre-generated list of [ConstellationParticle] (never recreated in paint).
  final List<ConstellationParticle> particles;

  /// Cached screen-space positions (reused each frame to avoid allocations).
  final List<double> _px;
  final List<double> _py;

  ThinkingConstellationPainter({
    required this.tick,
    required this.transitionValue,
    required this.isEntering,
    required this.orbRadius,
    required this.pulseScale,
    required this.particles,
  })  : _px = List.filled(particles.length, 0.0),
        _py = List.filled(particles.length, 0.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (transitionValue <= 0.001) return;

    final center = Offset(size.width / 2, size.height / 2);
    final scaledRadius = orbRadius * pulseScale;
    final opacity = transitionValue;

    // Entry halo pulse: scale from 0.8 → 1.0 during the first 600ms of entry
    final entryPulse = isEntering && transitionValue < 1.0
        ? 0.8 + 0.2 * Curves.easeOut.transform(transitionValue)
        : 1.0;
    final haloPulseFactor = entryPulse;

    // ── 1. Dark background (clipped to orb) ──
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: scaledRadius * 1.15));
    canvas.save();
    canvas.clipPath(clipPath);

    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        scaledRadius,
        [
          const Color(0xFF061520).withValues(alpha: opacity),
          const Color(0xFF020C12).withValues(alpha: opacity),
        ],
        [0.0, 1.0],
      );
    canvas.drawCircle(center, scaledRadius * 1.15, bgPaint);
    canvas.restore();

    // ── 3. Halo layers (outside clip, behind everything else) ──
    _drawHaloLayers(canvas, center, scaledRadius, opacity, haloPulseFactor);

    // ── 4. Particles + constellation lines (clipped) ──
    canvas.save();
    canvas.clipPath(clipPath);
    _drawConstellation(canvas, center, scaledRadius);
    canvas.restore();

    // ── Rim (on top, no clip) ──
    final rimPaint = Paint()
      ..color = const Color(0xFF00E5C8).withValues(alpha: 0.35 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, scaledRadius, rimPaint);
  }

  /// Draws the 3 teal halo layers outside the orb.
  void _drawHaloLayers(
    Canvas canvas,
    Offset center,
    double radius,
    double opacity,
    double pulse,
  ) {
    final t = tick;
    final pulseOffset = 1 + 0.08 * sin(t * 0.0008);

    // Layer 1 — bright teal ellipse, blur 20
    final r1 = radius * 1.4 * pulse * pulseOffset;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r1 * 2, height: r1 * 1.4),
      Paint()
        ..color = const Color(0xFF00E5C8).withValues(alpha: 0.18 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // Layer 2 — deeper teal, blur 40
    final r2 = radius * 1.7 * pulse * (1 + 0.08 * sin(t * 0.0008 + 1));
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r2 * 2, height: r2 * 1.4),
      Paint()
        ..color = const Color(0xFF007A8A).withValues(alpha: 0.10 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );
  }

  /// Updates particle positions, draws constellation lines, then glows + stars.
  void _drawConstellation(
    Canvas canvas,
    Offset center,
    double radius,
  ) {
    final t = tick;

    // Global drift
    final driftX = sin(t * 0.0018) * 0.04 * radius;
    final driftY = cos(t * 0.0014) * 0.04 * radius;

    // Slow global rotation
    final globalAngle = t * 0.0001;
    final cosG = cos(globalAngle);
    final sinG = sin(globalAngle);

    // Update particle screen positions
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];

      // Rotate base position by global angle
      final bxRot = p.bx * cosG - p.by * sinG;
      final byRot = p.bx * sinG + p.by * cosG;

      final depthFactor = 1 + p.bz * 0.18;
      _px[i] = center.dx +
          bxRot * radius * 0.95 * depthFactor +
          driftX;
      _py[i] = center.dy +
          byRot * radius * 0.60 * depthFactor +
          driftY;
    }

    final opacity = transitionValue;

    // Constellation lines (first 60 particles only for performance)
    final lineCount = min(60, particles.length);
    for (int i = 0; i < lineCount; i++) {
      for (final j in particles[i].connections) {
        final dx = _px[i] - _px[j];
        final dy = _py[i] - _py[j];
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 70) {
          final ba = particles[i].brightness;
          final bb = particles[j].brightness;
          final lineAlpha =
              ((1 - dist / 70) * 0.38 * 255 * ba * bb * opacity)
                  .round()
                  .clamp(0, 97);
          canvas.drawLine(
            Offset(_px[i], _py[i]),
            Offset(_px[j], _py[j]),
            Paint()
              ..color = const Color(0xFF00DCC8).withAlpha(lineAlpha)
              ..strokeWidth = 0.45,
          );
        }
      }
    }

    // Particles with glow
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      // Twinkle: brightness oscillates over time with individual speed
      final twinkle = p.brightness *
          (0.55 + 0.45 * sin(t * p.twinkleSpeed + p.phase));
      final twinkleAlpha =
          (twinkle * 255 * opacity).round().clamp(0, 255);

      final pos = Offset(_px[i], _py[i]);

      // Outer glow halo (radial gradient)
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          pos,
          p.size * 3.5,
          [
            const Color(0xFF00E5C8)
                .withAlpha((twinkleAlpha * 0.35).round()),
            const Color(0xFF00E5C8).withAlpha(0),
          ],
        );
      canvas.drawCircle(pos, p.size * 3.5, glowPaint);

      // Inner bright core
      canvas.drawCircle(
        pos,
        p.size,
        Paint()
          ..color =
              const Color(0xFFDFFFFA).withAlpha((twinkleAlpha * 0.9).round()),
      );
    }
  }

  @override
  bool shouldRepaint(ThinkingConstellationPainter oldDelegate) => true;
}
