import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import 'audio_waveform.dart';
import 'streaming_voice_input_controller.dart';

class StreamingVoiceInput extends StatefulWidget {
  final ValueChanged<String> onDone;
  final ValueChanged<String>? onSend;
  final VoidCallback onCancel;
  final String? existingText;
  final bool enableFormatting;

  const StreamingVoiceInput({
    super.key,
    required this.onDone,
    this.onSend,
    required this.onCancel,
    this.existingText,
    this.enableFormatting = false,
  });

  @override
  State<StreamingVoiceInput> createState() => _StreamingVoiceInputState();
}

class _StreamingVoiceInputState extends State<StreamingVoiceInput> {
  late final StreamingVoiceInputController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = StreamingVoiceInputController(
      enableFormatting: widget.enableFormatting,
    );
    _controller.addListener(_onControllerUpdate);
    _controller.start();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
    _autoScroll();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleDone() async {
    final text = await _controller.stop();
    if (!mounted) return;
    // If formatting failed, stay on screen so user sees the error UI
    if (_controller.formattingFailed) return;
    if (text != null && text.isNotEmpty) {
      widget.onDone(text);
    } else {
      widget.onCancel();
    }
  }

  Future<void> _handleSend() async {
    final text = await _controller.stop();
    if (!mounted) return;
    if (_controller.formattingFailed) return;
    if (text != null && text.isNotEmpty) {
      widget.onSend?.call(text);
    } else {
      widget.onCancel();
    }
  }

  Future<void> _handleCancel() async {
    if (_controller.displayText.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard recording?'),
          content: const Text('Your transcribed text will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep recording'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _controller.cancel();
    if (mounted) widget.onCancel();
  }

  Future<void> _handleRetryFormatting() async {
    final text = await _controller.retryFormatting();
    if (text != null && text.isNotEmpty && mounted) {
      widget.onDone(text);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.only(
        left: AppConfig.spacing16,
        right: AppConfig.spacing16,
        top: AppConfig.spacing12,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_controller.state == VoiceInputState.error)
            _buildError(colorScheme, textTheme)
          else ...[
            AudioWaveform(
              levels: _controller.amplitudeLevels,
              isPaused: _controller.state != VoiceInputState.listening,
            ),
            const SizedBox(height: AppConfig.spacing12),
            _buildTranscript(colorScheme, textTheme),
            const SizedBox(height: AppConfig.spacing8),
            _buildStatus(colorScheme, textTheme),
          ],
          const SizedBox(height: AppConfig.spacing12),
          _buildActions(colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildTranscript(ColorScheme colorScheme, TextTheme textTheme) {
    final text = _controller.displayText;
    final hasText = text.isNotEmpty;
    final isListening = _controller.state == VoiceInputState.listening;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      constraints: const BoxConstraints(maxHeight: 120),
      width: double.infinity,
      padding: const EdgeInsets.all(AppConfig.spacing12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isListening
              ? colorScheme.primary.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
        boxShadow: isListening
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Text(
          hasText ? text : 'Waiting for speech...',
          style: textTheme.bodyMedium?.copyWith(
            color: hasText
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            fontStyle: hasText ? null : FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(ColorScheme colorScheme, TextTheme textTheme) {
    final String statusText;
    final IconData statusIcon;

    switch (_controller.state) {
      case VoiceInputState.connecting:
        statusText = 'Connecting...';
        statusIcon = Icons.wifi;
      case VoiceInputState.listening:
        statusText = 'Listening...';
        statusIcon = Icons.mic;
      case VoiceInputState.paused:
        statusText = 'Paused';
        statusIcon = Icons.pause_circle;
      case VoiceInputState.processing:
        statusText = 'Processing...';
        statusIcon = Icons.hourglass_top;
      case VoiceInputState.formatting:
        statusText = 'Formatting...';
        statusIcon = Icons.auto_fix_high;
      case VoiceInputState.done:
        statusText = 'Done';
        statusIcon = Icons.check_circle;
      case VoiceInputState.error:
        statusText = 'Error';
        statusIcon = Icons.error;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(statusIcon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _formatDuration(_controller.recordingSeconds),
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
        Text(
          ' / ${_formatDuration(StreamingVoiceInputController.maxRecordingSeconds)}',
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }


  Widget _buildError(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing8),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 32),
          const SizedBox(height: AppConfig.spacing8),
          Text(
            _controller.errorMessage ?? 'Something went wrong',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConfig.spacing12),
          FilledButton.tonalIcon(
            onPressed: _controller.retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ColorScheme colorScheme, TextTheme textTheme) {
    final isListening = _controller.state == VoiceInputState.listening;
    final isPaused = _controller.state == VoiceInputState.paused;
    final isConnecting = _controller.state == VoiceInputState.connecting;
    final isActive = isListening || isConnecting;

    // Done state with formatting failure — show retry + use raw
    if (_controller.state == VoiceInputState.done && _controller.formattingFailed) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConfig.spacing8),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, size: 16, color: colorScheme.onErrorContainer),
                const SizedBox(width: AppConfig.spacing8),
                Expanded(
                  child: Text(
                    'Formatting failed. Using raw transcription.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConfig.spacing8),
          Row(
            children: [
              TextButton(
                onPressed: _handleCancel,
                child: const Text('Cancel'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _handleRetryFormatting,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
              const SizedBox(width: AppConfig.spacing8),
              FilledButton(
                onPressed: () => widget.onDone(_controller.finalText),
                child: const Text('Use Raw'),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        TextButton(
          onPressed: _handleCancel,
          child: const Text('Cancel'),
        ),
        const Spacer(),
        if (isActive || isPaused) ...[
          IconButton.filledTonal(
            onPressed: isListening
                ? _controller.pause
                : isPaused
                    ? _controller.resume
                    : null,
            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: isPaused ? 'Resume' : 'Pause',
          ),
          const SizedBox(width: AppConfig.spacing8),
          FilledButton.tonal(
            onPressed: _handleDone,
            child: const Text('Done'),
          ),
          if (widget.onSend != null) ...[
            const SizedBox(width: AppConfig.spacing8),
            FilledButton.icon(
              onPressed: _handleSend,
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ],
        ],
        if (_controller.state == VoiceInputState.error)
          TextButton(
            onPressed: _handleCancel,
            child: const Text('Dismiss'),
          ),
      ],
    );
  }
}
