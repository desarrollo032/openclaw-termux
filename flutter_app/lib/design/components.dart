import 'package:flutter/material.dart';
import 'tokens.dart';

// ─────────────────────────────────────────────
// Componentes reutilizables del Design System
// ─────────────────────────────────────────────

/// Botón de acción con icono — reemplaza el patrón _iconButton duplicado
class IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final Color? color;

  const IconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusTokens.sm + 1),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm - 1),
          child: Icon(
            icon,
            size: size,
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Badge de estado unificado (verde = activo, ámbar = cargando, rojo = error, gris = detenido)
class StatusBadge extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;

  const StatusBadge({
    super.key,
    required this.color,
    required this.label,
    required this.icon,
  });

  /// Crea un StatusBadge automáticamente según un estado booleano
  factory StatusBadge.active(String label) => StatusBadge(
        color: AppColors.statusGreen,
        label: label,
        icon: Icons.check_circle,
      );

  factory StatusBadge.loading(String label) => StatusBadge(
        color: AppColors.statusAmber,
        label: label,
        icon: Icons.hourglass_top,
      );

  factory StatusBadge.error(String label) => StatusBadge(
        color: AppColors.statusRed,
        label: label,
        icon: Icons.error_outline,
      );

  factory StatusBadge.inactive(String label) => StatusBadge(
        color: AppColors.statusGrey,
        label: label,
        icon: Icons.circle_outlined,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md - 2,
        vertical: Spacing.sm + 1,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(RadiusTokens.pill),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: Spacing.sm - 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado de sección consistente — icono + label en mayúsculas
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: Spacing.xs,
        bottom: Spacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.sm - 2),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenedor de sección con borde sutil — envuelve children en un Card
class SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SettingsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(icon: icon, title: title),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: List.generate(children.length, (i) {
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1),
                  children[i],
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Fila de información clave:valor — para mostrar datos del sistema
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      value,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
    return ListTile(
      leading: Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: text,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
    );
  }
}

/// Skeleton animado para estados de carga — placeholder que pulsa
class SkeletonCard extends StatefulWidget {
  final double height;
  final double width;

  const SkeletonCard({
    super.key,
    this.height = 80,
    this.width = double.infinity,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Card(
          child: Container(
            height: widget.height,
            width: widget.width,
            padding: const EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface
                        .withAlpha((_animation.value * 255).round()),
                    borderRadius: BorderRadius.circular(RadiusTokens.md),
                  ),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 14,
                        width: 140,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface
                              .withAlpha((_animation.value * 255).round()),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Container(
                        height: 10,
                        width: 200,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface
                              .withAlpha((_animation.value * 180).round()),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Estado vacío con icono, texto y acción opcional
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.lg + 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(RadiusTokens.xl),
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.primary.withAlpha(120),
              ),
            ),
            const SizedBox(height: Spacing.xl),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Spacing.xl),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// InfoBox — contenedor con color de fondo para mostrar información contextual
class InfoBox extends StatelessWidget {
  final IconData icon;
  final Widget child;
  final Color? color;

  const InfoBox({
    super.key,
    required this.icon,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: c.withAlpha(8),
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        border: Border.all(color: c.withAlpha(25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: Spacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Estado de error con icono y mensaje
class ErrorBox extends StatelessWidget {
  final String message;

  const ErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withAlpha(15),
        borderRadius: BorderRadius.circular(RadiusTokens.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card clickeable con micro-interacción de escala al presionar
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Card(
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
          onTapUp: widget.onTap != null ? (_) => _controller.reverse() : null,
          onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          child: widget.child,
        ),
      ),
    );
  }
}
