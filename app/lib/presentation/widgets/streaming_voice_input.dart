import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../domain/state/settings_state.dart';
import 'audio_waveform.dart';
import 'voice_input_controller.dart';

/// Result emitted from the streaming voice input on success.
///
/// Carries both the (optionally formatted) transcript and the path to the
/// fail-safe local audio recording, so callers can link the audio to a
/// domain object (e.g. a measurement record).
class VoiceInputResult {
  final String text;
  final String? audioWavPath;

  const VoiceInputResult({required this.text, this.audioWavPath});
}

class StreamingVoiceInput extends StatefulWidget {
  final ValueChanged<VoiceInputResult> onDone;
  final ValueChanged<VoiceInputResult>? onSend;
  final VoidCallback onCancel;
  final String? existingText;
  final bool enableFormatting;
  final String? formattingModelName;

  /// Whether the host is currently visible. When this goes false (e.g. the user
  /// switches away from the Assistant tab) an in-progress recording is paused
  /// so the mic never keeps capturing in the background.
  final bool active;

  const StreamingVoiceInput({
    super.key,
    required this.onDone,
    this.onSend,
    required this.onCancel,
    this.existingText,
    this.enableFormatting = false,
    this.formattingModelName,
    this.active = true,
  });

  @override
  State<StreamingVoiceInput> createState() => _StreamingVoiceInputState();
}

