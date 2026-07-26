// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_styled_run.dart';
import 'package:fountain_kit/src/parser/fountain_inline_parser.dart';
import 'package:fountain_kit/src/serializer/fountain_inline_serializer.dart';
import 'package:test/test.dart';

const FountainInlineParser _parser = FountainInlineParser();
const FountainInlineSerializer _serializer = FountainInlineSerializer();

void main() {
  group('single styles', () {
    test('a plain run serializes with no markers', () {
      expect(
        _serializer.write(const [FountainStyledRun(text: 'hello')]),
        'hello',
      );
    });

    test('a bold run serializes with "**"', () {
      expect(
        _serializer.write(const [FountainStyledRun(text: 'x', isBold: true)]),
        '**x**',
      );
    });

    test('an italic run serializes with "*"', () {
      expect(
        _serializer.write(const [FountainStyledRun(text: 'x', isItalic: true)]),
        '*x*',
      );
    });

    test('an underline run serializes with "_"', () {
      expect(
        _serializer.write(const [
          FountainStyledRun(text: 'x', isUnderline: true),
        ]),
        '_x_',
      );
    });
  });

  group('style combinations', () {
    test('bold+italic serializes with the canonical "***"', () {
      expect(
        _serializer.write(const [
          FountainStyledRun(text: 'x', isBold: true, isItalic: true),
        ]),
        '***x***',
      );
    });

    test('bold+underline serializes with underline outermost', () {
      expect(
        _serializer.write(const [
          FountainStyledRun(text: 'x', isBold: true, isUnderline: true),
        ]),
        '_**x**_',
      );
    });

    test('italic+underline serializes with underline outermost', () {
      expect(
        _serializer.write(const [
          FountainStyledRun(text: 'x', isItalic: true, isUnderline: true),
        ]),
        '_*x*_',
      );
    });

    test('bold+italic+underline serializes with underline outermost', () {
      expect(
        _serializer.write(const [
          FountainStyledRun(
            text: 'x',
            isBold: true,
            isItalic: true,
            isUnderline: true,
          ),
        ]),
        '_***x***_',
      );
    });
  });

  group('notes', () {
    test('a note run is emitted verbatim (text already has brackets)', () {
      expect(
        _serializer.write(const [
          FountainStyledRun(text: '[[a note]]', isNote: true),
        ]),
        '[[a note]]',
      );
    });

    test('adjacent notes are never merged into one run', () {
      final runs = _parser.parseRuns('[[first]][[second]]');
      expect(runs, [
        const FountainStyledRun(text: '[[first]]', isNote: true),
        const FountainStyledRun(text: '[[second]]', isNote: true),
      ]);
      expect(_serializer.write(runs), '[[first]][[second]]');
    });
  });

  group('merging adjacent runs', () {
    test('adjacent runs sharing a style are merged before emission', () {
      final line = _serializer.write(const [
        FountainStyledRun(text: 'bo', isBold: true),
        FountainStyledRun(text: 'ld', isBold: true),
      ]);
      expect(line, '**bold**');
      expect(_parser.parseRuns(line), const [
        FountainStyledRun(text: 'bold', isBold: true),
      ]);
    });

    test('empty runs are dropped and never emit stray markers', () {
      final line = _serializer.write(const [
        FountainStyledRun(text: 'a'),
        FountainStyledRun(text: '', isBold: true),
        FountainStyledRun(text: 'b'),
      ]);
      expect(line, 'ab');
    });

    test('an all-empty run list serializes to an empty line', () {
      expect(_serializer.write(const []), '');
      expect(_serializer.write(const [FountainStyledRun(text: '')]), '');
    });

    test('a run of only whitespace is preserved, not treated as empty', () {
      final line = _serializer.write(const [
        FountainStyledRun(text: ' ', isBold: true),
      ]);
      expect(line, '** **');
      expect(_parser.parseRuns(line), const [
        FountainStyledRun(text: ' ', isBold: true),
      ]);
    });
  });

  group('adjacent runs with different styles', () {
    test('bold immediately followed by italic round-trips', () {
      const runs = [
        FountainStyledRun(text: 'bold', isBold: true),
        FountainStyledRun(text: 'italic', isItalic: true),
      ];
      final line = _serializer.write(runs);
      expect(line, '**bold***italic*');
      expect(_parser.parseRuns(line), runs);
    });

    test('italic immediately followed by bold round-trips', () {
      const runs = [
        FountainStyledRun(text: 'italic', isItalic: true),
        FountainStyledRun(text: 'bold', isBold: true),
      ];
      final line = _serializer.write(runs);
      expect(_parser.parseRuns(line), runs);
    });

    test('bold immediately followed by bold+italic round-trips', () {
      const runs = [
        FountainStyledRun(text: 'B', isBold: true),
        FountainStyledRun(text: 'BI', isBold: true, isItalic: true),
      ];
      final line = _serializer.write(runs);
      expect(_parser.parseRuns(line), runs);
    });

    test('underline immediately followed by bold+underline round-trips', () {
      const runs = [
        FountainStyledRun(text: 'U', isUnderline: true),
        FountainStyledRun(text: 'BU', isBold: true, isUnderline: true),
      ];
      final line = _serializer.write(runs);
      expect(_parser.parseRuns(line), runs);
    });

    test('a plain run between two emphasis runs round-trips', () {
      const runs = [
        FountainStyledRun(text: 'one', isItalic: true),
        FountainStyledRun(text: ' and '),
        FountainStyledRun(text: 'two', isBold: true),
      ];
      final line = _serializer.write(runs);
      expect(_parser.parseRuns(line), runs);
    });
  });

  group('escaping', () {
    test('a lone, unpaired "*" in plain text is not escaped', () {
      const runs = [FountainStyledRun(text: '50% * off')];
      final line = _serializer.write(runs);
      expect(line, '50% * off');
      expect(_parser.parseRuns(line), runs);
    });

    test('a lone, unpaired "_" in plain text is not escaped', () {
      const runs = [FountainStyledRun(text: 'a snake_case name')];
      final line = _serializer.write(runs);
      expect(line, 'a snake_case name');
      expect(_parser.parseRuns(line), runs);
    });

    test('a lone, unpaired "[" in plain text is not escaped', () {
      const runs = [FountainStyledRun(text: 'array[index] value')];
      final line = _serializer.write(runs);
      expect(line, 'array[index] value');
      expect(_parser.parseRuns(line), runs);
    });

    test('two literal asterisks that would otherwise pair up are escaped', () {
      const runs = [FountainStyledRun(text: '2 * 2 = 4, not 3 * 3 = 9')];
      final line = _serializer.write(runs);
      expect(_parser.parseRuns(line), runs);
      expect(line, isNot(contains('* 2 = 4, not 3 *')));
    });

    test(
      'two literal underscores that would otherwise pair up are escaped',
      () {
        const runs = [
          FountainStyledRun(text: 'a_b and c_d look like underline'),
        ];
        final line = _serializer.write(runs);
        expect(_parser.parseRuns(line), runs);
      },
    );

    test('a literal "[[...]]" that is not meant as a note is escaped', () {
      const runs = [FountainStyledRun(text: 'matrix[[3]] example')];
      final line = _serializer.write(runs);
      // The opening "[[" is escaped (as "\[[") so it no longer reads as a
      // note start; the round trip below is the real correctness check.
      expect(line, r'matrix\[[3]] example');
      expect(_parser.parseRuns(line), runs);
    });

    test('an odd number of asterisks leaves the true lone one unescaped', () {
      const runs = [FountainStyledRun(text: 'a * b and c * d and e * f')];
      final line = _serializer.write(runs);
      expect(_parser.parseRuns(line), runs);
      // The pair (first two asterisks) needs escaping; the trailing,
      // truly-unpaired third asterisk does not.
      expect(line, endsWith('e * f'));
    });

    test('escaped asterisks and underscores round-trip byte-identically '
        'with the corpus authoring style (both sides of a pair escaped)', () {
      const runs = [
        FountainStyledRun(
          text:
              'This is an escaped *asterisk*, not italics, and an '
              'escaped _underscore_, not underline.',
        ),
      ];
      final line = _serializer.write(runs);
      expect(
        line,
        r'This is an escaped \*asterisk\*, not italics, and an '
        r'escaped \_underscore\_, not underline.',
      );
      expect(_parser.parseRuns(line), runs);
    });

    test('emphasis runs are not touched by escaping, only plain ones', () {
      const runs = [
        FountainStyledRun(text: 'bold', isBold: true),
        FountainStyledRun(text: ' and 2 * 2 stays plain'),
      ];
      final line = _serializer.write(runs);
      expect(_parser.parseRuns(line), runs);
    });
  });

  group('round-trips', () {
    /// A representative set of lines exercising plain text, every single
    /// style, every nested combination, notes, adjacency and escaping.
    const lines = <String>[
      '',
      'Plain text with no markers at all.',
      'An *italic* word.',
      'A **bold** word.',
      'An _underlined_ word.',
      'All ***bold and italic*** together.',
      'Bold and underline: _**both**_.',
      'Italic and underline: _*both*_.',
      'Everything: _***all***_.',
      'A note: [[remember this]] inline.',
      '**bold** immediately followed by *italic*.',
      r'An escaped \*asterisk\* and \_underscore\_.',
      'A lone * and a lone _ that mean nothing special.',
    ];

    for (final line in lines) {
      test('"$line" round-trips text -> runs -> text', () {
        final runs = _parser.parseRuns(line);
        expect(_serializer.write(runs), line);
      });
    }

    const runLists = <List<FountainStyledRun>>[
      [],
      [FountainStyledRun(text: 'plain only')],
      [FountainStyledRun(text: 'x', isBold: true)],
      [FountainStyledRun(text: 'x', isItalic: true)],
      [FountainStyledRun(text: 'x', isUnderline: true)],
      [FountainStyledRun(text: 'x', isBold: true, isItalic: true)],
      [FountainStyledRun(text: 'x', isBold: true, isUnderline: true)],
      [FountainStyledRun(text: 'x', isItalic: true, isUnderline: true)],
      [
        FountainStyledRun(
          text: 'x',
          isBold: true,
          isItalic: true,
          isUnderline: true,
        ),
      ],
      [FountainStyledRun(text: '[[a note]]', isNote: true)],
      [
        FountainStyledRun(text: 'a '),
        FountainStyledRun(text: 'b', isBold: true),
        FountainStyledRun(text: ' c'),
      ],
    ];

    for (final runs in runLists) {
      test('$runs round-trips runs -> text -> runs', () {
        final line = _serializer.write(runs);
        expect(_parser.parseRuns(line), runs);
      });
    }
  });
}
