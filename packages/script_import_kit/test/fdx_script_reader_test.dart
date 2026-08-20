// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:fountain_kit/fountain_kit.dart';
import 'package:script_import_kit/src/models/script_import_exception.dart';
import 'package:script_import_kit/src/readers/fdx_script_reader.dart';
import 'package:test/test.dart';

/// Wraps [content] (and, when given, [titlePage]) in a Final Draft document
/// envelope declaring [documentType].
String _fdx(
  String content, {
  String titlePage = '',
  String documentType = 'Script',
}) {
  final titlePageBlock = titlePage.isEmpty
      ? ''
      : '<TitlePage><Content>\n$titlePage\n</Content></TitlePage>\n';
  return '''
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<FinalDraft DocumentType="$documentType" Template="No" Version="1">
<Content>
$content
</Content>
$titlePageBlock</FinalDraft>
''';
}

/// Reads [xml] with a fresh [FdxScriptReader].
String _read(String xml) =>
    const FdxScriptReader().read(Uint8List.fromList(utf8.encode(xml)));

/// Reads [content], wrapped in a document envelope, as Fountain body text.
String _readBody(String content) => _read(_fdx(content));

/// One `<Paragraph>` of [type] holding [text], carrying [attributes] (a
/// ready-to-splice ` Name="value"` string) on top of its own `Type`.
String _paragraph(String type, String text, {String attributes = ''}) =>
    '<Paragraph Type="$type"$attributes><Text>$text</Text></Paragraph>';

/// One `<Paragraph Type="Action">` holding a single [style]d `<Text>` run.
String _styledAction(String style, String text) =>
    '<Paragraph Type="Action"><Text Style="$style">$text</Text></Paragraph>';

/// A `<DualDialogue>` group of two characters saying the same thing.
String _dualDialogueGroup() => '''
<Paragraph><DualDialogue>
${_paragraph('Character', 'BRICK')}
${_paragraph('Dialogue', 'Screw retirement.')}
${_paragraph('Character', 'STEEL')}
${_paragraph('Dialogue', 'Screw retirement.')}
</DualDialogue></Paragraph>''';

/// The [ScriptImportFailure] the [FdxScriptReader] throws on [xml].
ScriptImportFailure _failureOf(String xml) {
  try {
    _read(xml);
  } on ScriptImportException catch (exception) {
    return exception.failure;
  }
  fail('reading the document was expected to throw');
}

