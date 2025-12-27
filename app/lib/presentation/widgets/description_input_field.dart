import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../domain/services/audio_recording_service.dart';
import '../../domain/services/transcription_service.dart';
import 'transcription_voice_button.dart';

class DescriptionInputField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final VoidCallback? onChanged;
  final String labelText;
  final String hintText;
  final bool enabled;
  final int minLines;
  final IconData? prefixIcon;

  const DescriptionInputField({
    super.key,
    required this.controller,
    this.validator,
    this.onChanged,
    this.labelText = 'Description',
    this.hintText = 'Enter description...',
    this.enabled = true,
    this.minLines = 3,
    this.prefixIcon,
  });

  @override
  State<DescriptionInputField> createState() => _DescriptionInputFieldState();
}

class _DescriptionInputFieldState extends State<DescriptionInputField> {
  Future<void> _handleTranscription(String? audioFilePath) async {
    if (audioFilePath == null) return;

    final newText = await TranscriptionService.transcribeAndGetAction(
      context: context,
      audioFilePath: audioFilePath,
      currentText: widget.controller.text,
    );

    if (newText != null && mounted) {
      widget.controller.text = newText;
      widget.onChanged?.call();
    }

    try {
      await AudioRecordingService.deleteTemporaryAudio();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.labelText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            TranscriptionVoiceButton(
              onRecordingComplete: _handleTranscription,
            ),
          ],
        ),
        const SizedBox(height: AppConfig.spacing8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, child) {
            return TextFormField(
              controller: widget.controller,
              decoration: InputDecoration(
                hintText: widget.hintText,
                prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
                border: const OutlineInputBorder(),
                suffixIcon: value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          widget.controller.clear();
                          widget.onChanged?.call();
                        },
                        tooltip: 'Clear',
                      )
                    : null,
              ),
              validator: widget.validator,
              minLines: widget.minLines,
              maxLines: null,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              enabled: widget.enabled,
              onChanged: (_) => widget.onChanged?.call(),
            );
          },
        ),
      ],
    );
  }
}

