import 'package:flutter/foundation.dart';
import '../models/setup_state.dart';
import '../services/bootstrap_service.dart';

class SetupProvider extends ChangeNotifier {
  final BootstrapService _bootstrapService = BootstrapService();
  SetupState _state = const SetupState();
  bool _isRunning = false;
  final List<String> _logs = [];

  SetupState get state => _state;
  bool get isRunning => _isRunning;
  List<String> get logs => _logs;

  Future<bool> checkIfSetupNeeded() async {
    _state = await _bootstrapService.checkStatus();
    notifyListeners();
    return !_state.isComplete;
  }

  Future<void> runSetup() async {
    if (_isRunning) return;
    _isRunning = true;
    _logs.clear();
    notifyListeners();

    await _bootstrapService.runFullSetup(
      onProgress: (state) {
        _state = state;
        notifyListeners();
      },
      onLog: (log) {
        _logs.add(log);
        notifyListeners();
      },
    );

    _isRunning = false;
    notifyListeners();
  }

  void reset() {
    _state = const SetupState();
    _isRunning = false;
    _logs.clear();
    notifyListeners();
  }
}