class _StreamingVoiceInputState extends State<StreamingVoiceInput> {
  late final VoiceInputController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsState>().settings;
    _controller = VoiceInputController.create(
      settings: settings,
      enableFormatting: widget.enableFormatting,
      formattingModelName: widget.formattingModelName,
    );
    _controller.addListener(_onControllerUpdate);
    _controller.start();
  }

  @override
  void didUpdateWidget(StreamingVoiceInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Host went from visible → hidden (e.g. left the Assistant tab) while the
    // mic was live: pause so we don't record in the background. The user
    // resumes manually when they return.
    if (oldWidget.active &&
        !widget.active &&
        _controller.state == VoiceInputState.listening) {
      _controller.pause();
    }
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
      widget.onDone(VoiceInputResult(
        text: text,
        audioWavPath: _controller.backupWavPath,
      ));
    } else {
      widget.onCancel();
    }
  }

  Future<void> _handleSend() async {
    final text = await _controller.stop();
    if (!mounted) return;
    if (_controller.formattingFailed) return;
    if (text != null && text.isNotEmpty) {
      widget.onSend?.call(VoiceInputResult(
        text: text,
        audioWavPath: _controller.backupWavPath,
      ));
    } else {
      widget.onCancel();
    }
  }

  /// True if the session has captured anything worth warning the user about.
  /// We confirm in all active states — even with no transcript yet, the audio
  /// backup may already hold the user's voice, and they shouldn't lose it.
  bool get _hasRecordingToProtect {
    final s = _controller.state;
    return s != VoiceInputState.connecting &&
           s != VoiceInputState.error;
  }

  Future<bool> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard recording?'),
        content: const Text(
          'Your transcribed text and recorded audio will be lost. '
          'This cannot be undone.',
        ),
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
    return confirmed == true;
  }

  Future<void> _handleCancel() async {
    if (_hasRecordingToProtect) {
      final confirmed = await _confirmDiscard();
      if (!confirmed || !mounted) return;
    }
    await _controller.cancel();
    if (mounted) widget.onCancel();
  }

  Future<void> _handleRetryFormatting() async {
    final text = await _controller.retryFormatting();
    if (text != null && text.isNotEmpty && mounted) {
      widget.onDone(VoiceInputResult(
        text: text,
        audioWavPath: _controller.backupWavPath,
      ));
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

    return PopScope(
      // Block system back (and bottom-sheet back-button dismiss) while the
      // user has something to lose. _handleCancel runs the same confirm
      // dialog the on-screen Cancel button uses.
      canPop: !_hasRecordingToProtect,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleCancel();
      },
      child: Container(
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
            else if (_isLoading)
              _buildLoading(colorScheme, textTheme)
            else
              ..._buildRecordingBody(colorScheme, textTheme),
            const SizedBox(height: AppConfig.spacing16),
            _buildActions(colorScheme, textTheme),
          ],
        ),
      ),
    );
  }

  /// True for the post-Done states where the controller is busy producing
  /// the final text (transcribing for batch, formatting for either path).
  /// We swap to a clean spinner view so the user never sees the raw
  /// transcript briefly flash before the formatted version replaces it.
  bool get _isLoading {
    final s = _controller.state;
    return s == VoiceInputState.processing || s == VoiceInputState.formatting;
  }

  /// Recording-time body: waveform, optional transcript pane, status row,
  /// big play/pause. Pane is shown only when there's something meaningful
  /// to render — live partial transcripts during recording, OR the raw
  /// transcript on the formatting-failed recovery screen.
  List<Widget> _buildRecordingBody(ColorScheme colorScheme, TextTheme textTheme) {
    final state = _controller.state;
    final isActive = state == VoiceInputState.connecting ||
        state == VoiceInputState.listening ||
        state == VoiceInputState.paused;
    final isFailedDone =
        state == VoiceInputState.done && _controller.formattingFailed;
    final showPane = (_controller.isLive && isActive) || isFailedDone;

    return [
      if (isActive) ...[
        AudioWaveform(
          levels: _controller.amplitudeLevels,
          isPaused: state != VoiceInputState.listening,
        ),
        const SizedBox(height: AppConfig.spacing12),
      ],
      if (showPane) ...[
        _buildTranscript(colorScheme, textTheme),
        const SizedBox(height: AppConfig.spacing8),
      ],
      _buildStatus(colorScheme, textTheme),
      if (isActive) ...[
        const SizedBox(height: AppConfig.spacing16),
        _buildPrimaryControl(colorScheme),
      ],
    ];
  }

  /// Clean centered spinner shown while transcription or formatting runs.
  /// Replaces the waveform + transcript pane so the user never sees raw
  /// text appear and then get overwritten by the formatted version.
  Widget _buildLoading(ColorScheme colorScheme, TextTheme textTheme) {
    final isFormatting = _controller.state == VoiceInputState.formatting;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing24),
      child: Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppConfig.spacing16),
          Text(
            isFormatting ? 'Formatting…' : 'Transcribing…',
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppConfig.spacing4),
          Text(
            'This usually takes a few seconds.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Big centered Pause/Resume — the primary action while a session is in
  /// flight. Rendered above the secondary Cancel/Done/Send row so it sits
  /// where the thumb naturally lands.
  Widget _buildPrimaryControl(ColorScheme colorScheme) {
    final isListening = _controller.state == VoiceInputState.listening;
    final isPaused = _controller.state == VoiceInputState.paused;
    final isConnecting = _controller.state == VoiceInputState.connecting;

    // Hide entirely outside the active session — done/formatting states
    // don't have a pause concept and would crowd the layout.
    if (!isListening && !isPaused && !isConnecting) {
      return const SizedBox.shrink();
    }

    final VoidCallback? onTap = isListening
        ? _controller.pause
        : isPaused
            ? _controller.resume
            : null;
    final icon = isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded;
    final tooltip = isPaused ? 'Resume' : 'Pause';

    return Center(
      child: IconButton.filledTonal(
        onPressed: onTap,
        tooltip: tooltip,
        iconSize: 44,
        style: IconButton.styleFrom(
          minimumSize: const Size(80, 80),
          fixedSize: const Size(80, 80),
          shape: const CircleBorder(),
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
        ),
        icon: Icon(icon),
      ),
    );
  }

  Widget _buildTranscript(ColorScheme colorScheme, TextTheme textTheme) {
    final text = _controller.displayText;
    final hasText = text.isNotEmpty;
    final isListening = _controller.state == VoiceInputState.listening;

    // Batch controllers don't produce text until after stop() — show a
    // dimmed instruction in place of the streaming partial-transcript pane.
    final String placeholder = _controller.isLive
        ? 'Waiting for speech...'
        : 'Transcription will run when you tap Done.';

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
          hasText ? text : placeholder,
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
        statusText = _controller.isLive ? 'Connecting...' : 'Preparing...';
        statusIcon = Icons.wifi;
      case VoiceInputState.listening:
        statusText = _controller.isLive ? 'Listening...' : 'Recording...';
        statusIcon = Icons.mic;
      case VoiceInputState.paused:
        statusText = 'Paused';
        statusIcon = Icons.pause_circle;
      case VoiceInputState.processing:
        statusText = 'Transcribing...';
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
          ' / ${_formatDuration(VoiceInputController.maxRecordingSeconds)}',
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
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppConfig.spacing8,
            runSpacing: AppConfig.spacing8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _controller.retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              _BackupAudioButton(controller: _controller),
            ],
          ),
          const SizedBox(height: AppConfig.spacing8),
          Text(
            'Your audio is saved on this device.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ColorScheme colorScheme, TextTheme textTheme) {
    final isPaused = _controller.state == VoiceInputState.paused;
    final isActive = _controller.state == VoiceInputState.listening ||
        _controller.state == VoiceInputState.connecting;

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
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppConfig.spacing8,
                  runSpacing: AppConfig.spacing4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _handleRetryFormatting,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                    FilledButton(
                      onPressed: () => widget.onDone(VoiceInputResult(
                        text: _controller.finalText,
                        audioWavPath: _controller.backupWavPath,
                      )),
                      child: const Text('Use Raw'),
                    ),
                  ],
                ),
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
        if (isActive || isPaused)
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: AppConfig.spacing8,
              runSpacing: AppConfig.spacing4,
              children: [
                FilledButton.tonal(
                  onPressed: _handleDone,
                  child: const Text('Done'),
                ),
                if (widget.onSend != null)
                  FilledButton.icon(
                    onPressed: _handleSend,
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
              ],
            ),
          ),
        if (_controller.state == VoiceInputState.error)
          TextButton(
            onPressed: _handleCancel,
            child: const Text('Dismiss'),
          ),
      ],
    );
  }
}

