import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'ai_orb_controller.dart';

/// Advanced CustomPainter that renders the AI emotion orb.
///
/// Layers (from inside out):
///  1. Core — RadialGradient (white → primary color)
///  2. Surface wave — animated sin wave on perimeter
///  3. Halo — 3 concentric pulsing rings
///  4. Particles — 60 orbiting dots connected by lines when close
///  5. (speaking only) Radial bars around the orb
class OrbPainter extends CustomPainter {
  final AiEmotion emotion;
  final double audioLevel; // 0.0–1.0
  final double waveTime;   // from AnimationController (—∞, +∞)
  final double pulseScale; // 0.95–1.05
  final double particleTime;
  final double haloTime;
  final Color primaryColor;
  final Color secondaryColor;
  final EmotionConfig config;

  const OrbPainter({
    required this.emotion,
    required this.audioLevel,
    required this.waveTime,
    required this.pulseScale,
    required this.particleTime,
    required this.haloTime,
    required this.primaryColor,
    required this.secondaryColor,
    required this.config,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) / 2 * 0.7;
    final scaledRadius = baseRadius * pulseScale;

    // Audio-reactive scale for listening state
    final audioReactiveRadius = emotion == AiEmotion.listening
        ? scaledRadius * (1.0 + audioLevel * 0.06)
        : scaledRadius;

    // ── 3. Halo (drawn first, behind everything) ──
    _drawHalo(canvas, center, audioReactiveRadius);

    // ── 5. Radial bars (speaking state, drawn before surface) ──
    if (emotion == AiEmotion.speaking && audioLevel > 0.01) {
      _drawRadialBars(canvas, center, audioReactiveRadius);
    }

    // ── 2. Surface wave ──
    _drawSurface(canvas, center, audioReactiveRadius);

    // ── 1. Core gradient ──
    _drawCore(canvas, center, audioReactiveRadius);

    // ── 4. Particles ──
    _drawParticles(canvas, center, audioReactiveRadius);
  }

  /// Layer 1 — Radial gradient core
  void _drawCore(Canvas canvas, Offset center, double radius) {
    final corePaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius * 0.8,
        [
          Colors.white.withValues(alpha: 220 / 255),
          primaryColor.withValues(alpha: 200 / 255),
          primaryColor.withValues(alpha: 60 / 255),
        ],
        [0.0, 0.4, 1.0],
      );
    canvas.drawCircle(center, radius * 0.85, corePaint);
  }

  /// Layer 2 — Perimeter sine wave
  void _drawSurface(Canvas canvas, Offset center, double radius) {
    final path = Path();
    const segments = 64;
    final amplitude = config.waveAmplitude * (1.0 + audioLevel * 0.6);
    final speed = config.waveSpeed;

    for (int i = 0; i <= segments; i++) {
      final angle = (2 * pi * i / segments);
      final wave = sin(angle * 3 + waveTime * speed) * 0.6 +
          sin(angle * 5 + waveTime * speed * 1.4) * 0.3 +
          sin(angle * 7 + waveTime * speed * 1.9) * 0.1;

      final r = radius + wave * amplitude;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final wavePaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius * 1.2,
        [
          primaryColor.withValues(alpha: 30 / 255),
          secondaryColor.withValues(alpha: 20 / 255),
          Colors.transparent,
        ],
        [0.6, 0.85, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, wavePaint);

    // Filled wave surface
    final fillPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          primaryColor.withValues(alpha: 15 / 255),
          primaryColor.withValues(alpha: 8 / 255),
          Colors.transparent,
        ],
        [0.3, 0.7, 1.0],
      );
    canvas.drawPath(path, fillPaint);
  }

  /// Layer 3 — Concentric halo rings
  void _drawHalo(Canvas canvas, Offset center, double radius) {
    final intensity = config.haloIntensity * (0.8 + 0.2 * sin(haloTime));

    for (int i = 0; i < 3; i++) {
      final ringRadius = radius * (1.2 + i * 0.15 + 0.05 * sin(haloTime * (1.5 - i * 0.3)));
      final alpha = ((1.0 - i * 0.3) * intensity).clamp(0.0, 80 / 255);

      final paint = Paint()
        ..color = primaryColor.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 - i * 0.3;

      canvas.drawCircle(center, ringRadius, paint);
    }
  }

  /// Layer 4 — Orbiting particles with connecting lines
  void _drawParticles(Canvas canvas, Offset center, double radius) {
    const int count = 60;
    final baseOrbitRadius = radius * (0.7 + 0.15 * sin(particleTime * 0.3));

    // Particle positions
    final positions = <Offset>[];
    final speeds = <double>[];
    final randomPhase = <double>[];

    final rng = Random(42); // Fixed seed for deterministic layout
    for (int i = 0; i < count; i++) {
      speeds.add(0.5 + rng.nextDouble() * 1.5 * config.particleSpeed);
      randomPhase.add(rng.nextDouble() * 2 * pi);
    }

    for (int i = 0; i < count; i++) {
      final speed = speeds[i % speeds.length];
      final phase = randomPhase[i % randomPhase.length];
      final angle = particleTime * speed + phase;
      final orbitRadius = baseOrbitRadius + radius * 0.1 * sin(particleTime * speed * 0.7 + phase);
      final x = center.dx + orbitRadius * cos(angle);
      final y = center.dy + orbitRadius * sin(angle);
      positions.add(Offset(x, y));
    }

    // Draw connecting lines
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final dist = (positions[i] - positions[j]).distance;
        if (dist < 40) {
          final alpha = ((1.0 - dist / 40) * 120 / 255).clamp(0.0, 60 / 255);
          canvas.drawLine(
            positions[i],
            positions[j],
            Paint()
              ..color = primaryColor.withValues(alpha: alpha)
              ..strokeWidth = 0.5,
          );
        }
      }
    }

    // Draw particles
    for (int i = 0; i < positions.length; i++) {
      final size = 1.5 + 2.0 * sin(particleTime * speeds[i % speeds.length] * 1.5 + randomPhase[i % randomPhase.length]);
      final alpha = ((180 + 75 * sin(particleTime * speeds[i % speeds.length] + randomPhase[i % randomPhase.length])) / 255).clamp(60 / 255, 1.0);
      canvas.drawCircle(
        positions[i],
        size,
        Paint()..color = primaryColor.withValues(alpha: alpha),
      );
    }
  }

  /// Layer 5 (speaking only) — Radial bars that pulse with audio level
  void _drawRadialBars(Canvas canvas, Offset center, double radius) {
    const int barCount = 24;
    final barLength = radius * 0.3 * (0.4 + 0.6 * audioLevel);

    for (int i = 0; i < barCount; i++) {
      final angle = 2 * pi * i / barCount;
      // Each bar has a slight individual offset for a dynamic look
      final individual = sin(angle * 3 + waveTime * 3) * 0.15;
      final height = barLength * (0.5 + 0.5 * audioLevel + individual);

      final inner = radius * 0.95;
      final outer = radius + height;

      final x1 = center.dx + inner * cos(angle);
      final y1 = center.dy + inner * sin(angle);
      final x2 = center.dx + outer * cos(angle);
      final y2 = center.dy + outer * sin(angle);

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = primaryColor.withValues(alpha: (180 * (0.5 + 0.5 * audioLevel)) / 255)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(OrbPainter oldDelegate) {
    return oldDelegate.emotion != emotion ||
        oldDelegate.audioLevel != audioLevel ||
        oldDelegate.waveTime != waveTime ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.particleTime != particleTime ||
        oldDelegate.haloTime != haloTime ||
        oldDelegate.primaryColor != primaryColor;
  }
}
