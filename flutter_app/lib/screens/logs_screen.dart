import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../providers/gateway_provider.dart';
import '../services/screenshot_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _screenshotKey = GlobalKey();
  bool _autoScroll = true;
  String _filter = '';

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
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
                Icons.article_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Registros',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Captura',
            onPressed: _takeScreenshot,
          ),
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_top),
            tooltip: _autoScroll ? 'Auto-desplazamiento' : 'Desplazamiento manual',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copiar registros',
            onPressed: () => _copyLogs(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar en registros...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _filter = value),
            ),
          ),
          Expanded(
            child: RepaintBoundary(
              key: _screenshotKey,
              child: Consumer<GatewayProvider>(
                builder: (context, provider, _) {
                  final logs = provider.state.logs;
                  final filtered = _filter.isEmpty
                      ? logs
                      : logs.where((l) =>
                          l.toLowerCase().contains(_filter.toLowerCase())).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: EmptyState(
                          icon: logs.isEmpty ? Icons.article_outlined : Icons.search_off,
                          title: logs.isEmpty ? 'Sin registros' : 'Sin coincidencias',
                          subtitle: logs.isEmpty
                              ? 'Inicia el gateway para ver los registros aquí.'
                              : 'Prueba con otro término de búsqueda.',
                        ).animate().fadeIn(duration: 300.ms, curve: Curves.easeOut),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_autoScroll && _scrollController.hasClients) {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final line = filtered[index];
                      final logStyle = _logStyle(line, theme);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (logStyle.badge != null) ...{
                              Padding(
                                padding: const EdgeInsets.only(right: 6, top: 2),
                                child: SizedBox(
                                  width: 40,
                                  child: Text(
                                    logStyle.badge!,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: logStyle.color,
                                      fontFamily: 'monospace',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            },
                            Expanded(
                              child: Text(
                                logStyle.badge != null
                                    ? line.replaceAll(RegExp(r'\[(ERR|WARN|INFO|ERROR|WARNING)\]'), '').trim()
                                    : line,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.4,
                                  color: logStyle.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  _LogStyle _logStyle(String line, ThemeData theme) {
    if (line.contains('[ERR]') || line.contains('ERROR')) {
      return _LogStyle(theme.colorScheme.error, 'ERR');
    }
    if (line.contains('[WARN]') || line.contains('WARNING')) {
      return const _LogStyle(AppColors.statusAmber, 'WRN');
    }
    if (line.contains('[INFO]')) {
      return const _LogStyle(AppColors.mutedText, 'INF');
    }
    return _LogStyle(theme.colorScheme.onSurface.withAlpha(180), null);
  }

  Future<void> _takeScreenshot() async {
    final path = await ScreenshotService.capture(_screenshotKey, prefix: 'logs');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path != null
          ? 'Screenshot guardado: ${path.split('/').last}'
          : 'Error al capturar screenshot')),
    );
  }

  void _copyLogs(BuildContext context) {
    final provider = context.read<GatewayProvider>();
    final text = provider.state.logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registros copiados al portapapeles')),
    );
  }
}

class _LogStyle {
  final Color color;
  final String? badge;

  const _LogStyle(this.color, this.badge);
}
