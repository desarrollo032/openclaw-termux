import 'dart:async';
import 'dart:math' show min, pi;
import 'package:flutter/material.dart';
import 'ai_orb_controller.dart';
import 'ai_orb_painter.dart';
import 'constellation_particle.dart';
import 'thinking_constellation_painter.dart';

/// Emotion orb widget that reacts to AI state and audio levels.
///
/// Renders a layered animated circle with:
///  - Radial gradient core
///  - Perimeter sine wave (audio-reactive)
///  - Halo rings (3 concentric)
///  - Orbiting particles with connecting lines
///  - Radial bars (speaking state only)
///
/// When [emotion] is [AiEmotion.thinking], switches to a special
/// "constellation" visual: dark cosmic background, teal halo, 110 orbiting
/// star particles with constellation lines, and smooth entry/exit transitions.
class AiEmotionOrb extends StatefulWidget {
  /// Current emotion to display.
  final AiEmotion emotion;

  /// Stream of audio levels (0.0–1.0) for reactive animation.
  final Stream<double>? audioLevel;

  /// Desired orb diameter (default 220).
  final double size;

  /// Optional tap callback (e.g., toggle activation).
  final VoidCallback? onTap;

  /// Optional external controller to avoid rebuilding.
  final AiOrbController? controller;

  const AiEmotionOrb({
    super.key,
    this.emotion = AiEmotion.idle,
    this.audioLevel,
    this.size = 220,
    this.onTap,
    this.controller,
  });

  @override
  State<AiEmotionOrb> createState() => _AiEmotionOrbState();
}

class _AiEmotionOrbState extends State<AiEmotionOrb>
    with SingleTickerProviderStateMixin {
  late final AiOrbController _controller;
  late final AnimationController _waveController;   // 2s, repeat → wave + halo
  late final AnimationController _pulseController;  // 1.2s, repeat reverse
  late final AnimationController _particleController; // 4s, repeat

  // ── Thinking constellation state ──
  late final AnimationController _thinkingTickController;   // 6s repeat
  late final AnimationController _thinkingTransitionController; // 800ms

  /// Pre-generated constellation particles (instantiated once in [initState]).
  late final List<ConstellationParticle> _thinkingParticles;

  /// Whether the last known emotion was thinking (for transition detection).
  bool _wasThinking = false;

  // Color interpolation
  Color _currentPrimary = const Color(0xFF64748B);
  Color _targetPrimary = const Color(0xFF64748B);
  Color _currentSecondary = const Color(0xFF475569);
  Color _targetSecondary = const Color(0xFF475569);
  AiEmotion _displayedEmotion = AiEmotion.idle;
  StreamSubscription<double>? _audioSub;

  // Burst animation
  double _burstScale = 1.0; // ignore: prefer_final_fields

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? AiOrbController();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // ── Thinking controllers ──
    _thinkingTickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _thinkingTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Generate 110 constellation particles once
    _thinkingParticles = ConstellationParticle.generate(110, seed: 42);
    _updateColors(widget.emotion);

    // Subscribe to external audio level stream
    if (widget.audioLevel != null) {
      _audioSub = widget.audioLevel!.listen((level) {
        _controller.setAudioLevel(level);
      });
    }

    // Listen for emotion changes → trigger thinking transitions
    _controller.emotionStream.listen((emotion) {
      if (!mounted) return;
      if (emotion == AiEmotion.thinking && !_wasThinking) {
        // Entering thinking
        _thinkingTransitionController.forward(from: 0.0);
        _wasThinking = true;
      } else if (_wasThinking && emotion != AiEmotion.thinking) {
        // Exiting thinking
        _thinkingTransitionController.reverse(from: 1.0);
        _wasThinking = false;
      }
    });
  }

  @override
  void didUpdateWidget(AiEmotionOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emotion != widget.emotion) {
      _updateColors(widget.emotion);
    }
    if (oldWidget.audioLevel != widget.audioLevel) {
      _audioSub?.cancel();
      if (widget.audioLevel != null) {
        _audioSub = widget.audioLevel!.listen((level) {
          _controller.setAudioLevel(level);
        });
      }
    }
  }

  void _updateColors(AiEmotion emotion) {
    final cfg = EmotionConfig.emotions[emotion]!;
    _targetPrimary = Color(cfg.primaryColor);
    _targetSecondary = Color(cfg.secondaryColor);
    _displayedEmotion = emotion;
    setState(() {});
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _waveController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _thinkingTickController.dispose();
    _thinkingTransitionController.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _waveController,
          _pulseController,
          _particleController,
          _thinkingTickController,
          _thinkingTransitionController,
        ]),
        builder: (context, _) {
          // Smooth color interpolation (600ms transition)
          _currentPrimary = Color.lerp(_currentPrimary, _targetPrimary, 0.04)!;
          _currentSecondary =
              Color.lerp(_currentSecondary, _targetSecondary, 0.04)!;

          // If colors are close enough, snap to target
          if (_currentPrimary != _targetPrimary &&
              (_currentPrimary.computeLuminance() -
                      _targetPrimary.computeLuminance())
                  .abs() <
                  0.02) {
            _currentPrimary = _targetPrimary;
            _currentSecondary = _targetSecondary;
          }

          final audioLevel = _controller.currentAudioLevel;
          final waveTime = _waveController.value * 2 * pi;
          final pulseValue = _pulseController.value;
          final particleTime = _particleController.value * 2 * pi;
          final haloTime = _waveController.value * 2 * pi * 0.5;

          final cfg = EmotionConfig.emotions[_displayedEmotion]!;
          // Manual lerp to avoid import issues across Flutter versions
          final pulseScale =
              (cfg.pulseMin + (cfg.pulseMax - cfg.pulseMin) * pulseValue) *
                  _burstScale;

          // ── Determine if we should show the thinking constellation ──
          final transitionValue = _thinkingTransitionController.value;
          // Show constellation if:
          //   a) We are currently in thinking state, OR
          //   b) The exit transition is still animating (fading out)
          final bool showThinking = _displayedEmotion == AiEmotion.thinking ||
              (_thinkingTransitionController.status ==
                      AnimationStatus.reverse &&
                  transitionValue > 0);

          // true → entering thinking; false → exiting thinking
          final bool isEntering = _displayedEmotion == AiEmotion.thinking;

          if (showThinking) {
            final baseRadius = min(widget.size, widget.size) / 2 * 0.7;
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: ThinkingConstellationPainter(
                tick: _thinkingTickController.value * 6000,
                transitionValue: transitionValue,
                isEntering: isEntering,
                orbRadius: baseRadius,
                pulseScale: pulseScale,
                particles: _thinkingParticles,
              ),
            );
          }

          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: OrbPainter(
              emotion: _displayedEmotion,
              audioLevel: audioLevel,
              waveTime: waveTime,
              pulseScale: pulseScale,
              particleTime: particleTime,
              haloTime: haloTime,
              primaryColor: _currentPrimary,
              secondaryColor: _currentSecondary,
              config: cfg,
            ),
          );
        },
      ),
    );
  }
}

