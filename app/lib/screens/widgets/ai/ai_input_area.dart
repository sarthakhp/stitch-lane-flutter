import 'package:flutter/material.dart';
import '../../../presentation/widgets/streaming_voice_input.dart';
import 'ai_input_bar.dart';

class AiInputArea extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final void Function(String) onSend;

  const AiInputArea({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  State<AiInputArea> createState() => _AiInputAreaState();
}

class _AiInputAreaState extends State<AiInputArea> {
  bool _isVoiceActive = false;

  void _handleVoiceDone(String text) {
    setState(() => _isVoiceActive = false);
    final existing = widget.controller.text.trim();
    widget.controller.text = existing.isEmpty ? text : '$existing $text';
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
  }

  void _handleVoiceSend(String text) {
    setState(() => _isVoiceActive = false);
    final existing = widget.controller.text.trim();
    final fullText = existing.isEmpty ? text : '$existing $text';
    widget.controller.clear();
    widget.onSend(fullText);
  }

  void _handleVoiceCancel() {
    setState(() => _isVoiceActive = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: 1.0,
            child: child,
          ),
        );
      },
      child: _isVoiceActive
          ? StreamingVoiceInput(
              key: const ValueKey('voice'),
              existingText: widget.controller.text.trim(),
              onDone: _handleVoiceDone,
              onSend: _handleVoiceSend,
              onCancel: _handleVoiceCancel,
            )
          : AiInputBar(
              key: const ValueKey('text'),
              controller: widget.controller,
              isLoading: widget.isLoading,
              onSend: widget.onSend,
              onMicTap: () => setState(() => _isVoiceActive = true),
            ),
    );
  }
}
