import 'dart:typed_data';

class TtsAudioChunk {
  final Uint8List audioBytes;
  final String contentType;

  const TtsAudioChunk({required this.audioBytes, required this.contentType});
}

enum StreamingTtsEvent { connected, disconnected, error, completed }

class StreamingTtsEventData {
  final StreamingTtsEvent event;
  final String? message;

  const StreamingTtsEventData(this.event, {this.message});

  @override
  String toString() => 'StreamingTtsEventData($event, $message)';
}

class TtsConfig {
  final String targetLanguageCode;
  final String speaker;
  final String model;
  final int speechSampleRate;
  final String outputAudioCodec;

  const TtsConfig({
    this.targetLanguageCode = 'gu-IN',
    this.speaker = 'shubh',
    this.model = 'bulbul:v3',
    this.speechSampleRate = 22050,
    this.outputAudioCodec = 'pcm',
  });

  Map<String, dynamic> toWsJson() => {
        'target_language_code': targetLanguageCode,
        'speaker': speaker,
        'output_audio_codec': outputAudioCodec,
        'speech_sample_rate': speechSampleRate,
      };
}

abstract class StreamingTtsProvider {
  Future<void> connect({TtsConfig config = const TtsConfig()});

  void sendConfig(TtsConfig config);

  void sendText(String textChunk);

  void sendFlush();

  Future<void> close();

  Stream<TtsAudioChunk> get audioChunks;

  Stream<StreamingTtsEventData> get events;

  bool get isConnected;
}
