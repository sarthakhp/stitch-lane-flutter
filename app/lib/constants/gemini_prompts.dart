import '../backend/models/measurement_field.dart';
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

  // ── Measurement extraction (transcript → structured JSON) ─────────────

  /// System instruction for [buildMeasurementExtractionPrompt]. Keeps the
  /// model in "extract, don't invent" mode.
  static const String measurementExtractionSystemInstruction = '''
You extract tailoring measurements from a spoken-and-transcribed note (mixed
English + Gujarati) into a strict JSON structure. You never invent values and
never drop anything the user said.
''';

  /// Prompt that asks the model to return the measurement as structured JSON
  /// (validated against a response schema), NOT markdown. Injects the user's
  /// predefined fields (canonical labels + aliases) and common garment
  /// headings as hints.
  ///
  /// Why JSON instead of markdown: the structured editor needs structure, and
  /// a schema-constrained JSON response is far more reliable than emitting
  /// markdown and re-parsing it with regex. Anything the model can't map to a
  /// field must go into the section's `notes` so nothing is lost.
  static String buildMeasurementExtractionPrompt({
    required List<MeasurementField> fields,
    required List<String> headings,
  }) {
    final fieldLines = fields.map((f) {
      if (f.aliases.isEmpty) return '- ${f.label}';
      return '- ${f.label} (also: ${f.aliases.join(", ")})';
    }).join('\n');
    final headingsLine =
        headings.isEmpty ? '(none configured)' : headings.join(', ');

    return '''
Extract the measurements from this raw voice transcription of a tailoring note.

RULES:
1. Transliterate Gujarati-script English terms to English using this glossary:
   ${TailoringGlossary.asPromptList()}. Any other English word written in
   Gujarati script should also be converted to English.
2. Keep genuine Gujarati words in Gujarati script (e.g. ડગલો, ચણિયો, કુર્તી,
   સાડી) — EXCEPT when a word matches a field alias below, then use the
   canonical English label.
3. Fix transcription artifacts using tailoring context:
   - "into" between numbers means multiplication: "20 into 13" → "20 x 13"
   - Spoken fractions: "10 and half" → "10.5", "quarter" → "0.25"
4. Group measurements under garment sections (one object per garment). Common
   garments the user dictates: $headingsLine. Prefer these when the audio
   matches; otherwise use whatever garment name you heard. If no garment is
   mentioned, use an empty heading "".
5. Map each spoken measurement label to the closest field below (case- and
   alias-insensitive) and output the CANONICAL label. Known fields:
$fieldLines
6. Put anything that is NOT a measurement (free remarks, instructions), or any
   measurement you cannot confidently map, into that section's "notes" string.
   NEVER discard words the user said.

OUTPUT: JSON only, matching the provided schema. No markdown, no commentary.
Each section: { "heading": string, "measurements": [ { "label": string,
"value": string } ], "notes": string }. Values are strings (keep "13.5",
"10 x 13"). If the input is empty or nonsensical, return {"sections": []}.

EXAMPLE INPUT:
"blouse લેન્થ 13 and half upper bust 33 waist 30 મોરી 10 loose at waist"

EXAMPLE OUTPUT:
{"sections":[{"heading":"Blouse","measurements":[{"label":"Length","value":"13.5"},{"label":"Upper Bust","value":"33"},{"label":"Waist","value":"30"},{"label":"Mori","value":"10"}],"notes":"loose at waist"}]}
''';
  }

  /// Response schema for [buildMeasurementExtractionPrompt]. Uses an array of
  /// {label, value} pairs (not a free-form object) so it's expressible as a
  /// strict schema; the caller folds it into a label→value map.
  static const Map<String, dynamic> measurementExtractionSchema = {
    'type': 'object',
    'properties': {
      'sections': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'heading': {'type': 'string'},
            'measurements': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'label': {'type': 'string'},
                  'value': {'type': 'string'},
                },
                'required': ['label', 'value'],
              },
            },
            'notes': {'type': 'string'},
          },
          'required': ['heading', 'measurements', 'notes'],
        },
      },
    },
    'required': ['sections'],
  };
}
