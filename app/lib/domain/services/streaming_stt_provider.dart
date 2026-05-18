import 'dart:typed_data';

class StreamingTranscript {
  final String text;
  final bool isFinal;
  final String? languageCode;

  const StreamingTranscript({
    required this.text,
    this.isFinal = false,
    this.languageCode,
  });

  @override
  String toString() => 'StreamingTranscript(text: $text, isFinal: $isFinal)';
}

enum StreamingSttEvent { startSpeech, endSpeech, connected, disconnected, error }

class StreamingSttEventData {
  final StreamingSttEvent event;
  final String? message;

  const StreamingSttEventData(this.event, {this.message});

  @override
  String toString() => 'StreamingSttEventData($event, $message)';
}

abstract class StreamingSttProvider {
  Future<void> connect();

  void sendAudio(Uint8List pcmChunk);

  Future<void> flush();

  void sendFlush();

  Future<void> close();

  Stream<StreamingTranscript> get transcripts;

  Stream<StreamingSttEventData> get events;

  bool get isConnected;
}
