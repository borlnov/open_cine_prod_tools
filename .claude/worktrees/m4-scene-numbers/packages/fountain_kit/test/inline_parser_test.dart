// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_inline_span.dart';
import 'package:fountain_kit/src/models/fountain_styled_run.dart';
import 'package:fountain_kit/src/parser/fountain_inline_parser.dart';
import 'package:test/test.dart';

/// A [FountainInlineSpan]'s (text, style) pair, ignoring its source range,
/// which keeps the tests below focused on parsing outcome rather than on
/// offset bookkeeping (covered separately by the range-specific tests).
(String, FountainInlineStyle) _summarize(FountainInlineSpan span) =>
    (span.text, span.style);

/// Parses [text] with a fresh [FountainInlineParser] and summarizes every
/// resulting span as a (text, style) pair.
List<(String, FountainInlineStyle)> _parse(String text) =>
    const FountainInlineParser().parse(text).map(_summarize).toList();

void main() {
  group('plain text', () {
    test('text with no markers is a single plain span', () {
      expect(_parse('Nothing special here.'), [
        ('Nothing special here.', FountainInlineStyle.plain),
      ]);
    });

    test('an empty string yields no spans', () {
      expect(_parse(''), isEmpty);
    });
  });

  group('emphasis', () {
    test('single asterisks are italic', () {
      expect(_parse('an *italic* word'), [
        ('an ', FountainInlineStyle.plain),
        ('italic', FountainInlineStyle.italic),
        (' word', FountainInlineStyle.plain),
      ]);
    });

    test('double asterisks are bold', () {
      expect(_parse('a **bold** word'), [
        ('a ', FountainInlineStyle.plain),
        ('bold', FountainInlineStyle.bold),
        (' word', FountainInlineStyle.plain),
      ]);
    });

    test('triple asterisks are bold italic', () {
      expect(_parse('a ***bold italic*** word'), [
        ('a ', FountainInlineStyle.plain),
        ('bold italic', FountainInlineStyle.boldItalic),
        (' word', FountainInlineStyle.plain),
      ]);
    });

    test('underscores are underline', () {
      expect(_parse('an _underlined_ word'), [
        ('an ', FountainInlineStyle.plain),
        ('underlined', FountainInlineStyle.underline),
        (' word', FountainInlineStyle.plain),
      ]);
    });

    test('several emphasis runs on one line each parse separately', () {
      expect(_parse('*one* and **two** and _three_'), [
        ('one', FountainInlineStyle.italic),
        (' and ', FountainInlineStyle.plain),
        ('two', FountainInlineStyle.bold),
        (' and ', FountainInlineStyle.plain),
        ('three', FountainInlineStyle.underline),
      ]);
    });

    test('an unterminated marker is left as plain text', () {
      expect(_parse('an *unterminated marker'), [
        ('an *unterminated marker', FountainInlineStyle.plain),
      ]);
    });
  });

  group('notes', () {
    test('"[[note]]" becomes a note span', () {
      expect(_parse('before [[a note]] after'), [
        ('before ', FountainInlineStyle.plain),
        ('a note', FountainInlineStyle.note),
        (' after', FountainInlineStyle.plain),
      ]);
    });

    test('an unterminated note is left as plain text', () {
      expect(_parse('before [[unterminated'), [
        ('before [[unterminated', FountainInlineStyle.plain),
      ]);
    });
  });

  group('escaping', () {
    test(r'"\*" is a literal asterisk, not the start of emphasis', () {
      expect(_parse(r'2 \* 2 = 4'), [('2 * 2 = 4', FountainInlineStyle.plain)]);
    });

    test(r'"\_" is a literal underscore, not the start of underline', () {
      expect(_parse(r'a snake\_case name'), [
        ('a snake_case name', FountainInlineStyle.plain),
      ]);
    });

    test('escaping suppresses emphasis on both sides of a run', () {
      expect(_parse(r'\*not italic\*'), [
        ('*not italic*', FountainInlineStyle.plain),
      ]);
    });

    test(r'"\[" and "\]" are literal brackets, not the start of a note', () {
      expect(_parse(r'an array is written \[\[like this\]\]'), [
        ('an array is written [[like this]]', FountainInlineStyle.plain),
      ]);
    });
  });

  group('non-spanning behavior', () {
    test(
      'emphasis is parsed independently on each line of a multi-line call',
      () {
        // Fountain emphasis never spans a line break; a caller that wants
        // per-line spans simply calls parse() once per line, as this parser's
        // API (a single line in, its spans out) implies.
        final firstLine = _parse('*starts here');
        final secondLine = _parse('but does not continue*');
        expect(firstLine, [('*starts here', FountainInlineStyle.plain)]);
        expect(secondLine, [
          ('but does not continue*', FountainInlineStyle.plain),
        ]);
      },
    );
  });

  group('source ranges', () {
    test('a plain span default-ranges over its own text on line 0', () {
      final span = const FountainInlineParser().parse('hello').single;
      expect(span.sourceRange.startLine, 0);
      expect(span.sourceRange.endLine, 0);
      expect(span.sourceRange.startOffset, 0);
      expect(span.sourceRange.endOffset, 5);
    });

    test('an emphasis span ranges over its markers as well as its text', () {
      final spans = const FountainInlineParser().parse('a *b* c');
      final italic = spans.firstWhere(
        (span) => span.style == FountainInlineStyle.italic,
      );
      expect(italic.text, 'b');
      // "a *b* c": the "*b*" run starts at offset 2 and ends at offset 5
      // (one past the closing marker).
      expect(italic.sourceRange.startOffset, 2);
      expect(italic.sourceRange.endOffset, 5);
    });

    test('line and startOffset parameters shift every span', () {
      final span = const FountainInlineParser()
          .parse('hi', line: 4, startOffset: 10)
          .single;
      expect(span.sourceRange.startLine, 4);
      expect(span.sourceRange.endLine, 4);
      expect(span.sourceRange.startOffset, 10);
      expect(span.sourceRange.endOffset, 12);
    });
  });

  group('parseRuns', () {
    List<FountainStyledRun> parseRuns(String text) =>
        const FountainInlineParser().parseRuns(text);

    test('plain text is a single unstyled run', () {
      expect(parseRuns('Nothing special here.'), [
        const FountainStyledRun(text: 'Nothing special here.'),
      ]);
    });

    test('single asterisks produce an italic run', () {
      expect(parseRuns('an *italic* word'), [
        const FountainStyledRun(text: 'an '),
        const FountainStyledRun(text: 'italic', isItalic: true),
        const FountainStyledRun(text: ' word'),
      ]);
    });

    test('double asterisks produce a bold run', () {
      expect(parseRuns('a **bold** word'), [
        const FountainStyledRun(text: 'a '),
        const FountainStyledRun(text: 'bold', isBold: true),
        const FountainStyledRun(text: ' word'),
      ]);
    });

    test('underscores produce an underline run', () {
      expect(parseRuns('an _underlined_ word'), [
        const FountainStyledRun(text: 'an '),
        const FountainStyledRun(text: 'underlined', isUnderline: true),
        const FountainStyledRun(text: ' word'),
      ]);
    });

    test('triple asterisks produce a bold+italic run', () {
      expect(parseRuns('a ***bold italic*** word'), [
        const FountainStyledRun(text: 'a '),
        const FountainStyledRun(
          text: 'bold italic',
          isBold: true,
          isItalic: true,
        ),
        const FountainStyledRun(text: ' word'),
      ]);
    });

    test('"_**x**_" nests to bold+underline', () {
      expect(parseRuns('_**both**_'), [
        const FountainStyledRun(text: 'both', isBold: true, isUnderline: true),
      ]);
    });

    test('"_*x*_" nests to italic+underline', () {
      expect(parseRuns('_*both*_'), [
        const FountainStyledRun(
          text: 'both',
          isItalic: true,
          isUnderline: true,
        ),
      ]);
    });

    test('"**_x_**" nests to bold+underline (underline inside bold)', () {
      expect(parseRuns('**_both_**'), [
        const FountainStyledRun(text: 'both', isBold: true, isUnderline: true),
      ]);
    });

    test('"*_x_*" nests to italic+underline (underline inside italic)', () {
      expect(parseRuns('*_both_*'), [
        const FountainStyledRun(
          text: 'both',
          isItalic: true,
          isUnderline: true,
        ),
      ]);
    });

    test('"_***x***_" nests to bold+italic+underline', () {
      expect(parseRuns('_***all***_'), [
        const FountainStyledRun(
          text: 'all',
          isBold: true,
          isItalic: true,
          isUnderline: true,
        ),
      ]);
    });

    test('a non-wrapping inner marker leaves only the outer style', () {
      // "_a*b" is not a full wrap of "*" inside the underline span's text,
      // so the run stays plain underline with the literal asterisk kept.
      expect(parseRuns('_a*b_'), [
        const FountainStyledRun(text: 'a*b', isUnderline: true),
      ]);
    });

    test('"[[note]]" becomes a note run with brackets kept in its text', () {
      expect(parseRuns('before [[a note]] after'), [
        const FountainStyledRun(text: 'before '),
        const FountainStyledRun(text: '[[a note]]', isNote: true),
        const FountainStyledRun(text: ' after'),
      ]);
    });

    test('an empty string yields no runs', () {
      expect(parseRuns(''), isEmpty);
    });

    test('the original parse() API is unaffected by parseRuns', () {
      // parseRuns is additive: parse() keeps returning single-style spans
      // for callers (the raw-mode preview) that only need
      // FountainInlineStyle.
      const parser = FountainInlineParser();
      expect(parser.parse('a *b* c').map((span) => span.style).toList(), [
        FountainInlineStyle.plain,
        FountainInlineStyle.italic,
        FountainInlineStyle.plain,
      ]);
    });
  });
}
