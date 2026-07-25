// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_scene_numbers.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';

void main() {
  group("computeOcptStyledSceneNumbers", () {
    test("numbers every unnumbered heading sequentially, starting at 1", () {
      final decoded = OcptWysiwygCodec.decode(
        "INT. HOUSE - DAY\n\nAction.\n\nEXT. GARDEN - NIGHT\n\nINT. HOUSE - DAY",
      );
      final document = decoded.document;

      final numbers = computeOcptStyledSceneNumbers(document);

      expect(numbers[document.getNodeAt(0)!.id], "1");
      expect(numbers[document.getNodeAt(2)!.id], "2");
      expect(numbers[document.getNodeAt(3)!.id], "3");
      expect(numbers, hasLength(3));
    });

    test("an explicit #N# tag keeps its own number and does not consume a computed one", () {
      final decoded = OcptWysiwygCodec.decode(
        "INT. HOUSE - DAY #5#\n\nEXT. GARDEN - NIGHT\n\nINT. ATTIC - DAY #6#\n\nINT. CELLAR - DAY",
      );
      final document = decoded.document;

      final numbers = computeOcptStyledSceneNumbers(document);

      expect(numbers[document.getNodeAt(0)!.id], "5");
      expect(numbers[document.getNodeAt(1)!.id], "1");
      expect(numbers[document.getNodeAt(2)!.id], "6");
      expect(numbers[document.getNodeAt(3)!.id], "2");
    });

    test("a document with no scene headings produces no numbers", () {
      final decoded = OcptWysiwygCodec.decode("Just some action, no scenes at all.");

      expect(computeOcptStyledSceneNumbers(decoded.document), isEmpty);
    });
  });
}
