class UiComponent {
  final String type; // 'customer' or 'order'
  final String id;
  final String? title;
  final List<String> details;

  const UiComponent({
    required this.type,
    required this.id,
    this.title,
    this.details = const [],
  });

  /// Summary for conversation history context.
  String get historyLabel {
    final parts = [if (title != null) title!, ...details];
    return parts.isEmpty ? '$type:$id' : '${parts.join(', ')} ($type:$id)';
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        if (title != null) 'title': title,
        if (details.isNotEmpty) 'details': details,
      };

  factory UiComponent.fromJson(Map<String, dynamic> json) => UiComponent(
        type: json['type'] as String,
        id: json['id'] as String,
        title: json['title'] as String?,
        details: (json['details'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

class AiChatMessage {
  final String text;
  final bool isUser;
  final List<UiComponent> uiComponents;

  AiChatMessage({
    required this.text,
    required this.isUser,
    this.uiComponents = const [],
  });
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
  final List<UiComponent> uiComponents;

  AiChatResponse({
    required this.text,
    required this.usage,
    this.uiComponents = const [],
  });
}
