// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_pagination.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:super_editor/super_editor.dart';

/// Builds the `Stylesheet` that lays every Fountain line out at its true screenplay position
/// while the user types, driving the styled block editor entirely through super_editor's own
/// stylesheet mechanism: no custom `ComponentBuilder` is needed, because every plain
/// `ParagraphNode` this editor ever creates already supports `Styles.padding` (used here for the
/// element's left indent), `Styles.maxWidth` (its wrap width) and `Styles.textAlign`/
/// `Styles.textStyle` (its alignment, weight, color and italics), all keyed off the node's
/// `blockType` metadata (see [OcptFountainLineAttributions]).
///
/// Every measurement is derived from [OcptEditorPreviewLayout], the same class the raw mode's
/// paper preview uses to turn [FountainLayoutMetrics] character columns into pixels: reusing it
/// here (rather than re-deriving the same numbers) is what keeps the styled editor's proportions
/// consistent with the preview's, even though the styled editor is a fluid-width editing surface
/// with no simulated page.
class OcptFountainEditorStylesheet {
  /// Private constructor: this class only exposes static members.
  const OcptFountainEditorStylesheet._();

  /// The opacity applied to non-printing elements (sections and synopses), which never appear in
  /// the printed screenplay and so are dimmed to read as authoring scaffolding rather than
  /// content.
  static const double _nonPrintingOpacity = 0.55;

  /// The opacity applied to parentheticals: printed, but visually secondary to the dialogue they
  /// annotate.
  static const double _parentheticalOpacity = 0.75;

  /// The alpha applied to an inline authoring note's (`[[text]]`) color, dimming it relative to
  /// the surrounding text it's embedded in (a note is authoring scaffolding, never printed).
  static const double _noteInlineOpacity = 0.55;

  /// The fixed horizontal inset kept around the document even while page simulation is on (never
  /// 0): a zero horizontal `documentPadding` was found, empirically, to make `SuperEditor`
  /// occasionally fail to open a live IME connection when the caret is placed by a simulated tap
  /// right at the document's edge — this margin sidesteps it entirely.
  static const double _horizontalDocumentPaddingInset = 8;

  /// The vertical document padding used while page simulation is off (a small, fixed inset for
  /// the fluid, theme-following editing surface, top and bottom alike).
  static const double _fluidVerticalDocumentPaddingInset = 16;

