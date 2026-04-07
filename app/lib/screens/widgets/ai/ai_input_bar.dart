import 'package:flutter/material.dart';
import '../../../config/app_config.dart';

class AiInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final void Function(String) onSend;
  final VoidCallback onMicTap;

  const AiInputBar({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: AppConfig.spacing12,
        right: AppConfig.spacing4,
        top: AppConfig.spacing8,
        bottom: (MediaQuery.of(context).viewInsets.bottom > 0
            ? 0.0
            : MediaQuery.of(context).padding.bottom) + AppConfig.spacing8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
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
                hintText: 'Ask anything...',
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
