import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../design/components.dart';
import '../native/openclaw_native.dart';
import '../services/preferences_service.dart';

class WebDashboardScreen extends StatefulWidget {
  final String? url;

  const WebDashboardScreen({super.key, this.url});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  String? _error;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _loadAndOpen();
  }

  Future<void> _loadAndOpen() async {
    try {
      var url = widget.url;
      if (url == null || url.isEmpty) {
        final prefs = PreferencesService();
        await prefs.init();
        url = prefs.dashboardUrl;
      }
      final finalUrl = url ?? AppConstants.gatewayUrl;
      _currentUrl = finalUrl;

      final opened = await OpenClawNative.openWebDashboard(finalUrl);
      if (opened) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return;
      }
      if (!opened && mounted) {
        setState(() {
          _error = 'No se pudo abrir el panel web';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.open_in_browser,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Panel Web'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reintentar',
            onPressed: _loadAndOpen,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ErrorBox(message: _error!),
                ),
              Expanded(
                child: _currentUrl != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          EmptyState(
                            icon: Icons.open_in_browser,
                            title: 'Panel Web Abierto',
                            subtitle: _currentUrl,
                            actionLabel: 'Abrir de nuevo',
                            onAction: _loadAndOpen,
                          ).animate().fadeIn(
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
