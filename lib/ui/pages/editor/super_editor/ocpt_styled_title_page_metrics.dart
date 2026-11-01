// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_title_page_field_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:super_editor/super_editor.dart';

/// The result of [computeOcptStyledTitlePageMetrics]: the vertical flow height a document's
/// title-page field nodes occupy, and the Draft date/Contact row's own shift amount.
class OcptStyledTitlePageMetrics {
  /// The total vertical flow height, in logical pixels, the document's title-page field nodes
  /// occupy when rendered by `OcptFountainEditorStylesheet`'s title-page rule:
  /// `Σ (topGap(field) + wrappedLines(node) × lineHeight × fontScale)`, the top gap counted only
  /// once per field (on its first node), summed over every title-page node in document order. 0
  /// for a document with no title-page nodes.
  ///
  /// Unaffected by the title-page component builder's own Draft date/Contact transform: that
  /// transform only repaints where a node's content sits, it never changes the `Column`'s own
  /// per-node row height, so pagination keeps reading this exact sum (see the class-level doc
  /// comment of the component builder for why the transform is paint-only).
  final double flowHeight;

  /// The vertical distance the title-page component builder shifts the Contact and Source nodes
  /// up by, in logical pixels: the height Draft date's own node(s) occupy —
  /// `Σ wrappedLines × lineHeight` over the document's Draft date nodes only, normally one
  /// `lineHeight` but correctly larger for a wrapped or Enter-split Draft date. 0 for a document
  /// with no Draft date node.
  final double rowShift;

  /// Creates an [OcptStyledTitlePageMetrics].
  const OcptStyledTitlePageMetrics({required this.flowHeight, required this.rowShift});
}

/// Computes [document]'s title-page flow height at [metrics] — the real vertical space
/// `OcptFountainEditorStylesheet`'s title-page rule renders the sheet's title-page field nodes
/// into, used by `computeOcptStyledPagination` to know exactly how much of page 1 they actually
/// fill (rather than assuming they fill none of it, or all of it).
///
/// Pure Dart, independent of any live `SuperEditor` widget, mirroring
/// `computeOcptStyledPagination`'s own contract, so it can be unit-tested directly against a
/// `MutableDocument` built by `OcptWysiwygCodec.decodeWithTitlePage`.
OcptStyledTitlePageMetrics computeOcptStyledTitlePageMetrics({
  required Document document,
  required FountainLayoutMetrics metrics,
}) {
  final layout = OcptEditorPreviewLayout(metrics: metrics);

  var flowHeight = 0.0;
  var rowShift = 0.0;
  String? previousKey;

  for (final node in document) {
    if (node is! ParagraphNode || !OcptWysiwygCodec.isTitlePageNode(node)) {
      continue;
    }

    final key = node.getMetadataValue(ocptTitlePageKeyMetadataKey) as String;
    final fieldLayout = ocptTitlePageFieldLayoutOf(key, layout);

    if (key != previousKey) {
      flowHeight += fieldLayout.topGap;
      previousKey = key;
    }

    // The field's own usable width (its box minus the left/right padding split lands Draft date
    // and Contact half of the full content width — see [ocptTitlePageFieldLayoutOf]'s own doc
    // comment; every other field's `right` is 0, so this is the full content width for them).
    final fieldWidth = fieldLayout.maxWidth - fieldLayout.left - fieldLayout.right;
    final columnWidth = layout.glyphWidth * fieldLayout.fontScale;
    final maxColumns = (fieldWidth / columnWidth).floor();
    final wrappedLines = OcptEditorPreviewLayout.wrappedLineCount(
      node.text.toPlainText(),
      maxColumns,
    );
    final lineContribution = wrappedLines * layout.lineHeight * fieldLayout.fontScale;
    flowHeight += lineContribution;
    if (key == "Draft date") {
      rowShift += lineContribution;
    }
  }

  return OcptStyledTitlePageMetrics(flowHeight: flowHeight, rowShift: rowShift);
}
