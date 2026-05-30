import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'pricing.dart';

/// Display helpers shared by the AI usage dashboard widgets. Centralized so
/// every screen / card formats currencies, tokens, durations, and caller
/// labels identically.
class UsageFormatters {
  UsageFormatters._();

  static final NumberFormat _inrFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final NumberFormat _usdFormat =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);

  /// Formats a USD cost. Uses up to 4 decimals for sub-cent amounts so the
  /// dashboard never shows "\$0.00" for a real call (LLM calls regularly land
  /// in the \$0.0001–\$0.001 range).
  static String usd(double? cost) {
    if (cost == null) return '—';
    if (cost == 0) return '\$0.00';
    if (cost < 0.01) return '\$${cost.toStringAsFixed(4)}';
    return _usdFormat.format(cost);
  }

  /// Formats a USD cost in INR using the gateway's fixed FX rate.
  static String inr(double? costUsd) {
    if (costUsd == null) return '—';
    final value = Pricing.toInr(costUsd);
    if (value == 0) return '₹0.00';
    if (value < 0.50) return '₹${value.toStringAsFixed(3)}';
    return _inrFormat.format(value);
  }

  /// Compact token count: 12.3K, 1.42M, etc.
  static String tokens(int? value) {
    if (value == null || value == 0) return '—';
    if (value < 1000) return '$value';
    if (value < 1000000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '${(value / 1000000).toStringAsFixed(2)}M';
  }

  /// Wall-clock duration → "350ms" / "4.2s" / "1m 12s".
  static String duration(int ms) {
    if (ms < 1000) return '${ms}ms';
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)}s';
    final mins = ms ~/ 60000;
    final secs = ((ms % 60000) / 1000).round();
    return '${mins}m ${secs}s';
  }

  /// Audio duration with an em-dash fallback for null/zero.
  static String audioMs(int? ms) {
    if (ms == null || ms == 0) return '—';
    return duration(ms);
  }

  /// "just now" / "12m ago" / "3h ago" / "May 23".
  static String relativeTime(DateTime then) {
    final diff = DateTime.now().difference(then);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(then);
  }

  /// Maps the `caller_tag` string to a human-readable label for the UI.
  /// Unknown tags fall through to the raw string.
  static String callerLabel(String tag) {
    switch (tag) {
      case 'chat':
        return 'Chat assistant';
      case 'order_creator':
        return 'Order creator';
      case 'transcription':
        return 'Transcription';
      case 'transcript_format':
        return 'Transcript formatting';
      case 'stt_batch':
        return 'STT (batch)';
      case 'stt_stream':
        return 'STT (streaming)';
      case 'tts_stream':
        return 'TTS (streaming)';
      default:
        return tag;
    }
  }

  /// Each `caller_tag` is pinned to exactly one provider today (chat,
  /// order_creator, transcription, transcript_format → Gemini; stt_stream,
  /// tts_stream → Sarvam; stt_batch → Sarvam). Returns the display name, or
  /// null for unknown tags. If we ever multi-source a tag we'll switch this
  /// to read the per-event provider from the database instead.
  static String? callerProvider(String tag) {
    switch (tag) {
      case 'chat':
      case 'order_creator':
      case 'transcription':
      case 'transcript_format':
        return 'Gemini';
      case 'stt_batch':
      case 'stt_stream':
      case 'tts_stream':
        return 'Sarvam';
      default:
        return null;
    }
  }

  /// Display name for a [UsageProvider] enum value.
  static String providerName(String providerEnumName) {
    switch (providerEnumName) {
      case 'gemini':
        return 'Gemini';
      case 'sarvam':
        return 'Sarvam';
      default:
        return providerEnumName;
    }
  }

  static IconData callerIcon(String tag) {
    switch (tag) {
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'order_creator':
        return Icons.auto_awesome_outlined;
      case 'transcription':
        return Icons.mic_outlined;
      case 'transcript_format':
        return Icons.format_align_left_outlined;
      case 'stt_batch':
      case 'stt_stream':
        return Icons.record_voice_over_outlined;
      case 'tts_stream':
        return Icons.volume_up_outlined;
      default:
        return Icons.bolt_outlined;
    }
  }

  /// Cohesive color per feature for the breakdown bars. Stable mapping so
  /// the eye learns "chat is always blue".
  static Color callerColor(String tag, ColorScheme scheme) {
    switch (tag) {
      case 'chat':
        return scheme.primary;
      case 'order_creator':
        return scheme.tertiary;
      case 'transcription':
      case 'stt_batch':
      case 'stt_stream':
        return scheme.secondary;
      case 'transcript_format':
        return Colors.amber.shade700;
      case 'tts_stream':
        return Colors.deepPurple.shade400;
      default:
        return scheme.outline;
    }
  }
}
