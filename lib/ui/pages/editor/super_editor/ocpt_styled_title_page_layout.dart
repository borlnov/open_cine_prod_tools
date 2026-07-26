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
    this.right = 0,
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

  /// The field's right padding, in logical pixels (`Styles.padding.right`), non-zero only for
  /// Draft date and Contact: they split the same row half-and-half (see
  /// [ocptTitlePageFieldLayoutOf]'s own doc comment), so each one's box must stop short of the
  /// other's half rather than spanning the full [maxWidth] the way every other field does.
  final double right;

  /// The field's wrap width, in logical pixels (`Styles.maxWidth`) — inclusive of [left] and
  /// [right], exactly like every other element rule in `OcptFountainEditorStylesheet` (see
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
/// contact/source left-aligned), including its bottom row: the PDF pins contact at the
/// bottom-left and draft date at the bottom-right of the *same* row (a `Row(mainAxisAlignment:
/// spaceBetween)`), and this editor reproduces that literally — Draft date owns the row's top gap
/// and right half, Contact owns the left half with no top gap of its own (the shift
/// `computeOcptStyledTitlePageMetrics`'s `rowShift` describes takes its place; the title-page
/// component builder is what actually moves Contact, and Source below it, onto that row's height),
/// and Source follows underneath at the full content width, exactly as before. Splitting
/// horizontally through `left`/`right` padding rather than a narrowed `maxWidth` is deliberate
/// (`OcptFountainEditorStylesheet`'s own fact about `Styles.maxWidth` centering a narrower box):
/// Draft date and Contact both keep [OcptTitlePageFieldLayout.maxWidth] at the full row width and
/// instead have their usable box shrunk from opposite sides, which is what keeps their two halves
/// from overlapping (and swallowing each other's taps — see the component builder's own doc
/// comment).
///
/// [key] not matching any of [ocptTitlePageFieldKeys] (never expected — every title-page node's key
/// comes from that same list) falls back to a plain, full-width, left-aligned line with no extra
/// top gap.
OcptTitlePageFieldLayout ocptTitlePageFieldLayoutOf(String key, OcptEditorPreviewLayout layout) {
  final left = layout.marginLeft;
  final contentWidth = layout.pageWidth - layout.marginLeft - layout.marginRight;
  final maxWidth = left + contentWidth;
  final halfWidth = contentWidth / 2;

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
      left: left + halfWidth,
      maxWidth: maxWidth,
      textAlign: TextAlign.right,
      fontScale: 1,
      fontWeight: null,
    ),
    "Contact" => OcptTitlePageFieldLayout(
      topGap: 0,
      left: left,
      right: halfWidth,
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
/// title-page field nodes occupy, and the Draft date/Contact row's own shift amount.
class OcptStyledTitlePageMetrics {
  /// Creates an [OcptStyledTitlePageMetrics].
  const OcptStyledTitlePageMetrics({required this.flowHeight, required this.rowShift});

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
    final wrappedLines = OcptEditorPreviewLayout.wrappedLineCount(node.text.toPlainText(), maxColumns);
    final lineContribution = wrappedLines * layout.lineHeight * fieldLayout.fontScale;
    flowHeight += lineContribution;
    if (key == "Draft date") {
      rowShift += lineContribution;
    }
  }

  return OcptStyledTitlePageMetrics(flowHeight: flowHeight, rowShift: rowShift);
}
