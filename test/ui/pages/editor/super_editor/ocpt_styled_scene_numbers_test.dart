// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_scene_numbers.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_edit_requests.dart';
import 'package:super_editor/super_editor.dart';

/// Applies [requests] (as computed by `sceneNumberNormalizationRequests`, only ever
/// `OcptChangeNodeMetadataRequest`s) directly onto [document], mirroring what a live `Editor`
/// would do, without needing to spin one up for a pure-function test.
void _apply(MutableDocument document, List<EditRequest> requests) {
  for (final request in requests) {
    final metadataRequest = request as OcptChangeNodeMetadataRequest;
    final node = document.getNodeById(metadataRequest.nodeId)! as ParagraphNode;
    document.replaceNodeById(node.id, node.copyWithAddedMetadata(metadataRequest.metadata));
  }
}

/// The `ocptSceneNumber` metadata of the node at [index] of [document], or null if absent.
String? _sceneNumberAt(Document document, int index) {
  final value = document.getNodeAt(index)!.getMetadataValue(ocptSceneNumberMetadataKey);
  return value is String ? value : null;
}

void main() {
  group("sceneNumberNormalizationRequests", () {
    test("numbers every unnumbered heading sequentially, starting at 1", () {
      final decoded = OcptWysiwygCodec.decode(
        "INT. HOUSE - DAY\n\nAction.\n\nEXT. GARDEN - NIGHT\n\nINT. HOUSE - DAY",
      );
      final document = decoded.document;

      _apply(document, sceneNumberNormalizationRequests(document));

      expect(_sceneNumberAt(document, 0), "1");
      expect(_sceneNumberAt(document, 2), "2");
      expect(_sceneNumberAt(document, 3), "3");
    });

    test("keeps an explicit number that already matches the sequential position", () {
      final decoded = OcptWysiwygCodec.decode(
        "INT. HOUSE - DAY #1#\n\nEXT. GARDEN - NIGHT #2#\n\nINT. ATTIC - DAY #3#",
      );
      final document = decoded.document;

      expect(sceneNumberNormalizationRequests(document), isEmpty);
    });

    test("keeps a lettered insertion between two sequential scenes without consuming a number", () {
      final decoded = OcptWysiwygCodec.decode(
        "INT. HOUSE - DAY #1#\n\nINT. ATTIC - DAY #1A#\n\nEXT. GARDEN - NIGHT #2#",
      );
      final document = decoded.document;

      expect(sceneNumberNormalizationRequests(document), isEmpty);
    });

    test("corrects an out-of-order explicit number typed in raw mode", () {
      final decoded = OcptWysiwygCodec.decode(
        "INT. HOUSE - DAY #1#\n\nEXT. GARDEN - NIGHT #7#\n\nINT. ATTIC - DAY #2#",
      );
      final document = decoded.document;

      _apply(document, sceneNumberNormalizationRequests(document));

      expect(_sceneNumberAt(document, 0), "1");
      expect(_sceneNumberAt(document, 1), "2");
      expect(_sceneNumberAt(document, 2), "3");
    });

    test("corrects a lettered number that does not follow the scene right before it", () {
      // "3A" only makes sense right after scene 3; here it comes first, so it must be corrected
      // to a plain sequential number instead.
      final decoded = OcptWysiwygCodec.decode(
        "INT. HOUSE - DAY #3A#\n\nEXT. GARDEN - NIGHT",
      );
      final document = decoded.document;

      _apply(document, sceneNumberNormalizationRequests(document));

      expect(_sceneNumberAt(document, 0), "1");
      expect(_sceneNumberAt(document, 1), "2");
    });

    test("a document with no scene headings produces no requests", () {
      final decoded = OcptWysiwygCodec.decode("Just some action, no scenes at all.");

      expect(sceneNumberNormalizationRequests(decoded.document), isEmpty);
    });

    test("is idempotent: running it again on an already-normalized document changes nothing", () {
      final decoded = OcptWysiwygCodec.decode(
        "INT. HOUSE - DAY #9#\n\nEXT. GARDEN - NIGHT #2#",
      );
      final document = decoded.document;

      _apply(document, sceneNumberNormalizationRequests(document));
      expect(sceneNumberNormalizationRequests(document), isEmpty);
    });
  });
}
