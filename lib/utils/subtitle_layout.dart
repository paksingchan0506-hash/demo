import 'dart:math';
import 'package:flutter/widgets.dart';

class SubtitleLayout {
  static String reflow({
    required String input,
    required TextStyle style,
    required double maxWidth,
    required TextDirection textDirection,
    double textScaleFactor = 1.0,
  }) {
    final normalized = input.replaceAll('\r', '').trimRight();
    if (normalized.isEmpty) return '';

    final paragraphs = normalized.split('\n').where((p) => p.trim().isNotEmpty);
    final out = <String>[];
    for (final p in paragraphs) {
      out.addAll(
        _wrapParagraph(
          p.trim(),
          style: style,
          maxWidth: maxWidth,
          textDirection: textDirection,
          textScaleFactor: textScaleFactor,
        ),
      );
    }
    return out.join('\n');
  }

  static List<String> _wrapParagraph(
    String paragraph, {
    required TextStyle style,
    required double maxWidth,
    required TextDirection textDirection,
    required double textScaleFactor,
  }) {
    if (_measure(paragraph, style, maxWidth, textDirection, textScaleFactor) <=
        maxWidth) {
      return [paragraph];
    }

    final tokens = _tokenize(paragraph);
    final lines = <String>[];
    var current = StringBuffer();

    for (final t in tokens) {
      final candidate = current.isEmpty ? t : '${current.toString()}$t';
      final w = _measure(
        candidate,
        style,
        maxWidth,
        textDirection,
        textScaleFactor,
      );

      if (w <= maxWidth) {
        current
          ..clear()
          ..write(candidate);
        continue;
      }

      final curText = current.toString().trimRight();
      if (curText.isNotEmpty) {
        lines.add(curText);
        current
          ..clear()
          ..write(t.trimLeft());
        continue;
      }

      final hard = _hardBreak(
        t,
        style: style,
        maxWidth: maxWidth,
        textDirection: textDirection,
        textScaleFactor: textScaleFactor,
      );
      lines.addAll(hard.take(max(0, hard.length - 1)));
      current
        ..clear()
        ..write(hard.isNotEmpty ? hard.last : '');
    }

    final last = current.toString().trim();
    if (last.isNotEmpty) lines.add(last);

    return _postBreakAtPunctuation(lines);
  }

  static List<String> _tokenize(String input) {
    final tokens = <String>[];
    final runeList = input.runes.toList();

    bool isAsciiWord(int r) {
      return (r >= 0x30 && r <= 0x39) ||
          (r >= 0x41 && r <= 0x5A) ||
          (r >= 0x61 && r <= 0x7A) ||
          r == 0x27;
    }

    int i = 0;
    while (i < runeList.length) {
      final r = runeList[i];
      final ch = String.fromCharCode(r);
      if (ch == ' ' || ch == '\t') {
        tokens.add(' ');
        i++;
        continue;
      }

      if (isAsciiWord(r)) {
        final b = StringBuffer();
        while (i < runeList.length && isAsciiWord(runeList[i])) {
          b.writeCharCode(runeList[i]);
          i++;
        }
        tokens.add(b.toString());
        continue;
      }

      tokens.add(ch);
      i++;
    }

    return tokens;
  }

  static List<String> _hardBreak(
    String token, {
    required TextStyle style,
    required double maxWidth,
    required TextDirection textDirection,
    required double textScaleFactor,
  }) {
    final out = <String>[];
    var current = StringBuffer();
    for (final r in token.runes) {
      final ch = String.fromCharCode(r);
      final candidate = current.isEmpty ? ch : '${current.toString()}$ch';
      final w = _measure(
        candidate,
        style,
        maxWidth,
        textDirection,
        textScaleFactor,
      );
      if (w <= maxWidth) {
        current
          ..clear()
          ..write(candidate);
        continue;
      }
      if (current.isNotEmpty) out.add(current.toString());
      current
        ..clear()
        ..write(ch);
    }
    if (current.isNotEmpty) out.add(current.toString());
    return out;
  }

  static List<String> _postBreakAtPunctuation(List<String> lines) {
    const punctuation = {
      ',',
      '.',
      '!',
      '?',
      ';',
      ':',
      '，',
      '。',
      '！',
      '？',
      '；',
      '：',
      '、',
    };

    final out = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.length <= 1) {
        out.add(trimmed);
        continue;
      }
      final last = trimmed.substring(trimmed.length - 1);
      if (punctuation.contains(last)) {
        out.add(trimmed);
      } else {
        out.add(trimmed);
      }
    }
    return out;
  }

  static double _measure(
    String text,
    TextStyle style,
    double maxWidth,
    TextDirection textDirection,
    double textScaleFactor,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: TextScaler.linear(textScaleFactor),
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    return tp.width;
  }
}
