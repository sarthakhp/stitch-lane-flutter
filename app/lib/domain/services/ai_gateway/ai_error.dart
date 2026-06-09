import 'dart:async';
import 'dart:io' show SocketException;

/// Converts any exception thrown by an AI / transcription call — Gemini (via
/// googleai_dart or langchain_google), network failures, or timeouts — into a
/// short, non-technical message that is safe to show the user.
///
/// The raw error is still logged for developers; this only governs what
/// surfaces in the UI. Kept as one pure function so every AI entry point
/// (chat, order creator, transcription) shows consistent wording instead of
/// leaking raw strings like `RateLimitException(429): ...` to the tailor.
String describeAiError(Object error) {
  final lower = error.toString().toLowerCase();
  bool has(String s) => lower.contains(s);

  // Out of paid credits / billing problem (e.g. Gemini prepay depleted).
  if (has('deplet') ||
      has('prepayment') ||
      has('billing') ||
      (has('insufficient') && has('credit'))) {
    return 'The AI service is out of credits. Please top up the Gemini '
        'billing, then try again.';
  }

  // Rate limit / quota exceeded (429) that is not a credits problem.
  if (has('rate limit') ||
      has('ratelimit') ||
      has('quota') ||
      has('resource_exhausted') ||
      has('429')) {
    return 'The AI is busy right now (usage limit reached). Please wait a '
        'minute and try again.';
  }

  // No connectivity.
  if (error is SocketException ||
      has('socketexception') ||
      has('failed host lookup') ||
      has('no internet') ||
      has('network is unreachable') ||
      has('connection refused') ||
      has('connection closed')) {
    return 'No internet connection. Please check your network and try again.';
  }

  // Took too long.
  if (error is TimeoutException || has('timeout') || has('timed out')) {
    return 'The AI took too long to respond. Please try again.';
  }

  // Missing / invalid API key, or permission denied.
  if (has('api key') ||
      has('api_key_invalid') ||
      has('permission_denied') ||
      has('unauthorized') ||
      has('401') ||
      has('403')) {
    return 'The AI key is missing or invalid. Please check the API key.';
  }

  // Google server-side hiccup.
  if (has('500') ||
      has('502') ||
      has('503') ||
      has('unavailable') ||
      has('internal error')) {
    return "Google's AI service had a problem. Please try again in a moment.";
  }

  // Unknown — keep it generic but clearly an AI failure.
  return 'The AI request failed. Please try again.';
}
