// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

import 'ocpt_wysiwyg_codec_test_doubles.dart';

/// Decode then encode [source].
String _roundTrip(String source) {
  final decoded = OcptWysiwygCodec.decode(source);
  return OcptWysiwygCodec.encode(
    decoded.document,
    trailingBlankLines: decoded.trailingBlankLines,
  ).text;
}

/// Run the tests of the dual-dialogue metadata of the wysiwyg codec.
void main() {
  const pair = "ROSS\nHello.\n\nKIM^\nHi.\n";

  group("the dual-dialogue suffix", () {
    test("leaves the display text for metadata and keeps its spelling", () {
      for (final suffix in ["^", " ^"]) {
        final document = OcptWysiwygCodec.decode("ROSS\nHello.\n\nKIM$suffix\nHi.\n").document;
        final cue = document.getNodeAt(2)! as ParagraphNode;

        expect(cue.text.toPlainText(), "KIM");
        expect(OcptWysiwygDualDialogue.suffixOf(cue), suffix);
        expect(OcptWysiwygDualDialogue.suffixOf(document.getNodeAt(0)! as ParagraphNode), isNull);
      }
    });

    test("round-trips byte for byte, with and without a space", () {
      expect(_roundTrip(pair), pair);
      expect(_roundTrip("ROSS\nHello.\n\nKIM ^\nHi.\n"), "ROSS\nHello.\n\nKIM ^\nHi.\n");
      expect(_roundTrip("A\nx\n\n@kim (V.O.) ^\ny\n"), "A\nx\n\n@kim (V.O.) ^\ny\n");
    });

    test("a freshly decoded document has nothing to absorb", () {
      expect(OcptWysiwygDualDialogue.requests(OcptWysiwygCodec.decode(pair).document), isEmpty);
    });

    test("a typed marker is absorbed, whatever its spelling", () {
      for (final typed in ["KIM^", "KIM ^"]) {
        final document = OcptWysiwygCodec.decode("ROSS\nHello.\n\nKIM\nHi.\n").document;
        replaceText(document, 2, typed);

        final requests = OcptWysiwygDualDialogue.requests(document);

        expect(requests, hasLength(2));
      }
    });

    test("a node that is no longer a cue gets it written back into its text", () {
      final document = OcptWysiwygCodec.decode(pair).document;
      final cue = document.getNodeAt(2)! as ParagraphNode;
      document.replaceNodeById(
        cue.id,
        cue.copyWithAddedMetadata({
          "blockType": OcptFountainLineAttributions.attributionOf(FountainLineType.action),
        }),
      );

      final requests = OcptWysiwygDualDialogue.requests(document);

      expect(requests, hasLength(2));
      final replacement = requests.whereType<OcptReplaceNodeTextRequest>().single;
      expect(replacement.text.toPlainText(), "KIM^");
    });
  });

  group("the pairing over nodes", () {
    test("pairs a group with the marked one after it, and not a chain's third", () {
      final document = OcptWysiwygCodec.decode("A\nx\n\nB^\ny\n\nC^\nz\n").document;

      final pairs = OcptWysiwygDualDialogue.pairsOf(document);

      expect(pairs, hasLength(1));
      expect(pairs.single.leftNodeIds, [document.getNodeAt(0)!.id, document.getNodeAt(1)!.id]);
      expect(pairs.single.rightNodeIds, [document.getNodeAt(2)!.id, document.getNodeAt(3)!.id]);
    });

    test("an orphan marker is no pair", () {
      expect(OcptWysiwygDualDialogue.pairsOf(OcptWysiwygCodec.decode("A^\nx\n").document), isEmpty);
    });

    test("the toggle reads pair, orphan and neighbours", () {
      final document = OcptWysiwygCodec.decode("A\nx\n\nB\ny\n").document;
      final first = document.getNodeAt(0)!.id;
      final second = document.getNodeAt(2)!.id;

      expect(OcptWysiwygDualDialogue.toggleAt(document, second)?.isChecked, isFalse);
      expect(OcptWysiwygDualDialogue.toggleAt(document, second)?.cueNodeId, second);
      expect(OcptWysiwygDualDialogue.toggleAt(document, first)?.cueNodeId, second);

      final paired = OcptWysiwygCodec.decode("A\nx\n\nB^\ny\n").document;
      expect(OcptWysiwygDualDialogue.toggleAt(paired, paired.getNodeAt(0)!.id)?.isChecked, isTrue);

      // An orphan marker reads as checked, so that it can still be taken off.
      final orphan = OcptWysiwygCodec.decode("A^\nx\n").document;
      final toggle = OcptWysiwygDualDialogue.toggleAt(orphan, orphan.getNodeAt(0)!.id);
      expect(toggle?.isChecked, isTrue);
      expect(toggle?.cueNodeId, orphan.getNodeAt(0)!.id);

      final alone = OcptWysiwygCodec.decode("A\nx\n").document;
      expect(OcptWysiwygDualDialogue.toggleAt(alone, alone.getNodeAt(0)!.id), isNull);
    });
  });

  group("copying a cue", () {
    /// Encode the selection from [startOffset] of the cue to [endOffset] of node [endIndex].
    String copy(int startOffset, int endIndex, int endOffset) {
      final document = OcptWysiwygCodec.decode(pair).document;
      final selection = DocumentSelection(
        base: DocumentPosition(
          nodeId: document.getNodeAt(2)!.id,
          nodePosition: TextNodePosition(offset: startOffset),
        ),
        extent: DocumentPosition(
          nodeId: document.getNodeAt(endIndex)!.id,
          nodePosition: TextNodePosition(offset: endOffset),
        ),
      );
      return OcptWysiwygCodec.encodeSelectionToFountain(document, selection);
    }

    test("leaves the hidden suffix behind when the end of the cue is not copied", () {
      expect(copy(0, 2, 2), "@KI");
    });

    test("takes the suffix along when the whole cue is copied", () {
      expect(copy(0, 2, 3), "@KIM^");
    });

    test("takes the suffix along when the copy goes on past the cue", () {
      expect(copy(1, 3, 2), "IM^\nHi");
    });
  });
}
