import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class TextDisplay extends StatelessWidget {
  final String text;
  final int currentPosition;
  final double fontSize;
  final bool highlightEnabled;
  final ScrollController scrollController;
  final ValueChanged<int> onTextTap;

  const TextDisplay({
    super.key,
    required this.text,
    required this.currentPosition,
    required this.fontSize,
    required this.highlightEnabled,
    required this.scrollController,
    required this.onTextTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: SelectableText.rich(
        _buildTextSpan(context),
        style: TextStyle(
          fontSize: fontSize,
          height: 1.6,
        ),
      ),
    );
  }

  TextSpan _buildTextSpan(BuildContext context) {
    if (!highlightEnabled || currentPosition == 0) {
      return TextSpan(
        text: text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }

    final List<TextSpan> spans = [];
    
    // Calculate highlight range (±50 characters from current position)
    const highlightRange = 50;
    final highlightStart = (currentPosition - highlightRange).clamp(0, text.length);
    final highlightEnd = (currentPosition + highlightRange).clamp(0, text.length);
    
    // Build text spans with highlighting
    if (highlightStart > 0) {
      // Text before highlight
      spans.add(
        TextSpan(
          text: text.substring(0, highlightStart),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onTextTap(highlightStart ~/ 2),
        ),
      );
    }
    
    // Highlighted text (before current position)
    if (highlightStart < currentPosition) {
      spans.add(
        TextSpan(
          text: text.substring(highlightStart, currentPosition),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onTextTap((highlightStart + currentPosition) ~/ 2),
        ),
      );
    }
    
    // Current word (approximate)
    final currentWordEnd = _findWordEnd(text, currentPosition);
    if (currentPosition < currentWordEnd) {
      spans.add(
        TextSpan(
          text: text.substring(currentPosition, currentWordEnd),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            backgroundColor: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    // Highlighted text (after current position)
    if (currentWordEnd < highlightEnd) {
      spans.add(
        TextSpan(
          text: text.substring(currentWordEnd, highlightEnd),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onTextTap((currentWordEnd + highlightEnd) ~/ 2),
        ),
      );
    }
    
    // Text after highlight
    if (highlightEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(highlightEnd),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onTextTap((highlightEnd + text.length) ~/ 2),
        ),
      );
    }
    
    return TextSpan(children: spans);
  }
  
  int _findWordEnd(String text, int position) {
    if (position >= text.length) return text.length;
    
    // For Japanese text, find the next character boundary
    final isJapanese = _isJapaneseChar(text[position]);
    
    if (isJapanese) {
      // Japanese: move one character at a time
      return (position + 1).clamp(0, text.length);
    } else {
      // English: find the next space or punctuation
      int end = position;
      while (end < text.length && 
             !_isWordBoundary(text[end])) {
        end++;
      }
      return end;
    }
  }
  
  bool _isJapaneseChar(String char) {
    final code = char.codeUnitAt(0);
    // Hiragana: 0x3040-0x309F
    // Katakana: 0x30A0-0x30FF
    // Kanji: 0x4E00-0x9FAF
    return (code >= 0x3040 && code <= 0x309F) ||
           (code >= 0x30A0 && code <= 0x30FF) ||
           (code >= 0x4E00 && code <= 0x9FAF);
  }
  
  bool _isWordBoundary(String char) {
    return char == ' ' || 
           char == '\n' || 
           char == '.' || 
           char == ',' || 
           char == '!' || 
           char == '?' ||
           char == '、' ||
           char == '。' ||
           char == '！' ||
           char == '？';
  }
}