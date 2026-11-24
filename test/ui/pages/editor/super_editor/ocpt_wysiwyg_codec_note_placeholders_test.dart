// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_document_settle.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_notes.dart';
import 'package:super_editor/super_editor.dart';
import 'ocpt_wysiwyg_codec_test_doubles.dart';

/// Build a live [Editor] over [document], with the handlers the settle pass executes through.
Editor _editorFor(MutableDocument document) => Editor(
  editables: {Editor.documentKey: document, Editor.composerKey: MutableDocumentComposer()},
  requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
    ..add(ocptChangeNodeMetadataRequestHandler)
    ..add(ocptReplaceNodeTextRequestHandler),
);

/// Run the settle pass of the live editor on [document].
void _settle(MutableDocument document) =>
    OcptStyledDocumentSettle.settle(document, _editorFor(document));

/// Decode [source], encode it back and get the text written.
String _roundTrip(String source) {
  final decoded = OcptWysiwygCodec.decode(source);
  return OcptWysiwygCodec.encode(
    decoded.document,
    trailingBlankLines: decoded.trailingBlankLines,
  ).text;
}

/// Get the text of the node at [index] of [document].
AttributedText _textAt(Document document, int index) =>
    (document.getNodeAt(index)! as ParagraphNode).text;

/// Get the texts of the notes the node at [index] of [document] holds as placeholders.
List<String> _notesAt(Document document, int index) => [
  for (final placeholder in _textAt(document, index).placeholders.values)
    (placeholder as OcptFountainNote).text,
];