void main() {
  group('paragraph types', () {
    test('a scene heading keeps its INT./EXT. form', () {
      expect(
        _readBody(_paragraph('Scene Heading', 'INT. KITCHEN - DAY')),
        'INT. KITCHEN - DAY\n',
      );
    });

    test('a scene heading carries its Number attribute as a "#N#" tag', () {
      final text = _readBody(
        _paragraph(
          'Scene Heading',
          'INT. KITCHEN - DAY',
          attributes: ' Number="4A"',
        ),
      );

      expect(text, 'INT. KITCHEN - DAY #4A#\n');
      final heading =
          const FountainParser().parse(text).blocks.single
              as FountainSceneHeading;
      expect(heading.sceneNumber, '4A');
      expect(heading.headingText, 'INT. KITCHEN - DAY');
    });

    test('action, general, shot and cast list all become action', () {
      expect(
        _readBody(
          [
            _paragraph('Action', 'She waits.'),
            _paragraph('General', 'A general note.'),
            _paragraph('Shot', 'ANGLE ON THE DOOR'),
            _paragraph('Cast List', 'SARAH, BRICK'),
          ].join('\n'),
        ),
        '''
She waits.

A general note.

ANGLE ON THE DOOR

SARAH, BRICK
''',
      );
    });

    test('a character cue keeps its extension, and its dialogue follows', () {
      expect(
        _readBody(
          [
            _paragraph('Character', 'SARAH (V.O.)'),
            _paragraph('Parenthetical', '(to herself)'),
            _paragraph('Dialogue', 'Smells like Sunday.'),
          ].join('\n'),
        ),
        '''
SARAH (V.O.)
(to herself)
Smells like Sunday.
''',
      );
    });

    test('a transition becomes a transition', () {
      expect(_readBody(_paragraph('Transition', 'CUT TO:')), 'CUT TO:\n');
    });

    test('an act break becomes centered text', () {
      expect(
        _readBody(
          [
            _paragraph('New Act', 'ACT ONE'),
            _paragraph('End of Act', 'END OF ACT ONE'),
          ].join('\n'),
        ),
        '''
> ACT ONE <

> END OF ACT ONE <
''',
      );
    });

    test('an unknown paragraph type keeps its text as action', () {
      expect(
        _readBody(_paragraph('Whatever Final Draft Invents', 'Still prose.')),
        'Still prose.\n',
      );
    });

    test('a paragraph with no text at all is dropped', () {
      expect(
        _readBody(
          [
            _paragraph('Action', 'She waits.'),
            '<Paragraph Type="Action"><Text></Text></Paragraph>',
            _paragraph('Action', 'She leaves.'),
          ].join('\n'),
        ),
        '''
She waits.

She leaves.
''',
      );
    });
  });

  group('inline styles', () {
    test('a styled run becomes its Fountain emphasis', () {
      expect(
        _readBody('''
<Paragraph Type="Action">
<Text>Sarah stares at the </Text>
<Text Style="Italic">kettle</Text>
<Text>, then at the </Text>
<Text Style="Bold+Underline">clock</Text>
<Text>.</Text>
</Paragraph>'''),
        'Sarah stares at the *kettle*, then at the _**clock**_.\n',
      );
    });

    test('a style Fountain has no marker for is dropped, its text kept', () {
      expect(
        _readBody(_styledAction('Strikeout+AllCaps', 'She waits.')),
        'She waits.\n',
      );
    });

    test('the outer whitespace of a paragraph is trimmed, the inner kept', () {
      expect(
        _readBody('''
<Paragraph Type="Action">
<Text>  She waits </Text>
<Text Style="Italic">and</Text>
<Text> waits.  </Text>
</Paragraph>'''),
        'She waits *and* waits.\n',
      );
    });
  });

  group('dual dialogue', () {
    test('the second cue of the group takes the "^" marker', () {
      final text = _readBody(_dualDialogueGroup());

      expect(text, '''
BRICK
Screw retirement.

STEEL ^
Screw retirement.
''');
      final groups = const FountainParser()
          .parse(text)
          .blocks
          .cast<FountainDialogueGroup>();
      expect(groups.map((group) => group.isDualDialogue), [false, true]);
    });
  });

  group('what is deliberately dropped', () {
    test('a script note nested in a paragraph leaves its text out', () {
      expect(
        _readBody('''
<Paragraph Type="Dialogue"><Text>Smells like Sunday.</Text>
<ScriptNote><Paragraph><Text>rewrite this</Text></Paragraph></ScriptNote>
</Paragraph>'''),
        'Smells like Sunday.\n',
      );
    });

    test('a script note of its own is skipped entirely', () {
      expect(
        _readBody('''
${_paragraph('Action', 'She waits.')}
<ScriptNote><Paragraph><Text>rewrite this</Text></Paragraph></ScriptNote>
${_paragraph('Action', 'She leaves.')}'''),
        '''
She waits.

She leaves.
''',
      );
    });
  });

  group('title page', () {
    test('the free-form lines are sorted into the six fields', () {
      expect(
        _read(
          _fdx(
            _paragraph('Action', 'She waits.'),
            titlePage: '''
<Paragraph><Text>THE LAST KETTLE</Text></Paragraph>
<Paragraph><Text></Text></Paragraph>
<Paragraph><Text>Written by</Text></Paragraph>
<Paragraph><Text>Jane Doe</Text></Paragraph>
<Paragraph><Text>Based on the novel by John Roe</Text></Paragraph>
<Paragraph><Text>Second Draft</Text></Paragraph>
<Paragraph><Text>jane@example.com</Text></Paragraph>
<Paragraph><Text>+33 1 23 45 67 89</Text></Paragraph>''',
          ),
        ),
        '''
Title: THE LAST KETTLE
Credit: Written by
Author: Jane Doe
Draft date: Second Draft
Contact:
    jane@example.com
    +33 1 23 45 67 89
Source: Based on the novel by John Roe

She waits.
''',
      );
    });

    test('a French title page is sorted the same way', () {
      final document = const FountainParser().parse(
        _read(
          _fdx(
            _paragraph('Action', 'Elle attend.'),
            titlePage: '''
<Paragraph><Text>LA DERNIÈRE BOUILLOIRE</Text></Paragraph>
<Paragraph><Text>Scénario de</Text></Paragraph>
<Paragraph><Text>Jeanne Dupont</Text></Paragraph>
<Paragraph><Text>D'après le roman de Jean Roux</Text></Paragraph>
<Paragraph><Text>Version 3</Text></Paragraph>''',
          ),
        ),
      );

      final titlePage = document.titlePage!;
      expect(titlePage.title, 'LA DERNIÈRE BOUILLOIRE');
      expect(titlePage.entry('Credit')?.joinedValue, 'Scénario de');
      expect(titlePage.entry('Author')?.joinedValue, 'Jeanne Dupont');
      expect(titlePage.entry('Draft date')?.joinedValue, 'Version 3');
      expect(
        titlePage.entry('Source')?.joinedValue,
        "D'après le roman de Jean Roux",
      );
      expect(titlePage.entry('Contact'), isNull);
    });

    test('a title page of nothing but a title writes only that', () {
      expect(
        _read(
          _fdx(
            _paragraph('Action', 'She waits.'),
            titlePage: '<Paragraph><Text>THE LAST KETTLE</Text></Paragraph>',
          ),
        ),
        '''
Title: THE LAST KETTLE

She waits.
''',
      );
    });

    test('a document with no title page gets none', () {
      expect(_readBody(_paragraph('Action', 'She waits.')), 'She waits.\n');
    });
  });

  group('refused documents', () {
    test('a document type other than a script is unsupported', () {
      expect(
        _failureOf(
          _fdx(
            _paragraph('Action', 'She waits.'),
            documentType: 'ScriptNotes',
          ),
        ),
        ScriptImportFailure.unsupportedFormat,
      );
    });

    test('XML that does not parse is malformed', () {
      expect(
        _failureOf('<FinalDraft DocumentType="Script"><Content>'),
        ScriptImportFailure.malformedFile,
      );
    });

    test("another format's XML is malformed", () {
      expect(
        _failureOf('<?xml version="1.0"?><celtx><body/></celtx>'),
        ScriptImportFailure.malformedFile,
      );
    });

    test('a document with no Content element is malformed', () {
      expect(
        _failureOf('<FinalDraft DocumentType="Script"></FinalDraft>'),
        ScriptImportFailure.malformedFile,
      );
    });

    test('a document with no line of screenplay is empty', () {
      expect(_failureOf(_fdx('')), ScriptImportFailure.emptyScript);
    });
  });

  group('round trip', () {
    test('re-parsing the produced text yields the types the reader meant', () {
      final text = _read(
        _fdx(
          [
            _paragraph(
              'Scene Heading',
              'INT. KITCHEN - DAY',
              attributes: ' Number="1"',
            ),
            _paragraph('Action', 'Sarah stares at the kettle.'),
            _paragraph('Character', 'SARAH (V.O.)'),
            _paragraph('Parenthetical', '(to herself)'),
            _paragraph('Dialogue', 'Smells like Sunday.'),
            _paragraph('Shot', 'ANGLE ON THE DOOR'),
            _paragraph('Action', 'INT. is how this one starts.'),
            _paragraph('Character', 'Sarah'),
            _paragraph('Dialogue', 'GET OUT.'),
            _paragraph('New Act', 'ACT TWO'),
            _paragraph('Transition', 'FADE OUT.'),
            _dualDialogueGroup(),
          ].join('\n'),
          titlePage: '<Paragraph><Text>THE LAST KETTLE</Text></Paragraph>',
        ),
      );

      final document = const FountainParser().parse(text);
      expect(document.titlePage?.title, 'THE LAST KETTLE');
      expect(document.blocks.map((block) => block.runtimeType.toString()), [
        'FountainSceneHeading',
        'FountainActionBlock',
        'FountainDialogueGroup',
        'FountainActionBlock',
        'FountainActionBlock',
        'FountainDialogueGroup',
        'FountainCenteredText',
        'FountainTransition',
        'FountainDialogueGroup',
        'FountainDialogueGroup',
      ]);

      final heading = document.blocks.first as FountainSceneHeading;
      expect(heading.headingText, 'INT. KITCHEN - DAY');
      expect(heading.sceneNumber, '1');

      final firstGroup = document.blocks[2] as FountainDialogueGroup;
      expect(firstGroup.character.name, 'SARAH');
      expect(firstGroup.character.extension, 'V.O.');
      expect(firstGroup.children, hasLength(2));

      // The all-caps shot line stayed prose rather than turning into a cue,
      // and the action line opening on `INT.` stayed prose rather than
      // turning into a scene heading: the two things a forcing marker,
      // or the lack of one, is there to decide.
      expect(
        (document.blocks[3] as FountainActionBlock).lines.single,
        'ANGLE ON THE DOOR',
      );
      expect(
        (document.blocks[4] as FountainActionBlock).lines.single,
        'INT. is how this one starts.',
      );

      final lowerCaseCue = document.blocks[5] as FountainDialogueGroup;
      expect(lowerCaseCue.character.name, 'Sarah');
      expect(
        (lowerCaseCue.children.single as FountainDialogueLine).text,
        'GET OUT.',
      );

      expect((document.blocks[6] as FountainCenteredText).text, 'ACT TWO');
      expect((document.blocks[7] as FountainTransition).text, 'FADE OUT.');
      expect(
        (document.blocks[9] as FountainDialogueGroup).isDualDialogue,
        isTrue,
      );
    });
  });

  group('bytes', () {
    test('a byte order mark and CRLF endings are absorbed', () {
      final xml = _fdx(_paragraph('Action', 'She waits.'));
      final bytes = Uint8List.fromList(
        utf8.encode('\u{FEFF}${xml.replaceAll('\n', '\r\n')}'),
      );

      expect(const FdxScriptReader().read(bytes), 'She waits.\n');
    });
  });
}
