import 'dart:convert';
import 'package:langchain/langchain.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Number of recent exchanges that include full tool call details in history.
/// Older exchanges only include user text + assistant response text.
const int _recentFullDetailCount = 2;

const String _storageKey = 'ai_chat_history';
const String _usageStorageKey = 'ai_chat_token_usage';

/// A single tool call and its response, captured during an exchange.
class ToolCallRecord {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final String response;

  ToolCallRecord({
    required this.id,
    required this.name,
    required this.arguments,
    required this.response,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arguments': arguments,
        'response': response,
      };

  factory ToolCallRecord.fromJson(Map<String, dynamic> json) => ToolCallRecord(
        id: json['id'] as String,
        name: json['name'] as String,
        arguments: Map<String, dynamic>.from(json['arguments'] as Map),
        response: json['response'] as String,
      );
}

/// A complete user→assistant exchange, including any tool calls that happened.
class ChatExchange {
  final String userText;
  final String assistantText;
  final List<ToolCallRecord> toolCalls;

  ChatExchange({
    required this.userText,
    required this.assistantText,
    this.toolCalls = const [],
  });

  Map<String, dynamic> toJson() => {
        'userText': userText,
        'assistantText': assistantText,
        'toolCalls': toolCalls.map((t) => t.toJson()).toList(),
      };

  factory ChatExchange.fromJson(Map<String, dynamic> json) => ChatExchange(
        userText: json['userText'] as String,
        assistantText: json['assistantText'] as String,
        toolCalls: (json['toolCalls'] as List?)
                ?.map((t) => ToolCallRecord.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class AiChatHistory {
  /// Load saved exchanges from storage.
  static Future<List<ChatExchange>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (json == null) return [];

    final List<dynamic> list = jsonDecode(json);
    return list.map((e) => ChatExchange.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Save exchanges to storage.
  static Future<void> save(List<ChatExchange> exchanges) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(exchanges.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  /// Clear saved conversation.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_usageStorageKey);
  }

  /// Save token usage to storage.
  static Future<void> saveUsage(Map<String, int> usage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usageStorageKey, jsonEncode(usage));
  }

  /// Load token usage from storage.
  static Future<Map<String, int>?> loadUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_usageStorageKey);
    if (json == null) return null;
    final map = jsonDecode(json) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as int));
  }

  /// Build langchain ChatMessage list from saved exchanges.
  ///
  /// Strategy:
  /// - Last [_recentFullDetailCount] exchanges: include full tool call details
  ///   (AI tool call message → tool response → AI final response)
  /// - Older exchanges: only user text + assistant response text
  ///
  /// This keeps recent context rich for the model while avoiding history bloat.
  static List<ChatMessage> buildLangchainHistory(
    String systemPrompt,
    List<ChatExchange> exchanges,
  ) {
    final messages = <ChatMessage>[ChatMessage.system(systemPrompt)];
    if (exchanges.isEmpty) return messages;

    final cutoff = exchanges.length - _recentFullDetailCount;

    for (int i = 0; i < exchanges.length; i++) {
      final exchange = exchanges[i];
      final isRecent = i >= cutoff;

      // Always add the user message
      messages.add(ChatMessage.humanText(exchange.userText));

      if (isRecent && exchange.toolCalls.isNotEmpty) {
        // Recent exchange: include full tool call flow
        // 1. AI message with tool calls
        messages.add(AIChatMessage(
          content: '',
          toolCalls: exchange.toolCalls
              .map((tc) => AIChatMessageToolCall(
                    id: tc.id,
                    name: tc.name,
                    argumentsRaw: jsonEncode(tc.arguments),
                    arguments: tc.arguments,
                  ))
              .toList(),
        ));

        // 2. Tool responses
        for (final tc in exchange.toolCalls) {
          messages.add(ChatMessage.tool(
            toolCallId: tc.id,
            content: tc.response,
          ));
        }

        // 3. Final AI text response
        messages.add(AIChatMessage(content: exchange.assistantText));
      } else {
        // Older exchange: just the assistant's text response
        messages.add(AIChatMessage(content: exchange.assistantText));
      }
    }

    return messages;
  }
}
