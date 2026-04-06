class AiChatMessage {
  final String text;
  final bool isUser;

  AiChatMessage({required this.text, required this.isUser});
}

class AiTokenUsage {
  final int promptTokens;
  final int responseTokens;
  final int totalTokens;

  const AiTokenUsage({
    required this.promptTokens,
    required this.responseTokens,
    required this.totalTokens,
  });

  static const zero = AiTokenUsage(promptTokens: 0, responseTokens: 0, totalTokens: 0);

  AiTokenUsage operator +(AiTokenUsage other) => AiTokenUsage(
        promptTokens: promptTokens + other.promptTokens,
        responseTokens: responseTokens + other.responseTokens,
        totalTokens: totalTokens + other.totalTokens,
      );
}

class AiChatResponse {
  final String text;
  final AiTokenUsage usage;

  AiChatResponse({required this.text, required this.usage});
}
