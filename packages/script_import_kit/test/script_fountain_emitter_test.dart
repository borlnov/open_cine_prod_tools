// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:script_import_kit/src/emitter/script_fountain_emitter.dart';
import 'package:script_import_kit/src/emitter/script_line.dart';
import 'package:script_import_kit/src/emitter/script_title_page.dart';
import 'package:test/test.dart';

/// Renders [lines] with a fresh [ScriptFountainEmitter].
String _write(
  List<ScriptLine> lines, {
  ScriptTitlePage titlePage = const ScriptTitlePage(),
}) => const ScriptFountainEmitter().write(lines: lines, titlePage: titlePage);

/// A plain line of [type] holding [text].
ScriptLine _line(
  FountainLineType type,
  String text, {
  String? sceneNumber,
  bool isDualDialogue = false,
  bool continuesBlock = false,
}) => ScriptLine.plain(
  type: type,
  text: text,
  sceneNumber: sceneNumber,
  isDualDialogue: isDualDialogue,
  continuesBlock: continuesBlock,
);

void main() {
  group('block separation', () {
    test('two blocks are separated by a blank line', () {
      expect(
        _write([
          _line(FountainLineType.sceneHeading, 'INT. KITCHEN - DAY'),
          _line(FountainLineType.action, 'Sarah waits.'),
        ]),
        'INT. KITCHEN - DAY\n\nSarah waits.\n',
      );
    });

    test('a dialogue block stays glued to its cue', () {
      expect(
        _write([
          _line(FountainLineType.character, 'SARAH'),
          _line(FountainLineType.parenthetical, '(to herself)'),
          _line(FountainLineType.dialogue, 'Smells like Sunday.'),
        ]),
        'SARAH\n(to herself)\nSmells like Sunday.\n',
      );
    });

    test('a line continuing its block gets no blank line before it', () {
      expect(
        _write([
          _line(FountainLineType.action, 'She opens the door.'),
          _line(
            FountainLineType.action,
            'She closes it again.',
            continuesBlock: true,
          ),
        ]),
        'She opens the door.\nShe closes it again.\n',
      );
    });

    test('a line with no text at all is dropped', () {
      expect(
        _write([
          _line(FountainLineType.action, 'She waits.'),
          _line(FountainLineType.action, '   '),
          _line(FountainLineType.action, 'She leaves.'),
        ]),
        'She waits.\n\nShe leaves.\n',
      );
    });

    test('no line at all renders nothing at all', () {
      expect(_write([]), '');
    });
  });

  group('forcing markers', () {
    test('an action paragraph opening on a scene heading prefix is forced', () {
      expect(
        _write([_line(FountainLineType.action, 'INT. is how it starts.')]),
        '!INT. is how it starts.\n',
      );
    });

    test('an all-caps line of dialogue is written as dialogue, not as a cue', () {
      final text = _write([
        _line(FountainLineType.character, 'SARAH'),
        _line(FountainLineType.dialogue, 'GET OUT.'),
      ]);

      expect(text, 'SARAH\nGET OUT.\n');
      final blocks = const FountainParser().parse(text).blocks;
      expect(blocks, hasLength(1));
      expect((blocks.single as FountainDialogueGroup).children, [
        const FountainDialogueLine(
          sourceRange: FountainSourceRange(
            startLine: 0,
            endLine: 0,
            startOffset: 0,
            endOffset: 0,
          ),
          text: 'GET OUT.',
        ),
      ]);
    });

    test('a lower-case character cue is forced with an "@"', () {
      expect(
        _write([
          _line(FountainLineType.character, 'Sarah'),
          _line(FountainLineType.dialogue, 'Hello.'),
        ]),
        '@Sarah\nHello.\n',
      );
    });

    test('a transition that does not end in "TO:" is forced with a ">"', () {
      expect(
        _write([_line(FountainLineType.transition, 'FADE OUT.')]),
        '>FADE OUT.\n',
      );
    });

    test('centered text is wrapped in its own markers', () {
      expect(
        _write([_line(FountainLineType.centeredText, 'ACT ONE')]),
        '> ACT ONE <\n',
      );
    });
  });

  group('tags the line writer knows nothing about', () {
    test('a scene number is appended to the heading text', () {
      expect(
        _write([
          _line(
            FountainLineType.sceneHeading,
            'INT. KITCHEN - DAY',
            sceneNumber: '4A',
          ),
        ]),
        'INT. KITCHEN - DAY #4A#\n',
      );
    });

    test('a blank scene number appends nothing', () {
      expect(
        _write([
          _line(
            FountainLineType.sceneHeading,
            'INT. KITCHEN - DAY',
            sceneNumber: '  ',
          ),
        ]),
        'INT. KITCHEN - DAY\n',
      );
    });

    test('a dual dialogue cue takes the "^" marker', () {
      expect(
        _write([
          _line(FountainLineType.character, 'STEEL', isDualDialogue: true),
          _line(FountainLineType.dialogue, 'Screw retirement.'),
        ]),
        'STEEL ^\nScrew retirement.\n',
      );
    });
  });

  group('inline styles', () {
    test('runs are serialized with their emphasis markers', () {
      expect(
        _write([
          const ScriptLine(
            type: FountainLineType.action,
            runs: [
              FountainStyledRun(text: 'Sarah stares at the '),
              FountainStyledRun(text: 'kettle', isItalic: true),
              FountainStyledRun(text: ' and the '),
              FountainStyledRun(text: 'clock', isBold: true, isUnderline: true),
              FountainStyledRun(text: '.'),
            ],
          ),
        ]),
        'Sarah stares at the *kettle* and the _**clock**_.\n',
      );
    });

    test('a marker pair the text itself carried is escaped', () {
      final text = _write([
        _line(FountainLineType.action, 'She types *this* on the machine.'),
      ]);

      expect(text, r'She types \*this\* on the machine.' '\n');
      final blocks = const FountainParser().parse(text).blocks;
      expect(
        (blocks.single as FountainActionBlock).lines.single,
        r'She types \*this\* on the machine.',
      );
    });
  });

  group('title page', () {
    test('the six fields are written in the canonical order', () {
      expect(
        _write([
          _line(FountainLineType.action, 'She waits.'),
        ], titlePage: const ScriptTitlePage(
          title: 'THE LAST KETTLE',
          credit: 'Written by',
          author: 'Jane Doe',
          draftDate: 'Second Draft',
          contact: ['jane@example.com', '+33 1 23 45 67 89'],
          source: 'Based on the novel by John Roe',
        )),
        'Title: THE LAST KETTLE\n'
        'Credit: Written by\n'
        'Author: Jane Doe\n'
        'Draft date: Second Draft\n'
        'Contact:\n'
        '    jane@example.com\n'
        '    +33 1 23 45 67 89\n'
        'Source: Based on the novel by John Roe\n'
        '\n'
        'She waits.\n',
      );
    });

    test('a title page with nothing in it is not written at all', () {
      expect(
        _write([
          _line(FountainLineType.action, 'She waits.'),
        ], titlePage: const ScriptTitlePage(title: '   ')),
        'She waits.\n',
      );
    });

    test('a written title page is read back by the parser', () {
      final document = const FountainParser().parse(
        _write([
          _line(FountainLineType.action, 'She waits.'),
        ], titlePage: const ScriptTitlePage(title: 'THE LAST KETTLE')),
      );

      expect(document.titlePage?.title, 'THE LAST KETTLE');
      expect(document.blocks, hasLength(1));
    });
  });
}
