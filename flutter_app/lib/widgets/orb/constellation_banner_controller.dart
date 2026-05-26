import 'package:flutter/material.dart';
import 'ai_orb_controller.dart';
import 'constellation_banner.dart';
import 'constellation_painter.dart' show ActiveLine;
import 'constellation_star.dart';
import 'emotion_color_map.dart';

/// Singleton controller for the [ConstellationBanner].
///
/// Usage:
/// ```dart
/// // Initialize once after MaterialApp is mounted
/// ConstellationBannerController.instance.init(context);
///
/// // Show a banner
/// ConstellationBannerController.instance.show(
///   emotion: AiEmotion.thinking,
///   text: 'Procesando...',
/// );
///
/// // Update audio level (call from TTS callback)
/// ConstellationBannerController.instance.setAudioLevel(0.72);
///
/// // Hide manually
/// ConstellationBannerController.instance.hide();
/// ```
class ConstellationBannerController {
  // ── Singleton ──
  ConstellationBannerController._();
  static final ConstellationBannerController instance =
      ConstellationBannerController._();

  // ── State ──
  OverlayEntry? _overlayEntry;
  BuildContext? _context;
  bool _isVisible = false;

  // Current values
  String _currentText = '';
  BannerEmotionConfig _currentConfig =
      BannerEmotionConfig.emotions[AiEmotion.idle]!;
  List<ConstellationStar> _stars = [];
  List<ActiveLine> _activeLines = [];
  int _tick = 0;
  double _audioLevel = 0.0;

  // Tick controller (100ms repeat)
  AnimationController? _tickController;

  // Entrance/exit animation controller (300ms)
  AnimationController? _animController;
  Animation<Offset>? _slideAnim;
  Animation<double>? _fadeAnim;

  /// Whether the banner is currently visible.
  bool get isVisible => _isVisible;

  /// Initialize with a [BuildContext] from inside the MaterialApp's Navigator tree.
  /// Call once from an [initState] or post-frame callback.
  void init(BuildContext context) {
    _context = context;
  }

  /// Show the constellation banner with the given [emotion] and [text].
  /// Optional [autoDismiss] hides the banner after the duration.
  void show({
    required AiEmotion emotion,
    String text = '',
    Duration autoDismiss = const Duration(seconds: 6),
  }) {
    if (_context == null) return;

    hide(); // Remove any existing overlay first

    _currentText = text;
    _currentConfig = BannerEmotionConfig.emotions[emotion]!;

    // Generate fresh stars and pre-compute connections
    _stars =
        ConstellationStar.generate(_currentConfig.starCount, seed: 42);
    _recalculateConnections();
    _tick = 0;
    _audioLevel = 0.0;

    final overlay = Overlay.of(_context!);

    // Entrance animation (300ms slide + fade)
    _animController = AnimationController(
      vsync: overlay,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController!,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animController!,
      curve: Curves.easeOutCubic,
    ));

    // Tick controller — drives star updates + repaint
    _tickController = AnimationController(
      vsync: overlay,
      duration: const Duration(milliseconds: 100),
    );

    _tickController!.addListener(_onTick);

    _overlayEntry = OverlayEntry(
      builder: (_) => _buildBanner(),
    );

    overlay.insert(_overlayEntry!);
    _animController!.forward();
    _tickController!.repeat();
    _isVisible = true;

    // Auto-dismiss
    if (autoDismiss > Duration.zero) {
      Future.delayed(autoDismiss, () {
        if (_isVisible) hide();
      });
    }
  }

  /// Hide the banner with a reverse animation (300ms).
  void hide() {
    if (!_isVisible || _animController == null) return;

    _tickController?.stop();
    _tickController?.removeListener(_onTick);

    _animController!.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isVisible = false;
      _tickController?.dispose();
      _tickController = null;
      _animController?.dispose();
      _animController = null;
    });
  }

  /// Update the audio level in real time (call from TTS callback, ~50ms).
  void setAudioLevel(double level) {
    _audioLevel = level.clamp(0.0, 1.0);
  }

  /// Called every tick (~100ms): advance star positions and
  /// recalculate connections every 90 ticks for performance.
  void _onTick() {
    _tick++;
    final speed = _currentConfig.speed;
    for (final star in _stars) {
      star.update(speed);
    }
    // Recalculate connections every 90 ticks (avoids O(n²) every frame)
    if (_tick % 90 == 0) {
      _recalculateConnections();
    }
    _overlayEntry?.markNeedsBuild();
  }

  /// Pre-compute active line connections from the first 60 stars.
  void _recalculateConnections() {
    _activeLines = [];
    final limit = 60 < _stars.length ? 60 : _stars.length;
    for (int i = 0; i < limit; i++) {
      for (int j = i + 1; j < _stars.length; j++) {
        // Quick approximate check in normalized space to reduce work
        final dx = (_stars[i].x - _stars[j].x).abs();
        final dy = (_stars[i].y - _stars[j].y).abs();
        // Normalized max dist: 70px / banner width (assume ~400px) ≈ 0.175
        // Use a slightly larger threshold to be safe
        if (dx < 0.2 && dy < 0.2) {
          _activeLines.add(ActiveLine(i, j));
        }
      }
    }
  }

  /// Build the banner widget with entrace animation, constellation, and text.
  Widget _buildBanner() {
    return SlideTransition(
      position: _slideAnim!,
      child: FadeTransition(
        opacity: _fadeAnim!,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            bottom: false,
            child: ConstellationBanner(
              stars: _stars,
              tick: _tick,
              starColor: _currentConfig.starColor,
              lineColor: _currentConfig.lineColor,
              audioLevel: _audioLevel,
              activeLines: _activeLines,
              text: _currentText,
            ),
          ),
        ),
      ),
    );
  }
}
