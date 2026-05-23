import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import '../models/optional_package.dart';
import '../providers/setup_provider.dart';
import '../services/package_service.dart';
import '../widgets/progress_step.dart';
import 'onboarding_screen.dart';
import 'package_install_screen.dart';

/// Represents a logical phase grouping in the setup flow.
class _SetupPhase {
  final String name;
  final String icon; // emoji as simple icon alternative
  final List<_StepInfo> steps;
  final int startIndex;

  const _SetupPhase({
    required this.name,
    required this.icon,
    required this.steps,
    required this.startIndex,
  });
}

/// Info for each step mapped to SetupStep enum.
class _StepInfo {
  final int number;
  final SetupStep step;
  const _StepInfo(this.number, this.step);
}

const _phases = [
  _SetupPhase(
    name: 'Descarga',
    icon: '⬇️',
    steps: [
      _StepInfo(1, SetupStep.downloadingRootfs),
      _StepInfo(2, SetupStep.extractingRootfs),
    ],
    startIndex: 1,
  ),
  _SetupPhase(
    name: 'Instalación',
    icon: '🔧',
    steps: [
      _StepInfo(3, SetupStep.installingNode),
      _StepInfo(4, SetupStep.installingOpenClaw),
    ],
    startIndex: 3,
  ),
  _SetupPhase(
    name: 'Configuración',
    icon: '⚙️',
    steps: [
      _StepInfo(5, SetupStep.configuringBypass),
    ],
    startIndex: 5,
  ),
];

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen>
    with SingleTickerProviderStateMixin {
  bool _started = false;
  Map<String, bool> _pkgStatuses = {};
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
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

  /// Calculate overall progress from the current state.
  double _overallProgress(SetupState state) {
    if (state.isComplete) return 1.0;
    if (state.step == SetupStep.error) return -1;

    const totalSteps = 5.0;
    final stepIndex = SetupStep.values.indexOf(state.step);
    if (stepIndex < 0) return 0.0;

    // Step contribution: each step is 1/5, plus partial progress within step
    final stepContribution = stepIndex / totalSteps;
    final withinStep = state.progress.clamp(0.0, 0.99) / totalSteps;
    return (stepContribution + withinStep).clamp(0.0, 0.99);
  }

  /// Determine the current phase name.
  String? _currentPhaseName(SetupState state) {
    for (final phase in _phases) {
      for (final stepInfo in phase.steps) {
        if (state.step == stepInfo.step) {
          return phase.name;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Consumer<SetupProvider>(
              builder: (context, provider, _) {
                final state = provider.state;
                final overallProgress = _overallProgress(state);
                final phaseName = _currentPhaseName(state);

                if (state.isComplete && _pkgStatuses.isEmpty) {
                  _refreshPkgStatuses();
                }

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Header with logo and title
                      _buildHeader(theme, state, phaseName, isDark),
                      const SizedBox(height: 16),

                      // Overall progress bar (shown during installation)
                      if (_started && !state.isComplete && !state.hasError)
                        _buildOverallProgress(theme, state, overallProgress, isDark),

                      const SizedBox(height: 16),

                      // Steps list
                      Expanded(
                        child: _buildSteps(state, theme, isDark),
                      ),

                      // Error display
                      if (state.hasError) _buildErrorCard(theme, state, isDark),

                      // Action buttons
                      if (state.isComplete)
                        _buildCompleteActions(theme)
                      else if (!_started || state.hasError)
                        _buildStartActions(provider, theme, state, isDark),

                      // Info text before start
                      if (!_started) _buildInfoRow(theme, isDark),

                      const SizedBox(height: 8),
                      // Footer
                      Center(
                        child:                        Text(
                          '${AppConstants.orgName}/openclaw-termux',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    SetupState state,
    String? phaseName,
    bool isDark,
  ) {
    return Row(
      children: [
        // Logo
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(25),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.bolt,
              size: 28,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configurar OpenClaw',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _started && phaseName != null
                      ? 'Fase: $phaseName'
                      : state.isComplete
                          ? '¡Instalación completada!'
                          : state.hasError
                              ? 'Error en la instalación'
                              : 'Descargar Ubuntu, Node.js y OpenClaw',
                  key: ValueKey(
                    '${_started}_${phaseName}_${state.isComplete}_${state.hasError}',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: state.hasError
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverallProgress(
    ThemeData theme,
    SetupState state,
    double progress,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(
              begin: 0,
              end: progress.clamp(0.0, 1.0),
            ),
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF6C63FF),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            'Progreso general: ${(progress * 100).clamp(0, 99).toInt()}%',
            key: ValueKey((progress * 10).round()),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSteps(SetupState state, ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final phase in _phases) ...[
            // Phase header
            _buildPhaseHeader(theme, phase, state, isDark),
            // Steps in this phase
            for (final stepInfo in phase.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _StepItem(
                  stepNumber: stepInfo.number,
                  step: stepInfo.step,
                  state: state,
                  index: phase.steps.indexOf(stepInfo),
                  totalInPhase: phase.steps.length,
                ),
              ),
          ],
          // Completion step
          if (state.isComplete) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: ProgressStep(
                stepNumber: 6,
                label: '¡Instalación completada!',
                isComplete: true,
              ),
            ),
            const SizedBox(height: 20),
            // Optional packages section
            _buildOptionalPackagesSection(theme, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildPhaseHeader(
    ThemeData theme,
    _SetupPhase phase,
    SetupState state,
    bool isDark,
  ) {
    // Determine if this phase is active, completed, or pending
    final phaseStepIndices = phase.steps.map((s) => s.step.index);
    final currentIndex = SetupStep.values.indexOf(state.step);
    final minPhaseIndex = phaseStepIndices.reduce((a, b) => a < b ? a : b);
    final maxPhaseIndex = phaseStepIndices.reduce((a, b) => a > b ? a : b);

    final isPhaseActive = currentIndex >= minPhaseIndex && currentIndex <= maxPhaseIndex;
    final isPhaseComplete = !state.hasError && currentIndex > maxPhaseIndex || state.isComplete;
    final isPhasePending = !isPhaseActive && !isPhaseComplete && !state.hasError;

    Color phaseColor;
    if (isPhaseComplete) {
      phaseColor = AppColors.statusGreen;
    } else if (isPhaseActive) {
      phaseColor = theme.colorScheme.primary;
    } else if (isPhasePending) {
      phaseColor = theme.colorScheme.onSurfaceVariant.withAlpha(100);
    } else {
      phaseColor = theme.colorScheme.error;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6, left: 2),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: phaseColor.withAlpha(
                isPhaseComplete ? 25 : isPhaseActive ? 25 : 12,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                phase.icon,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            phase.name.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: phaseColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          // Status dot
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: phaseColor.withAlpha(120),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalPackagesSection(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.extension_outlined,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'PAQUETES OPCIONALES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Herramientas adicionales para tu entorno Ubuntu.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        for (final pkg in OptionalPackage.all)
          _buildPackageCard(theme, pkg, isDark),
      ],
    );
  }

  Widget _buildPackageCard(ThemeData theme, OptionalPackage package, bool isDark) {
    final installed = _pkgStatuses[package.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: installed ? null : () => _installPackage(package),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon with gradient-ish background
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: installed
                      ? AppColors.statusGreen.withAlpha(15)
                      : package.color.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: installed
                      ? Border.all(color: AppColors.statusGreen.withAlpha(40))
                      : null,
                ),
                child: Icon(
                  installed ? Icons.check_circle_outline : package.icon,
                  color: installed ? AppColors.statusGreen : package.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          package.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (installed)
                          _buildBadge(
                            'Instalado',
                            AppColors.statusGreen,
                            theme,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${package.description} (${package.estimatedSize})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              installed
                  ? Icon(
                      Icons.check_circle,
                      color: AppColors.statusGreen.withAlpha(180),
                      size: 22,
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () => _installPackage(package),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Instalar', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme, SetupState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.error.withAlpha(35),
        ),
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
                  color: theme.colorScheme.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Error',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.error ?? 'Error desconocido',
            style: TextStyle(
              color: theme.colorScheme.error.withAlpha(200),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 14,
                color: theme.colorScheme.error.withAlpha(150),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Verifica tu conexión a internet y espacio disponible (~500MB).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error.withAlpha(150),
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

  Widget _buildCompleteActions(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _goToOnboarding(context),
        icon: const Icon(Icons.arrow_forward, size: 18),
        label: const Text('Configurar Claves API'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildStartActions(SetupProvider provider, ThemeData theme, SetupState state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: provider.isRunning
                ? null
                : () {
                    setState(() => _started = true);
                    provider.runSetup();
                  },
            icon: Icon(
              _started ? Icons.refresh : Icons.download,
              size: 18,
            ),
            label: Text(_started ? 'Reintentar' : 'Iniciar Instalación'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 13,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
          ),
          const SizedBox(width: 6),
          Text(
            'Requiere ~500MB y conexión a internet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _goToOnboarding(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(isFirstRun: true),
      ),
    );
  }
}

/// Individual step item with staggered entrance animation.
class _StepItem extends StatelessWidget {
  final int stepNumber;
  final SetupStep step;
  final SetupState state;
  final int index;
  final int totalInPhase;

  const _StepItem({
    required this.stepNumber,
    required this.step,
    required this.state,
    required this.index,
    required this.totalInPhase,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = state.step == step;
    final isComplete = state.stepNumber > step.index || state.isComplete;
    final hasError = state.hasError && state.step == step;

    // Get the dynamic label for active step, static label otherwise
    final displayLabel = isActive && state.message.isNotEmpty
        ? state.message
        : _defaultLabel(step);

    return ProgressStep(
      stepNumber: stepNumber,
      label: displayLabel,
      isActive: isActive,
      isComplete: isComplete,
      hasError: hasError,
      progress: isActive ? state.progress : null,
    );
  }

  String _defaultLabel(SetupStep step) {
    switch (step) {
      case SetupStep.downloadingRootfs:
        return 'Descargar Ubuntu rootfs';
      case SetupStep.extractingRootfs:
        return 'Extraer rootfs';
      case SetupStep.installingNode:
        return 'Instalar Node.js';
      case SetupStep.installingOpenClaw:
        return 'Instalar OpenClaw';
      case SetupStep.configuringBypass:
        return 'Configurar Bionic Bypass';
      default:
        return step.name;
    }
  }
}
