import 'dart:math' show Random, pi;

/// A drifting star particle in the constellation banner.
///
/// Positions are normalized (0.0–1.0) and scaled by the banner size
/// at paint time. Each star has subtle velocity for a slow drift,
/// an individual twinkle animation, and a visual size/brightness.
class ConstellationStar {
  /// Normalized X position (0.0–1.0, wraps at edges).
  double x;

  /// Normalized Y position (0.0–1.0, wraps at edges).
  double y;

  /// Horizontal drift speed per tick (±0.00015 to ±0.0003).
  final double vx;

  /// Vertical drift speed per tick (±0.00015 to ±0.0003).
  final double vy;

  /// Base radius in pixels (0.7–2.5).
  final double size;

  /// Base brightness (0.3–1.0).
  final double brightness;

  /// Random phase offset for twinkle (0–2π).
  final double phase;

  /// Individual twinkle speed (0.015–0.055).
  final double twinkleSpeed;

  ConstellationStar({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.brightness,
    required this.phase,
    required this.twinkleSpeed,
  });

  /// Update position using [speedMult] as the multiplier.
  /// Wraps around edges: if a star exits one side it reappears on the opposite.
  void update(double speedMult) {
    x += vx * speedMult;
    y += vy * speedMult;
    if (x < 0) x = 1.0;
    if (x > 1) x = 0.0;
    if (y < 0) y = 1.0;
    if (y > 1) y = 0.0;
  }

  /// Generate [count] stars with deterministic seed.
  static List<ConstellationStar> generate(int count, {int seed = 42}) {
    final rng = Random(seed);
    return List.generate(count, (_) {
      return ConstellationStar(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        vx: (rng.nextDouble() * 0.00015 + 0.00015) *
            (rng.nextBool() ? 1 : -1),
        vy: (rng.nextDouble() * 0.00015 + 0.00015) *
            (rng.nextBool() ? 1 : -1),
        size: 0.7 + rng.nextDouble() * 1.8,
        brightness: 0.3 + rng.nextDouble() * 0.7,
        phase: rng.nextDouble() * 2 * pi,
        twinkleSpeed: 0.015 + rng.nextDouble() * 0.040,
      );
    });
  }
}
