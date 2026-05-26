import 'dart:async';

enum AiEmotion {
  idle,
  listening,
  thinking,
  speaking,
  happy,
  surprised,
  calm,
  error;

  /// Parse from lowercase string (e.g. "happy", "listening")
  static AiEmotion fromString(String value) {
    return AiEmotion.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AiEmotion.idle,
    );
  }
}

/// Emotion visual configuration for the orb.
class EmotionConfig {
  final int primaryColor;
  final int secondaryColor;
  final double waveAmplitude;
  final double waveSpeed;
  final double particleSpeed;
  final double haloIntensity;
  final double pulseMin;
  final double pulseMax;

  const EmotionConfig({
    required this.primaryColor,
    required this.secondaryColor,
    this.waveAmplitude = 6.0,
    this.waveSpeed = 1.0,
    this.particleSpeed = 1.0,
    this.haloIntensity = 0.3,
    this.pulseMin = 0.95,
    this.pulseMax = 1.05,
  });

  static const Map<AiEmotion, EmotionConfig> emotions = {
    AiEmotion.idle: EmotionConfig(
      primaryColor: 0xFF64748B,
      secondaryColor: 0xFF475569,
      waveAmplitude: 2.0,
      waveSpeed: 0.5,
      particleSpeed: 0.3,
      haloIntensity: 0.15,
      pulseMin: 0.97,
      pulseMax: 1.03,
    ),
    AiEmotion.listening: EmotionConfig(
      primaryColor: 0xFF06B6D4,
      secondaryColor: 0xFF0891B2,
      waveAmplitude: 8.0,
      waveSpeed: 1.5,
      particleSpeed: 1.5,
      haloIntensity: 0.4,
      pulseMin: 0.96,
      pulseMax: 1.04,
    ),
    AiEmotion.thinking: EmotionConfig(
      primaryColor: 0xFF8B5CF6,
      secondaryColor: 0xFF7C3AED,
      waveAmplitude: 5.0,
      waveSpeed: 1.8,
      particleSpeed: 2.0,
      haloIntensity: 0.5,
      pulseMin: 0.95,
      pulseMax: 1.06,
    ),
    AiEmotion.speaking: EmotionConfig(
      primaryColor: 0xFF6366F1,
      secondaryColor: 0xFF4F46E5,
      waveAmplitude: 14.0,
      waveSpeed: 2.2,
      particleSpeed: 1.8,
      haloIntensity: 0.6,
      pulseMin: 0.94,
      pulseMax: 1.06,
    ),
    AiEmotion.happy: EmotionConfig(
      primaryColor: 0xFF10B981,
      secondaryColor: 0xFF059669,
      waveAmplitude: 10.0,
      waveSpeed: 2.5,
      particleSpeed: 3.0,
      haloIntensity: 0.5,
      pulseMin: 0.93,
      pulseMax: 1.08,
    ),
    AiEmotion.surprised: EmotionConfig(
      primaryColor: 0xFFF59E0B,
      secondaryColor: 0xFFD97706,
      waveAmplitude: 18.0,
      waveSpeed: 3.0,
      particleSpeed: 2.5,
      haloIntensity: 0.7,
      pulseMin: 0.90,
      pulseMax: 1.10,
    ),
    AiEmotion.calm: EmotionConfig(
      primaryColor: 0xFF3B82F6,
      secondaryColor: 0xFF2563EB,
      waveAmplitude: 3.0,
      waveSpeed: 0.6,
      particleSpeed: 0.5,
      haloIntensity: 0.2,
      pulseMin: 0.98,
      pulseMax: 1.02,
    ),
    AiEmotion.error: EmotionConfig(
      primaryColor: 0xFFEF4444,
      secondaryColor: 0xFFDC2626,
      waveAmplitude: 16.0,
      waveSpeed: 2.8,
      particleSpeed: 1.2,
      haloIntensity: 0.5,
      pulseMin: 0.92,
      pulseMax: 1.08,
    ),
  };
}

/// Controller for the AiEmotionOrb widget.
/// Manages emotion state and audio level, exposing streams for reactive UI.
class AiOrbController {
  final _emotionController = StreamController<AiEmotion>.broadcast();
  final _audioLevelController = StreamController<double>.broadcast();
  final _burstController = StreamController<void>.broadcast();

  AiEmotion _currentEmotion = AiEmotion.idle;
  double _currentAudioLevel = 0.0;

  /// Stream of emotion changes.
  Stream<AiEmotion> get emotionStream => _emotionController.stream;

  /// Stream of audio level changes (0.0–1.0).
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  /// Stream that fires once on emotion transitions (for burst animation).
  Stream<void> get burstStream => _burstController.stream;

  /// Current emotion value.
  AiEmotion get currentEmotion => _currentEmotion;

  /// Current audio level value.
  double get currentAudioLevel => _currentAudioLevel;

  /// Set the current emotion. Fires [emotionStream] and [burstStream] if changed.
  void setEmotion(AiEmotion emotion) {
    if (emotion == _currentEmotion) return;
    _currentEmotion = emotion;
    _emotionController.add(emotion);
    _burstController.add(null);
  }

  /// Set the current audio level (clamped 0.0–1.0). Fires [audioLevelStream].
  void setAudioLevel(double level) {
    final clamped = level.clamp(0.0, 1.0);
    if (clamped == _currentAudioLevel) return;
    _currentAudioLevel = clamped;
    _audioLevelController.add(clamped);
  }

  /// Set emotion from a lowercase string (e.g. "happy", "speaking").
  void setEmotionFromString(String value) {
    setEmotion(AiEmotion.fromString(value));
  }

  /// Clean up resources.
  void dispose() {
    _emotionController.close();
    _audioLevelController.close();
    _burstController.close();
  }
}