/// Play/stop button for the fail-safe backup recording, shown in error state.
/// Resolves the .wav lazily so it works even if the controller's finalize
/// hasn't completed yet by the time the user taps it.
class _BackupAudioButton extends StatefulWidget {
  final VoiceInputController controller;

  const _BackupAudioButton({required this.controller});

  @override
  State<_BackupAudioButton> createState() => _BackupAudioButtonState();
}

class _BackupAudioButtonState extends State<_BackupAudioButton> {
  AudioPlayer? _player;
  StreamSubscription<void>? _completeSub;
  bool _isPlaying = false;
  bool _isPreparing = false;

  @override
  void dispose() {
    _completeSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<File?> _resolveWavFile() async {
    // Try a few times — the controller fires finalize() but it's async, so
    // the .wav may appear a beat after the error UI shows up.
    for (var i = 0; i < 30; i++) {
      final path = widget.controller.backupWavPath;
      if (path != null) {
        final f = File(path);
        if (await f.exists() && await f.length() > 0) return f;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player?.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPreparing = true);
    final wav = await _resolveWavFile();
    if (!mounted) return;
    setState(() => _isPreparing = false);

    if (wav == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.backupPcmPath == null
                ? 'No backup audio was recorded for this session.'
                : 'Audio is still being prepared — try again in a moment.',
          ),
        ),
      );
      return;
    }

    _player ??= AudioPlayer();
    _completeSub ??= _player!.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    try {
      await _player!.play(DeviceFileSource(wav.path));
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play audio: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget icon;
    final String label;
    if (_isPreparing) {
      icon = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      label = 'Preparing…';
    } else if (_isPlaying) {
      icon = const Icon(Icons.stop);
      label = 'Stop';
    } else {
      icon = const Icon(Icons.play_arrow);
      label = 'Play recorded audio';
    }
    return FilledButton.icon(
      onPressed: _isPreparing ? null : _toggle,
      icon: icon,
      label: Text(label),
    );
  }
}
