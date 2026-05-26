import 'package:flutter/material.dart';
import 'constellation_painter.dart';
import 'constellation_star.dart';

/// Standalone banner widget that displays the constellation visual
/// with star particles and connection lines.
///
/// Used by [ConstellationBannerController] via OverlayEntry.
class ConstellationBanner extends StatelessWidget {
  /// Pre-generated list of stars.
  final List<ConstellationStar> stars;

  /// Global animation tick.
  final int tick;

  /// Color for star glow cores and highlights.
  final Color starColor;

  /// Color for constellation connection lines.
  final Color lineColor;

  /// Audio level (0.0–1.0) for subtle reactive pulsing.
  final double audioLevel;

  /// Pre-computed active line connections (recalculated periodically for perf).
  final List<ActiveLine> activeLines;

  /// Optional text shown at the bottom of the banner.
  final String? text;

  const ConstellationBanner({
    super.key,
    required this.stars,
    required this.tick,
    required this.starColor,
    required this.lineColor,
    required this.audioLevel,
    required this.activeLines,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 90,
        child: Stack(
          children: [
            // Constellation background
            RepaintBoundary(
              child: CustomPaint(
                size: const Size(double.infinity, 90),
                painter: ConstellationPainter(
                  stars: stars,
                  tick: tick,
                  starColor: starColor,
                  lineColor: lineColor,
                  audioLevel: audioLevel,
                  activeLines: activeLines,
                ),
              ),
            ),
            // Text overlay at bottom
            if (text != null && text!.isNotEmpty)
              Positioned(
                bottom: 10,
                left: 16,
                right: 16,
                child: Text(
                  text!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.08,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
