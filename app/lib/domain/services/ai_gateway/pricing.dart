import 'usage_event.dart';

/// Per-unit prices for a (provider, model, kind) combination.
///
/// Any field may be null — only the fields that apply to the kind are used.
/// Chat/multimodal use [inputPerMillion]/[outputPerMillion] (plus optional
/// [audioInputPerSecond] for Gemini multimodal). STT/TTS use the audio and
/// character fields.
class PricingEntry {
  /// USD per 1,000,000 input tokens.
  final double? inputPerMillion;

  /// USD per 1,000,000 output tokens.
  final double? outputPerMillion;

  /// USD per second of audio sent in (Gemini multimodal, Sarvam STT).
  final double? audioInputPerSecond;

  /// USD per second of audio returned (TTS).
  final double? audioOutputPerSecond;

  /// USD per input character (Sarvam TTS).
  final double? perCharacter;

  const PricingEntry({
    this.inputPerMillion,
    this.outputPerMillion,
    this.audioInputPerSecond,
    this.audioOutputPerSecond,
    this.perCharacter,
  });
}

/// Lookup table of provider prices.
///
/// Numbers below are pulled from each provider's published rate. The
/// dashboard still labels totals as "estimated cost" because (a) prices can
/// move between updates of this file and (b) per-modality token splits
/// (text vs audio inside the same Gemini call) aren't tracked separately
/// yet, so multimodal cost is an upper-bound estimate.
class Pricing {
  Pricing._();

  /// All rates are stored in USD. Sarvam publishes prices in INR; we convert
  /// at a fixed rate documented in [_inrToUsd] below. Update both when the FX
  /// rate moves materially or when providers change their published rates.
  ///
  /// Last verified: 2026-05-28.
  /// Sources:
  ///   - Gemini:  https://ai.google.dev/gemini-api/docs/pricing
  ///   - Sarvam:  https://www.sarvam.ai/api-pricing
  static const double _inrToUsd = 1 / 83.0; // ~₹83 per USD as of mid-2026.

  static String _key(UsageProvider provider, String model, UsageKind kind) =>
      '${provider.name}|$model|${kind.name}';

  static final Map<String, PricingEntry> _table = {
    // ────────────────────────── Gemini ──────────────────────────
    // Gemini 3.1 Flash-Lite (standard tier):
    //   text/image/video input  $0.25 / 1M tokens
    //   audio input             $0.50 / 1M tokens   ← used for `multimodal`
    //   output                  $1.50 / 1M tokens
    // Audio is tokenized server-side (~32 tokens/sec). We don't currently
    // split audio vs text tokens in [UsageEvent]; multimodal calls use the
    // higher audio rate, which slightly overestimates cost for image-only or
    // text-only multimodal calls. Refine when we track per-modality token
    // breakdown.
    _key(UsageProvider.gemini, 'gemini-3.1-flash-lite', UsageKind.chat):
        const PricingEntry(
      inputPerMillion: 0.25,
      outputPerMillion: 1.50,
    ),
    _key(UsageProvider.gemini, 'gemini-3.1-flash-lite', UsageKind.multimodal):
        const PricingEntry(
      inputPerMillion: 0.50,
      outputPerMillion: 1.50,
    ),

    // ────────────────────────── Sarvam ──────────────────────────
    // STT: ₹30 per hour of audio → ₹30 / 3600 sec / 83 ≈ $0.0001004 / sec
    // TTS: ₹30 per 10,000 chars  → ₹30 / 10000 / 83 ≈ $0.0000361 / char
    // Sarvam publishes one STT rate for all current STT models; per-model
    // entries below intentionally use the same rate so adapters can pass
    // their own model id without falling back.
    _key(UsageProvider.sarvam, 'saaras:v3', UsageKind.stt): const PricingEntry(
      audioInputPerSecond: (30.0 / 3600.0) * _inrToUsd,
    ),
    _key(UsageProvider.sarvam, 'saarika:v2.5', UsageKind.stt): const PricingEntry(
      audioInputPerSecond: (30.0 / 3600.0) * _inrToUsd,
    ),
    _key(UsageProvider.sarvam, 'bulbul:v3', UsageKind.tts): const PricingEntry(
      perCharacter: (30.0 / 10000.0) * _inrToUsd,
    ),
  };

  /// Returns null when no entry matches the (provider, model, kind) triple.
  /// Otherwise returns the computed USD cost from whatever input fields are
  /// non-null.
  static double? estimate({
    required UsageProvider provider,
    required String model,
    required UsageKind kind,
    int? inputTokens,
    int? outputTokens,
    int? audioInputMs,
    int? audioOutputMs,
    int? inputChars,
  }) {
    final entry = _table[_key(provider, model, kind)];
    if (entry == null) return null;

    var cost = 0.0;
    if (entry.inputPerMillion != null && inputTokens != null) {
      cost += (inputTokens / 1e6) * entry.inputPerMillion!;
    }
    if (entry.outputPerMillion != null && outputTokens != null) {
      cost += (outputTokens / 1e6) * entry.outputPerMillion!;
    }
    if (entry.audioInputPerSecond != null && audioInputMs != null) {
      cost += (audioInputMs / 1000.0) * entry.audioInputPerSecond!;
    }
    if (entry.audioOutputPerSecond != null && audioOutputMs != null) {
      cost += (audioOutputMs / 1000.0) * entry.audioOutputPerSecond!;
    }
    if (entry.perCharacter != null && inputChars != null) {
      cost += inputChars * entry.perCharacter!;
    }
    return cost;
  }

  /// True if a pricing entry exists for the triple. Useful for the dashboard
  /// to flag rows where cost was not computed because of a missing rate.
  static bool hasEntry(UsageProvider provider, String model, UsageKind kind) =>
      _table.containsKey(_key(provider, model, kind));

  /// Converts a USD cost back into INR using the same fixed FX rate that the
  /// table uses to convert Sarvam's INR prices into USD. Display-only helper;
  /// does not affect stored cost values.
  static double toInr(double usd) => usd / _inrToUsd;
}
