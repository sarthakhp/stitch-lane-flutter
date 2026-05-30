import 'package:flutter/material.dart';
import '../../../config/app_config.dart';

/// Text-mode bar with mic + text field + send button. The mic is purely a
/// trigger — callers wire it however they want (inline voice swap via
/// [AiInputArea], or a modal bottom sheet, or anything else).
///
/// [inline] = false (default) is for chat-style screens where the bar lives
/// stuck to the bottom of the viewport — adds safe-area bottom padding and a
/// top divider so the bar reads as the page footer. [inline] = true is for
/// screens that embed the bar mid-column with their own content below
/// (e.g. the order-creator refinement section followed by a CTA) — drops the
/// safe-area padding and the top divider for visual continuity.
class AiInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final void Function(String) onSend;
  final VoidCallback onMicTap;
  final bool inline;

  /// Placeholder shown when the field is empty.
  final String hintText;

  const AiInputBar({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.onMicTap,
    this.inline = false,
    this.hintText = 'Ask anything...',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: AppConfig.spacing12,
        right: AppConfig.spacing4,
        top: AppConfig.spacing8,
        bottom: inline
            ? AppConfig.spacing8
            : (MediaQuery.of(context).viewInsets.bottom > 0
                    ? 0.0
                    : MediaQuery.of(context).padding.bottom) +
                AppConfig.spacing8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: inline
            ? null
            : Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          _MicButton(
            onTap: isLoading ? null : onMicTap,
            colorScheme: colorScheme,
          ),
          const SizedBox(width: AppConfig.spacing4),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConfig.spacing16,
                  vertical: AppConfig.spacing12,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              enabled: !isLoading,
              maxLines: null,
            ),
          ),
          const SizedBox(width: AppConfig.spacing4),
          IconButton.filled(
            onPressed: isLoading ? null : () => onSend(controller.text),
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final VoidCallback? onTap;
  final ColorScheme colorScheme;

  const _MicButton({required this.onTap, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    const borderWidth = 1.5;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.tertiary,
            ],
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(borderWidth),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surface,
          ),
          child: Icon(
            Icons.mic,
            size: 20,
            color: onTap != null
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}
