enum SetupStep {
  checkingStatus,
  downloadingRootfs,
  extractingRootfs,
  installingNode,
  installingOpenClaw,
  configuringBypass,
  complete,
  error,
}

enum InstallationMode { native, proot }

class SetupState {
  final SetupStep step;
  final double progress;
  final String message;
  final String? error;
  final InstallationMode? mode;

  const SetupState({
    this.step = SetupStep.checkingStatus,
    this.progress = 0.0,
    this.message = '',
    this.error,
    this.mode,
  });

  SetupState copyWith({
    SetupStep? step,
    double? progress,
    String? message,
    String? error,
    InstallationMode? mode,
  }) {
    return SetupState(
      step: step ?? this.step,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      error: error,
      mode: mode ?? this.mode,
    );
  }

  bool get isComplete => step == SetupStep.complete;
  bool get hasError => step == SetupStep.error;

  String get stepLabel {
    switch (step) {
      case SetupStep.checkingStatus:
        return 'Comprobando estado...';
      case SetupStep.downloadingRootfs:
        return 'Descargando paquetes nativos';
      case SetupStep.extractingRootfs:
        return 'Extrayendo runtime nativo';
      case SetupStep.installingNode:
        return 'Instalando Node.js nativo';
      case SetupStep.installingOpenClaw:
        return 'Instalando OpenClaw';
      case SetupStep.configuringBypass:
        return 'Configurando compatibilidad glibc';
      case SetupStep.complete:
        return 'Instalacion completa';
      case SetupStep.error:
        return 'Error';
    }
  }

  int get stepNumber {
    switch (step) {
      case SetupStep.checkingStatus:
        return 0;
      case SetupStep.downloadingRootfs:
        return 1;
      case SetupStep.extractingRootfs:
        return 2;
      case SetupStep.installingNode:
        return 3;
      case SetupStep.installingOpenClaw:
        return 4;
      case SetupStep.configuringBypass:
        return 5;
      case SetupStep.complete:
        return 6;
      case SetupStep.error:
        return -1;
    }
  }

  static const int totalSteps = 6;
}
