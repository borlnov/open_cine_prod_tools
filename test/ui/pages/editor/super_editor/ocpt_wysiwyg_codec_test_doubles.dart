// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// Reads the classified [FountainLineType] the node at [index] of [document] currently carries.
FountainLineType typeAt(Document document, int index) =>
    OcptFountainLineAttributions.typeOfAttributionValue(
      document.getNodeAt(index)!.getMetadataValue("blockType"),
    );

/// Reads the node at [index] of [document]'s `ocptBlankLinesBefore` metadata (0 if absent).
int blanksBeforeAt(Document document, int index) {
  final value = document.getNodeAt(index)!.getMetadataValue(ocptBlankLinesBeforeMetadataKey);
  return value is int ? value : 0;
}

/// Replaces the text of the node at [index] of [document] with [newText], keeping its id and every
/// other metadata entry, the same way a real edit would change a node's text before the next
/// reclassification/note-attribution pass.
void replaceText(MutableDocument document, int index, String newText) {
  final node = document.getNodeAt(index)! as ParagraphNode;
  document.replaceNodeById(node.id, node.copyParagraphWith(text: AttributedText(newText)));
}
