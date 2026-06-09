import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/state/settings_state.dart';
import '../streaming_voice_input.dart';
import 'ai_input_bar.dart';

/// Reusable AI-input shell. Swaps between a compact text bar
/// ([AiInputBar]) and the rich voice UI ([StreamingVoiceInput]) in place,
/// instead of pushing a modal. Used by the AI chat screen and the order
/// creator's refinement bar — anywhere the user converses with an LLM.
///
/// Two distinct send signals come out of voice mode:
///   - **Done** → stash transcript into the text field, return to text mode.
///     Lets the user combine voice with typed edits before sending.
///   - **Send** → fire transcript (with any existing text prepended) and
///     return to text mode. The voice-only happy path.
///
/// [enableFormatting] gates the Gemini formatting pass on the transcript.
/// Default off — both call sites (chat + order creator refinement) feed
/// the transcript to an LLM that doesn't care about polished punctuation.
/// Only set it to true when the transcript will be persisted and shown
/// back to a human (e.g. a description field saved to the DB).
class AiInputArea extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final void Function(String, {bool wasVoiceInput, String? audioWavPath})
      onSend;
  final bool enableFormatting;

  /// Optional override for the text bar's placeholder. Defaults to the
  /// chat-style "Ask anything..." prompt.
  final String? hintText;

  /// Open directly in voice mode (mic listening) on first build. Used by the
  /// home-screen widget deep link so the mother taps once and starts talking.
  final bool autoStartVoice;

  /// Whether the host screen is currently visible. Forwarded to the voice UI so
  /// an in-progress recording pauses when the host is hidden (e.g. tab switch).
  final bool active;

  const AiInputArea({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSend,
    this.enableFormatting = false,
    this.hintText,
    this.autoStartVoice = false,
    this.active = true,
  });

  @override
  State<AiInputArea> createState() => _AiInputAreaState();
}

class _AiInputAreaState extends State<AiInputArea> {
  bool _isVoiceActive = false;

  @override
  void initState() {
    super.initState();
    _isVoiceActive = widget.autoStartVoice;
  }

  void _handleVoiceDone(VoiceInputResult result) {
    setState(() => _isVoiceActive = false);
    final existing = widget.controller.text.trim();
    widget.controller.text = existing.isEmpty ? result.text : '$existing ${result.text}';
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
  }

  void _handleVoiceSend(VoiceInputResult result) {
    setState(() => _isVoiceActive = false);
    final existing = widget.controller.text.trim();
    final fullText = existing.isEmpty ? result.text : '$existing ${result.text}';
    widget.controller.clear();
    widget.onSend(
      fullText,
      wasVoiceInput: true,
      audioWavPath: result.audioWavPath,
    );
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
              active: widget.active,
              existingText: widget.controller.text.trim(),
              // Only consult the formatting model setting if the caller has
              // opted into formatting. When disabled we leave it null so the
              // pipeline skips the LLM round-trip entirely.
              formattingModelName: widget.enableFormatting
                  ? context.read<SettingsState>().settings.aiFormattingModel
                  : null,
              enableFormatting: widget.enableFormatting,
              onDone: _handleVoiceDone,
              onSend: _handleVoiceSend,
              onCancel: _handleVoiceCancel,
            )
          : AiInputBar(
              key: const ValueKey('text'),
              controller: widget.controller,
              isLoading: widget.isLoading,
              hintText: widget.hintText ?? 'Ask anything...',
              onSend: (text) => widget.onSend(text),
              onMicTap: () => setState(() => _isVoiceActive = true),
            ),
    );
  }
}
