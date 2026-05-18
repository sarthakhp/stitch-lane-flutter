import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/services/streaming_stt_provider.dart';
import '../../domain/services/streaming_transcription_service.dart';

class StreamingSttTestDialog extends StatefulWidget {
  const StreamingSttTestDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const StreamingSttTestDialog(),
    );
  }

  @override
  State<StreamingSttTestDialog> createState() => _StreamingSttTestDialogState();
}

class _StreamingSttTestDialogState extends State<StreamingSttTestDialog> {
  final StreamingTranscriptionService _service = StreamingTranscriptionService();
  StreamSubscription<StreamingTranscript>? _transcriptSub;
  StreamSubscription<StreamingSttEventData>? _eventSub;

  String _status = 'Connecting...';
  String _partialText = '';
  String _finalText = '';
  String? _error;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    try {
      _transcriptSub = _service.transcripts.listen((t) {
        if (!mounted) return;
        setState(() {
          if (t.isFinal) {
            _finalText = _service.currentTranscript;
            _partialText = '';
          } else {
            _partialText = t.text;
          }
        });
      });

      _eventSub = _service.events.listen((e) {
        if (!mounted) return;
        switch (e.event) {
          case StreamingSttEvent.connected:
            setState(() => _status = 'Listening...');
          case StreamingSttEvent.startSpeech:
            setState(() => _status = 'Speaking detected...');
          case StreamingSttEvent.endSpeech:
            setState(() => _status = 'Processing...');
          case StreamingSttEvent.error:
            setState(() {
              _error = e.message ?? 'Unknown error';
              _status = 'Error';
            });
          case StreamingSttEvent.disconnected:
            setState(() => _status = 'Disconnected');
        }
      });

      await _service.start();
      if (mounted) {
        setState(() {
          _isListening = true;
          _status = 'Listening...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _status = 'Failed to start';
        });
      }
    }
  }

  Future<void> _stop() async {
    setState(() => _status = 'Finalizing...');
    final result = await _service.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _finalText = result ?? _finalText;
        _status = 'Done';
      });
    }
  }

  Future<void> _cancel() async {
    await _service.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _transcriptSub?.cancel();
    _eventSub?.cancel();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = _finalText.isNotEmpty || _partialText.isNotEmpty
        ? '$_finalText${_partialText.isNotEmpty ? ' $_partialText' : ''}'
        : '';

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isListening ? Icons.mic : Icons.mic_off,
            color: _isListening ? Colors.red : theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 8),
          Text('Streaming STT Test', style: theme.textTheme.titleMedium),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _status,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _error != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  displayText.isEmpty ? 'Waiting for speech...' : displayText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: displayText.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                    fontStyle: displayText.isEmpty ? FontStyle.italic : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        if (_isListening)
          FilledButton(
            onPressed: _stop,
            child: const Text('Done'),
          ),
        if (!_isListening && _finalText.isNotEmpty)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
      ],
    );
  }
}
