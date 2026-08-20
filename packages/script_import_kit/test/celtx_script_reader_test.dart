// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:script_import_kit/src/models/script_import_exception.dart';
import 'package:script_import_kit/src/readers/celtx_script_reader.dart';
import 'package:test/test.dart';

/// The name the manifests below give the project's script document.
const String _scriptFileName = 'script-a1b2c3.html';

/// A `project.rdf` manifest naming [scriptFileName] as the project's script
/// document, carrying whichever of [title] and [creator] is given.
///
/// Neither is given by default, so that a test about the body of a
/// screenplay is not read against a title page it never asked for.
String _manifest({
  String? title,
  String? creator,
  String scriptFileName = _scriptFileName,
}) {
  final metadata = [
    if (title != null) 'dc:title="$title"',
    if (creator != null) 'dc:creator="$creator"',
  ].join(' ');
  return '''
<?xml version="1.0"?>
<RDF:RDF xmlns:RDF="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:cx="http://celtx.com/NS/v1/"
         xmlns:dc="http://purl.org/dc/elements/1.1/">
  <cx:Project RDF:about="urn:x-celtx:project" $metadata/>
  <cx:Document RDF:about="urn:x-celtx:doc-1" cx:type="ScriptDocument"
               cx:localFile="$scriptFileName"/>
</RDF:RDF>
''';
}

/// A Celtx script document holding [body]'s paragraphs.
String _scriptDocument(String body) =>
    '''
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html><head><title>Script</title></head>
<body>
$body
</body></html>
''';

