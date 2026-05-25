import 'package:flutter/material.dart';
import '../constants.dart';
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
      if (!opened && mounted) {
        setState(() {
          _error = 'Could not open web dashboard';
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
        title: const Text('Panel Web'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAndOpen,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.open_in_browser,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Panel Web Abierto',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentUrl ?? 'Cargando...',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _loadAndOpen,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Abrir de nuevo'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Volver'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
