// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';

/// The alpha applied to [ColorScheme.primary] for text covered by the shot being edited: strong
/// enough to read at a glance, on the simulated paper sheet, as "this shot films this text".
const double _ocptOwnCoverageAlpha = 0.30;

/// The alpha applied to [ColorScheme.primary] for text covered by another shot: a faint wash, the
/// `Also covered by` caption under the block being what names the shots covering it.
const double _ocptOtherCoverageAlpha = 0.10;

/// The vertical padding of a clickable word's own box, in logical pixels.
///
/// This is what makes the whole band around a word clickable rather than only the glyphs
/// themselves, and what makes a covered range read as one continuous highlight: each word's box
/// carries the whitespace that follows it in the source, so two consecutive covered words leave no
/// gap between their two bands.
const double _ocptWordVerticalPadding = 2;

/// A pending coverage range anchor, exactly as `OcptShotListState.pendingCoverageAnchor` holds it:
/// the first word clicked of a range currently being drawn.
typedef OcptShotCoverageAnchor = ({int blockStartOffset, int wordStartOffset, int wordEndOffset});

/// The dialog a shot's scenario coverage is selected in: the sequence typeset on a simulated paper
/// sheet, in Courier Prime at its true screenplay indents, every word clickable.
///
/// The right dock only ever *shows* what a shot covers (`OcptShotCoverageSummary`); the selecting
/// happens here, where there is room to read the sequence and to click comfortably. The
/// interaction is the same three-state one the bloc owns (see
/// `OcptShotListCoverageWordClickedEvent`): a first click marks the start of a range, a second one
/// in the same block closes it, a click on already-covered text removes the range covering it.
///
/// Purely presentational, like every other widget of this mode: it renders [layout] and the range
/// lists it is given and reports every click upward. The mode is what keeps it in step with the
/// bloc, rebuilding it as ranges are recorded.
class OcptShotCoverageDialog extends StatelessWidget {
  /// The shot's `OcptShot.code`, shown in the dialog's title.
  final String shotCode;

  /// The sequence's heading, shown under the title.
  final String sequenceHeading;

  /// The sequence, laid out into blocks and words.
  final OcptShotCoverageLayout layout;

  /// The page setup the sheet is typeset with, so the sequence reads exactly as it does in the
  /// screenplay mode's own preview.
  final OcptPageSetup pageSetup;

  /// The edited shot's own coverage ranges.
  final List<OcptShotCoverageRange> ownRanges;

  /// Every other shot's coverage ranges of this scene, keyed by that shot's code.
  final Map<String, List<OcptShotCoverageRange>> otherShotsRanges;

  /// The first word clicked of a range currently being drawn, or null while none is.
  final OcptShotCoverageAnchor? pendingAnchor;

  /// Called with a clicked word's own block start offset and its own start/end offsets — exactly
  /// what `OcptShotListCoverageWordClickedEvent` carries.
  final void Function(int blockStartOffset, int wordStartOffset, int wordEndOffset) onWordTapped;

  /// Called when the `Clear all` action is clicked.
  final VoidCallback onClearAll;

