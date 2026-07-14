// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:super_editor/super_editor.dart';

/// The `ParagraphNode` metadata key holding whether the pagination pass decided a node starts a
/// fresh simulated page, read by `OcptFountainEditorStylesheet` to open up extra top padding
/// standing in for the page gap and the previous/next page's margins.
const String ocptStartsNewPageMetadataKey = "ocptStartsNewPage";

/// The result of [computeOcptStyledPagination]: which nodes of a styled editor document start a
/// fresh simulated page, and how many pages the document currently spans.
class OcptStyledPagination {
  /// Creates an [OcptStyledPagination].
  const OcptStyledPagination({required this.pageStartNodeIds, required this.pageCount});

  /// The ids of every `ParagraphNode` that starts a page other than the very first one (the
  /// document's first node never carries the flag: there is no page boundary to show above it).
  final Set<String> pageStartNodeIds;

  /// The total number of simulated pages the document currently spans (0 for a document with no
  /// `ParagraphNode`, at least 1 otherwise).
  final int pageCount;
}

/// Buckets every `ParagraphNode` of [document] into simulated pages, the same line-estimation
/// approach `OcptEditorPreviewLayout`'s own pagination uses for the raw preview: a running sum of
/// [OcptEditorPreviewLayout.wrappedLineCount] (plus each node's `ocptBlankLinesBefore` metadata,
/// capped like [ocptMaxBlankLinesBeforeSpacing]) is compared against [metrics]'
/// `linesPerPage`, starting a fresh page once it would be exceeded.
///
/// A node classified [FountainLineType.pageBreak] always starts a fresh page itself (rather than
/// being folded into the page it would otherwise fit on): unlike the raw preview, which hides a
/// page break from its printed content and lets the block *after* it open the new page, the
/// styled editor keeps one `ParagraphNode` per source line with no exceptions, so the break line
/// itself is what visually leads the new page.
///
/// Pure Dart, independent of any live `SuperEditor` widget, so it can be unit-tested directly
/// against a `MutableDocument` built by `OcptWysiwygCodec.decode`.
OcptStyledPagination computeOcptStyledPagination({
  required Document document,
  required FountainLayoutMetrics metrics,
}) {
  final pageStartNodeIds = <String>{};
  var pageCount = 0;
  var currentLines = 0;

  for (final node in document) {
    if (node is! ParagraphNode) {
      continue;
    }

    final type = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
    final lines = _lineCountOf(node, type, metrics);

    if (pageCount == 0) {
      pageCount = 1;
    } else if (type == FountainLineType.pageBreak || currentLines + lines > metrics.linesPerPage) {
      pageCount++;
      pageStartNodeIds.add(node.id);
      currentLines = 0;
    }

    currentLines += lines;
  }

  return OcptStyledPagination(pageStartNodeIds: pageStartNodeIds, pageCount: pageCount);
}

/// The number of rendered lines [node] (classified as [type]) is estimated to span: its own
/// wrapped line count at [type]'s element width, plus its `ocptBlankLinesBefore` metadata.
int _lineCountOf(ParagraphNode node, FountainLineType type, FountainLayoutMetrics metrics) {
  final element = _elementLayoutOf(type, metrics);
  final wrappedLines = OcptEditorPreviewLayout.wrappedLineCount(node.text.toPlainText(), element.maxWidthColumns);
  return wrappedLines + _blankLinesBeforeOf(node);
}

/// The layout box [type] is set in, mirroring `OcptFountainEditorStylesheet`'s own element choice
/// per type (in particular lyrics sharing the dialogue box, and every non-printing/scaffolding
/// type using the full-width action box).
FountainElementLayout _elementLayoutOf(FountainLineType type, FountainLayoutMetrics metrics) => switch (type) {
  FountainLineType.sceneHeading => metrics.sceneHeading,
  FountainLineType.character => metrics.character,
  FountainLineType.parenthetical => metrics.parenthetical,
  FountainLineType.dialogue => metrics.dialogue,
  FountainLineType.lyrics => metrics.dialogue,
  FountainLineType.transition => metrics.transition,
  FountainLineType.centeredText => metrics.centeredText,
  FountainLineType.pageBreak => metrics.centeredText,
  FountainLineType.section ||
  FountainLineType.synopsis ||
  FountainLineType.action ||
  FountainLineType.blank => metrics.action,
};

/// Reads [node]'s `ocptBlankLinesBefore` metadata, capped at [ocptMaxBlankLinesBeforeSpacing] to
/// match the extra spacing `OcptFountainEditorStylesheet` actually renders for it.
int _blankLinesBeforeOf(ParagraphNode node) {
  final value = node.getMetadataValue(ocptBlankLinesBeforeMetadataKey);
  final count = value is int ? value : 0;
  return count.clamp(0, ocptMaxBlankLinesBeforeSpacing);
}