/// Run the tests of the notes the styled editor holds as inline placeholders.
void main() {
  group('a note on one line is a placeholder', () {
    test('at the start, in the middle, at the end of a line and alone on it', () {
      final document = OcptWysiwygCodec.decode(
        '[[a]] start\n\nmiddle [[b]] here\n\nend [[c]]\n\n[[d]]',
      ).document;

      expect(_textAt(document, 0).toPlainText(), '￼ start');
      expect(_notesAt(document, 0), ['a']);
      expect(_textAt(document, 1).toPlainText(), 'middle ￼ here');
      expect(_notesAt(document, 1), ['b']);
      expect(_textAt(document, 2).toPlainText(), 'end ￼');
      expect(_notesAt(document, 2), ['c']);
      expect(_textAt(document, 3).toPlainText(), '￼');
      expect(_notesAt(document, 3), ['d']);
    });

    test('and holds no dimming text attribution of its own', () {
      final text = _textAt(OcptWysiwygCodec.decode('a [[b]] c').document, 0);

      expect(text.getAttributionSpans({ocptFountainNoteAttribution}), isEmpty);
    });

    test('and an empty note too', () {
      expect(_notesAt(OcptWysiwygCodec.decode('a [[]] c').document, 0), ['']);
    });

    test('two notes side by side stay two placeholders with their own ids', () {
      final text = _textAt(OcptWysiwygCodec.decode('[[a]][[b]] twice').document, 0);

      expect(text.toPlainText(), '￼￼ twice');
      final ids = {for (final note in text.placeholders.values) (note as OcptFountainNote).id};
      expect(ids, hasLength(2));
    });

    test('and every note of a line is written back byte for byte', () {
      const lines = [
        '[[x]]',
        '[[x]] start',
        'middle [[x]] here',
        'end [[x]]',
        '[[a]][[b]]',
        '[[a]] and [[b]]',
        '[[]]',
        '[[x]]INT. HOUSE - DAY',
        'INT. HOUSE - DAY [[x]]',
        'CUT TO:[[x]]',
        'SARAH[[y]]\n(softly) [[z]]\nHi.',
        'He **runs [[n]] fast**.',
        'He _runs_ [[n]] _fast_.',
        'KIM ^ [[aside]]',
        '[[a ]] [[ b]]',
        '[[ one ]]',
      ];

      for (final line in lines) {
        for (final source in [line, 'He waits.\n\n$line\n\nShe leaves.', 'A.\n$line']) {
          expect(_roundTrip(source), source, reason: source);
        }
      }
    });
  });

  group('a note stays text where it is no placeholder', () {
    test('inside a boneyard, on its line or over several', () {
      for (final source in ['/* [[x]] */', 'a /* b [[x]] c */ d', '/*\n[[x]]\n*/']) {
        final document = OcptWysiwygCodec.decode(source).document;

        for (final node in document.whereType<ParagraphNode>()) {
          expect(node.text.placeholders, isEmpty, reason: source);
        }
        expect(_roundTrip(source), source);
      }
    });

    test('holding a boneyard marker', () {
      for (final source in ['a [[x /* y]] b', 'a [[x */ y]] b']) {
        final document = OcptWysiwygCodec.decode(source).document;

        expect(_textAt(document, 0).placeholders, isEmpty, reason: source);
        expect(_textAt(document, 0).toPlainText(), source);
        expect(_roundTrip(source), source);
      }
    });

    test('running over several lines with a boneyard on one of them', () {
      const source = 'He waits [[ a\nmiddle\n]] /* b */\nSARAH\nHi.';
      final document = OcptWysiwygCodec.decode(source).document;

      for (final node in document.whereType<ParagraphNode>()) {
        expect(node.text.placeholders, isEmpty);
      }
      expect(_roundTrip(source), source);
    });

    test('escaped', () {
      final document = OcptWysiwygCodec.decode(r'He \[[x]] y.').document;

      expect(_textAt(document, 0).placeholders, isEmpty);
      expect(_textAt(document, 0).toPlainText(), 'He [[x]] y.');
      expect(_roundTrip(r'He \[[x]] y.'), r'He \[[x]] y.');
    });

    test('opened earlier on the line, the first opening taking the rest as its text', () {
      final document = OcptWysiwygCodec.decode('a [[ b [[c]] d').document;

      expect(_notesAt(document, 0), [' b [[c']);
      expect(_textAt(document, 0).toPlainText(), 'a ￼ d');
      expect(_roundTrip('a [[ b [[c]] d'), 'a [[ b [[c]] d');
    });
  });

  group('the line a node stands for is the one the parser reads', () {
    test('a note before a heading leaves it a heading', () {
      final document = OcptWysiwygCodec.decode('[[x]]INT. HOUSE - DAY').document;

      expect(typeAt(document, 0), FountainLineType.sceneHeading);
      expect(_notesAt(document, 0), ['x']);
    });

    test('a note after a transition leaves it a transition', () {
      final document = OcptWysiwygCodec.decode('He leaves.\n\nCUT TO:[[x]]').document;

      expect(typeAt(document, 1), FountainLineType.transition);
    });

    test('a note alone on its line is inert and written as it was', () {
      final document = OcptWysiwygCodec.decode('He.\n\n[[x]]\nSARAH\nHi.').document;

      expect(OcptWysiwygCodec.inertNodeIds(document), {document.getNodeAt(1)!.id});
      expect(typeAt(document, 2), FountainLineType.character);
    });

    test('the ^ before a note is not absorbed and still pairs the speeches', () {
      final document = OcptWysiwygCodec.decode('ROSS\nA.\n\nKIM ^ [[aside]]\nB.').document;

      _settle(document);

      expect(_textAt(document, 2).toPlainText(), 'KIM ^ ￼');
      expect(OcptWysiwygDualDialogue.suffixOf(document.getNodeAt(2)! as ParagraphNode), isNull);
      expect(OcptWysiwygDualDialogue.pairsOf(document), hasLength(1));
      expect(OcptWysiwygCodec.encode(document).text, 'ROSS\nA.\n\nKIM ^ [[aside]]\nB.');
    });

    test('the text of a note is never uppercased, the heading around it is', () {
      final document = OcptWysiwygCodec.decode('int. house [[later]] - day').document;

      _settle(document);

      expect(_textAt(document, 0).toPlainText(), 'INT. HOUSE ￼ - DAY');
      expect(_notesAt(document, 0), ['later']);
      expect(OcptWysiwygCodec.encode(document).text, 'INT. HOUSE [[later]] - DAY #1#');
    });
  });

  group('the settle keeps the notes of a document in line with the invariant', () {
    /// Replace the text of the node at [index] of [document] with [text].
    void setText(MutableDocument document, int index, AttributedText text) {
      final node = document.getNodeAt(index)! as ParagraphNode;
      document.replaceNodeById(node.id, node.copyParagraphWith(text: text));
    }

    test('a decoded document has no note to absorb or dissolve', () {
      final document = OcptWysiwygCodec.decode(
        'a [[x]] b\n\n/* [[y]] */\n\n[[ open\nclosed ]]\n\nc [[z /* w]]',
      ).document;

      expect(OcptWysiwygNotes.requests(document), isEmpty);
    });

    test('a note typed as text is absorbed, its text kept', () {
      final document = OcptWysiwygCodec.decode('He waits.').document;
      setText(document, 0, AttributedText('He [[typed]] waits.'));

      _settle(document);

      expect(_textAt(document, 0).toPlainText(), 'He ￼ waits.');
      expect(_notesAt(document, 0), ['typed']);
      expect(OcptWysiwygNotes.requests(document), isEmpty);
    });

    test('keeps the emphasis around the note it absorbs', () {
      final document = OcptWysiwygCodec.decode('He waits.').document;
      final text = AttributedText('He [[n]] waits.')
        ..addAttribution(boldAttribution, const SpanRange(9, 14));
      setText(document, 0, text);

      _settle(document);

      expect(
        _textAt(
          document,
          0,
        ).getAttributionSpans({boldAttribution}).map((span) => (span.start, span.end)),
        [(5, 10)],
      );
      expect(OcptWysiwygCodec.encode(document).text, 'He [[n]] **waits.**');
    });

    test('a placeholder is dissolved into text when a boneyard opens before and closes after', () {
      final document = OcptWysiwygCodec.decode('a [[x]] b').document;
      setText(
        document,
        0,
        AttributedText(
          '/* ',
        ).copyAndAppend(_textAt(document, 0)).copyAndAppend(AttributedText(' */')),
      );

      _settle(document);

      expect(_textAt(document, 0).placeholders, isEmpty);
      expect(_textAt(document, 0).toPlainText(), '/* a [[x]] b */');
      expect(OcptWysiwygCodec.encode(document).text, '/* a [[x]] b */');
    });

    test('and is absorbed again once the boneyard goes', () {
      final document = OcptWysiwygCodec.decode('/* a [[x]] b */').document;
      setText(document, 0, AttributedText('a [[x]] b'));

      _settle(document);

      expect(_notesAt(document, 0), ['x']);
    });

    test('a placeholder is dissolved when a marker of a boneyard slips into its text', () {
      final document = OcptWysiwygCodec.decode('a [[x]] b').document;
      final note = OcptFountainNote.create('x /* y');
      setText(document, 0, AttributedText('a  b').insertPlaceholder(2, note));

      _settle(document);

      expect(_textAt(document, 0).placeholders, isEmpty);
      expect(_textAt(document, 0).toPlainText(), 'a [[x /* y]] b');
      expect(OcptWysiwygCodec.encode(document).text, 'a [[x /* y]] b');
    });

    test('a note opened before a placeholder swallows it into one note', () {
      final document = OcptWysiwygCodec.decode('a [[x]] b').document;
      setText(document, 0, AttributedText('[[ ').copyAndAppend(_textAt(document, 0)));

      _settle(document);

      expect(_notesAt(document, 0), [' a [[x']);
      expect(OcptWysiwygCodec.encode(document).text, '[[ a [[x]] b');
    });

    test('a node an input method is composing in is left for the settle after it', () {
      final document = OcptWysiwygCodec.decode('a').document;
      setText(document, 0, AttributedText('a [[x]] b'));
      final id = document.getNodeAt(0)!.id;

      expect(OcptWysiwygNotes.requests(document, composingNodeIds: {id}), isEmpty);
      expect(OcptWysiwygNotes.requests(document), hasLength(1));
    });

    test('the offsets of the text it rewrites are carried to where their characters went', () {
      final document = OcptWysiwygCodec.decode('a').document;
      setText(document, 0, AttributedText('a [[x]] b'));

      final request = OcptWysiwygNotes.requests(document).single as OcptReplaceNodeTextRequest;
      final map = request.mapOffset!;

      // `a ￼ b`: the note took the offsets 2 to 7 of the text and now takes the offset 2.
      expect(map(0), 0);
      expect(map(2), 2);
      expect(map(5), 3);
      expect(map(7), 3);
      expect(map(8), 4);
      expect(map(9), 5);
    });

    test('the settle is stable once done', () {
      final document = OcptWysiwygCodec.decode('a').document;
      setText(document, 0, AttributedText('[[a]] b [[c]]'));

      _settle(document);
      final once = _textAt(document, 0).toPlainText();
      _settle(document);

      expect(_textAt(document, 0).toPlainText(), once);
      expect(_notesAt(document, 0), ['a', 'c']);
    });
  });
}
