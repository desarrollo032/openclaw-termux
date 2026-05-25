import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
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

class _SetupWizardScreenState extends State<SetupWizardScreen>
    with TickerProviderStateMixin {
  bool _started = false;
  Map<String, bool> _pkgStatuses = {};
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // Celebration animation
  late final AnimationController _celebrationController;
  late final Animation<double> _celebrationScale;
  late final Animation<double> _celebrationRotate;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _celebrationScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _celebrationController,
        curve: Curves.elasticOut,
      ),
    );
    _celebrationRotate = Tween<double>(begin: -0.1, end: 0).animate(
      CurvedAnimation(
        parent: _celebrationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

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
                    const Color(0xFFF0F1FA),
                    const Color(0xFFF8F9FE),
                    const Color(0xFFEEF0F7),
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
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Consumer<SetupProvider>(
                    builder: (context, provider, _) {
                      final state = provider.state;

                      // Refresh package statuses on completion
                      if (state.isComplete && _pkgStatuses.isEmpty) {
                        _refreshPkgStatuses();
                      }

                      // Trigger celebration on completion
                      if (state.isComplete &&
                          !_celebrationController.isAnimating) {
                        _celebrationController.forward();
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            // ── Header ──
                            _buildHeader(theme, cs, state, isDark),
                            const SizedBox(height: 12),

                            // ── Main content area ──
                            // No Expanded here during active install to avoid
                            // white blocks — the console fills the space
                            Expanded(
                              child: _buildContentArea(
                                state, provider, theme, cs, isDark,
                              ),
                            ),

                            // ── Error card ──
                            if (state.hasError) ...[
                              const SizedBox(height: 8),
                              _buildErrorCard(theme, cs, state, isDark),
                            ],

                            const SizedBox(height: 8),

                            // ── Action buttons ──
                            _buildActions(provider, state, theme, cs),

                            const SizedBox(height: 6),

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
                            const SizedBox(height: 4),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Content Area ──────────────────────────────────────────────────────
  // No white blocks: every branch fills the Expanded with dark-colored content.

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

        // Live console fills remaining space (dark background, no white blocks)
        Expanded(
          child: _buildConsoleSection(provider, cs, isDark),
        ),
      ],
    );
  }

  // ─── Pre-install info (before user clicks "Iniciar") ──────────────────

  Widget _buildPreInstallInfo(ThemeData theme, ColorScheme cs, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow.withAlpha(200),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withAlpha(60)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withAlpha(120),
                      cs.primary.withAlpha(60),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.download_for_offline_rounded,
                  size: 40,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Instalación del Entorno',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Este proceso descargará e instalará Ubuntu rootfs, '
                'Node.js y OpenClaw en tu dispositivo.\n\n'
                '• ~500 MB de descarga\n'
                '• Conexión a internet requerida\n'
                '• El proceso puede tomar 5-15 minutos',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              // What will be installed - compact cards
              _buildInstallItem(
                Icons.cloud_download_rounded,
                'Ubuntu 24.04 Base',
                'Sistema base ARM64',
                const Color(0xFF6C63FF),
                theme,
                cs,
              ),
              const SizedBox(height: 8),
              _buildInstallItem(
                Icons.javascript_rounded,
                'Node.js 22',
                'Entorno JavaScript',
                const Color(0xFF22C55E),
                theme,
                cs,
              ),
              const SizedBox(height: 8),
              _buildInstallItem(
                Icons.auto_awesome_rounded,
                'OpenClaw',
                'AI Gateway',
                const Color(0xFFF59E0B),
                theme,
                cs,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallItem(
    IconData icon,
    String name,
    String desc,
    Color color,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
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

  // ─── Compact steps during installation ────────────────────────────────

  Widget _buildCompactSteps(
    SetupState state,
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
  ) {
    final phaseName = _currentPhaseName(state);
    final progress = _overallProgress(state);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: Row(
        children: [
          // Phase icon
          if (phaseName != null)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.play_circle_rounded, size: 18, color: cs.primary),
            ),
          if (phaseName != null) const SizedBox(width: 10),

          // Phase name + progress percent
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
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
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

          const SizedBox(width: 10),

          // Step counter
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

  // ─── Live Console ─────────────────────────────────────────────────────

  Widget _buildConsoleSection(
    SetupProvider provider,
    ColorScheme cs,
    bool isDark,
  ) {
    return Column(
      children: [
        // The console takes all available space
        Expanded(
          child: LiveConsoleWidget(logs: provider.logs, isDark: isDark),
        ),
        // Auto-scroll indicator
        if (provider.logs.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: cs.onSurfaceVariant.withAlpha(100),
                ),
                const SizedBox(width: 4),
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

  // ─── Header ───────────────────────────────────────────────────────────

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
    } else {
      subtitle = 'Descargar Ubuntu, Node.js y OpenClaw';
      subtitleColor = cs.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 22, color: cs.primary),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 2),
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
    );
  }

  // ─── Error card ───────────────────────────────────────────────────────

  Widget _buildErrorCard(
    ThemeData theme, ColorScheme cs, SetupState state, bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withAlpha(180),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.error.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
              ),
              const SizedBox(width: 10),
              Text(
                'Error',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.error ?? 'Error desconocido',
            style: TextStyle(
              color: cs.onErrorContainer,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 13, color: cs.error.withAlpha(160)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Verifica tu conexión a internet y espacio disponible (~500MB).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.error.withAlpha(160),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Completion content ───────────────────────────────────────────────

  Widget _buildCompletionContent(ThemeData theme, ColorScheme cs, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildCompletionCelebration(theme, cs, isDark),
          const SizedBox(height: 20),
          // Log console in compact mode
          SizedBox(
            height: 180,
            child: Consumer<SetupProvider>(
              builder: (context, provider, _) {
                return LiveConsoleWidget(logs: provider.logs, isDark: isDark);
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildOptionalPackagesSection(theme, cs, isDark),
        ],
      ),
    );
  }

  // ─── Celebration ──────────────────────────────────────────────────────

  Widget _buildCompletionCelebration(ThemeData theme, ColorScheme cs, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.statusGreen.withAlpha(40)),
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _celebrationScale,
            child: RotationTransition(
              turns: _celebrationRotate,
              child: Container(
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
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '¡Instalación completada!',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.statusGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Todo está listo. Ahora configura tus claves API.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Optional packages ────────────────────────────────────────────────

  Widget _buildOptionalPackagesSection(ThemeData theme, ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.extension_outlined, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              'PAQUETES OPCIONALES',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...OptionalPackage.all.map((pkg) => _buildPackageCard(theme, cs, pkg, isDark)),
      ],
    );
  }

  Widget _buildPackageCard(ThemeData theme, ColorScheme cs, OptionalPackage package, bool isDark) {
    final installed = _pkgStatuses[package.id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: installed
              ? AppColors.statusGreen.withAlpha(50)
              : cs.outlineVariant.withAlpha(80),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: installed ? null : () => _installPackage(package),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (installed ? AppColors.statusGreen : package.color).withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  installed ? Icons.check_circle_outline : package.icon,
                  color: installed ? AppColors.statusGreen : package.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
                          const SizedBox(width: 6),
                          _buildBadge('Instalado', AppColors.statusGreen, theme),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
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
              const SizedBox(width: 8),
              installed
                  ? Icon(Icons.check_circle, color: AppColors.statusGreen.withAlpha(160), size: 20)
                  : FilledButton.tonalIcon(
                      onPressed: () => _installPackage(package),
                      icon: const Icon(Icons.download, size: 14),
                      label: const Text('Instalar', style: TextStyle(fontSize: 11)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildBadge(String text, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }

  // ─── Action buttons ───────────────────────────────────────────────────

  Widget _buildActions(SetupProvider provider, SetupState state, ThemeData theme, ColorScheme cs) {
    if (state.isComplete) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _goToOnboarding(context),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('Configurar Claves API'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
          label: Text(_started ? 'Reintentar' : 'Iniciar Instalación'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