  /// Builds the stylesheet for typesetting the styled editor at [metrics].
  ///
  /// When [isPageSimulationEnabled] is off, colors follow [colorScheme] (so the editing surface
  /// follows the app's light/dark theme). When it's on, every color is a fixed paper color (black
  /// text, greyed-out scaffolding) instead, regardless of [colorScheme]: the simulated page is
  /// always white, so a theme-derived color (in particular dark mode's light `onSurface`) would
  /// otherwise render invisible or near-invisible on it. A page-starting node (flagged by
  /// [ocptStartsNewPageMetadataKey], set by `computeOcptStyledPagination`) also gets extra top
  /// padding — the exact pixel amount `computeOcptStyledPagination` computed for it — standing in
  /// for the page gap and the previous/next page's margins. When page simulation is on, the
  /// document's own top/bottom padding is the page's real top margin and (respectively)
  /// [trailingBottomPadding], so the first page's content starts at its true margin and the last
  /// page's content region genuinely fills the sheet down to its own bottom margin, exactly like
  /// every other simulated page (see [OcptStyledPagination.trailingBottomPadding]'s own doc
  /// comment for how that padding is computed).
  static Stylesheet build({
    required FountainLayoutMetrics metrics,
    required ColorScheme colorScheme,
    required bool isPageSimulationEnabled,
    double trailingBottomPadding = 0,
  }) {
    final layout = OcptEditorPreviewLayout(metrics: metrics);
    final onSurface = isPageSimulationEnabled ? Colors.black : colorScheme.onSurface;
    final onSurfaceVariant = isPageSimulationEnabled ? Colors.black54 : colorScheme.onSurfaceVariant;
    final accent = isPageSimulationEnabled ? Colors.black : colorScheme.primary;
    final baseStyle = TextStyle(
      fontFamily: OcptEditorPreviewLayout.fontFamily,
      fontSize: OcptEditorPreviewLayout.fontSize,
      height: layout.lineHeightFactor,
      color: onSurface,
    );

    return Stylesheet(
      documentPadding: EdgeInsets.only(
        left: _horizontalDocumentPaddingInset,
        right: _horizontalDocumentPaddingInset,
        top: isPageSimulationEnabled ? layout.marginTop : _fluidVerticalDocumentPaddingInset,
        bottom: isPageSimulationEnabled ? trailingBottomPadding : _fluidVerticalDocumentPaddingInset,
      ),
      inlineTextStyler: (attributions, existingStyle) =>
          _inlineTextStyler(attributions, existingStyle, onSurfaceVariant),
      rules: [
        // `blank` and `action` both use the action box (left margin, full width) in the base text
        // color; every FountainLineType gets its own explicit rule below (rather than a
        // `BlockSelector.all` fallback) because every node's `blockType` only ever matches one
        // rule's selector, and the styler only overwrites a style key the *first* time a matching
        // rule sets it (see `SingleColumnStylesheetStyler._mergeStyles`) — a second, more specific
        // rule matching the same node would otherwise leave `Styles.maxWidth`, `Styles.textAlign`
        // and `Styles.opacity` stuck at whatever the first matching rule set, since only
        // `Styles.textStyle` and `Styles.padding` are actually merged across rules.
        _rule(
          FountainLineType.blank,
          metrics.action,
          layout,
          textStyle: baseStyle,
        ),
        _rule(
          FountainLineType.action,
          metrics.action,
          layout,
          textStyle: baseStyle,
        ),
        _rule(
          FountainLineType.sceneHeading,
          metrics.sceneHeading,
          layout,
          textStyle: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ),
        _rule(
          FountainLineType.character,
          metrics.character,
          layout,
          textStyle: baseStyle.copyWith(color: accent, fontWeight: FontWeight.bold),
        ),
        _rule(
          FountainLineType.parenthetical,
          metrics.parenthetical,
          layout,
          textStyle: baseStyle.copyWith(
            color: onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
          opacity: _parentheticalOpacity,
        ),
        _rule(
          FountainLineType.dialogue,
          metrics.dialogue,
          layout,
          textStyle: baseStyle,
        ),
        _rule(
          FountainLineType.transition,
          metrics.transition,
          layout,
          textStyle: baseStyle,
          textAlign: TextAlign.right,
        ),
        _rule(
          FountainLineType.centeredText,
          metrics.centeredText,
          layout,
          textStyle: baseStyle,
          textAlign: TextAlign.center,
        ),
        _rule(
          FountainLineType.lyrics,
          metrics.dialogue,
          layout,
          textStyle: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ),
        _rule(
          FountainLineType.section,
          metrics.action,
          layout,
          textStyle: baseStyle.copyWith(
            color: onSurfaceVariant,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
          ),
          opacity: _nonPrintingOpacity,
        ),
        _rule(
          FountainLineType.synopsis,
          metrics.action,
          layout,
          textStyle: baseStyle.copyWith(
            color: onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
          opacity: _nonPrintingOpacity,
        ),
        _rule(
          FountainLineType.pageBreak,
          metrics.centeredText,
          layout,
          textStyle: baseStyle.copyWith(color: onSurfaceVariant),
          textAlign: TextAlign.center,
          opacity: _nonPrintingOpacity,
        ),
      ],
    );
  }

  /// Builds the `StyleRule` for [type], selecting nodes by the `blockType` attribution
  /// [OcptFountainLineAttributions.attributionOf] gives it, and positioning them at [element]'s
  /// indent and width (converted to pixels through [layout]); each node's own
  /// [ocptBlankLinesBeforeMetadataKey] metadata additionally opens up top padding, visually
  /// standing in for the blank source lines folded into it.
  ///
  /// super_editor sizes a node's component to `Styles.maxWidth` first, then applies
  /// `Styles.padding` *inside* that box, so the left indent eats into the box rather than
  /// starting a fresh one: `Styles.maxWidth` must therefore be the indent plus the element's own
  /// width, so the box's right edge lands where the raw preview's does and the padding-shrunk
  /// remainder is exactly [OcptEditorPreviewLayout.widthOf].
  static StyleRule _rule(
    FountainLineType type,
    FountainElementLayout element,
    OcptEditorPreviewLayout layout, {
    required TextStyle textStyle,
    TextAlign textAlign = TextAlign.left,
    double opacity = 1,
  }) => StyleRule(
    BlockSelector(OcptFountainLineAttributions.attributionOf(type).name),
    (document, node) => {
      Styles.padding: CascadingPadding.only(
        left: layout.indentOf(element),
        top: _blankLinesBeforeTopPadding(node, layout) + _pageBoundaryTopPadding(node),
      ),
      Styles.maxWidth: layout.indentOf(element) + layout.widthOf(element),
      Styles.textAlign: textAlign,
      Styles.textStyle: textStyle,
      Styles.opacity: opacity,
    },
  );

  /// The extra top padding standing in for [node]'s [ocptBlankLinesBeforeMetadataKey] blank source
  /// lines, one [OcptEditorPreviewLayout.lineHeight] each, capped at
  /// [ocptMaxBlankLinesBeforeSpacing].
  static double _blankLinesBeforeTopPadding(DocumentNode node, OcptEditorPreviewLayout layout) {
    final blankLinesBefore = node.getMetadataValue(ocptBlankLinesBeforeMetadataKey);
    final count = blankLinesBefore is int ? blankLinesBefore : 0;
    return count.clamp(0, ocptMaxBlankLinesBeforeSpacing) * layout.lineHeight;
  }

  /// The extra top padding standing in for the page gap and the previous/next page's margins,
  /// opened up above a node flagged [ocptStartsNewPageMetadataKey] by `computeOcptStyledPagination`
  /// — the exact pixel amount that pass computed for this node so it lands precisely at its
  /// sheet's text origin, rather than a fixed estimate (0 for a node not flagged, or while page
  /// simulation is off: the flag is only ever set while it's on).
  static double _pageBoundaryTopPadding(DocumentNode node) {
    final value = node.getMetadataValue(ocptStartsNewPageMetadataKey);
    return value is double ? value : 0;
  }

  /// Wraps `defaultInlineTextStyler` to additionally dim an [ocptFountainNoteAttribution] span
  /// ([_noteInlineOpacity] of [onSurfaceVariant]), read-only authoring scaffolding that never
  /// prints.
  static TextStyle _inlineTextStyler(
    Set<Attribution> attributions,
    TextStyle existingStyle,
    Color onSurfaceVariant,
  ) {
    final style = defaultInlineTextStyler(attributions, existingStyle);
    if (!attributions.contains(ocptFountainNoteAttribution)) {
      return style;
    }

    return style.copyWith(color: onSurfaceVariant.withValues(alpha: _noteInlineOpacity));
  }
}
