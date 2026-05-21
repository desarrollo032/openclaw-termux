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
      circleChild = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white,
          value: effectiveProgress,
        ),
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
        : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              boxShadow: isActive || isComplete
                  ? [
                      BoxShadow(
                        color: circleColor.withAlpha(60),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: circleChild,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
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
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                  child: Text(label),
                ),
                if (isActive && progress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress! > 0.0 ? progress : null,
                      minHeight: 4,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  if (progress! > 0.0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${(progress! * 100).toInt()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
