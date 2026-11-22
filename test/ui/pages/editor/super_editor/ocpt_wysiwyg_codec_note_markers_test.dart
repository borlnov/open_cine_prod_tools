// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_document_settle.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_scene_numbers.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comments.dart';
import 'package:super_editor/super_editor.dart';

/// Decode [source], encode it back and get the text written.
String _roundTrip(String source) {
  final decoded = OcptWysiwygCodec.decode(source);
  return OcptWysiwygCodec.encode(
    decoded.document,
    trailingBlankLines: decoded.trailingBlankLines,
  ).text;
}

/// Build a live [Editor] over [document], with the handlers the settle pass executes through.
Editor _editorFor(MutableDocument document) => Editor(
  editables: {Editor.documentKey: document, Editor.composerKey: MutableDocumentComposer()},
  requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
    ..add(ocptChangeNodeMetadataRequestHandler)
    ..add(ocptReplaceNodeTextRequestHandler),
);

/// Run the tests of the codec on the lines holding a note or a boneyard next to a marker.
void main() {
  group('a line with a comment around its marker is written back byte for byte', () {
    const lines = [
      '[[x]]# Act',
      '[[x]]===',
      '===[[x]]',
      '/* x */===',
      '[[x]]= syn',
      '= syn[[x]]',
      '[[x]]~la la',
      '~la la[[x]]',
      '[[x]]> THE END <',
      '> THE END <[[x]]',
      '/* x */> THE END <',
      '/* x */# Act',
      '/* x */= syn',
      '/* x */~la la',
      '[[x]]!int. house',
      '[[x]].The void',
      '[[x]]>Burn to white.',
      '[[x]]@McCLANE',
      '[[x]]INT. HOUSE - DAY',
      'INT. HOUSE - DAY #4# [[x]]',
      '> THE [[x]] END <',
      '====',
      '  = syn',
      'He **runs [[n]] fast**.',
      'He *runs [[n]] fast*.',
      'He _runs /* x */ fast_.',
      'He *x /* y* */ z.',
      'He /* x */ runs.',
      '/* *a* */',
      'a /* b */ c *d*',
      'He said *yes*/no.',
      'his/*her* car',
      '*and*/or',
      '**A**/**B**',
      '**bold**/',
      '**bold /* x',
      'y */ z**',
      r'He \[[x]] y.',
      r'He \[[x]] **b**.',
      'a \uE000 b \uE001 c \uE002 d \uE003 e \uE004',
    ];

    for (final line in lines) {
      test(line, () {
        for (final source in [line, 'He waits.\n\n$line\n\nShe leaves.', 'A.\n$line']) {
          expect(_roundTrip(source), source, reason: source);
        }
      });
    }
  });

  group('a multi-line note or boneyard opening or closing mid-line', () {
    const sources = [
      'He waits [[ a\nmiddle\n]]\nSARAH\nHi.',
      'He.\n\nINT. HOUSE - DAY\n[[ x\ny ]] z',
      'He.\n\nSARAH\nHi. /* a\nmiddle\n*/ Still.\n\nCUT TO:',
      'He.\n\nSARAH\n(softly) [[ a\nINT. HOUSE - DAY\nb ]]\nHi.',
    ];

    for (final source in sources) {
      test(source.replaceAll('\n', r'\n'), () {
        expect(_roundTrip(source), source);
      });
    }
  });

  group('a decoded document is already settled', () {
    /// Every derived pass of the live editor, run on [document]: none may have anything to do.
    void expectSettled(Document document, String reason, {bool isUppercaseChecked = true}) {
      expect(OcptWysiwygCodec.sceneNumberRequests(document), isEmpty, reason: reason);
      expect(OcptWysiwygCodec.reclassifyRequests(document), isEmpty, reason: reason);
      expect(OcptWysiwygCodec.noteAttributionRequests(document), isEmpty, reason: reason);
      expect(OcptWysiwygCodec.commentAttributionRequests(document), isEmpty, reason: reason);
      if (isUppercaseChecked) {
        expect(OcptWysiwygCodec.uppercaseRequests(document), isEmpty, reason: reason);
      }
      // The numbering a heading without a `#N#` tag is given when the editor opens it is the one
      // pass that has work on a decoded document, and it is not a history step (see
      // `sceneNumberNormalizationRequests`).
      expect(
        sceneNumberNormalizationRequests(
          document,
          isHistorical: false,
        ).every((request) => request is OcptChangeNodeMetadataRequest && !request.isHistorical),
        isTrue,
        reason: reason,
      );
    }

    final corpusFiles = Directory('packages/fountain_kit/test/corpus')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.fountain'))
        .toList(growable: false);

    for (final file in corpusFiles) {
      test(file.uri.pathSegments.last, () {
        expectSettled(
          OcptWysiwygCodec.decode(file.readAsStringSync()).document,
          file.uri.pathSegments.last,
          // A forced cue written in mixed case (`@McCLANE`) is capitalised by the first edit.
          isUppercaseChecked: false,
        );
      });
    }

    const sources = [
      'He waits. [[a note]]\n\n/*\nINT. GONE - DAY\n*/\n\nShe leaves.',
      'He waits [[ a\nmiddle\n]]\nSARAH\nHi.',
      '[[x]]# Act\n\n[[x]]===\n\n/* x */= syn\n\n[[x]]~la la\n\n/* x */> THE END <',
      'INT. HOUSE - DAY #1# [[x]]\n\n/* a **b** _c_ */\n\nHe **runs** /* x\n*/ now.',
      '[[a]][[b]] twice\n\n/* a */[[b]] and\n\n[[ one\ntwo ]]',
      'SARAH[[y]]\n(softly) [[z]]\nHi.',
    ];
    for (final source in sources) {
      test(source.replaceAll('\n', r'\n'), () {
        expectSettled(OcptWysiwygCodec.decode(source).document, source);
      });
    }
  });

  group('emphasis across a comment', () {
    /// Run the settle pass of the live editor on [document].
    void settle(MutableDocument document) =>
        OcptStyledDocumentSettle.settle(document, _editorFor(document));

    test('a line commented out keeps its emphasis when written back', () {
      // The emphasis attributions of a node that becomes inert are written back as source.
      final source = OcptWysiwygCodec.decode('A.\n\nHe **runs** _away_.\n\nB.');
      final mutable = source.document;
      final opener = mutable.getNodeAt(0)! as ParagraphNode;
      mutable.replaceNodeById(opener.id, opener.copyParagraphWith(text: AttributedText('A. /*')));
      final closer = mutable.getNodeAt(2)! as ParagraphNode;
      mutable.replaceNodeById(closer.id, closer.copyParagraphWith(text: AttributedText('*/ B.')));

      settle(mutable);

      expect(
        OcptWysiwygCodec.encode(mutable, trailingBlankLines: source.trailingBlankLines).text,
        'A. /*\n\nHe **runs** _away_.\n\n*/ B.',
      );
    });

    test('an inert line holds its emphasis as styled text, live or not', () {
      final decoded = OcptWysiwygCodec.decode('/*\nHe **runs** _away_.\n*/');
      final document = decoded.document;
      final opener = document.getNodeAt(0)! as ParagraphNode;
      document.replaceNodeById(opener.id, opener.copyParagraphWith(text: AttributedText('')));

      settle(document);

      final node = document.getNodeAt(1)! as ParagraphNode;
      expect(node.text.toPlainText(), 'He runs away.');
      expect(
        node.text.getAttributionSpans({boldAttribution}).map((span) => (span.start, span.end)),
        [(3, 6)],
      );
      expect(
        OcptWysiwygCodec.encode(document, trailingBlankLines: decoded.trailingBlankLines).text,
        '\nHe **runs** _away_.\n*/',
      );
    });

    test('a boneyard on a live line is no emphasis, and is dimmed', () {
      final decoded = OcptWysiwygCodec.decode('a /* b */ c *d*');
      final text = (decoded.document.getNodeAt(0)! as ParagraphNode).text;

      expect(text.toPlainText(), 'a /* b */ c d');
      expect(text.getAttributionSpans({italicsAttribution}).map((span) => (span.start, span.end)), [
        (12, 12),
      ]);
      expect(
        text
            .getAttributionSpans({ocptFountainCommentAttribution})
            .map((span) => (span.start, span.end)),
        [(2, 8)],
      );
    });

    test('a line with emphasis commented out is dimmed whole and keeps its emphasis', () {
      final source = OcptWysiwygCodec.decode('A.\n\nHe **runs** _away_.\n\nB.');
      final document = source.document;
      final opener = document.getNodeAt(0)! as ParagraphNode;
      document.replaceNodeById(opener.id, opener.copyParagraphWith(text: AttributedText('/*')));
      final closer = document.getNodeAt(2)! as ParagraphNode;
      document.replaceNodeById(closer.id, closer.copyParagraphWith(text: AttributedText('*/')));

      settle(document);

      final node = document.getNodeAt(1)! as ParagraphNode;
      expect(
        node.text
            .getAttributionSpans({ocptFountainCommentAttribution})
            .map((span) => (span.start, span.end + 1)),
        [(0, node.text.length)],
      );
      expect(node.text.getAttributionSpans({boldAttribution}), isNotEmpty);
      const commented = '/*\n\nHe **runs** _away_.\n\n*/';
      expect(OcptWysiwygCodec.encode(document).text, commented);

      // And the other way round: the opener taken off, nothing is dimmed and nothing is lost.
      document.replaceNodeById(
        document.getNodeAt(0)!.id,
        (document.getNodeAt(0)! as ParagraphNode).copyParagraphWith(text: AttributedText('A.')),
      );
      settle(document);

      expect(
        (document.getNodeAt(1)! as ParagraphNode).text.getAttributionSpans({
          ocptFountainCommentAttribution,
        }),
        isEmpty,
      );
      expect(OcptWysiwygCodec.encode(document).text, 'A.\n\nHe **runs** _away_.\n\n*/');
    });

    test('bold across the edge of a note is written as valid Fountain', () {
      final decoded = OcptWysiwygCodec.decode('He runs [[note]] away.');
      final document = decoded.document;
      final node = document.getNodeAt(0)! as ParagraphNode;
      node.text.addAttribution(boldAttribution, const SpanRange(3, 10));

      settle(document);
      final written = OcptWysiwygCodec.encode(document).text;

      final reread = OcptWysiwygCodec.decode(written).document.getNodeAt(0)! as ParagraphNode;
      expect(reread.text.toPlainText(), 'He runs [[note]] away.');
      expect(
        reread.text.getAttributionSpans({boldAttribution}).map((span) => (span.start, span.end)),
        [(3, 7)],
      );
      expect(
        reread.text
            .getAttributionSpans({ocptFountainNoteAttribution})
            .map((span) => (span.start, span.end)),
        [(8, 15)],
      );
    });

    test('an escaped note is no note, and is not dimmed', () {
      final decoded = OcptWysiwygCodec.decode('He \\[[x]] y.\n\n/* \\[[z]] */');
      final first = decoded.document.getNodeAt(0)! as ParagraphNode;

      expect(first.text.toPlainText(), 'He [[x]] y.');
      expect(first.text.getAttributionSpans({ocptFountainNoteAttribution}), isEmpty);
      expect(first.text.getAttributionSpans({ocptFountainCommentAttribution}), isEmpty);
      expect(OcptWysiwygCodec.noteAttributionRequests(decoded.document), isEmpty);
      expect(OcptWysiwygCodec.commentAttributionRequests(decoded.document), isEmpty);
    });

    test('a settle lays the document out once when no pass changes its text', () {
      final document = OcptWysiwygCodec.decode(
        'INT. HOUSE - DAY\n\nHe **runs** /* x */ now.\n\n[[ a\nb ]]',
      ).document;
      final before = OcptWysiwygComments.layoutCount;

      settle(document);

      expect(OcptWysiwygComments.layoutCount - before, 1);
    });
  });
}
