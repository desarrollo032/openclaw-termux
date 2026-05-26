import 'dart:math';

/// A star particle in the thinking constellation effect.
///
/// Each particle has a base position (bx, by, bz) within a unit circle,
/// individual animation properties (twinkle, orbit), and pre-computed
/// connections to neighboring particles for constellation lines.
class ConstellationParticle {
  /// Normalized base X within unit circle (-1..1).
  final double bx;

  /// Normalized base Y within unit circle (-1..1).
  final double by;

  /// Depth factor (-1..1) for 3D parallax effect.
  final double bz;

  /// Random phase offset for twinkle animation (0..2π).
  final double phase;

  /// Speed of individual twinkle oscillation.
  final double twinkleSpeed;

  /// Orbital rotation speed (can be negative for reverse orbit).
  final double orbitSpeed;

  /// Visual size of the particle in pixels.
  final double size;

  /// Base brightness (0.4–1.0).
  final double brightness;

  /// Current orbital angle (updated each frame).
  double angle;

  /// Indices of connected particles (pre-computed from base distance < 0.085).
  final List<int> connections;

  ConstellationParticle({
    required this.bx,
    required this.by,
    required this.bz,
    required this.phase,
    required this.twinkleSpeed,
    required this.orbitSpeed,
    required this.size,
    required this.brightness,
    required this.angle,
    required this.connections,
  });

  /// Generate [count] particles with deterministic random seed.
  static List<ConstellationParticle> generate(int count, {int seed = 42}) {
    final rng = Random(seed);
    final particles = <ConstellationParticle>[];

    for (int i = 0; i < count; i++) {
      // Rejection sample within unit circle
      double bx, by;
      do {
        bx = rng.nextDouble() * 2 - 1;
        by = rng.nextDouble() * 2 - 1;
      } while (bx * bx + by * by > 1);

      final bz = rng.nextDouble() * 2 - 1;
      final phase = rng.nextDouble() * 2 * pi;
      final twinkleSpeed = 0.03 + rng.nextDouble() * 0.05;
      final orbitSpeed = 0.0008 + rng.nextDouble() * 0.0012;
      // Randomly negate orbit direction
      if (rng.nextBool()) {
        particles.add(ConstellationParticle(
          bx: bx,
          by: by,
          bz: bz,
          phase: phase,
          twinkleSpeed: twinkleSpeed,
          orbitSpeed: -orbitSpeed,
          size: 0.6 + rng.nextDouble() * 2.2,
          brightness: 0.4 + rng.nextDouble() * 0.6,
          angle: rng.nextDouble() * 2 * pi,
          connections: [],
        ));
      } else {
        particles.add(ConstellationParticle(
          bx: bx,
          by: by,
          bz: bz,
          phase: phase,
          twinkleSpeed: twinkleSpeed,
          orbitSpeed: orbitSpeed,
          size: 0.6 + rng.nextDouble() * 2.2,
          brightness: 0.4 + rng.nextDouble() * 0.6,
          angle: rng.nextDouble() * 2 * pi,
          connections: [],
        ));
      }
    }

    // Pre-compute connections: pairs with Euclidean distance < 0.085
    // in normalized 3D space (bx, by, bz * 0.5 to account for depth compression).
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final dx = particles[i].bx - particles[j].bx;
        final dy = particles[i].by - particles[j].by;
        final dz = (particles[i].bz - particles[j].bz) * 0.5;
        final dist = sqrt(dx * dx + dy * dy + dz * dz);
        if (dist < 0.085) {
          particles[i].connections.add(j);
        }
      }
    }

    return particles;
  }

  /// Total count of unique constellation connections (for stats).
  static int totalConnections(List<ConstellationParticle> particles) {
    return particles.fold(0, (sum, p) => sum + p.connections.length);
  }
}
