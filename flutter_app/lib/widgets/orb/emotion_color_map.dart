import 'package:flutter/material.dart';
import 'ai_orb_controller.dart';

/// Visual configuration for the [ConstellationBanner] per emotion.
class BannerEmotionConfig {
  /// Color used for star cores and glow.
  final Color starColor;

  /// Color used for constellation connection lines.
  final Color lineColor;

  /// Number of stars for this emotion (55–90).
  final int starCount;

  /// Speed multiplier for star drift (0.4–2.0).
  final double speed;

  const BannerEmotionConfig({
    required this.starColor,
    required this.lineColor,
    required this.starCount,
    required this.speed,
  });

  /// Mapping of [AiEmotion] to its visual config.
  static const Map<AiEmotion, BannerEmotionConfig> emotions = {
    AiEmotion.idle: BannerEmotionConfig(
      starColor: Color(0xFFC8C8B8),
      lineColor: Color(0xFF888878),
      starCount: 55,
      speed: 0.6,
    ),
    AiEmotion.listening: BannerEmotionConfig(
      starColor: Color(0xFFA0F0FF),
      lineColor: Color(0xFF00C8E0),
      starCount: 70,
      speed: 1.1,
    ),
    AiEmotion.thinking: BannerEmotionConfig(
      starColor: Color(0xFFD4FFFA),
      lineColor: Color(0xFF00D4B8),
      starCount: 80,
      speed: 0.9,
    ),
    AiEmotion.speaking: BannerEmotionConfig(
      starColor: Color(0xFFC0C8FF),
      lineColor: Color(0xFF6060F0),
      starCount: 75,
      speed: 1.5,
    ),
    AiEmotion.happy: BannerEmotionConfig(
      starColor: Color(0xFFB0FFCC),
      lineColor: Color(0xFF00E070),
      starCount: 85,
      speed: 1.4,
    ),
    AiEmotion.surprised: BannerEmotionConfig(
      starColor: Color(0xFFFFF0A0),
      lineColor: Color(0xFFE0A000),
      starCount: 90,
      speed: 2.0,
    ),
    AiEmotion.calm: BannerEmotionConfig(
      starColor: Color(0xFFB0CCFF),
      lineColor: Color(0xFF3060D0),
      starCount: 60,
      speed: 0.4,
    ),
    AiEmotion.error: BannerEmotionConfig(
      starColor: Color(0xFFFFB0B0),
      lineColor: Color(0xFFE03030),
      starCount: 80,
      speed: 1.8,
    ),
  };
}
