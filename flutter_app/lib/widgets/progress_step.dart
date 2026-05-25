import 'package:flutter/material.dart';
import '../app.dart';

class ProgressStep extends StatelessWidget {
  final int stepNumber;
  final String label;
  final bool isActive;
  final bool isComplete;
  final bool hasError;
  final double? progress;
  final bool isLast;

  const ProgressStep({
    super.key,
    required this.stepNumber,
    required this.label,
    this.isActive = false,
    this.isComplete = false,
    this.hasError = false,
    this.progress,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Color indicatorColor;
    Widget indicatorChild;

    if (hasError) {
      indicatorColor = AppColors.statusRed;
      indicatorChild = const Icon(Icons.close_rounded, color: Colors.white, size: 14);
    } else if (isComplete) {
      indicatorColor = AppColors.statusGreen;
      indicatorChild = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
    } else if (isActive) {
      indicatorColor = cs.primary;
      final effectiveProgress = (progress != null && progress! > 0.0) ? progress : null;
      indicatorChild = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white,
          value: effectiveProgress,
          backgroundColor: Colors.white.withAlpha(60),
        ),
      );
    } else {
      indicatorColor = cs.surfaceContainerHighest;
      indicatorChild = Text(
        '$stepNumber',
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    // Surface color using Material 3 elevation layers instead of alpha
    final bgColor = isActive
        ? cs.surfaceContainerLow
        : hasError
            ? cs.errorContainer.withAlpha(220)
            : isComplete
                ? cs.surfaceContainerLow
                : cs.surface;

    final borderColor = isActive
        ? cs.primary.withAlpha(40)
        : hasError
            ? cs.error
            : isComplete
                ? AppColors.statusGreen.withAlpha(60)
                : cs.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: (isActive || hasError) ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicator circle (compact)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: _PulsingWidget(
                isPulsing: isActive,
                child: indicatorChild,
              ),
            ),
            const SizedBox(width: 10),
            // Label and progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: theme.textTheme.bodySmall!.copyWith(
                      fontWeight: isActive
                          ? FontWeight.w600
                          : isComplete || hasError
                              ? FontWeight.w500
                              : FontWeight.normal,
                      color: isActive
                          ? cs.onSurface
                          : isComplete
                              ? cs.onSurface.withAlpha(200)
                              : hasError
                                  ? cs.error
                                  : cs.onSurfaceVariant,
                      height: 1.3,
                    ),
                    child: Text(label),
                  ),
                  _AnimatedProgressSection(
                    isActive: isActive,
                    progress: progress,
                    theme: theme,
                  ),
                ],
              ),
            ),
            // Status dot
            if (isComplete)
              const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.statusGreen)
            else if (hasError)
              Icon(Icons.error_rounded, size: 14, color: cs.error)
            else if (isActive)
              _PulseDot(color: cs.primary),
          ],
        ),
      ),
    );
  }
}

/// Widget that pulses when active
class _PulsingWidget extends StatefulWidget {
  final bool isPulsing;
  final Widget child;

  const _PulsingWidget({
    required this.isPulsing,
    required this.child,
  });

  @override
  State<_PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<_PulsingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingWidget old) {
    super.didUpdateWidget(old);
    if (widget.isPulsing && !old.isPulsing) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPulsing && old.isPulsing) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isPulsing ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Animated dot that pulses
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withAlpha(((0.3 + _animation.value * 0.7) * 255).round()),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

/// Animated section that shows/hides the progress bar
class _AnimatedProgressSection extends StatelessWidget {
  final bool isActive;
  final double? progress;
  final ThemeData theme;

  const _AnimatedProgressSection({
    required this.isActive,
    required this.progress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final showProgress = isActive && progress != null;

    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(
                  begin: 0,
                  end: (progress! > 0.0 ? progress! : 0.0).clamp(0.0, 1.0),
                ),
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value > 0.0 ? value : null,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6C63FF),
                    ),
                  );
                },
              ),
            ),
            if (progress! > 0.0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(progress! * 100).clamp(0, 100).toInt()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'completado',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      crossFadeState: showProgress
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
    );
  }
}
