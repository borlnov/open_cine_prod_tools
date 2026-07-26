// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:super_editor/super_editor.dart';

/// The font-size multiple the Title field renders at, relative to every other title-page field and
/// the body text: the Title field is the one title-page field whose glyphs are wider and taller
/// than [OcptEditorPreviewLayout.fontSize]'s own, so both its wrap width and its line height scale
/// with it wherever this module measures it.
const double ocptTitlePageTitleFontScale = 1.6;

/// The vertical gap opened above the Title field, as a fraction of the simulated page's own height,
/// landing it in the upper-middle area the PDF exporter also centers it in.
const double _titlePageTitleTopFraction = 0.32;

/// The vertical gap opened above the Draft date/Contact/Source group, as a fraction of the
/// simulated page's own height (see [ocptTitlePageFieldLayoutOf]'s own doc comment for why that
/// group renders stacked here, rather than in the PDF's side-by-side row).
const double _titlePageBottomGroupTopFraction = 0.22;

/// One title-page field's typesetting: everything `OcptFountainEditorStylesheet`'s title-page rule
/// needs to style a node, and everything [computeOcptStyledTitlePageMetrics] needs to estimate how
/// much vertical flow the field consumes — the single definition both now share, built by
/// [ocptTitlePageFieldLayoutOf].
class OcptTitlePageFieldLayout {
  /// Creates an [OcptTitlePageFieldLayout].
  const OcptTitlePageFieldLayout({
    required this.topGap,
    required this.left,
    required this.maxWidth,
    required this.textAlign,
    required this.fontScale,
    required this.fontWeight,
  });

  /// The top padding opened above the field's first node, in logical pixels
  /// (`Styles.padding.top`).
  final double topGap;

  /// The field's left padding, in logical pixels (`Styles.padding.left`).
  final double left;

  /// The field's wrap width, in logical pixels (`Styles.maxWidth`) — inclusive of [left], exactly
  /// like every other element rule in `OcptFountainEditorStylesheet` (see
  /// `OcptFountainEditorStylesheet._rule`'s own doc comment for why).
  final double maxWidth;

  /// The field's text alignment.
  final TextAlign textAlign;

  /// The multiple of [OcptEditorPreviewLayout.fontSize] the field renders at (only the Title field
  /// differs from the body's own size, at [ocptTitlePageTitleFontScale]).
  final double fontScale;

  /// The field's font weight (only the Title field is bold; every other field is `null`, i.e. the
  /// body's own regular weight).
  final FontWeight? fontWeight;
}

/// Returns [key]'s typesetting at [layout], mirroring the PDF exporter's own title page
/// (title/credit/authors centered in the upper-middle area; draft date right-aligned;
/// contact/source left-aligned) with one deliberate adaptation: the PDF pins contact at the
/// bottom-left and draft date at the bottom-right of the *same* row, which has no equivalent in the
/// editor's single-column, top-to-bottom document flow. Here the three are stacked instead — draft
/// date, then contact, then source — each keeping its PDF alignment, separated from the
/// title/credit/author block by a generous top gap standing in for the PDF's own bottom-anchoring.
///
/// [key] not matching any of [ocptTitlePageFieldKeys] (never expected — every title-page node's key
/// comes from that same list) falls back to a plain, full-width, left-aligned line with no extra
/// top gap.
OcptTitlePageFieldLayout ocptTitlePageFieldLayoutOf(String key, OcptEditorPreviewLayout layout) {
  final left = layout.marginLeft;
  final maxWidth = left + (layout.pageWidth - layout.marginLeft - layout.marginRight);

  return switch (key) {
    "Title" => OcptTitlePageFieldLayout(
      topGap: layout.pageHeight * _titlePageTitleTopFraction,
      left: left,
      maxWidth: maxWidth,
      textAlign: TextAlign.center,
      fontScale: ocptTitlePageTitleFontScale,
      fontWeight: FontWeight.bold,
    ),
    "Credit" => OcptTitlePageFieldLayout(
      topGap: layout.lineHeight * 2,
      left: left,
      maxWidth: maxWidth,
      textAlign: TextAlign.center,
      fontScale: 1,
      fontWeight: null,
    ),
    "Author" => OcptTitlePageFieldLayout(
      topGap: layout.lineHeight,
      left: left,
      maxWidth: maxWidth,
      textAlign: TextAlign.center,
      fontScale: 1,
      fontWeight: null,
    ),
    "Draft date" => OcptTitlePageFieldLayout(
      topGap: layout.pageHeight * _titlePageBottomGroupTopFraction,
      left: left,
      maxWidth: maxWidth,
      textAlign: TextAlign.right,
      fontScale: 1,
      fontWeight: null,
    ),
    "Contact" => OcptTitlePageFieldLayout(
      topGap: layout.lineHeight,
      left: left,
      maxWidth: maxWidth,
      textAlign: TextAlign.left,
      fontScale: 1,
      fontWeight: null,
    ),
    "Source" => OcptTitlePageFieldLayout(
      topGap: layout.lineHeight,
      left: left,
      maxWidth: maxWidth,
      textAlign: TextAlign.left,
      fontScale: 1,
      fontWeight: null,
    ),
    _ => OcptTitlePageFieldLayout(
      topGap: 0,
      left: left,
      maxWidth: maxWidth,
      textAlign: TextAlign.left,
      fontScale: 1,
      fontWeight: null,
    ),
  };
}

/// The result of [computeOcptStyledTitlePageMetrics]: the vertical flow height a document's
/// title-page field nodes occupy.
class OcptStyledTitlePageMetrics {
  /// Creates an [OcptStyledTitlePageMetrics].
  const OcptStyledTitlePageMetrics({required this.flowHeight});

  /// The total vertical flow height, in logical pixels, the document's title-page field nodes
  /// occupy when rendered by `OcptFountainEditorStylesheet`'s title-page rule:
  /// `Σ (topGap(field) + wrappedLines(node) × lineHeight × fontScale)`, the top gap counted only
  /// once per field (on its first node), summed over every title-page node in document order. 0
  /// for a document with no title-page nodes.
  final double flowHeight;
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
  final contentWidth = layout.pageWidth - layout.marginLeft - layout.marginRight;

  var flowHeight = 0.0;
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

    final columnWidth = layout.glyphWidth * fieldLayout.fontScale;
    final maxColumns = (contentWidth / columnWidth).floor();
    final wrappedLines = OcptEditorPreviewLayout.wrappedLineCount(node.text.toPlainText(), maxColumns);
    flowHeight += wrappedLines * layout.lineHeight * fieldLayout.fontScale;
  }

  return OcptStyledTitlePageMetrics(flowHeight: flowHeight);
}
