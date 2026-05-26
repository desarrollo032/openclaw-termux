import 'package:flutter/material.dart';
import '../design/tokens.dart';

/// Visor de logs en estilo terminal para salida de instalación en tiempo real.
/// Usa DejaVuSansMono y codifica colores por prefijo de línea.
class LiveConsoleWidget extends StatefulWidget {
  final List<String> logs;
  final bool isDark;

  const LiveConsoleWidget({
    super.key,
    required this.logs,
    this.isDark = true,
  });

  @override
  State<LiveConsoleWidget> createState() => _LiveConsoleWidgetState();
}

class _LiveConsoleWidgetState extends State<LiveConsoleWidget> {
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void didUpdateWidget(LiveConsoleWidget old) {
    super.didUpdateWidget(old);
    if (widget.logs.length > old.logs.length && _autoScroll) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDurations.fast,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _lineColor(String line) {
    if (line.startsWith('[OK]')) return AppColors.statusGreen;
    if (line.startsWith('[ERR]') || line.startsWith('[ERROR]')) {
      return AppColors.statusRed;
    }
    if (line.startsWith('[WARN]')) return AppColors.statusAmber;
    if (line.startsWith('[DOWNLOAD]')) return AppColors.accentSubtle;
    if (line.startsWith('[STEP]')) return AppColors.accent;
    return AppColors.statusGrey;
  }

  FontWeight _lineWeight(String line) {
    if (line.startsWith('[OK]') ||
        line.startsWith('[ERR]') ||
        line.startsWith('[ERROR]')) {
      return FontWeight.w700;
    }
    return FontWeight.w400;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        border: Border.all(color: AppColors.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header bar — estilo terminal con dots de semáforo
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg - 2,
              vertical: Spacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
            ),
            child: Row(
              children: [
                _dot(const Color(0xFFFF5F56)),
                const SizedBox(width: Spacing.sm - 2),
                _dot(const Color(0xFFFFBD2E)),
                const SizedBox(width: Spacing.sm - 2),
                _dot(const Color(0xFF27C93F)),
                const SizedBox(width: Spacing.md),
                const Text(
                  'CONSOLA DE INSTALACIÓN',
                  style: TextStyle(
                    color: AppColors.darkMutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    fontFamily: 'DejaVuSansMono',
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.logs.length} líneas',
                  style: TextStyle(
                    color: AppColors.darkMutedText.withAlpha(160),
                    fontSize: 9,
                    fontFamily: 'DejaVuSansMono',
                  ),
                ),
              ],
            ),
          ),
          // Log content
          Expanded(
            child: widget.logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.terminal_rounded,
                          size: 28,
                          color: AppColors.mutedText.withAlpha(80),
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          'Esperando inicio de instalación...',
                          style: TextStyle(
                            color: AppColors.mutedText.withAlpha(120),
                            fontSize: 12,
                            fontFamily: 'DejaVuSansMono',
                          ),
                        ),
                      ],
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification) {
                        final maxScroll =
                            _scrollController.position.maxScrollExtent;
                        final currentScroll =
                            _scrollController.position.pixels;
                        _autoScroll = (maxScroll - currentScroll) < 40;
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(Spacing.md),
                      itemCount: widget.logs.length,
                      itemBuilder: (context, index) {
                        final line = widget.logs[index];
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            line,
                            style: TextStyle(
                              color: _lineColor(line),
                              fontSize: 11,
                              height: 1.45,
                              fontFamily: 'DejaVuSansMono',
                              fontWeight: _lineWeight(line),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
