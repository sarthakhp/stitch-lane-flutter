import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_chat_models.dart';

/// Number of recent exchanges that include full tool call + response details.
const int _recentFullDetailCount = 2;

/// Max chars to show from front/back when truncating.
const int _truncateEdge = 100;

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
  final List<UiComponent> uiComponents;

  ChatExchange({
    required this.userText,
    required this.assistantText,
    this.toolCalls = const [],
    this.uiComponents = const [],
  });

  Map<String, dynamic> toJson() => {
        'userText': userText,
        'assistantText': assistantText,
        'toolCalls': toolCalls.map((t) => t.toJson()).toList(),
        'uiComponents': uiComponents.map((c) => c.toJson()).toList(),
      };

  factory ChatExchange.fromJson(Map<String, dynamic> json) => ChatExchange(
        userText: json['userText'] as String,
        assistantText: json['assistantText'] as String,
        toolCalls: (json['toolCalls'] as List?)
                ?.map((t) => ToolCallRecord.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        uiComponents: (json['uiComponents'] as List?)
                ?.map((c) => UiComponent.fromJson(c as Map<String, dynamic>))
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

  /// Build conversation history as a plain text string.
  ///
  /// Strategy:
  /// - Last [_recentFullDetailCount] exchanges: full user message + full
  ///   assistant response + tool call details (tool output truncated)
  /// - Older exchanges: full user message + truncated assistant response
  ///
  /// Returns null if there's no history.
  static String? buildHistoryText(List<ChatExchange> exchanges) {
    if (exchanges.isEmpty) return null;

    final buf = StringBuffer();
    final cutoff = exchanges.length - _recentFullDetailCount;

    for (int i = 0; i < exchanges.length; i++) {
      final e = exchanges[i];
      final isRecent = i >= cutoff;

      buf.writeln('User: ${e.userText}');

      if (isRecent && e.toolCalls.isNotEmpty) {
        // Recent: include tool call details
        for (final tc in e.toolCalls) {
          buf.writeln('Tool call: ${tc.name}(${jsonEncode(tc.arguments)})');
          buf.writeln('Tool result: ${_truncate(tc.response)}');
        }
        buf.writeln('Assistant: ${e.assistantText}');
      } else {
        // Older: truncate assistant response
        buf.writeln('Assistant: ${_truncate(e.assistantText)}');
      }

      buf.writeln();
    }

    return buf.toString().trimRight();
  }

  static String _truncate(String text) {
    if (text.length <= _truncateEdge * 2 + 3) return text;
    return '${text.substring(0, _truncateEdge)}...${text.substring(text.length - _truncateEdge)}';
  }
}
