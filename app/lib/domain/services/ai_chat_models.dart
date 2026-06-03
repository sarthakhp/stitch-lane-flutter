import 'ai_action/proposed_action.dart';

class UiComponent {
  final String type; // 'customer' or 'order'
  final String id;
  final String? title;
  final List<String> details;

  /// Local image paths (orders only) — shown as the card's cover photo.
  final List<String> imagePaths;

  const UiComponent({
    required this.type,
    required this.id,
    this.title,
    this.details = const [],
    this.imagePaths = const [],
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
        if (imagePaths.isNotEmpty) 'imagePaths': imagePaths,
      };

  factory UiComponent.fromJson(Map<String, dynamic> json) => UiComponent(
        type: json['type'] as String,
        id: json['id'] as String,
        title: json['title'] as String?,
        details: (json['details'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        imagePaths: (json['imagePaths'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

class AiChatMessage {
  final String text;
  final bool isUser;
  final bool wasVoiceInput;
  final List<UiComponent> uiComponents;

  /// Staged changes the assistant proposed in this message (write actions).
  /// Mutated via [copyWith] as the user confirms/cancels them.
  final List<ProposedAction> proposedActions;

  AiChatMessage({
    required this.text,
    required this.isUser,
    this.wasVoiceInput = false,
    this.uiComponents = const [],
    this.proposedActions = const [],
  });

  AiChatMessage copyWith({List<ProposedAction>? proposedActions}) {
    return AiChatMessage(
      text: text,
      isUser: isUser,
      wasVoiceInput: wasVoiceInput,
      uiComponents: uiComponents,
      proposedActions: proposedActions ?? this.proposedActions,
    );
  }
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
  final List<ProposedAction> proposedActions;

  AiChatResponse({
    required this.text,
    required this.usage,
    this.uiComponents = const [],
    this.proposedActions = const [],
  });
}
