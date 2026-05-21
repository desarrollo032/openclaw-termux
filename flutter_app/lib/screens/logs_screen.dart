import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app.dart';
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
        title: const Text('Gateway Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Screenshot',
            onPressed: _takeScreenshot,
          ),
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_top),
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all logs',
            onPressed: () => _copyLogs(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            logs.isEmpty ? Icons.article_outlined : Icons.search_off,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            logs.isEmpty ? 'No logs yet. Start the gateway.' : 'No matching logs.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final line = filtered[index];
                      final logStyle = _logStyle(line, theme);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (logStyle.badge != null) ...[
                              Container(
                                margin: const EdgeInsets.only(right: 6, top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: logStyle.color.withAlpha(30),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  logStyle.badge!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: logStyle.color,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
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
      return _LogStyle(theme.colorScheme.error, '[ERR]');
    }
    if (line.contains('[WARN]') || line.contains('WARNING')) {
      return const _LogStyle(AppColors.statusAmber, '[WRN]');
    }
    if (line.contains('[INFO]')) {
      return const _LogStyle(AppColors.mutedText, '[INF]');
    }
    return _LogStyle(theme.colorScheme.onSurface.withAlpha(180), null);
  }

  Future<void> _takeScreenshot() async {
    final path = await ScreenshotService.capture(_screenshotKey, prefix: 'logs');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path != null
          ? 'Screenshot saved: ${path.split('/').last}'
          : 'Failed to capture screenshot')),
    );
  }

  void _copyLogs(BuildContext context) {
    final provider = context.read<GatewayProvider>();
    final text = provider.state.logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }
}

class _LogStyle {
  final Color color;
  final String? badge;

  const _LogStyle(this.color, this.badge);
}
