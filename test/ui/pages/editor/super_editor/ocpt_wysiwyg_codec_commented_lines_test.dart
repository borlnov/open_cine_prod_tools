// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

import 'ocpt_wysiwyg_codec_test_doubles.dart';

/// A screenplay whose boneyard and multi-line note are full of lines that look active.
const String _commentedSource =
    'INT. HOUSE - DAY\n'
    '\n'
    'He waits.\n'
    '\n'
    '/*\n'
    'INT. GONE - DAY\n'
    '\n'
    'SARAH\n'
    '(softly)\n'
    'Hello.\n'
    '\n'
    'cut to:\n'
    '@forced\n'
    '!Forced action #4#\n'
    '*/\n'
    '\n'
    '[[ a long note\n'
    'INT. NOTE - DAY\n'
    'end of the note ]]\n'
    '\n'
    'SARAH\n'
    'Back.';

/// Decode [text] and give the types the parser reads for the live lines, keyed by their text.
Map<String, FountainLineType> _parserTypes(String text) {
  final types = <String, FountainLineType>{};
  void walk(FountainBlock block) {
    switch (block) {
      case FountainSceneHeading(:final rawText):
        types[rawText] = FountainLineType.sceneHeading;
      case FountainCharacter(:final name):
        types[name] = FountainLineType.character;
      case FountainDialogueLine(:final text):
        types[text] = FountainLineType.dialogue;
      case FountainActionBlock(:final lines):
        types[lines.first] = FountainLineType.action;
      case FountainDialogueGroup(:final character, :final children):
        walk(character);
        children.forEach(walk);
      default:
    }
  }

  const FountainParser().parse(text).blocks.forEach(walk);
  return types;
}

/// Build a live [Editor] over [document], the one the settle pass executes its requests on.
Editor _editorFor(MutableDocument document) => Editor(
  editables: {Editor.documentKey: document, Editor.composerKey: MutableDocumentComposer()},
  requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers),
);

