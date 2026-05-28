import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import '../models/optional_package.dart';
import '../providers/setup_provider.dart';
import '../services/package_service.dart';
import '../widgets/live_console_widget.dart';
import 'onboarding_screen.dart';
import 'package_install_screen.dart';

// ─── Phase definitions ───────────────────────────────────────────────────────

class _SetupPhase {
  final String name;
  final IconData icon;
  final Color color;
  final List<_StepInfo> steps;
  final int startIndex;

  const _SetupPhase({
    required this.name,
    required this.icon,
    required this.color,
    required this.steps,
    required this.startIndex,
  });
}

class _StepInfo {
  final int number;
  final SetupStep step;
  const _StepInfo(this.number, this.step);
}

const _phases = [
  _SetupPhase(
    name: 'Descarga',
    icon: Icons.cloud_download_rounded,
    color: Color(0xFF6C63FF),
    steps: [
      _StepInfo(1, SetupStep.downloadingRootfs),
      _StepInfo(2, SetupStep.extractingRootfs),
    ],
    startIndex: 1,
  ),
  _SetupPhase(
    name: 'Instalación',
    icon: Icons.build_rounded,
    color: Color(0xFF22C55E),
    steps: [
      _StepInfo(3, SetupStep.installingNode),
      _StepInfo(4, SetupStep.installingOpenClaw),
    ],
    startIndex: 3,
  ),
  _SetupPhase(
    name: 'Configuración',
    icon: Icons.tune_rounded,
    color: Color(0xFFF59E0B),
    steps: [
      _StepInfo(5, SetupStep.configuringBypass),
    ],
    startIndex: 5,
  ),
];

// ─── Animated background particles ───────────────────────────────────────────

class _BackgroundParticles extends StatefulWidget {
  final bool isDark;
  const _BackgroundParticles({required this.isDark});

  @override
  State<_BackgroundParticles> createState() => _BackgroundParticlesState();
}

