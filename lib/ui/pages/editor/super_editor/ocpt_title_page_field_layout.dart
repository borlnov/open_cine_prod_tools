// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_title_page_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

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

  /// Create an [OcptTitlePageFieldLayout].
  const OcptTitlePageFieldLayout({
    required this.topGap,
    required this.left,
    this.right = 0,
    required this.maxWidth,
    required this.textAlign,
    required this.fontScale,
    required this.fontWeight,
  });
}

/// Return [key]'s typesetting at [layout], mirroring the PDF exporter's own title page
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
