import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../app.dart';

/// Termux-style extra keys toolbar for terminal screens.
class TerminalToolbar extends StatefulWidget {
  final Pty? pty;
  final ValueNotifier<bool> ctrlNotifier;
  final ValueNotifier<bool> altNotifier;

  const TerminalToolbar({
    super.key,
    required this.pty,
    required this.ctrlNotifier,
    required this.altNotifier,
  });

  @override
  State<TerminalToolbar> createState() => _TerminalToolbarState();
}

class _TerminalToolbarState extends State<TerminalToolbar> {
  bool get _ctrlActive => widget.ctrlNotifier.value;
  bool get _altActive => widget.altNotifier.value;

  @override
  void initState() {
    super.initState();
    widget.ctrlNotifier.addListener(_onModifierChanged);
    widget.altNotifier.addListener(_onModifierChanged);
  }

  @override
  void dispose() {
    widget.ctrlNotifier.removeListener(_onModifierChanged);
    widget.altNotifier.removeListener(_onModifierChanged);
    super.dispose();
  }

  void _onModifierChanged() {
    setState(() {});
  }

  void _send(String data) {
    final pty = widget.pty;
    if (pty == null) return;

    if (_ctrlActive) {
      widget.ctrlNotifier.value = false;
      if (data.length == 1) {
        final code = data.toLowerCase().codeUnitAt(0);
        if (code >= 97 && code <= 122) {
          pty.write(Uint8List.fromList([code - 96]));
          return;
        }
      }
      const ctrlSeqMap = <String, String>{
        '\x1b[A': '\x1b[1;5A',
        '\x1b[B': '\x1b[1;5B',
        '\x1b[D': '\x1b[1;5D',
        '\x1b[C': '\x1b[1;5C',
        '\x1b[H': '\x1b[1;5H',
        '\x1b[F': '\x1b[1;5F',
        '\x1b[5~': '\x1b[5;5~',
        '\x1b[6~': '\x1b[6;5~',
      };
      final ctrlVariant = ctrlSeqMap[data];
      if (ctrlVariant != null) {
        pty.write(utf8.encode(ctrlVariant));
        return;
      }
      pty.write(utf8.encode(data));
      return;
    }

    if (_altActive) {
      widget.altNotifier.value = false;
      pty.write(utf8.encode('\x1b$data'));
      return;
    }

    pty.write(utf8.encode(data));
  }

  void _toggleCtrl() {
    widget.ctrlNotifier.value = !_ctrlActive;
    if (_ctrlActive) widget.altNotifier.value = false;
  }

  void _toggleAlt() {
    widget.altNotifier.value = !_altActive;
    if (_altActive) widget.ctrlNotifier.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFE8E8E8);
    final btnColor = isDark ? AppColors.darkSurfaceAlt : const Color(0xFFF5F5F5);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFD0D0D0);
    const activeColor = AppColors.accent;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    Widget keyButton(String label, {VoidCallback? onTap, String? sendData, bool active = false, double? width}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Material(
          color: active ? activeColor : btnColor,
          borderRadius: BorderRadius.circular(6),
          elevation: active ? 2 : 0,
          shadowColor: active ? activeColor.withAlpha(80) : Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap ?? () => _send(sendData ?? label),
            child: Container(
              width: width,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 32),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: active ? activeColor : borderColor.withAlpha(80),
                  width: active ? 1.5 : 0.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : textColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget arrowButton(IconData icon, String escSequence) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: btnColor,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _send(escSequence),
            child: Container(
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: borderColor.withAlpha(80),
                  width: 0.5,
                ),
              ),
              child: Icon(icon, size: 15, color: textColor),
            ),
          ),
        ),
      );
    }

    return Container(
      color: bgColor,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(
            children: [
              keyButton('ESC', sendData: '\x1b'),
              keyButton('CTRL', onTap: _toggleCtrl, active: _ctrlActive),
              keyButton('ALT', onTap: _toggleAlt, active: _altActive),
              keyButton('TAB', sendData: '\t'),
              keyButton('⏎', sendData: '\r'),
              const SizedBox(width: 6),
              arrowButton(Icons.arrow_upward, '\x1b[A'),
              arrowButton(Icons.arrow_downward, '\x1b[B'),
              arrowButton(Icons.arrow_back, '\x1b[D'),
              arrowButton(Icons.arrow_forward, '\x1b[C'),
              const SizedBox(width: 6),
              keyButton('HOME', sendData: '\x1b[H'),
              keyButton('END', sendData: '\x1b[F'),
              keyButton('PG↑', sendData: '\x1b[5~'),
              keyButton('PG↓', sendData: '\x1b[6~'),
              const SizedBox(width: 6),
              keyButton('-', sendData: '-'),
              keyButton('/', sendData: '/'),
              keyButton('|', sendData: '|'),
              keyButton('~', sendData: '~'),
              keyButton('_', sendData: '_'),
            ],
          ),
        ),
      ),
    );
  }
}