class _BackgroundParticlesState extends State<_BackgroundParticles>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  final _particles = List<_Particle>.generate(12, (_) => _Particle());
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            progress: _controller.value,
            isDark: widget.isDark,
            random: _random,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  double x = 0;
  double y = 0;
  double size = 0;
  double speedX = 0;
  double speedY = 0;
  double opacity = 0;
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final bool isDark;
  final Random random;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.isDark,
    required this.random,
  }) {
    for (final p in particles) {
      if (p.size == 0) {
        p.x = random.nextDouble();
        p.y = random.nextDouble();
        p.size = 2 + random.nextDouble() * 3;
        p.speedX = (random.nextDouble() - 0.5) * 0.006;
        p.speedY = (random.nextDouble() - 0.5) * 0.006;
        p.opacity = 0.08 + random.nextDouble() * 0.12;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final x = ((p.x + progress * p.speedX) % 1.0) * size.width;
      final y = ((p.y + progress * p.speedY) % 1.0) * size.height;
      paint.color = (isDark ? Colors.white : const Color(0xFF6C63FF))
          .withAlpha((p.opacity * 255).round());
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  bool _started = false;
  Map<String, bool> _pkgStatuses = {};

  Future<void> _refreshPkgStatuses() async {
    final statuses = await PackageService.checkAllStatuses();
    if (mounted) setState(() => _pkgStatuses = statuses);
  }

  Future<void> _installPackage(OptionalPackage package) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PackageInstallScreen(package: package),
      ),
    );
    if (result == true) _refreshPkgStatuses();
  }

  double _overallProgress(SetupState state) {
    if (state.isComplete) return 1.0;
    if (state.step == SetupStep.error) return -1;

    const totalSteps = 5.0;
    final stepIndex = SetupStep.values.indexOf(state.step);
    if (stepIndex < 0) return 0.0;

    final stepContribution = stepIndex / totalSteps;
    final withinStep = state.progress.clamp(0.0, 0.99) / totalSteps;
    return (stepContribution + withinStep).clamp(0.0, 0.99);
  }

  String? _currentPhaseName(SetupState state) {
    for (final phase in _phases) {
      for (final stepInfo in phase.steps) {
        if (state.step == stepInfo.step) return phase.name;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0A0A0F),
                    const Color(0xFF0D0D12),
                    const Color(0xFF08080C),
                  ]
                : [
                    const Color(0xFFEBE6F8),
                    const Color(0xFFE2DCF5),
                    const Color(0xFFD8D1EE),
                  ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background particles
            Positioned.fill(
              child: IgnorePointer(
                child: _BackgroundParticles(isDark: isDark),
              ),
            ),
            // Main content
            SafeArea(
              child: Consumer<SetupProvider>(
                builder: (context, provider, _) {
                  final state = provider.state;

                  // Refresh package statuses on completion
                  if (state.isComplete && _pkgStatuses.isEmpty) {
                    _refreshPkgStatuses();
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Column(
                      children: [
                        const SizedBox(height: Spacing.sm),
                        // ── Header ──
                        _buildHeader(theme, cs, state, isDark),
                        const SizedBox(height: Spacing.sm + 2),

                        // ── Main content area ──
                        Expanded(
                          child: _buildContentArea(
                            state, provider, theme, cs, isDark,
                          ),
                        ),

                        // ── Error card ──
                        if (state.hasError) ...[
                          const SizedBox(height: Spacing.sm),
                          ErrorBox(
                            message: state.error ?? 'Error desconocido',
                          ),
                        ],

                        const SizedBox(height: Spacing.sm),

                        // ── Action buttons ──
                        _buildActions(provider, state, theme, cs),

                        const SizedBox(height: Spacing.sm - 2),

                        // ── Footer ──
                        Center(
                          child: Text(
                            '${AppConstants.orgName}/openclaw-termux',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withAlpha(100),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme, ColorScheme cs, SetupState state, bool isDark) {
    String subtitle;
    Color subtitleColor;

    if (_started && !state.isComplete && !state.hasError) {
      final phaseName = _currentPhaseName(state);
      subtitle = phaseName != null
          ? 'Instalando: $phaseName...'
          : 'Instalando...';
      subtitleColor = cs.primary;
    } else if (state.isComplete) {
      subtitle = '¡Instalación completada!';
      subtitleColor = AppColors.statusGreen;
    } else if (state.hasError) {
      subtitle = 'Error en la instalación';
      subtitleColor = cs.error;
    } else if (!_started) {
      subtitle = 'Proot: Ubuntu rootfs + Node.js + OpenClaw';
      subtitleColor = cs.onSurfaceVariant;
    } else {
      subtitle = 'Preparando instalación...';
      subtitleColor = cs.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : Colors.transparent,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        border: Border.all(
          color: isDark
              ? cs.outlineVariant.withAlpha(80)
              : cs.outlineVariant.withAlpha(160),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(RadiusTokens.md + 2),
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 22, color: cs.primary),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configurar OpenClaw',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: Spacing.xs - 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppDurations.normal, curve: Curves.easeOut);
  }

  // ─── Content Area ─────────────────────────────────────────────────────────

  Widget _buildContentArea(
    SetupState state,
    SetupProvider provider,
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
  ) {
    if (state.isComplete) {
      return _buildCompletionContent(theme, cs, isDark);
    }

    if (!_started) {
      return _buildPreInstallInfo(theme, cs, isDark);
    }

    // During active installation: compact steps header + live console
    return Column(
      children: [
        // Compact phase/step indicators at the top
        if (state.step != SetupStep.checkingStatus && !state.hasError)
          _buildCompactSteps(state, theme, cs, isDark),

        // Live console fills remaining space
        Expanded(
          child: _buildConsoleSection(provider, cs, isDark),
        ),
      ],
    );
  }

  // ─── Pre-install info ──────────────────────────────────────────────────────

  Widget _buildPreInstallInfo(ThemeData theme, ColorScheme cs, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainerLow.withAlpha(200) : Colors.transparent,
            borderRadius: BorderRadius.circular(RadiusTokens.xl),
            border: Border.all(
              color: isDark
                  ? cs.outlineVariant.withAlpha(60)
                  : cs.outlineVariant.withAlpha(160),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(Spacing.md + 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withAlpha(120),
                      cs.primary.withAlpha(60),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(RadiusTokens.xl - 4),
                ),
                child: Icon(
                  Icons.vpn_lock_rounded,
                  size: 40,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: Spacing.xl),

              Text(
                'Instalación Proot',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: Spacing.sm),

              Text(
                  'Este proceso descargara e instalara un rootfs Ubuntu 24.04 '
                  'completo, Node.js y OpenClaw mediante proot.\n\n'
                  '• ~500 MB de descarga\n'
                  '• Conexion a internet requerida\n'
                  '• El proceso puede tomar 10-20 minutos',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),

              const SizedBox(height: Spacing.xl),

              // What will be installed - compact cards
              _buildInstallItem(
                Icons.cloud_download_rounded,
                'Ubuntu 24.04 Base',
                'Sistema ARM64 completo',
                const Color(0xFFE55E2B),
                theme, cs,
              ),
              const SizedBox(height: Spacing.sm),
              _buildInstallItem(
                Icons.javascript_rounded,
                'Node.js 22',
                'Entorno JavaScript',
                const Color(0xFF22C55E),
                theme, cs,
              ),
              const SizedBox(height: Spacing.sm),
              _buildInstallItem(
                Icons.auto_awesome_rounded,
                'OpenClaw',
                'AI Gateway',
                const Color(0xFFF59E0B),
                theme, cs,
              ),

              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: AppDurations.normal, curve: Curves.easeOut);
  }

  Widget _buildInstallItem(
    IconData icon,
    String name,
    String desc,
    Color color,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final isLight = theme.brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm + 4, vertical: Spacing.sm + 2),
      decoration: BoxDecoration(
        color: color.withAlpha(isLight ? 12 : 8),
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        border: Border.all(color: color.withAlpha(isLight ? 30 : 20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Spacing.sm + 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Compact steps during installation ────────────────────────────────────

  Widget _buildCompactSteps(
    SetupState state,
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
  ) {
    final phaseName = _currentPhaseName(state);
    final progress = _overallProgress(state);

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm + 2),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : Colors.transparent,
        borderRadius: BorderRadius.circular(RadiusTokens.md + 2),
        border: Border.all(
          color: isDark
              ? cs.outlineVariant.withAlpha(80)
              : cs.outlineVariant.withAlpha(160),
        ),
      ),
      child: Row(
        children: [
          if (phaseName != null)
            Container(
              padding: const EdgeInsets.all(Spacing.xs + 2),
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(Spacing.sm),
              ),
              child: Icon(Icons.play_circle_rounded, size: 18, color: cs.primary),
            ),
          if (phaseName != null) const SizedBox(width: Spacing.sm + 2),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (phaseName != null)
                  Text(
                    'Fase: $phaseName',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: cs.onSurface,
                    ),
                  ),
                const SizedBox(height: Spacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: TweenAnimationBuilder<double>(
                    duration: AppDurations.normal,
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(
                      begin: 0,
                      end: progress.clamp(0.0, 1.0),
                    ),
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(3),
                        backgroundColor: cs.surfaceContainerHighest,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: Spacing.sm),

          // Percentage
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xs + 1, vertical: Spacing.xs - 2),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(RadiusTokens.sm - 2),
            ),
            child: Text(
              '${(progress.clamp(0.0, 1.0) * 100).toInt()}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),

          Text(
            'Paso ${state.stepNumber}/${SetupState.totalSteps}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Live Console ─────────────────────────────────────────────────────────

  Widget _buildConsoleSection(
    SetupProvider provider,
    ColorScheme cs,
    bool isDark,
  ) {
    return Column(
      children: [
        Expanded(
          child: LiveConsoleWidget(logs: provider.logs, isDark: isDark),
        ),
        if (provider.logs.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: cs.onSurfaceVariant.withAlpha(100),
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  'Consola en vivo',
                  style: TextStyle(
                    color: cs.onSurfaceVariant.withAlpha(100),
                    fontSize: 10,
                    fontFamily: 'DejaVuSansMono',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Completion content ────────────────────────────────────────────────────

  Widget _buildCompletionContent(ThemeData theme, ColorScheme cs, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: Spacing.sm),
          _buildCompletionCelebration(theme, cs, isDark),
          const SizedBox(height: Spacing.xl),
          // Log console in compact mode
          SizedBox(
            height: 180,
            child: Consumer<SetupProvider>(
              builder: (context, provider, _) {
                return LiveConsoleWidget(logs: provider.logs, isDark: isDark);
              },
            ),
          ),
          const SizedBox(height: Spacing.xl),
          _buildOptionalPackagesSection(theme, cs, isDark),
        ],
      ),
    );
  }

  // ─── Celebration ──────────────────────────────────────────────────────────

  Widget _buildCompletionCelebration(ThemeData theme, ColorScheme cs, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl, horizontal: Spacing.md + 4),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : Colors.transparent,
        borderRadius: BorderRadius.circular(RadiusTokens.xl),
        border: Border.all(
          color: AppColors.statusGreen.withAlpha(isDark ? 40 : 80),
        ),
      ),
      child: Column(
        children: [
          // Celebration checkmark with elastic animation
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.statusGreen, Color(0xFF16A34A)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.statusGreen.withAlpha(60),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
          ).animate().scale(
            duration: AppDurations.slow + 100.ms,
            curve: Curves.elasticOut,
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
          ).then().shake(duration: 300.ms, hz: 2),

          const SizedBox(height: Spacing.md + 2),
          Text(
            '¡Instalación completada!',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.statusGreen,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Todo está listo. Ahora configura tus claves API.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
      duration: AppDurations.normal,
      delay: 200.ms,
      curve: Curves.easeOut,
    );
  }

  // ─── Optional packages ────────────────────────────────────────────────────

  Widget _buildOptionalPackagesSection(ThemeData theme, ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.extension_outlined,
          title: 'Paquetes Opcionales',
        ),
        const SizedBox(height: Spacing.sm),
        ...OptionalPackage.all.map((pkg) => _buildPackageCard(theme, cs, pkg, isDark)),
      ],
    );
  }

  Widget _buildPackageCard(ThemeData theme, ColorScheme cs, OptionalPackage package, bool isDark) {
    final installed = _pkgStatuses[package.id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : Colors.transparent,
        borderRadius: BorderRadius.circular(RadiusTokens.md + 2),
        border: Border.all(
          color: installed
              ? AppColors.statusGreen.withAlpha(50)
              : isDark
                  ? cs.outlineVariant.withAlpha(80)
                  : cs.outlineVariant.withAlpha(160),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusTokens.md + 2),
        onTap: installed ? null : () => _installPackage(package),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (installed ? AppColors.statusGreen : package.color).withAlpha(18),
                  borderRadius: BorderRadius.circular(Spacing.sm + 2),
                ),
                child: Icon(
                  installed ? Icons.check_circle_outline : package.icon,
                  color: installed ? AppColors.statusGreen : package.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            package.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (installed) ...[
                          const SizedBox(width: Spacing.sm - 2),
                          StatusBadge.active('Instalado'),
                        ],
                      ],
                    ),
                    const SizedBox(height: Spacing.xs - 1),
                    Text(
                      '${package.description} (${package.estimatedSize})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              installed
                  ? Icon(Icons.check_circle, color: AppColors.statusGreen.withAlpha(160), size: 20)
                  : FilledButton.tonalIcon(
                      onPressed: () => _installPackage(package),
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('Instalar', style: TextStyle(fontSize: 11)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.md - 4, vertical: Spacing.sm - 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Action buttons ───────────────────────────────────────────────────────

  Widget _buildActions(SetupProvider provider, SetupState state, ThemeData theme, ColorScheme cs) {
    if (state.isComplete) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _goToOnboarding(context),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('Configurar Claves API'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: Spacing.md + 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RadiusTokens.md + 2),
            ),
          ),
        ),
      );
    }

    if (!_started || state.hasError) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: provider.isRunning
              ? null
              : () {
                  setState(() => _started = true);
                  provider.runSetup();
                },
          icon: Icon(
            _started ? Icons.refresh_rounded : Icons.download_rounded,
            size: 18,
          ),
          label: Text(
            _started ? 'Reintentar' : 'Iniciar Instalación Proot',
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: Spacing.md + 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RadiusTokens.md + 2),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _goToOnboarding(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(isFirstRun: true),
      ),
    );
  }
}
