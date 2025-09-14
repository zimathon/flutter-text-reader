import 'text_chunk.dart';

/// Detects the language of text content
class LanguageDetector {
  // Unicode ranges for different scripts
  static const _japaneseHiragana = r'[\u3040-\u309F]';
  static const _japaneseKatakana = r'[\u30A0-\u30FF]';
  static const _japaneseKanji = r'[\u4E00-\u9FAF]';
  static const _chineseOnly = r'[\u3400-\u4DBF]'; // CJK Extension A
  static const _korean = r'[\uAC00-\uD7AF]';
  static const _latin = r'[a-zA-Z]';
  static const _numbers = r'[0-9]';

  /// Detect the primary language and composition of text
  LanguageDetectionResult detect(String text) {
    if (text.isEmpty) {
      return const LanguageDetectionResult(
        primaryLanguage: TextLanguage.unknown,
        languageRatios: {},
        confidence: 0.0,
      );
    }

    // Count characters by script
    int hiraganaCount = 0;
    int katakanaCount = 0;
    int kanjiCount = 0;
    int latinCount = 0;
    int koreanCount = 0;
    int numberCount = 0;
    int otherCount = 0;

    for (final char in text.runes) {
      final charStr = String.fromCharCode(char);
      
      if (RegExp(_japaneseHiragana).hasMatch(charStr)) {
        hiraganaCount++;
      } else if (RegExp(_japaneseKatakana).hasMatch(charStr)) {
        katakanaCount++;
      } else if (RegExp(_japaneseKanji).hasMatch(charStr)) {
        kanjiCount++;
      } else if (RegExp(_korean).hasMatch(charStr)) {
        koreanCount++;
      } else if (RegExp(_latin).hasMatch(charStr)) {
        latinCount++;
      } else if (RegExp(_numbers).hasMatch(charStr)) {
        numberCount++;
      } else if (!_isWhitespaceOrPunctuation(charStr)) {
        otherCount++;
      }
    }

    final totalChars = hiraganaCount + katakanaCount + kanjiCount + 
                       latinCount + koreanCount + numberCount + otherCount;

    if (totalChars == 0) {
      return const LanguageDetectionResult(
        primaryLanguage: TextLanguage.unknown,
        languageRatios: {},
        confidence: 0.0,
      );
    }

    // Calculate ratios
    final japaneseTotal = hiraganaCount + katakanaCount + kanjiCount;
    final japaneseRatio = japaneseTotal / totalChars;
    final latinRatio = latinCount / totalChars;
    final koreanRatio = koreanCount / totalChars;

    final ratios = <TextLanguage, double>{};
    
    if (japaneseRatio > 0) ratios[TextLanguage.japanese] = japaneseRatio;
    if (latinRatio > 0) ratios[TextLanguage.english] = latinRatio;
    if (koreanRatio > 0) ratios[TextLanguage.korean] = koreanRatio;
    
    // Check for Chinese (Kanji without Hiragana/Katakana might be Chinese)
    if (kanjiCount > 0 && hiraganaCount == 0 && katakanaCount == 0) {
      ratios[TextLanguage.chinese] = kanjiCount / totalChars;
      ratios.remove(TextLanguage.japanese);
    }

    // Determine primary language
    TextLanguage primaryLanguage = TextLanguage.unknown;
    double maxRatio = 0.0;

    for (final entry in ratios.entries) {
      if (entry.value > maxRatio) {
        maxRatio = entry.value;
        primaryLanguage = entry.key;
      }
    }

    // Check if mixed
    if (ratios.length > 1 && ratios.values.any((r) => r > 0.1 && r < 0.9)) {
      primaryLanguage = TextLanguage.mixed;
    }

    // Calculate confidence
    double confidence = maxRatio;
    if (primaryLanguage == TextLanguage.japanese) {
      // Higher confidence if we have both kana and kanji
      if (hiraganaCount > 0 && kanjiCount > 0) {
        confidence = (confidence + 0.2).clamp(0.0, 1.0);
      }
    }

    return LanguageDetectionResult(
      primaryLanguage: primaryLanguage,
      languageRatios: ratios,
      confidence: confidence,
    );
  }

  /// Detect language for each chunk
  List<LanguageDetectionResult> detectForChunks(List<TextChunk> chunks) {
    return chunks.map((chunk) => detect(chunk.text)).toList();
  }

  /// Check if character is whitespace or punctuation
  bool _isWhitespaceOrPunctuation(String char) {
    return RegExp(r'[\s\p{P}]', unicode: true).hasMatch(char);
  }

  /// Get recommended chunker based on detected language
  String getRecommendedChunker(LanguageDetectionResult result) {
    switch (result.primaryLanguage) {
      case TextLanguage.japanese:
        return 'JapaneseTextChunker';
      case TextLanguage.chinese:
        return 'ChineseTextChunker';
      case TextLanguage.korean:
        return 'KoreanTextChunker';
      case TextLanguage.english:
        return 'EnglishTextChunker';
      case TextLanguage.mixed:
        // Use Japanese chunker for mixed content with significant Japanese
        if ((result.languageRatios[TextLanguage.japanese] ?? 0) > 0.3) {
          return 'JapaneseTextChunker';
        }
        return 'UniversalTextChunker';
      case TextLanguage.unknown:
      default:
        return 'UniversalTextChunker';
    }
  }

  /// Get language code for TTS
  String getLanguageCode(TextLanguage language) {
    switch (language) {
      case TextLanguage.japanese:
        return 'ja-JP';
      case TextLanguage.english:
        return 'en-US';
      case TextLanguage.chinese:
        return 'zh-CN';
      case TextLanguage.korean:
        return 'ko-KR';
      case TextLanguage.mixed:
        return 'ja-JP'; // Default to Japanese for mixed
      case TextLanguage.unknown:
      default:
        return 'en-US';
    }
  }
}

/// Extension for language names
extension TextLanguageExtension on TextLanguage {
  String get displayName {
    switch (this) {
      case TextLanguage.japanese:
        return '日本語';
      case TextLanguage.english:
        return 'English';
      case TextLanguage.chinese:
        return '中文';
      case TextLanguage.korean:
        return '한국어';
      case TextLanguage.mixed:
        return 'Mixed';
      case TextLanguage.unknown:
        return 'Unknown';
    }
  }

  String get code {
    switch (this) {
      case TextLanguage.japanese:
        return 'ja';
      case TextLanguage.english:
        return 'en';
      case TextLanguage.chinese:
        return 'zh';
      case TextLanguage.korean:
        return 'ko';
      case TextLanguage.mixed:
        return 'mixed';
      case TextLanguage.unknown:
        return 'unknown';
    }
  }
}