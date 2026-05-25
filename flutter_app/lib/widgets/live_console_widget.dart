import 'package:flutter/material.dart';

/// Terminal-style log viewer for real-time installation output.
/// Uses DejaVuSansMono for monospace rendering and color-codes
/// log lines by their prefix tag.
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
          duration: const Duration(milliseconds: 150),
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
    if (line.startsWith('[OK]')) return const Color(0xFF22C55E);
    if (line.startsWith('[ERR]') || line.startsWith('[ERROR]')) {
      return const Color(0xFFEF4444);
    }
    if (line.startsWith('[WARN]')) return const Color(0xFFF59E0B);
    if (line.startsWith('[DOWNLOAD]')) return const Color(0xFF818CF8);
    if (line.startsWith('[STEP]')) return const Color(0xFF6C63FF);
    return const Color(0xFF9CA3AF);
  }

  FontWeight _lineWeight(String line) {
    if (line.startsWith('[OK]')) return FontWeight.w700;
    if (line.startsWith('[ERR]') || line.startsWith('[ERROR]')) return FontWeight.w700;
    return FontWeight.w400;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF08080E) : const Color(0xFF0D0D12);
    final borderColor = isDark ? const Color(0xFF1E1E2A) : const Color(0xFF2A2A3E);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Console header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF12121A) : const Color(0xFF16161E),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                // Traffic light dots
                _dot(const Color(0xFFFF5F56)),
                const SizedBox(width: 6),
                _dot(const Color(0xFFFFBD2E)),
                const SizedBox(width: 6),
                _dot(const Color(0xFF27C93F)),
                const SizedBox(width: 12),
                const Text(
                  'CONSOLA DE INSTALACIÓN',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    fontFamily: 'DejaVuSansMono',
                  ),
                ),
                const Spacer(),
                // Line count
                Text(
                  '${widget.logs.length} líneas',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
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
                          color: const Color(0xFF6B7280).withAlpha(80),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Esperando inicio de instalación...',
                          style: TextStyle(
                            color: const Color(0xFF6B7280).withAlpha(120),
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
                        final maxScroll = _scrollController.position.maxScrollExtent;
                        final currentScroll = _scrollController.position.pixels;
                        _autoScroll = (maxScroll - currentScroll) < 40;
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: widget.logs.length,
                      itemBuilder: (context, index) {
                        final line = widget.logs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
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