  /// Class constructor
  const OcptShotCoverageDialog({
    super.key,
    required this.shotCode,
    required this.sequenceHeading,
    required this.layout,
    required this.pageSetup,
    required this.ownRanges,
    required this.otherShotsRanges,
    required this.pendingAnchor,
    required this.onWordTapped,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final previewLayout = OcptEditorPreviewLayout(metrics: pageSetup.toMetrics());
    final media = MediaQuery.sizeOf(context);

    return Dialog(
      child: SizedBox(
        width: previewLayout.pageWidth + 48,
        height: media.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr.shotListCoverageDialogTitle(shotCode),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          sequenceHeading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: tr.shotListCoverageDialogCloseAction,
                    onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: theme.extension<OcptSpecificColors>()!.previewBackdrop,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: _OcptShotCoverageSheet(
                      layout: layout,
                      previewLayout: previewLayout,
                      ownRanges: ownRanges,
                      otherShotsRanges: otherShotsRanges,
                      pendingAnchor: pendingAnchor,
                      onWordTapped: onWordTapped,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pendingAnchor == null
                        ? tr.shotListCoverageHintNoAnchor
                        : tr.shotListCoverageHintPendingAnchor,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${tr.shotListCoverageWordsCovered(layout.countCoveredWords(ownRanges), _totalWordCount)}"
                          " · ${tr.shotListCoverageRangesCount(layout.rangesInReadingOrder(ownRanges).length)}",
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: onClearAll,
                        child: Text(tr.shotListCoverageClearAllAction),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
                        child: Text(tr.shotListCoverageDialogCloseAction),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The total number of words across every block of [layout], the denominator of the footer's
  /// `N words covered of M` counter.
  int get _totalWordCount =>
      layout.blocks.fold(0, (total, block) => total + block.words.length);
}

/// The simulated paper sheet the sequence is typeset on: white, at the page setup's own width, each
/// block indented and capped at its element's screenplay geometry, exactly as the screenplay mode's
/// own preview lays the same text out.
class _OcptShotCoverageSheet extends StatelessWidget {
  /// The sequence laid out into blocks and words.
  final OcptShotCoverageLayout layout;

  /// The pixel geometry the sheet is typeset with.
  final OcptEditorPreviewLayout previewLayout;

  /// The edited shot's own coverage ranges.
  final List<OcptShotCoverageRange> ownRanges;

  /// Every other shot's coverage ranges of this scene, keyed by that shot's code.
  final Map<String, List<OcptShotCoverageRange>> otherShotsRanges;

  /// The first word clicked of a range currently being drawn, or null while none is.
  final OcptShotCoverageAnchor? pendingAnchor;

  /// Called with a clicked word's own block start offset and its own start/end offsets.
  final void Function(int blockStartOffset, int wordStartOffset, int wordEndOffset) onWordTapped;

  /// Class constructor
  const _OcptShotCoverageSheet({
    required this.layout,
    required this.previewLayout,
    required this.ownRanges,
    required this.otherShotsRanges,
    required this.pendingAnchor,
    required this.onWordTapped,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 2,
    borderRadius: BorderRadius.circular(3),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: previewLayout.pageWidth,
      child: Padding(
        padding: EdgeInsets.only(
          top: previewLayout.marginTop,
          bottom: previewLayout.marginBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final block in layout.blocks)
              _OcptShotCoverageSheetBlock(
                layout: layout,
                block: block,
                previewLayout: previewLayout,
                ownRanges: ownRanges,
                otherShotsRanges: otherShotsRanges,
                pendingAnchor: pendingAnchor,
                onWordTapped: onWordTapped,
              ),
          ],
        ),
      ),
    ),
  );
}

/// One block of the sheet: its words, each clickable, at the block's own screenplay indent, width
/// and alignment, followed by the `Also covered by` caption when another shot covers part of it.
class _OcptShotCoverageSheetBlock extends StatelessWidget {
  /// The layout [block] belongs to.
  final OcptShotCoverageLayout layout;

  /// The block rendered.
  final OcptShotCoverageBlock block;

  /// The pixel geometry the sheet is typeset with.
  final OcptEditorPreviewLayout previewLayout;

  /// The edited shot's own coverage ranges.
  final List<OcptShotCoverageRange> ownRanges;

  /// Every other shot's coverage ranges of this scene, keyed by that shot's code.
  final Map<String, List<OcptShotCoverageRange>> otherShotsRanges;

  /// The first word clicked of a range currently being drawn, or null while none is.
  final OcptShotCoverageAnchor? pendingAnchor;

  /// Called with a clicked word's own block start offset and its own start/end offsets.
  final void Function(int blockStartOffset, int wordStartOffset, int wordEndOffset) onWordTapped;

  /// Class constructor
  const _OcptShotCoverageSheetBlock({
    required this.layout,
    required this.block,
    required this.previewLayout,
    required this.ownRanges,
    required this.otherShotsRanges,
    required this.pendingAnchor,
    required this.onWordTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    final element = _elementLayout;
    final printStyle = FountainPrintStyle.of(block.type);
    final baseStyle = TextStyle(
      fontFamily: OcptEditorPreviewLayout.fontFamily,
      fontSize: OcptEditorPreviewLayout.fontSize,
      height: previewLayout.lineHeightFactor,
      color: Colors.black,
      fontWeight: printStyle.isBold ? FontWeight.bold : null,
      fontStyle: printStyle.isItalic ? FontStyle.italic : null,
    );

    final otherCodes = [
      for (final entry in otherShotsRanges.entries)
        if (layout.rangesIn(block, entry.value).isNotEmpty) entry.key,
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: previewLayout.blockSpacing),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(left: previewLayout.indentOf(element)),
          child: SizedBox(
            width: previewLayout.widthOf(element),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      for (var i = 0; i < block.words.length; i++)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: _OcptShotCoverageWord(
                            text: _displayedTextOf(i, printStyle),
                            style: baseStyle,
                            state: _stateOf(block.words[i]),
                            onTap: () => onWordTapped(
                              block.startOffset,
                              block.words[i].startOffset,
                              block.words[i].endOffset,
                            ),
                          ),
                        ),
                    ],
                  ),
                  style: baseStyle,
                  textAlign: _textAlign,
                ),
                if (otherCodes.isNotEmpty)
                  Text(
                    tr.shotListCoverageAlsoCoveredBy(otherCodes.join(" · ")),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The screenplay layout box [block]'s own line type is typeset in.
  ///
  /// The types that are never printed (a section, a synopsis, a page break — and the blank lines
  /// the layout has no block for at all) have no box of their own: they borrow the action box, so
  /// a sequence carrying one still reads as a paragraph rather than disappearing.
  FountainElementLayout get _elementLayout {
    final metrics = previewLayout.metrics;
    return switch (block.type) {
      FountainLineType.sceneHeading => metrics.sceneHeading,
      FountainLineType.character => metrics.character,
      FountainLineType.parenthetical => metrics.parenthetical,
      FountainLineType.dialogue => metrics.dialogue,
      FountainLineType.transition => metrics.transition,
      FountainLineType.centeredText => metrics.centeredText,
      FountainLineType.lyrics => metrics.lyrics,
      FountainLineType.action ||
      FountainLineType.section ||
      FountainLineType.synopsis ||
      FountainLineType.pageBreak ||
      FountainLineType.blank => metrics.action,
    };
  }

  /// The horizontal alignment [block]'s element is typeset with.
  TextAlign get _textAlign => switch (_elementLayout.alignment) {
    FountainLayoutAlignment.center => TextAlign.center,
    FountainLayoutAlignment.right => TextAlign.right,
    FountainLayoutAlignment.left => TextAlign.left,
  };

  /// The text rendered for the word at [index]: the word itself **plus the whitespace separating
  /// it from the next one** (or ending the line), upper-cased when [printStyle] says the element
  /// prints upper-cased.
  ///
  /// Carrying the trailing whitespace inside the word's own box is what makes a covered range read
  /// as one continuous highlight instead of a row of separate word-sized patches, and what makes
  /// the gap between two words clickable rather than dead.
  String _displayedTextOf(int index, FountainPrintStyle printStyle) {
    final word = block.words[index];
    final endOffset = index + 1 < block.words.length
        ? block.words[index + 1].startOffset
        : block.endOffset;
    final text = layout.sceneText.substring(word.startOffset, endOffset);

    return printStyle.isUppercase ? text.toUpperCase() : text;
  }

  /// How [word] is currently painted: the anchor of a range being drawn wins over every coverage,
  /// and this shot's own coverage wins over another shot's.
  _OcptShotCoverageWordState _stateOf(OcptShotCoverageWord word) {
    if (pendingAnchor?.wordStartOffset == word.startOffset &&
        pendingAnchor?.blockStartOffset == block.startOffset) {
      return _OcptShotCoverageWordState.anchor;
    }
    if (layout.isWordCovered(word, ownRanges)) {
      return _OcptShotCoverageWordState.own;
    }
    if (otherShotsRanges.values.any((ranges) => layout.isWordCovered(word, ranges))) {
      return _OcptShotCoverageWordState.other;
    }

    return _OcptShotCoverageWordState.plain;
  }
}

/// How one word of the sheet is painted.
enum _OcptShotCoverageWordState {
  /// Covered by no shot at all: plain paper text.
  plain,

  /// Covered by the shot being edited: a strong accent band.
  own,

  /// Covered by another shot, but not by this one: a faint accent wash.
  other,

  /// The first word clicked of a range currently being drawn: the accent itself, so it is
  /// unmistakably the click the next one closes.
  anchor,
}

/// One clickable word of the sheet, painted per its [state], its whole box (the glyphs, the
/// whitespace that follows them and [_ocptWordVerticalPadding] above and below) being the click
/// target.
class _OcptShotCoverageWord extends StatelessWidget {
  /// The word's text, whitespace and print-time casing included.
  final String text;

  /// The paper text style the word is typeset in.
  final TextStyle style;

  /// How the word is currently painted.
  final _OcptShotCoverageWordState state;

  /// Called when the word is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptShotCoverageWord({
    required this.text,
    required this.style,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    final background = switch (state) {
      _OcptShotCoverageWordState.plain => null,
      _OcptShotCoverageWordState.own => accent.withValues(alpha: _ocptOwnCoverageAlpha),
      _OcptShotCoverageWordState.other => accent.withValues(alpha: _ocptOtherCoverageAlpha),
      _OcptShotCoverageWordState.anchor => accent,
    };

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: background,
          padding: const EdgeInsets.symmetric(vertical: _ocptWordVerticalPadding),
          child: Text(
            text,
            style: state == _OcptShotCoverageWordState.anchor
                ? style.copyWith(color: Theme.of(context).colorScheme.onPrimary)
                : style,
          ),
        ),
      ),
    );
  }
}
