/// Roman transliteration for the Indic scripts this application supports.
///
/// The Devanagari, Kannada, Telugu, Malayalam and Tamil blocks were encoded on
/// a shared layout: a consonant, vowel or vowel sign sits at the same offset
/// from its block's base code point in every one of them. So a single offset
/// table transliterates all five, and the script is identified by which block
/// the characters fall in.
///
/// The output is close to ISO 15919 and is a *writing-system* conversion, not a
/// translation: the words, including medical terms, are unchanged.
///
///   ನನಗೆ ಜ್ವರ ಇದೆ  ->  nanage jvara ide
///
/// Known limits, stated rather than hidden:
///  * Tamil has a much smaller consonant inventory and writes several sounds
///    with one letter, so its Roman form is approximate by nature.
///  * Schwa deletion in Hindi is not modelled, so Devanagari output keeps the
///    inherent 'a' (`ज्वर` -> `jvara`, not `jvar`).
///  * Nasal assimilation is not applied; anusvāra is written `ṁ`.
class Transliteration {
  const Transliteration._();

  static const Map<String, int> _scriptBase = {
    'hi': 0x0900, // Devanagari
    'ta': 0x0B80, // Tamil
    'te': 0x0C00, // Telugu
    'kn': 0x0C80, // Kannada
    'ml': 0x0D00, // Malayalam
  };

  /// Independent vowels, by offset from the block base.
  static const Map<int, String> _vowels = {
    0x05: 'a', 0x06: 'ā', 0x07: 'i', 0x08: 'ī', 0x09: 'u', 0x0A: 'ū',
    0x0B: 'r̥', 0x0C: 'l̥', 0x0E: 'e', 0x0F: 'ē', 0x10: 'ai',
    0x12: 'o', 0x13: 'ō', 0x14: 'au',
  };

  /// Consonants, by offset. Shared across all five scripts.
  static const Map<int, String> _consonants = {
    0x15: 'k', 0x16: 'kh', 0x17: 'g', 0x18: 'gh', 0x19: 'ṅ',
    0x1A: 'c', 0x1B: 'ch', 0x1C: 'j', 0x1D: 'jh', 0x1E: 'ñ',
    0x1F: 'ṭ', 0x20: 'ṭh', 0x21: 'ḍ', 0x22: 'ḍh', 0x23: 'ṇ',
    0x24: 't', 0x25: 'th', 0x26: 'd', 0x27: 'dh', 0x28: 'n', 0x29: 'ṉ',
    0x2A: 'p', 0x2B: 'ph', 0x2C: 'b', 0x2D: 'bh', 0x2E: 'm',
    0x2F: 'y', 0x30: 'r', 0x31: 'ṟ', 0x32: 'l', 0x33: 'ḷ', 0x34: 'ḻ',
    0x35: 'v', 0x36: 'ś', 0x37: 'ṣ', 0x38: 's', 0x39: 'h',
  };

  /// Dependent vowel signs (mātrās), by offset.
  static const Map<int, String> _matras = {
    0x3E: 'ā', 0x3F: 'i', 0x40: 'ī', 0x41: 'u', 0x42: 'ū',
    0x43: 'r̥', 0x44: 'r̥̄', 0x46: 'e', 0x47: 'ē', 0x48: 'ai',
    0x4A: 'o', 0x4B: 'ō', 0x4C: 'au',
  };

  // Devanagari places plain e/o where the southern scripts place the long
  // forms, so those two offsets are overridden for Devanagari only.
  static const Map<int, String> _devanagariMatraOverrides = {
    0x47: 'e', 0x4B: 'o',
  };
  static const Map<int, String> _devanagariVowelOverrides = {
    0x0F: 'e', 0x13: 'o',
  };

  static const int _virama = 0x4D;
  static const int _anusvara = 0x02;
  static const int _visarga = 0x03;
  static const int _candrabindu = 0x01;
  static const int _nukta = 0x3C;
  static const int _avagraha = 0x3D;

  /// Detects which supported script [text] is written in, or null for Latin
  /// and anything else. Identification is by code-point block, never by
  /// keyword or word list.
  static String? detectScript(String text) {
    final counts = <String, int>{};
    for (final rune in text.runes) {
      for (final entry in _scriptBase.entries) {
        if (rune >= entry.value && rune <= entry.value + 0x7F) {
          counts[entry.key] = (counts[entry.key] ?? 0) + 1;
          break;
        }
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static bool isIndicScript(String text) => detectScript(text) != null;

  /// Transliterates [text] to Roman. Characters outside the detected block —
  /// spaces, digits, punctuation, Latin letters — pass through untouched.
  ///
  /// Returns null when the text is not in a supported Indic script, so callers
  /// can hide the Roman line rather than showing a copy of the original.
  static String? toRoman(String text, {String? script}) {
    final detected = script ?? detectScript(text);
    if (detected == null) return null;

    final base = _scriptBase[detected];
    if (base == null) return null;

    final isDevanagari = detected == 'hi';
    final runes = text.runes.toList();
    final buffer = StringBuffer();

    for (var i = 0; i < runes.length; i++) {
      final rune = runes[i];
      final offset = rune - base;

      if (offset < 0 || offset > 0x7F) {
        buffer.writeCharCode(rune); // outside the block, keep as-is
        continue;
      }

      final consonant = _consonants[offset];
      if (consonant != null) {
        buffer.write(consonant);

        // A consonant carries an inherent 'a' unless the next character
        // cancels it (virama) or replaces it (a vowel sign).
        final next = i + 1 < runes.length ? runes[i + 1] - base : -1;
        final suppressed = next == _virama ||
            next == _nukta ||
            _matras.containsKey(next);
        if (!suppressed) buffer.write('a');
        continue;
      }

      final matra = isDevanagari
          ? (_devanagariMatraOverrides[offset] ?? _matras[offset])
          : _matras[offset];
      if (matra != null) {
        buffer.write(matra);
        continue;
      }

      final vowel = isDevanagari
          ? (_devanagariVowelOverrides[offset] ?? _vowels[offset])
          : _vowels[offset];
      if (vowel != null) {
        buffer.write(vowel);
        continue;
      }

      switch (offset) {
        case _virama:
        case _nukta:
          break; // silent: the inherent vowel was already suppressed
        case _anusvara:
          buffer.write('ṁ');
          break;
        case _visarga:
          buffer.write('ḥ');
          break;
        case _candrabindu:
          buffer.write('m̐');
          break;
        case _avagraha:
          buffer.write("'");
          break;
        default:
          // Digits and script-specific signs with no Roman equivalent are
          // preserved rather than dropped, so nothing is silently lost.
          buffer.writeCharCode(rune);
      }
    }

    return buffer.toString();
  }
}
