// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
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

/// Run the tests of the section levels and the forced cue case of the wysiwyg codec.
void main() {
  group("section levels", () {
    test("every level round-trips byte for byte", () {
      for (var level = 1; level <= 6; level++) {
        final source = "${"#" * level} Part $level\n\nSome action.\n";
        expect(_roundTrip(source), source);
      }
    });

    test("a section line survives an edit elsewhere in the document", () {
      const source = "## Sequence A\n\n### Beat\n\nSome action.\n";
      final decoded = OcptWysiwygCodec.decode(source);
      replaceText(decoded.document, 2, "Other action.");

      final encoded = OcptWysiwygCodec.encode(
        decoded.document,
        trailingBlankLines: decoded.trailingBlankLines,
      );

      expect(encoded.text, "## Sequence A\n\n### Beat\n\nOther action.\n");
    });

    test("a section without a level in its metadata is written at level 1", () {
      final decoded = OcptWysiwygCodec.decode("## Sequence A\n");
      final node = decoded.document.getNodeAt(0)! as ParagraphNode;
      decoded.document.replaceNodeById(
        node.id,
        ParagraphNode(
          id: node.id,
          text: node.text,
          metadata: {...node.metadata}..remove(ocptSectionLevelMetadataKey),
        ),
      );

      expect(OcptWysiwygCodec.encode(decoded.document).text, startsWith("# Sequence A"));
    });
  });

  group("forced cue case", () {
    test("a cue forced with @ keeps its mixed case through the uppercasing pass", () {
      final decoded = OcptWysiwygCodec.decode("@McCLANE\nYippee.\n");

      expect(OcptWysiwygCodec.uppercaseRequests(decoded.document), isEmpty);
      expect(_roundTrip("@McCLANE\nYippee.\n"), "@McCLANE\nYippee.\n");
    });

    test("a cue that is not forced is still uppercased", () {
      final decoded = OcptWysiwygCodec.decode("HANS\nHello.\n");
      replaceText(decoded.document, 0, "hans (on the radio)");

      final requests = OcptWysiwygCodec.uppercaseRequests(decoded.document)
          .cast<OcptReplaceNodeTextRequest>();

      expect(requests.single.text.toPlainText(), "HANS (ON THE RADIO)");
    });
  });
}
