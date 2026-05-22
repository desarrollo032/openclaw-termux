import 'package:flutter/material.dart';
import '../app.dart';

class ProgressStep extends StatelessWidget {
  final int stepNumber;
  final String label;
  final bool isActive;
  final bool isComplete;
  final bool hasError;
  final double? progress;

  const ProgressStep({
    super.key,
    required this.stepNumber,
    required this.label,
    this.isActive = false,
    this.isComplete = false,
    this.hasError = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color circleColor;
    Widget circleChild;

    if (hasError) {
      circleColor = theme.colorScheme.error;
      circleChild = const Icon(Icons.close, color: Colors.white, size: 14);
    } else if (isComplete) {
      circleColor = AppColors.statusGreen;
      circleChild = const Icon(Icons.check, color: Colors.white, size: 14);
    } else if (isActive) {
      circleColor = theme.colorScheme.primary;
      final effectiveProgress = (progress != null && progress! > 0.0) ? progress : null;
      circleChild = Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
              value: effectiveProgress,
              backgroundColor: Colors.white.withAlpha(60),
            ),
          ),
          if (effectiveProgress != null)
            Text(
              '${(effectiveProgress * 100).toInt()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      );
    } else {
      circleColor = theme.colorScheme.surfaceContainerHighest;
      circleChild = Text(
        '$stepNumber',
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final bgColor = isActive
        ? theme.colorScheme.primary.withAlpha(8)
        : hasError
            ? theme.colorScheme.error.withAlpha(6)
            : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(
                color: theme.colorScheme.primary.withAlpha(20),
              )
            : hasError
                ? Border.all(
                    color: theme.colorScheme.error.withAlpha(20),
                  )
                : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circle indicator with glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              boxShadow: isActive || isComplete
                  ? [
                      BoxShadow(
                        color: circleColor.withAlpha(isActive ? 80 : 50),
                        blurRadius: isActive ? 14 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : hasError
                      ? [
                          BoxShadow(
                            color: circleColor.withAlpha(50),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
            ),
            alignment: Alignment.center,
            child: _PulsingWidget(
              isPulsing: isActive,
              child: circleChild,
            ),
          ),
          const SizedBox(width: 14),
          // Label and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: (theme.textTheme.bodyMedium ?? theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
                    fontWeight: isActive
                        ? FontWeight.w600
                        : isComplete
                            ? FontWeight.w500
                            : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.onSurface
                        : isComplete
                            ? theme.colorScheme.onSurface.withAlpha(200)
                            : hasError
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                  child: Text(label),
                ),
                // Animated progress bar
                _AnimatedProgressSection(
                  isActive: isActive,
                  progress: progress,
                  theme: theme,
                ),
              ],
            ),
          ),
          // Error/Complete badge
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.error_outline,
                size: 18,
                color: theme.colorScheme.error,
              ),
            ),
        ],
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
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
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
      firstChild: const SizedBox(height: 0),
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
                  final isDark = theme.brightness == Brightness.dark;
                  return LinearProgressIndicator(
                    value: value > 0.0 ? value : null,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF6C63FF),
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
                    Text(
                      '${(progress! * 100).clamp(0, 100).toInt()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
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