/// Run the tests of the commented lines of the styled editor's codec.
void main() {
  group('inert lines', () {
    test('a boneyard and a multi-line note round trip byte for byte', () {
      final decoded = OcptWysiwygCodec.decode(_commentedSource);
      final encoded = OcptWysiwygCodec.encode(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, _commentedSource);
    });

    test('an inert line keeps its raw text and the action type', () {
      final decoded = OcptWysiwygCodec.decode(_commentedSource);
      final inert = OcptWysiwygCodec.inertNodeIds(decoded.document);

      // The note running over three lines is one node.
      expect(decoded.document.nodeCount, 14);
      expect(decoded.mapping.lineCountOfNodeIndex(11), 3);
      for (var index = 0; index < decoded.document.nodeCount; index++) {
        final node = decoded.document.getNodeAt(index)! as ParagraphNode;
        final isCommented = index >= 2 && index <= 11;
        expect(inert.contains(node.id), isCommented, reason: node.text.toPlainText());
        if (isCommented) {
          expect(typeAt(decoded.document, index), FountainLineType.action);
          expect(blanksBeforeAt(decoded.document, index) >= 0, isTrue);
        }
      }
    });

    test('no pass produces a request for an inert line', () {
      final decoded = OcptWysiwygCodec.decode(_commentedSource);
      final inert = OcptWysiwygCodec.inertNodeIds(decoded.document);

      // Lowercase everything commented, as a pass that ignored the comments would find it.
      for (var index = 0; index < decoded.document.nodeCount; index++) {
        final node = decoded.document.getNodeAt(index)! as ParagraphNode;
        if (inert.contains(node.id)) {
          replaceText(decoded.document, index, node.text.toPlainText().toLowerCase());
        }
      }
      final requests = [
        ...OcptWysiwygCodec.reclassifyRequests(decoded.document),
        ...OcptWysiwygCodec.uppercaseRequests(decoded.document),
        ...OcptWysiwygCodec.sceneNumberRequests(decoded.document),
      ];

      expect(requests, isEmpty);
    });

    test('the live lines around a comment have the types the parser reads', () {
      final decoded = OcptWysiwygCodec.decode(_commentedSource);
      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);

      final parserTypes = _parserTypes(_commentedSource);
      final inert = OcptWysiwygCodec.inertNodeIds(decoded.document);
      var checked = 0;
      for (var index = 0; index < decoded.document.nodeCount; index++) {
        final node = decoded.document.getNodeAt(index)! as ParagraphNode;
        if (inert.contains(node.id)) {
          continue;
        }
        expect(typeAt(decoded.document, index), parserTypes[node.text.toPlainText()]);
        checked++;
      }
      expect(checked, 4);
    });

    test('a live line with a trailing comment opener keeps its type', () {
      const source = 'INT. HOUSE - DAY /* later\nstill commented */\n\nHe waits.';
      final decoded = OcptWysiwygCodec.decode(source);

      expect(typeAt(decoded.document, 0), FountainLineType.sceneHeading);
      expect(OcptWysiwygCodec.inertNodeIds(decoded.document), {decoded.document.getNodeAt(1)!.id});
      expect(OcptWysiwygCodec.encode(decoded.document).text, source);
    });

    test('a live line with a leading comment closer keeps its type', () {
      const source = '/* start\n*/ INT. HOUSE - DAY\n\nHe waits.';
      final decoded = OcptWysiwygCodec.decode(source);

      expect(typeAt(decoded.document, 1), FountainLineType.sceneHeading);
      expect(OcptWysiwygCodec.inertNodeIds(decoded.document), {decoded.document.getNodeAt(0)!.id});
      expect(OcptWysiwygCodec.encode(decoded.document).text, source);
    });

    test('typing a boneyard opener comments the lines below out', () {
      final decoded = OcptWysiwygCodec.decode('He waits.\n\nINT. HOUSE - DAY\n\n*/');
      expect(OcptWysiwygCodec.inertNodeIds(decoded.document), isEmpty);

      replaceText(decoded.document, 0, '/* He waits.');
      final inert = OcptWysiwygCodec.inertNodeIds(decoded.document);

      expect(inert, hasLength(3));
      expect(OcptWysiwygCodec.reclassifyRequests(decoded.document), isEmpty);
      expect(
        OcptWysiwygCodec.encode(decoded.document).text,
        '/* He waits.\n\nINT. HOUSE - DAY\n\n*/',
      );
    });
  });

  group('dimming', () {
    /// The (start, exclusive end) ranges of the comment attribution of the node at [index].
    List<(int, int)> rangesAt(Document document, int index) =>
        (document.getNodeAt(index)! as ParagraphNode).text
            .getAttributionSpans({ocptFountainCommentAttribution})
            .map((span) => (span.start, span.end + 1))
            .toList();

    test('a boneyard and a multi-line note are dimmed on every node they cover', () {
      final decoded = OcptWysiwygCodec.decode(
        'He waits /* aside\nINT. GONE - DAY\nend */ now.\n\n[[ a note\nover two ]]',
      );
      final editor = _editorFor(decoded.document);

      editor.execute(OcptWysiwygCodec.commentAttributionRequests(decoded.document));

      expect(rangesAt(decoded.document, 0), [(9, 17)]);
      expect(rangesAt(decoded.document, 1), [(0, 15)]);
      expect(rangesAt(decoded.document, 2), [(0, 6)]);
      // The note is one node, held as a placeholder the dimming covers whole.
      expect(decoded.document.nodeCount, 4);
      expect(rangesAt(decoded.document, 3), [(0, 1)]);
      expect(OcptWysiwygCodec.commentAttributionRequests(decoded.document), isEmpty);
    });

    test('removing the closing marker takes the dimming off', () {
      final decoded = OcptWysiwygCodec.decode('/* a\nb\n*/\n\nc');
      final editor = _editorFor(decoded.document);
      editor.execute(OcptWysiwygCodec.commentAttributionRequests(decoded.document));
      expect(rangesAt(decoded.document, 1), [(0, 1)]);

      replaceText(decoded.document, 2, 'x');
      editor.execute(OcptWysiwygCodec.commentAttributionRequests(decoded.document));

      for (var index = 0; index < 4; index++) {
        expect(rangesAt(decoded.document, index), isEmpty);
      }
    });
  });

  group('uppercasing and notes', () {
    test('the text of a note in a heading is left as written', () {
      final decoded = OcptWysiwygCodec.decode('int. house - day [[later]]');

      final requests = OcptWysiwygCodec.uppercaseRequests(decoded.document);

      expect(requests, hasLength(1));
      final text = (requests.single as OcptReplaceNodeTextRequest).text;
      expect(text.toPlainText(), 'INT. HOUSE - DAY \uFFFC');
      expect((text.placeholders[17]! as OcptFountainNote).text, 'later');
    });

    test('the text of a note kept as text is left as written too', () {
      final decoded = OcptWysiwygCodec.decode('int. house - day [[later /* x]]');

      final requests = OcptWysiwygCodec.uppercaseRequests(decoded.document);

      expect(
        (requests.single as OcptReplaceNodeTextRequest).text.toPlainText(),
        'INT. HOUSE - DAY [[later /* x]]',
      );
    });

    test('a note before the heading text is left as written too', () {
      final decoded = OcptWysiwygCodec.decode('[[later]]int. house - day');

      expect(typeAt(decoded.document, 0), FountainLineType.sceneHeading);
      final request =
          OcptWysiwygCodec.uppercaseRequests(decoded.document).single as OcptReplaceNodeTextRequest;
      expect(request.text.toPlainText(), '\uFFFCINT. HOUSE - DAY');
      expect((request.text.placeholders[0]! as OcptFountainNote).text, 'later');
    });

    test('the comment of a live line is not uppercased', () {
      final decoded = OcptWysiwygCodec.decode('int. house - day /* later\nstill commented */');

      final request =
          OcptWysiwygCodec.uppercaseRequests(decoded.document).single as OcptReplaceNodeTextRequest;

      expect(request.text.toPlainText(), 'INT. HOUSE - DAY /* later');
    });

    test('a note around a transition or a cue keeps the type of its line', () {
      final decoded = OcptWysiwygCodec.decode('He leaves.\n\nCUT TO:[[x]]\n\nSARAH[[y]]\nHi.');

      expect(typeAt(decoded.document, 1), FountainLineType.transition);
      expect(typeAt(decoded.document, 2), FountainLineType.character);
      expect(
        OcptWysiwygCodec.encode(decoded.document).text,
        'He leaves.\n\nCUT TO:[[x]]\n\nSARAH[[y]]\nHi.',
      );
    });
  });
}