/// Packs [entries] into the zip container a `.celtx` file is.
Uint8List _container(Map<String, String> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.add(ArchiveFile.string(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// A whole `.celtx` file holding [body] as its script document, under
/// [manifest].
Uint8List _celtx(String body, {String? manifest}) => _container({
  'project.rdf': manifest ?? _manifest(),
  _scriptFileName: _scriptDocument(body),
});

/// Reads a `.celtx` holding [body] as Fountain text.
String _readBody(String body) => const CeltxScriptReader().read(_celtx(body));

/// One `<p>` of [className] holding [text], carrying [attributes] (a
/// ready-to-splice ` name="value"` string) on top of its own class.
String _paragraph(String className, String text, {String attributes = ''}) =>
    '<p class="$className"$attributes>$text</p>';

/// The [ScriptImportFailure] reading [bytes] throws.
ScriptImportFailure _failureOf(Uint8List bytes) {
  try {
    const CeltxScriptReader().read(bytes);
  } on ScriptImportException catch (exception) {
    return exception.failure;
  }
  fail('reading the container was expected to throw');
}

void main() {
  group('paragraph classes', () {
    test('a scene heading keeps its INT./EXT. form', () {
      expect(
        _readBody(_paragraph('sceneheading', 'INT. KITCHEN - DAY')),
        'INT. KITCHEN - DAY\n',
      );
    });

    test('a scene heading carries its scenenumber as a "#N#" tag', () {
      final text = _readBody(
        _paragraph(
          'sceneheading',
          'INT. KITCHEN - DAY',
          attributes: ' scenenumber="4A"',
        ),
      );

      expect(text, 'INT. KITCHEN - DAY #4A#\n');
      final heading =
          const FountainParser().parse(text).blocks.single
              as FountainSceneHeading;
      expect(heading.sceneNumber, '4A');
      expect(heading.headingText, 'INT. KITCHEN - DAY');
    });

    test('a character cue and its dialogue stay one block', () {
      expect(
        _readBody(
          [
            _paragraph('character', 'SARAH'),
            _paragraph('parenthetical', '(to herself)'),
            _paragraph('dialog', 'Smells like Sunday.'),
          ].join('\n'),
        ),
        '''
SARAH
(to herself)
Smells like Sunday.
''',
      );
    });

    test('a transition is written as one', () {
      final text = _readBody(
        [
          _paragraph('action', 'She puts the kettle down.'),
          _paragraph('transition', 'CUT TO:'),
        ].join('\n'),
      );

      // No forcing `>`: an all-caps line ending in `TO:` is a transition to
      // the parser on its own, and the emitter only ever writes the marker
      // a line would be misread without.
      expect(text, '''
She puts the kettle down.

CUT TO:
''');
      expect(
        const FountainParser().parse(text).blocks.last,
        isA<FountainTransition>(),
      );
    });

    test('an act break is centered', () {
      expect(
        _readBody(
          [
            _paragraph('act', 'ACT ONE'),
            _paragraph('actbreak', 'END OF ACT ONE'),
          ].join('\n'),
        ),
        '''
> ACT ONE <

> END OF ACT ONE <
''',
      );
    });

    test('a shot, a text block and an action all become action', () {
      expect(
        _readBody(
          [
            _paragraph('shot', 'ANGLE ON THE DOOR'),
            _paragraph('text', 'A note to the reader.'),
            _paragraph('action', 'She waits.'),
          ].join('\n'),
        ),
        '''
ANGLE ON THE DOOR

A note to the reader.

She waits.
''',
      );
    });

    test('an unknown class keeps its text, as action', () {
      expect(
        _readBody(_paragraph('sluglinealternate', 'Something else entirely.')),
        'Something else entirely.\n',
      );
    });

    test('a paragraph with no class at all keeps its text, as action', () {
      expect(_readBody('<p>She waits.</p>'), 'She waits.\n');
    });

    test('the class is matched among the several a paragraph carries', () {
      expect(
        _readBody(_paragraph('celtx-block dialog', 'Smells like Sunday.')),
        'Smells like Sunday.\n',
      );
    });

    test('a paragraph holding nothing but whitespace is dropped', () {
      expect(
        _readBody(
          [
            _paragraph('action', 'She waits.'),
            _paragraph('action', '  '),
            _paragraph('action', 'Then she does not.'),
          ].join('\n'),
        ),
        '''
She waits.

Then she does not.
''',
      );
    });
  });

  group('inside a paragraph', () {
    test('a <br> splits the paragraph into lines of one same block', () {
      expect(
        _readBody(
          _paragraph('action', 'She waits.<br>Then she does not.<br>Ever.'),
        ),
        '''
She waits.
Then she does not.
Ever.
''',
      );
    });

    test('a <br> at the end of a paragraph adds no line', () {
      expect(_readBody(_paragraph('action', 'She waits.<br>')), 'She waits.\n');
    });

    test('bold, italic and underline become their Fountain markers', () {
      expect(
        _readBody(
          _paragraph(
            'action',
            'She <b>waits</b>, <i>quietly</i>, and <u>alone</u>.',
          ),
        ),
        'She **waits**, *quietly*, and _alone_.\n',
      );
    });

    test('<strong> and <em> are read as bold and italic too', () {
      expect(
        _readBody(
          _paragraph('action', 'She <strong>waits</strong>, <em>still</em>.'),
        ),
        'She **waits**, *still*.\n',
      );
    });

    test('nested emphasis carries both styles', () {
      expect(
        _readBody(_paragraph('action', 'She <b>waits <i>alone</i></b>.')),
        'She **waits *****alone***.\n',
      );
    });

    test('an element Fountain has no marker for keeps its text', () {
      expect(
        _readBody(
          _paragraph(
            'action',
            'She waits <span class="rev">by the door</span>.',
          ),
        ),
        'She waits by the door.\n',
      );
    });

    test(
      'entities, non-breaking spaces and layout whitespace are absorbed',
      () {
        expect(
          _readBody(
            '<p class="action">\n  She waits &amp; waits,&nbsp;alone.\n</p>',
          ),
          'She waits & waits, alone.\n',
        );
      },
    );
  });

  group('the title page', () {
    test("the project's title and creator make one", () {
      expect(
        const CeltxScriptReader().read(
          _celtx(
            _paragraph('action', 'She waits.'),
            manifest: _manifest(
              title: 'The Last Kettle',
              creator: 'Sarah Vaughn',
            ),
          ),
        ),
        '''
Title: The Last Kettle
Author: Sarah Vaughn

She waits.
''',
      );
    });

    test('a project with no creator gets a title alone', () {
      expect(
        const CeltxScriptReader().read(
          _celtx(
            _paragraph('action', 'She waits.'),
            manifest: _manifest(title: 'The Last Kettle'),
          ),
        ),
        '''
Title: The Last Kettle

She waits.
''',
      );
    });

    test('a project with no metadata at all gets no title page', () {
      expect(_readBody(_paragraph('action', 'She waits.')), 'She waits.\n');
    });

    test('a manifest writing its metadata as child elements is read too', () {
      const manifest =
          '''
<?xml version="1.0"?>
<RDF:RDF xmlns:RDF="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:cx="http://celtx.com/NS/v1/"
         xmlns:dc="http://purl.org/dc/elements/1.1/">
  <cx:Project RDF:about="urn:x-celtx:project">
    <dc:title>The Last Kettle</dc:title>
    <dc:creator>Sarah Vaughn</dc:creator>
  </cx:Project>
  <RDF:Description RDF:about="urn:x-celtx:doc-1"
                   RDF:type="http://celtx.com/NS/v1/ScriptDocument"
                   cx:localFile="$_scriptFileName"/>
</RDF:RDF>
''';

      expect(
        const CeltxScriptReader().read(
          _celtx(_paragraph('action', 'She waits.'), manifest: manifest),
        ),
        '''
Title: The Last Kettle
Author: Sarah Vaughn

She waits.
''',
      );
    });
  });

  group('the container', () {
    test('the first script document is the one read', () {
      const manifest = '''
<?xml version="1.0"?>
<RDF:RDF xmlns:RDF="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:cx="http://celtx.com/NS/v1/"
         xmlns:dc="http://purl.org/dc/elements/1.1/">
  <cx:Project RDF:about="urn:x-celtx:project" dc:title="The Last Kettle"/>
  <cx:Document RDF:about="urn:x-celtx:doc-1" cx:type="CatalogDocument"
               cx:localFile="catalog.html"/>
  <cx:Document RDF:about="urn:x-celtx:doc-2" cx:type="ScriptDocument"
               cx:localFile="script-first.html"/>
  <cx:Document RDF:about="urn:x-celtx:doc-3" cx:type="ScriptDocument"
               cx:localFile="script-second.html"/>
</RDF:RDF>
''';

      final bytes = _container({
        'project.rdf': manifest,
        'catalog.html': _scriptDocument(_paragraph('action', 'A location.')),
        'script-first.html': _scriptDocument(
          _paragraph('action', 'She waits.'),
        ),
        'script-second.html': _scriptDocument(
          _paragraph('action', 'Another episode entirely.'),
        ),
      });

      expect(const CeltxScriptReader().read(bytes), '''
Title: The Last Kettle

She waits.
''');
    });

    test('a project wrapped in a folder of its own still opens', () {
      final bytes = _container({
        'The Last Kettle/project.rdf': _manifest(title: 'The Last Kettle'),
        'The Last Kettle/$_scriptFileName': _scriptDocument(
          _paragraph('action', 'She waits.'),
        ),
      });

      expect(const CeltxScriptReader().read(bytes), '''
Title: The Last Kettle

She waits.
''');
    });
  });

  group('refused containers', () {
    test('a file that does not open as a zip is malformed', () {
      expect(
        _failureOf(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])),
        ScriptImportFailure.malformedFile,
      );
    });

    test('a container with no project.rdf holds no script document', () {
      expect(
        _failureOf(
          _container({
            _scriptFileName: _scriptDocument(
              _paragraph('action', 'She waits.'),
            ),
          }),
        ),
        ScriptImportFailure.noScriptDocument,
      );
    });

    test('a manifest that does not parse holds no script document', () {
      expect(
        _failureOf(
          _container({
            'project.rdf': '<?xml version="1.0"?><RDF:RDF><cx:Project',
            _scriptFileName: _scriptDocument(
              _paragraph('action', 'She waits.'),
            ),
          }),
        ),
        ScriptImportFailure.noScriptDocument,
      );
    });

    test('a manifest naming no script document is refused', () {
      const manifest = '''
<?xml version="1.0"?>
<RDF:RDF xmlns:RDF="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:cx="http://celtx.com/NS/v1/"
         xmlns:dc="http://purl.org/dc/elements/1.1/">
  <cx:Project RDF:about="urn:x-celtx:project" dc:title="The Last Kettle"/>
  <cx:Document RDF:about="urn:x-celtx:doc-1" cx:type="StoryboardDocument"
               cx:localFile="storyboard.html"/>
</RDF:RDF>
''';

      expect(
        _failureOf(
          _celtx(_paragraph('action', 'She waits.'), manifest: manifest),
        ),
        ScriptImportFailure.noScriptDocument,
      );
    });

    test('a script document the container does not hold is refused', () {
      expect(
        _failureOf(
          _container({'project.rdf': _manifest(scriptFileName: 'gone.html')}),
        ),
        ScriptImportFailure.noScriptDocument,
      );
    });

    test('a script with no recognised paragraph is empty', () {
      expect(
        _failureOf(
          _celtx('''
<table><tr><td class="video">WIDE ON THE KITCHEN</td>
<td class="audio">She waits.</td></tr></table>'''),
        ),
        ScriptImportFailure.emptyScript,
      );
    });
  });

  group('round trip', () {
    test('re-parsing the produced text yields the types the reader meant', () {
      final text = const CeltxScriptReader().read(
        _celtx(
          [
            _paragraph(
              'sceneheading',
              'INT. KITCHEN - DAY',
              attributes: ' scenenumber="1"',
            ),
            _paragraph('action', 'Sarah stares at the kettle.'),
            _paragraph('character', 'SARAH (V.O.)'),
            _paragraph('parenthetical', '(to herself)'),
            _paragraph('dialog', 'Smells like Sunday.'),
            _paragraph('shot', 'ANGLE ON THE DOOR'),
            _paragraph('action', 'INT. is how this one starts.'),
            _paragraph('character', 'Sarah'),
            _paragraph('dialog', 'GET OUT.'),
            _paragraph('act', 'ACT TWO'),
            _paragraph('transition', 'FADE OUT.'),
          ].join('\n'),
          manifest: _manifest(title: 'The Last Kettle'),
        ),
      );

      final document = const FountainParser().parse(text);
      expect(document.titlePage?.title, 'The Last Kettle');
      expect(document.blocks.map((block) => block.runtimeType.toString()), [
        'FountainSceneHeading',
        'FountainActionBlock',
        'FountainDialogueGroup',
        'FountainActionBlock',
        'FountainActionBlock',
        'FountainDialogueGroup',
        'FountainCenteredText',
        'FountainTransition',
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
      // turning into a scene heading: the two things a forcing marker, or
      // the lack of one, is there to decide.
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
    });

    test('a paragraph split by a <br> comes back as one action block', () {
      final text = _readBody(
        _paragraph('action', 'She waits.<br>Then she does not.'),
      );

      final block =
          const FountainParser().parse(text).blocks.single
              as FountainActionBlock;
      expect(block.lines, ['She waits.', 'Then she does not.']);
    });
  });
}
