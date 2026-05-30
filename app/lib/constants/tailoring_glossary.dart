/// Domain vocabulary the LLM needs as data, not buried in prompt text.
///
/// Speech-to-text models routinely transcribe English tailoring terms in
/// Gujarati script when the speaker code-switches. The formatting prompt
/// uses this map to transliterate them back to English consistently.
///
/// Adding a new term: drop a single line into [gujaratiToEnglish]. The
/// formatting prompt picks it up automatically via [asPromptList].
///
/// Keep "genuine" Gujarati garment / sewing nouns (મોરી, ડગલો, ચણિયો, કુર્તી,
/// સાડી) OUT of this map — those should stay in Gujarati script.
class TailoringGlossary {
  TailoringGlossary._();

  /// Gujarati-script transcription → canonical English spelling. Order is
  /// not significant — we render to a flat list at prompt-build time.
  static const Map<String, String> gujaratiToEnglish = {
    'લેન્થ': 'Length',
    'બ્લાઉઝ': 'Blouse',
    'સ્લીવ': 'Sleeve',
    'બસ્ટ': 'Bust',
    'વેસ્ટ': 'Waist',
    'શોલ્ડર': 'Shoulder',
    'આર્મહોલ': 'Armhole',
    'હૂક': 'Hook',
    'ટિપ': 'Tip',
    'શ્રગ': 'Shrug',
    'સાઈઝ': 'Size',
    'ફ્રન્ટ': 'Front',
    'બેક': 'Back',
    'નેક': 'Neck',
    'ડાર્ટ': 'Dart',
  };

  /// Renders the glossary as a comma-separated, arrow-joined list suitable
  /// for embedding inside a prompt. Cached lazily via the `late final` in
  /// [GeminiPrompts.formattingPrompt] so it's only computed once per app run.
  static String asPromptList() => gujaratiToEnglish.entries
      .map((e) => '${e.key} → ${e.value}')
      .join(', ');
}