/// Example usage screen with a demo orb and controls,
/// plus a WebSocket connection to the Kotlin orb server.
class OrbDemoScreen extends StatefulWidget {
  const OrbDemoScreen({super.key});

  @override
  State<OrbDemoScreen> createState() => _OrbDemoScreenState();
}

class _OrbDemoScreenState extends State<OrbDemoScreen> {
  final _controller = AiOrbController();
  AiEmotion _currentEmotion = AiEmotion.idle;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Emotion Orb')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Orb
            AiEmotionOrb(
              emotion: _currentEmotion,
              controller: _controller,
              size: 220,
              onTap: () {
                // Cycle through emotions on tap
                final next =
                    AiEmotion.values[(_currentEmotion.index + 1) %
                        AiEmotion.values.length];
                setState(() => _currentEmotion = next);
                _controller.setEmotion(next);
              },
            ),
            const SizedBox(height: 24),
            // Message
            Text(
              _currentEmotion.name.toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the orb to cycle emotions\n'
              'Audio level: ${(_controller.currentAudioLevel * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Emotion buttons row
            SizedBox(
              width: 300,
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: AiEmotion.values.map((emotion) {
                  final cfg = EmotionConfig.emotions[emotion]!;
                  final isActive = _currentEmotion == emotion;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(emotion.name,
                          style: const TextStyle(fontSize: 11)),
                      selected: isActive,
                      selectedColor:
                          Color(cfg.primaryColor).withAlpha(60),
                      onSelected: (_) {
                        setState(() => _currentEmotion = emotion);
                        _controller.setEmotion(emotion);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            // Audio slider
            SizedBox(
              width: 200,
              child: Slider(
                value: _controller.currentAudioLevel,
                onChanged: (v) => _controller.setAudioLevel(v),
                max: 1.0,
                label: 'Audio Level',
              ),
            ),
            Text(
              'Audio level',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
