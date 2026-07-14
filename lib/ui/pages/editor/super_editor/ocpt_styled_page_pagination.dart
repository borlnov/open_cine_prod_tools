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
/// fresh simulated page (and by how much exact top padding), how many pages the document
/// currently spans, and how much trailing bottom padding fills the last page out to its full
/// height.
class OcptStyledPagination {
  /// Creates an [OcptStyledPagination].
  const OcptStyledPagination({
    required this.pageStartNodeIds,
    required this.pageStartTopPaddings,
    required this.pageCount,
    required this.trailingBottomPadding,
  });

  /// The ids of every `ParagraphNode` that starts a page other than the very first one (the
  /// document's first node never carries the flag: there is no page boundary to show above it).
  ///
  /// Always exactly [pageStartTopPaddings]' keys; kept as its own field so callers that only care
  /// about membership (not the exact padding) don't need to go through the map.
  final Set<String> pageStartNodeIds;

  /// For every id in [pageStartNodeIds], the exact top padding (in logical pixels) that node needs
  /// so its text starts precisely at its simulated page's text origin
  /// (`pageIndex * (pageHeight + OcptEditorPreviewLayout.pageGap) + marginTop`), computed by
  /// tracking the estimated Y position content would reach through natural flow alone (the same
  /// per-node line-count estimate [pageStartNodeIds] itself is decided from) and padding by
  /// whatever shortfall remains — rather than a fixed `marginTop + marginBottom + pageGap`
  /// estimate, which only happens to be exact when every earlier page's content exactly fills
  /// [FountainLayoutMetrics.linesPerPage].
  final Map<String, double> pageStartTopPaddings;

  /// The total number of simulated pages the document currently spans (0 for a document with no
  /// `ParagraphNode`, at least 1 otherwise).
  final int pageCount;

  /// The extra padding (in logical pixels) to reserve below the document's last node so its
  /// scrollable content genuinely reaches the bottom edge of the last simulated sheet
  /// (`(pageCount - 1) * (pageHeight + OcptEditorPreviewLayout.pageGap) + pageHeight`), the same
  /// way [pageStartTopPaddings] pads *between* pages: without it, the document's scrollable
  /// content simply ends wherever the last line of text happens to fall, leaving no space to
  /// scroll into so the last sheet's own bottom margin is never shown, only cropped short.
  final double trailingBottomPadding;
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
/// Alongside which nodes start a page, this also tracks an estimated running Y position (in
/// logical pixels, using the exact same [OcptEditorPreviewLayout.lineHeight] the stylesheet
/// renders at) through the document's natural flow, so [OcptStyledPagination.pageStartTopPaddings]
/// and [OcptStyledPagination.trailingBottomPadding] can close the gap between where content
/// happens to land and where each page boundary actually is — see their own doc comments.
///
/// Pure Dart, independent of any live `SuperEditor` widget, so it can be unit-tested directly
/// against a `MutableDocument` built by `OcptWysiwygCodec.decode`.
OcptStyledPagination computeOcptStyledPagination({
  required Document document,
  required FountainLayoutMetrics metrics,
}) {
  final layout = OcptEditorPreviewLayout(metrics: metrics);
  final sheetExtent = layout.pageHeight + OcptEditorPreviewLayout.pageGap;

  final pageStartNodeIds = <String>{};
  final pageStartTopPaddings = <String, double>{};
  var pageCount = 0;
  var pageIndex = 0;
  var currentLines = 0;
  // The document's own top padding, while page simulation is on, is the first page's true top
  // margin (see `OcptFountainEditorStylesheet.build`), so the flow's starting Y already sits
  // there before the first node's own text.
  var currentY = layout.marginTop;

  for (final node in document) {
    if (node is! ParagraphNode) {
      continue;
    }

    final type = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
    final wrappedLines = _wrappedLineCountOf(node, type, metrics);
    final blankLinesBefore = _blankLinesBeforeOf(node);
    final lines = wrappedLines + blankLinesBefore;

    if (pageCount == 0) {
      pageCount = 1;
    } else if (type == FountainLineType.pageBreak || currentLines + lines > metrics.linesPerPage) {
      pageCount++;
      pageIndex++;
      currentLines = 0;

      // The stylesheet separately opens up `blankLinesBefore * lineHeight` of top padding for
      // this same node (see `OcptFountainEditorStylesheet._blankLinesBeforeTopPadding`), stacked
      // on top of this page-boundary padding: subtracting it here (rather than padding from
      // `currentY` as if this node had no blank lines before it) is what keeps the two paddings'
      // combined total landing the node's text exactly at `desiredY`, instead of one extra
      // `lineHeight` too low.
      final desiredY = pageIndex * sheetExtent + layout.marginTop;
      final blankLinesPadding = blankLinesBefore * layout.lineHeight;
      final padding = (desiredY - currentY - blankLinesPadding).clamp(0.0, double.infinity);
      pageStartNodeIds.add(node.id);
      pageStartTopPaddings[node.id] = padding;
      currentY += padding;
    }

    currentLines += lines;
    currentY += lines * layout.lineHeight;
  }

  final desiredBottomY = pageCount == 0 ? 0.0 : (pageCount - 1) * sheetExtent + layout.pageHeight;
  final trailingBottomPadding = pageCount == 0 ? 0.0 : (desiredBottomY - currentY).clamp(0.0, double.infinity);

  return OcptStyledPagination(
    pageStartNodeIds: pageStartNodeIds,
    pageStartTopPaddings: pageStartTopPaddings,
    pageCount: pageCount,
    trailingBottomPadding: trailingBottomPadding,
  );
}

/// The number of lines [node] (classified as [type]) is estimated to wrap its own text to, not
/// counting its `ocptBlankLinesBefore` metadata (see [_blankLinesBeforeOf] for that half).
int _wrappedLineCountOf(ParagraphNode node, FountainLineType type, FountainLayoutMetrics metrics) {
  final element = _elementLayoutOf(type, metrics);
  return OcptEditorPreviewLayout.wrappedLineCount(node.text.toPlainText(), element.maxWidthColumns);
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
