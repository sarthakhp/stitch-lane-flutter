import 'tailoring_glossary.dart';

/// Prompts for Gemini-powered transcription and formatting.
///
/// **Separation of concerns:**
///   - Transcription prompts ([systemInstruction] + [transcriptionPrompt])
///     do exactly one thing: take audio in, return plain text out, preserving
///     the original language of each spoken word. No markdown, no domain
///     cleanup, no formatting opinions.
///   - Formatting prompts ([formattingSystemInstruction] + [formattingPrompt])
///     own all the domain knowledge: transliteration via [TailoringGlossary],
///     fraction parsing, multiplication idioms, markdown structure. They run
///     after STT (any provider) when the caller opts in.
///
/// Why this split: when STT was Gemini and formatting was also on, the
/// previous design double-formatted (Gemini emitted markdown during
/// transcription, then we re-formatted on top). Splitting the responsibilities
/// removes the overlap and makes the call cost halve in that path.
class GeminiPrompts {
  GeminiPrompts._();

  // ── Transcription (audio → plain text) ────────────────────────────────

  static const String systemInstruction = '''
You are a transcription assistant for a tailoring business. Audio mixes
English and Gujarati (code-switching). Transcribe every word in the language
it was spoken — English words in English, Gujarati words in Gujarati script
(ગુજરાતી). Never translate.
''';

  static const String transcriptionPrompt = '''
Transcribe this audio as plain text. Output the transcription only — no
markdown, no commentary, no explanation. If silent, respond: "No one is
speaking".
''';

  // ── Formatting (plain text → polished markdown) ───────────────────────

  static const String formattingSystemInstruction = '''
You clean up speech-to-text transcripts from a tailoring business app. Input
may mix English and Gujarati. Clean up the text — never translate, summarize,
or invent details that weren't in the input.
''';

  /// `static final` (not `const`) because the glossary is interpolated from
  /// [TailoringGlossary.asPromptList]. Initialized once on first access, then
  /// cached for the rest of the app's lifetime — zero per-call cost.
  static final String formattingPrompt = '''
Clean up this raw voice transcription from a tailoring business.

TASKS:
1. Transliterate Gujarati-script English terms back to English using this
   glossary: ${TailoringGlossary.asPromptList()}. Any other English word
   written in Gujarati script should also be converted to English.
2. Keep genuine Gujarati words in Gujarati script (e.g. મોરી, ડગલો, ચણિયો,
   કુર્તી, સાડી).
3. Fix transcription errors using tailoring context:
   - "into" between numbers means multiplication: "20 into 13" → 20 x 13
   - Spoken fractions: "10 and half" → 10.5, "quarter" → 0.25
4. Add punctuation and structure.
5. Format as markdown using ONLY these elements:
   - **bold** for garment names, quantities, and prices
   - *italic* for special notes or instructions
   - Bullet lists (- item) for measurements and details
   - Blank line between each garment/section
   - NO headers (#), numbered lists, horizontal rules, code blocks, links,
     or blockquotes

EXAMPLE INPUT:
"2 શ્રગ 950 રૂપિયા મોરી 31 બસ્ટ 39 and half સ્લીવ 10 into 13 and half હૂક બેક 1 સાડી 950 રૂપિયા"

EXAMPLE OUTPUT:
**2 Shrug** (**950** rps):
- મોરી: 31
- Bust: 39.5
- Sleeve: 10 x 13.5
- Hook: Back

**1 સાડી** (**950** rps):

STRICT:
- Output only the formatted text — no preamble or commentary
- Never invent prices, measurements, or details not in the input
- If the input is empty or nonsensical, return it as-is
''';
}
