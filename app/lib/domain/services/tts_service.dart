import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import '../../utils/app_logger.dart';
import '../../utils/markdown_helper.dart';
import 'sarvam_streaming_tts_provider.dart';
import 'streaming_tts_provider.dart';

enum TtsPlaybackState { idle, connecting, buffering, playing, stopped, error }

class TtsService {
  /// Master switch for text-to-speech. Sarvam TTS is the only provider wired in
  /// (no Gemini TTS adapter yet) and we're not incurring its cost yet, so this
  /// is off: [speak] is a no-op and the UI hides Play buttons. Flip to true to
  /// re-enable everywhere. (Non-const so it doesn't statically dead-code the
  /// real implementation below.)
  // ignore: prefer_const_declarations
  static final bool ttsEnabled = false;

  static const _sampleRate = 22050;
  static const _channels = 1;

  SarvamStreamingTtsProvider? _provider;
  StreamSubscription<TtsAudioChunk>? _audioSubscription;
  StreamSubscription<StreamingTtsEventData>? _eventSubscription;

  // Queue of int16 samples waiting to be fed to the player.
  final _sampleQueue = <int>[];
  bool _playerInitialized = false;
  bool _playbackStarted = false;
  bool _ttsCompleted = false;
  Timer? _drainCheckTimer;

  String? _currentText;
  bool _isActive = false;

  final _stateController = StreamController<TtsPlaybackState>.broadcast();

  String? get currentText => _currentText;
  bool get isActive => _isActive;
  Stream<TtsPlaybackState> get stateChanges => _stateController.stream;

  Future<void> speak(String text, {String speaker = 'shubh'}) async {
    if (!ttsEnabled) {
      AppLogger.info('TtsService.speak: skipped (TTS disabled)');
      return;
    }
    if (text.isEmpty) return;

    await stop();

    final stripped = MarkdownHelper.stripMarkdown(text);
    if (stripped.trim().isEmpty) return;

    _currentText = text;
    _isActive = true;
    _ttsCompleted = false;
    _playbackStarted = false;
    _emitState(TtsPlaybackState.connecting);

    try {
      await _initPlayer();

      _provider = SarvamStreamingTtsProvider();
      _audioSubscription = _provider!.audioChunks.listen(_onAudioChunk);
      _eventSubscription = _provider!.events.listen(_onEvent);

      final config = TtsConfig(speaker: speaker);
      await _provider!.connect(config: config);
      _provider!.sendConfig(config);

      _emitState(TtsPlaybackState.buffering);

      _provider!.sendText(stripped);
      _provider!.sendFlush();
    } catch (e) {
      AppLogger.error('TtsService: failed to start', e);
      _emitState(TtsPlaybackState.error);
      await _cleanup();
    }
  }

  Future<void> _initPlayer() async {
    if (_playerInitialized) return;
    await FlutterPcmSound.setup(
      sampleRate: _sampleRate,
      channelCount: _channels,
    );
    // Feed callback fires when remaining frames drop below this threshold.
    // ~150ms cushion at 22050 Hz mono.
    await FlutterPcmSound.setFeedThreshold(_sampleRate ~/ 7);
    FlutterPcmSound.setFeedCallback(_onFeed);
    _playerInitialized = true;
  }

  Future<void> stop() async {
    if (!_isActive && !_playbackStarted) return;
    _isActive = false;
    _currentText = null;
    _emitState(TtsPlaybackState.stopped);
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _drainCheckTimer?.cancel();
    _drainCheckTimer = null;

    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _eventSubscription?.cancel();
    _eventSubscription = null;

    if (_provider?.isConnected == true) {
      await _provider?.close();
    }
    _provider = null;

    _sampleQueue.clear();
    _playbackStarted = false;
    _ttsCompleted = false;

    if (_playerInitialized) {
      try {
        await FlutterPcmSound.release();
      } catch (_) {}
      _playerInitialized = false;
    }
  }

  void _onAudioChunk(TtsAudioChunk chunk) {
    if (!_isActive) return;
    // Sarvam PCM = signed 16-bit little-endian samples.
    final samples = Int16List.view(
      chunk.audioBytes.buffer,
      chunk.audioBytes.offsetInBytes,
      chunk.audioBytes.lengthInBytes ~/ 2,
    );
    _sampleQueue.addAll(samples);

    if (!_playbackStarted) {
      _playbackStarted = true;
      _emitState(TtsPlaybackState.playing);
      FlutterPcmSound.start();
      // Kick the first feed manually since threshold may not be crossed yet.
      _onFeed(0);
    }
  }

  void _onFeed(int remainingFrames) {
    if (!_isActive) return;
    if (_sampleQueue.isEmpty) {
      // If TTS is done and queue is drained, schedule end-of-playback check.
      if (_ttsCompleted) _scheduleDrainCheck(remainingFrames);
      return;
    }
    final take = _sampleQueue.length < 8192 ? _sampleQueue.length : 8192;
    final chunk = _sampleQueue.sublist(0, take);
    _sampleQueue.removeRange(0, take);
    FlutterPcmSound.feed(PcmArrayInt16.fromList(chunk));
  }

  void _scheduleDrainCheck(int remainingFrames) {
    if (_drainCheckTimer != null) return;
    // Wait for the player's buffered samples to drain before declaring done.
    final ms = (remainingFrames / _sampleRate * 1000).ceil() + 100;
    _drainCheckTimer = Timer(Duration(milliseconds: ms), () {
      _drainCheckTimer = null;
      if (_isActive && _ttsCompleted && _sampleQueue.isEmpty) {
        _isActive = false;
        _currentText = null;
        _emitState(TtsPlaybackState.idle);
        _cleanup();
      }
    });
  }

  void _onEvent(StreamingTtsEventData event) {
    switch (event.event) {
      case StreamingTtsEvent.completed:
        _ttsCompleted = true;
        // If no audio ever arrived, finish immediately.
        if (!_playbackStarted) {
          _isActive = false;
          _currentText = null;
          _emitState(TtsPlaybackState.idle);
          _cleanup();
        }
      case StreamingTtsEvent.error:
        AppLogger.error('TtsService: provider error: ${event.message}');
        _emitState(TtsPlaybackState.error);
        _cleanup();
      case StreamingTtsEvent.disconnected:
        // Server may close idle connections after playback — only a problem
        // if it happens mid-TTS before completion.
        if (_isActive && !_ttsCompleted) {
          _ttsCompleted = true;
        }
      case StreamingTtsEvent.connected:
        break;
    }
  }

  void _emitState(TtsPlaybackState state) {
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _stateController.close();
  }
}
