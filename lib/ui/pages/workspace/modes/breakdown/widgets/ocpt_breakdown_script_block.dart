// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_block.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_scene_bars.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_search_candidate.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_tag_span.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_pending_tag.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_run_style.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_selected_target_ref.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_tag_popover.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_fountain_line_display.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_warning_color.dart';

/// The alpha a tagged word's own target colour is washed onto the paper sheet at: light enough that
/// black Courier Prime text stays legible over even the palette's darkest entries, calibrated the
/// same way `OcptShotCoverageDialog`'s own `_ocptOwnCoverageAlpha` is — lower, though, since
/// `ocptBreakdownColorOf`'s palette is pastel by itself rather than one accent colour reused at
/// different strengths.
const double _ocptBreakdownTagAlpha = 0.35;

/// The alpha a **selected** target's tag is washed at, replacing [_ocptBreakdownTagAlpha]: strong
/// enough that a scene carrying several tags of the same category still reads unambiguously which
/// one is selected.
const double _ocptBreakdownSelectedTagAlpha = 0.55;

/// The width of the ring `OcptBreakdownScriptView` draws around a selected target's tagged words,
/// in logical pixels — what distinguishes the selection from the plain category wash every other
/// tag of the same category still carries.
const double _ocptBreakdownSelectedTagRingWidth = 1.5;

/// The vertical padding of a clickable word's own box, in logical pixels.
///
/// This is what makes the whole band around a word clickable rather than only the glyphs
/// themselves, and what makes a tagged range read as one continuous highlight: each word's box
/// carries the whitespace that follows it, so two consecutive tagged words leave no gap between
/// their two bands. Mirrors `OcptShotCoverageDialog`'s own `_ocptWordVerticalPadding`.
const double _ocptWordVerticalPadding = 2;

/// One non-heading block of the sheet: every word its own click target, painted per the live tag
/// (if any) covering it — see `OcptBreakdownScriptView`'s own doc comment for the painting and
/// click-routing rules this class implements.
class OcptBreakdownScriptBlock extends StatelessWidget {
  /// The scene this block belongs to, whose [OcptBreakdownScene.tags] every word is resolved
  /// against.
  final OcptBreakdownScene scene;

  /// The block rendered.
  final OcptScriptWordBlock block;

  /// `{(kind, id): target}`, forwarded from `OcptBreakdownScriptView`.
  final OcptBreakdownTargetsById targetById;

  /// Forwarded from `OcptBreakdownScriptView`.
  final Set<OcptBreakdownLegendKey> hiddenLegendKeys;

  /// Forwarded from `OcptBreakdownScriptView`.
  final OcptBreakdownSelectedTargetRef selectedTargetRef;

  /// The pixel geometry the sheet is typeset with.
  final OcptEditorPreviewLayout previewLayout;

  /// The multiplier this block's indent and box width are scaled by — 1 on the desktop, the compact
  /// factor on a phone (`OcptEditorPreviewLayout.compactLayoutScale`).
  final double layoutScale;

  /// Whether the source leaves a blank line right after this block.
  final bool isFollowedByBlankLine;

  /// Forwarded from `OcptBreakdownScriptView`.
  final void Function(OcptBreakdownTargetKind targetKind, String targetId, String sceneId)
  onTargetSelected;

  /// Forwarded from `OcptBreakdownScriptView`.
  final void Function(String sceneId, int wordStartOffset, int wordEndOffset)? onWordClicked;

  /// Forwarded from `OcptBreakdownScriptView`.
  final OcptBreakdownPendingTagAnchor? pendingTagAnchor;

  /// Forwarded from `OcptBreakdownScriptView`.
  final OcptBreakdownPendingTagRange? pendingTagRange;

  /// Forwarded from `OcptBreakdownScriptView`.
  final List<OcptBreakdownSearchCandidate> candidates;

  /// Forwarded from `OcptBreakdownScriptView`.
  final VoidCallback onPopoverCancelled;

  /// Forwarded from `OcptBreakdownScriptView`.
  final void Function(OcptBreakdownTargetKind targetKind, String targetId) onPopoverTargetLinked;

  /// Forwarded from `OcptBreakdownScriptView`.
  final void Function(OcptElementCategory category, String name) onPopoverElementCreationRequested;

  /// Every location of the project, `(id, name)`, offered by the popover's own `Create a set`
  /// control as the place a new set goes into.
  final List<(String, String)> locations;

  /// Called with the location a new set belongs to — null for one minted along with it — and the
  /// popover's own field text, creating that set and tagging the pending range with it.
  final void Function(String? locationId, String name) onPopoverSetCreationRequested;

  /// Forwarded from `OcptBreakdownScriptView`.
  final VoidCallback onOpenInResourcesRequested;

  /// Class constructor
  const OcptBreakdownScriptBlock({
    super.key,
    required this.scene,
    required this.block,
    required this.targetById,
    required this.hiddenLegendKeys,
    required this.selectedTargetRef,
    required this.previewLayout,
    required this.layoutScale,
    required this.isFollowedByBlankLine,
    required this.onTargetSelected,
    required this.onWordClicked,
    required this.pendingTagAnchor,
    required this.pendingTagRange,
    required this.candidates,
    required this.onPopoverCancelled,
    required this.onPopoverTargetLinked,
    required this.onPopoverElementCreationRequested,
    required this.locations,
    required this.onPopoverSetCreationRequested,
    required this.onOpenInResourcesRequested,
  });

  /// Build the breakdown script block as a [Padding].
  @override
  Widget build(BuildContext context) {
    final element = _elementLayoutOf(block.type, previewLayout.metrics);
    final printStyle = FountainPrintStyle.of(block.type);
    final baseStyle = TextStyle(
      fontFamily: OcptEditorPreviewLayout.fontFamily,
      fontSize: OcptEditorPreviewLayout.fontSize,
      height: previewLayout.lineHeightFactor,
      color: Colors.black,
      fontWeight: printStyle.isBold ? FontWeight.bold : null,
      fontStyle: printStyle.isItalic ? FontStyle.italic : null,
    );
    final displayRuns = ocptFountainWordDisplayRuns(block);

    return Padding(
      padding: EdgeInsets.only(bottom: isFollowedByBlankLine ? previewLayout.blockSpacing : 0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(left: previewLayout.indentOf(element) * layoutScale),
          child: SizedBox(
            width: previewLayout.widthOf(element) * layoutScale,
            child: Text.rich(
              TextSpan(
                children: [
                  for (var i = 0; i < block.words.length; i++)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: _OcptBreakdownWordSlot(
                        word: _OcptBreakdownWord(
                          runs: displayRuns[i],
                          isUppercase: printStyle.isUppercase,
                          style: baseStyle,
                          paint: _paintOf(block.words[i]),
                          onTap: _onTapFor(block.words[i]),
                        ),
                        popover: _isPopoverAnchorWord(block.words[i])
                            ? OcptBreakdownTagPopover(
                                taggedText: pendingTagRange!.taggedText,
                                candidates: candidates,
                                onCandidateSelected: (candidate) =>
                                    onPopoverTargetLinked(candidate.kind, candidate.id),
                                onCategorySelected: onPopoverElementCreationRequested,
                                locations: locations,
                                onSetCreationSelected: onPopoverSetCreationRequested,
                                onOpenInResourcesRequested: onOpenInResourcesRequested,
                                onClose: onPopoverCancelled,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              style: baseStyle,
              textAlign: _textAlignOf(element),
            ),
          ),
        ),
      ),
    );
  }

  /// Get the live tag of [scene] covering [word], or null if none does.
  ///
  /// Tags never overlap, so at most one can ever cover a given word.
  OcptBreakdownTag? _tagCovering(OcptScriptWord word) {
    for (final tag in scene.tags) {
      if (tag.startOffset < word.endOffset && tag.endOffset > word.startOffset) {
        return tag;
      }
    }
    return null;
  }

  /// Tell whether [word] is the very word [pendingTagAnchor] names in this scene.
  bool _isPendingAnchor(OcptScriptWord word) {
    final anchor = pendingTagAnchor;
    return anchor != null &&
        anchor.sceneId == scene.id &&
        anchor.wordStartOffset == word.startOffset &&
        anchor.wordEndOffset == word.endOffset;
  }

  /// Tell whether [word] is the exact word [pendingTagRange] closed on — where
  /// [OcptBreakdownTagPopoverAnchor] mounts the popover.
  bool _isPopoverAnchorWord(OcptScriptWord word) {
    final range = pendingTagRange;
    return range != null &&
        range.sceneId == scene.id &&
        range.closingWordStartOffset == word.startOffset &&
        range.closingWordEndOffset == word.endOffset;
  }

  /// Tell whether closing a range between [pendingTagAnchor] and [word] would overlap a live tag of
  /// [scene] — computed cheaply, straight over the scene's own (typically short) tag list, exactly
  /// as `OcptBreakdownBloc._onWordClicked` itself refuses the same overlap. False while no anchor
  /// is open in this scene, or for a word already covered by a live tag: a tagged word is never
  /// this kind of click target to begin with, it is always ordinary tagged word instead.
  bool _isBlockedByAnchor(OcptScriptWord word) {
    final anchor = pendingTagAnchor;
    if (anchor == null || anchor.sceneId != scene.id) {
      return false;
    }

    final startOffset = anchor.wordStartOffset <= word.startOffset
        ? anchor.wordStartOffset
        : word.startOffset;
    final endOffset = anchor.wordEndOffset >= word.endOffset
        ? anchor.wordEndOffset
        : word.endOffset;

    return scene.tags.any((tag) => startOffset < tag.endOffset && tag.startOffset < endOffset);
  }

  /// Tell whether the highlight span starting at scene-relative [spanStart] starts inside [word] —
  /// i.e.
  /// [word] is the first word the span covers, whose leading affix the box then trims.
  bool _spanStartsIn(OcptScriptWord word, int spanStart) =>
      spanStart >= word.startOffset && spanStart < word.endOffset;

  /// Tell whether the highlight span ending at scene-relative [spanEnd] ends inside [word] — i.e.
  /// [word]
  /// is the last word the span covers, whose trailing affix (punctuation and the whitespace up to
  /// the next word) the box then trims.
  bool _spanEndsIn(OcptScriptWord word, int spanEnd) =>
      spanEnd > word.startOffset && spanEnd <= word.endOffset;

  /// Tell how [word] is painted: the tagged rules `OcptBreakdownScriptView`'s own doc comment
  /// describes,
  /// then — for a plain word — the pending anchor's own distinct mark, then a word of the range
  /// whose popover is open, then the greyed-out mark of a word blocked by an anchor, and plain
  /// otherwise.
  ///
  /// A tag or a range only trims the affix at the end it actually reaches: the word it starts in
  /// loses its leading affix, the word it ends in its trailing affix, so a passage of several words
  /// still reads as one continuous band — only its two ends hug the words rather than the
  /// sentence's punctuation. A tag's and a range's stored offsets are both already narrowed to word
  /// cores, so [_spanStartsIn]/[_spanEndsIn] land on the boundary words, and the pending anchor (a
  /// single word) trims both ends alike.
  _OcptBreakdownWordPaint _paintOf(OcptScriptWord word) {
    final tag = _tagCovering(word);
    if (tag != null) {
      final target = targetById[(tag.targetKind, tag.targetId)];
      if (target == null || hiddenLegendKeys.contains(ocptBreakdownLegendKeyOf(target))) {
        return _OcptBreakdownWordPaint.plain;
      }

      return _OcptBreakdownWordPaint(
        color: Color(target.color),
        isSelected: selectedTargetRef == (target.kind, target.id),
        needsCheck: tag.needsCheck,
        tooltipTargetName: target.name,
        trimLeadingAffix: _spanStartsIn(word, tag.startOffset),
        trimTrailingAffix: _spanEndsIn(word, tag.endOffset),
      );
    }

    if (_isPendingAnchor(word)) {
      return const _OcptBreakdownWordPaint(
        isPendingAnchor: true,
        trimLeadingAffix: true,
        trimTrailingAffix: true,
      );
    }

    final range = pendingTagRange;
    if (range != null &&
        range.sceneId == scene.id &&
        range.startOffset < word.endOffset &&
        range.endOffset > word.startOffset) {
      return _OcptBreakdownWordPaint(
        isPendingRange: true,
        trimLeadingAffix: _spanStartsIn(word, range.startOffset),
        trimTrailingAffix: _spanEndsIn(word, range.endOffset),
      );
    }

    if (_isBlockedByAnchor(word)) {
      return _OcptBreakdownWordPaint.blocked;
    }

    return _OcptBreakdownWordPaint.plain;
  }

  /// Get [word]'s own click callback: its tag's target through [onTargetSelected] when one resolves
  /// —
  /// selecting it, and (per `OcptBreakdownBloc._onTargetSelected`) the scene the click happened in,
  /// so the left dock and the sheet stay in step — never null, since selecting writes nothing. A
  /// hidden legend key never changes this: hiding a category withholds its paint, not its click.
  ///
  /// Otherwise null while [onWordClicked] itself is (a previewed version withholding the whole
  /// range interaction) or while [_isBlockedByAnchor] says so — neither is a click target at all,
  /// not merely one whose click is refused — and [onWordClicked] with the word's own scene-relative
  /// offsets in every other case.
  VoidCallback? _onTapFor(OcptScriptWord word) {
    final tag = _tagCovering(word);
    final target = tag == null ? null : targetById[(tag.targetKind, tag.targetId)];
    if (target != null) {
      return () => onTargetSelected(target.kind, target.id, scene.id);
    }

    final onWordClicked = this.onWordClicked;
    if (onWordClicked == null || _isBlockedByAnchor(word)) {
      return null;
    }

    return () => onWordClicked(scene.id, word.startOffset, word.endOffset);
  }
}

/// One word of a script block: the plain click target, or — for the one word that anchors the
/// pending tag's popover — that same target anchoring [popover] under it through
/// [OcptBreakdownTagPopoverAnchor].
class _OcptBreakdownWordSlot extends StatelessWidget {
  /// The word's click target.
  final Widget word;

  /// The popover the word anchors, or null for a word that anchors none.
  final OcptBreakdownTagPopover? popover;

  /// Class constructor
  const _OcptBreakdownWordSlot({required this.word, required this.popover});

  /// Build the word slot as the word itself or an [OcptBreakdownTagPopoverAnchor] around it.
  @override
  Widget build(BuildContext context) {
    final popover = this.popover;
    if (popover == null) {
      return word;
    }

    return OcptBreakdownTagPopoverAnchor(popover: popover, child: word);
  }
}

/// Get the screenplay layout box a line of [type] is typeset in, mirroring
/// `OcptShotCoverageDialog`'s own `_elementLayout` getter.
FountainElementLayout _elementLayoutOf(FountainLineType type, FountainLayoutMetrics metrics) =>
    switch (type) {
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

/// Get the horizontal alignment [element] is typeset with.
TextAlign _textAlignOf(FountainElementLayout element) => switch (element.alignment) {
  FountainLayoutAlignment.center => TextAlign.center,
  FountainLayoutAlignment.right => TextAlign.right,
  FountainLayoutAlignment.left => TextAlign.left,
};

/// How one word of the sheet is painted, decided once by `OcptBreakdownScriptBlock` per word from
/// its own tag (if any) — see that class's own `_paintOf` for the rules.
class _OcptBreakdownWordPaint {
  /// A plain word: no tag, or one whose target does not resolve.
  static const plain = _OcptBreakdownWordPaint();

  /// A word that would overlap a live tag if the pending anchor's range closed on it.
  static const blocked = _OcptBreakdownWordPaint(isBlocked: true);

  /// The tagged target's own colour, or null for a plain word (untagged, or its target gone) and
  /// for the two transient marks below, which never use a category colour.
  final Color? color;

  /// Whether this word's tag belongs to the currently selected target.
  final bool isSelected;

  /// Whether this word's tag needs a check (`OcptBreakdownTag.needsCheck`).
  final bool needsCheck;

  /// The tagged target's own name, shown as this word's tooltip — null for a plain word.
  final String? tooltipTargetName;

  /// Whether this word is the pending anchor of a range not yet closed — a distinct, obviously
  /// transient mark, never a category colour, since the anchor itself is not yet any category at
  /// all. Carries the anchor's own tooltip, which [isPendingRange] does not.
  final bool isPendingAnchor;

  /// Whether this word falls inside a range that a second click has closed and whose popover is now
  /// open: the same transient accent as [isPendingAnchor], so the passage stays lit while the user
  /// picks what to tag it as, but wordlessly (the popover is the affordance).
  final bool isPendingRange;

  /// Whether this word is not a click target because closing a range on it, from the pending
  /// anchor, would overlap a live tag — greyed out rather than merely refused on click.
  final bool isBlocked;

  /// Whether the highlight box should leave this word's leading affix (its opening punctuation)
  /// outside it — set for the word a tag or a range **starts** in, so the box hugs the core.
  final bool trimLeadingAffix;

  /// Whether the highlight box should leave this word's trailing affix (its closing punctuation and
  /// the whitespace up to the next word) outside it — set for the word a tag or a range **ends**
  /// in. An interior word trims neither end, so its whole-word wash still bridges to its neighbour.
  final bool trimTrailingAffix;

  /// Tell whether this word wears the transient accent — the pending anchor or a word of the
  /// pending
  /// range — rather than a category wash or nothing.
  bool get isAccent => isPendingAnchor || isPendingRange;

  /// Class constructor
  const _OcptBreakdownWordPaint({
    this.color,
    this.isSelected = false,
    this.needsCheck = false,
    this.tooltipTargetName,
    this.isPendingAnchor = false,
    this.isPendingRange = false,
    this.isBlocked = false,
    this.trimLeadingAffix = false,
    this.trimTrailingAffix = false,
  });
}

/// A word's display runs split into the three parts a boundary highlight paints differently: the
/// leading affix left outside the box, the word core the box hugs, and the trailing affix.
typedef _OcptTrimmedRuns = ({
  List<OcptFountainDisplayRun> leading,
  List<OcptFountainDisplayRun> core,
  List<OcptFountainDisplayRun> trailing,
});

/// One clickable word of the sheet, painted per its [paint], its whole box (the glyphs, the
/// whitespace that follows them and [_ocptWordVerticalPadding] above and below) being the click
/// target.
///
/// The word is drawn from its printed display [runs] rather than from the source text it covers, so
/// the Fountain markers around it (`*italic*`, a forced line's leading character) are resolved into
/// real emphasis instead of being shown — exactly as the raw mode's paper preview resolves them.
/// The offsets the click reports are the source ones all the same, markers included.
class _OcptBreakdownWord extends StatelessWidget {
  /// The word's printed runs, whitespace and inline emphasis included.
  final List<OcptFountainDisplayRun> runs;

  /// Whether the element this word belongs to prints upper-cased.
  final bool isUppercase;

  /// The paper text style the word is typeset in, before its own runs' emphasis.
  final TextStyle style;

  /// How this word is painted.
  final _OcptBreakdownWordPaint paint;

  /// Called when the word is clicked, or null when it is not a click target at all — a version
  /// being previewed withholding the whole range interaction, or
  /// [_OcptBreakdownWordPaint.isBlocked] saying closing a range on it would overlap a live tag.
  final VoidCallback? onTap;

  /// Class constructor
  const _OcptBreakdownWord({
    required this.runs,
    required this.isUppercase,
    required this.style,
    required this.paint,
    required this.onTap,
  });

  /// Build the breakdown word as a [Tooltip].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final color = paint.color;

    // The box drawn behind the word (or its core), the text style worn inside it, and the tooltip.
    BoxDecoration? decoration;
    var insideStyle = style;
    String? tooltip;

    if (paint.isAccent) {
      decoration = BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(2),
      );
      insideStyle = insideStyle.copyWith(color: theme.colorScheme.onPrimary);
      // The anchor names its own gesture; a range's affordance is the popover already open over it.
      tooltip = paint.isPendingAnchor ? tr.breakdownPendingAnchorTooltip : null;
    } else if (paint.isBlocked) {
      insideStyle = insideStyle.copyWith(color: insideStyle.color?.withValues(alpha: 0.35));
      tooltip = tr.breakdownBlockedWordTooltip;
    } else {
      final background = color?.withValues(
        alpha: paint.isSelected ? _ocptBreakdownSelectedTagAlpha : _ocptBreakdownTagAlpha,
      );
      if (background != null) {
        decoration = BoxDecoration(
          color: background,
          border: paint.isSelected && color != null
              ? Border.all(color: color, width: _ocptBreakdownSelectedTagRingWidth)
              : null,
          borderRadius: BorderRadius.circular(2),
        );
      }
      if (paint.needsCheck) {
        insideStyle = insideStyle.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dashed,
          decorationColor: ocptWarningColor(context),
        );
      }
      final tooltipTargetName = paint.tooltipTargetName;
      if (tooltipTargetName != null) {
        tooltip = paint.needsCheck
            ? "$tooltipTargetName\n${tr.breakdownTagNeedsCheckTooltip}"
            : tooltipTargetName;
      }
    }

    // When a tag or range boundary trims an affix off this word, the box hugs the word core and the
    // affix sits outside it in the plain paper style; an interior or single-box word keeps its
    // whole wash (the bridging whitespace of a multi-word band included). A word with no box never
    // trims.
    final groups = decoration == null
        ? null
        : _trimmedRunGroups(paint.trimLeadingAffix, paint.trimTrailingAffix);

    final wordBody = groups != null
        ? _TrimmedBox(
            decoration: decoration!,
            insideStyle: insideStyle,
            style: style,
            isUppercase: isUppercase,
            groups: groups,
          )
        : Container(
            decoration: decoration,
            padding: const EdgeInsets.symmetric(vertical: _ocptWordVerticalPadding),
            child: Text.rich(
              TextSpan(
                children: [
                  for (final run in runs)
                    TextSpan(
                      text: isUppercase ? run.text.toUpperCase() : run.text,
                      style: ocptBreakdownRunStyleOf(run.style, insideStyle),
                    ),
                ],
              ),
              style: insideStyle,
            ),
          );

    final content = MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: wordBody),
    );

    if (tooltip == null) {
      return content;
    }

    return Tooltip(message: tooltip, child: content);
  }

  /// Get [runs] split into the leading affix, the word core, and the trailing affix the highlight
  /// box
  /// leaves outside itself — or null when there is nothing to trim (neither end asked for, no affix
  /// there, or the word holds no letter or digit to trim down to), in which case the caller wraps
  /// the whole word.
  ///
  /// [trimLeading]/[trimTrailing] say which ends this word is a boundary of; an affix is everything
  /// that is neither a letter nor a digit at that end — the punctuation the recorded span already
  /// drops through [ocptNonWordAffixLengthsOf], plus, at the trailing end, the whitespace a word's
  /// runs carry up to the next word. The split is on the word's own **displayed** characters
  /// (markers already hidden), so the highlight and the tag it stands for read the same passage
  /// without this widget reasoning in source offsets.
  _OcptTrimmedRuns? _trimmedRunGroups(bool trimLeading, bool trimTrailing) {
    if (!trimLeading && !trimTrailing) {
      return null;
    }

    final rawText = [for (final run in runs) run.text].join();
    final affixes = ocptNonWordAffixLengthsOf(rawText);
    final coreStart = trimLeading ? affixes.leadingLength : 0;
    final coreEnd = trimTrailing ? rawText.length - affixes.trailingLength : rawText.length;
    if (coreStart == 0 && coreEnd == rawText.length) {
      return null;
    }

    return (
      leading: _sliceRuns(0, coreStart),
      core: _sliceRuns(coreStart, coreEnd),
      trailing: _sliceRuns(coreEnd, rawText.length),
    );
  }

  /// Get [runs] restricted to the displayed characters in `[start, end)`, splitting any run that
  /// straddles a boundary and keeping each surviving piece's own emphasis.
  List<OcptFountainDisplayRun> _sliceRuns(int start, int end) {
    final slice = <OcptFountainDisplayRun>[];
    var position = 0;
    for (final run in runs) {
      final runStart = position;
      final runEnd = position + run.text.length;
      position = runEnd;

      final from = start > runStart ? start : runStart;
      final to = end < runEnd ? end : runEnd;
      if (from < to) {
        slice.add((text: run.text.substring(from - runStart, to - runStart), style: run.style));
      }
    }
    return slice;
  }
}

/// A word drawn with its highlight box ([decoration], its text in [insideStyle]) hugging
/// [groups]`.core` alone: the leading and trailing affixes sit outside the box in the plain paper
/// [style], so a boundary word reads over exactly the passage the highlight stands for.
class _TrimmedBox extends StatelessWidget {
  /// The box drawn behind the word core.
  final BoxDecoration decoration;

  /// The text style worn inside the box.
  final TextStyle insideStyle;

  /// The plain paper text style the affixes outside the box are typeset in.
  final TextStyle style;

  /// Whether the element this word belongs to prints upper-cased.
  final bool isUppercase;

  /// The word's runs split into the leading affix, the core and the trailing affix.
  final _OcptTrimmedRuns groups;

  /// Class constructor
  const _TrimmedBox({
    required this.decoration,
    required this.insideStyle,
    required this.style,
    required this.isUppercase,
    required this.groups,
  });

  /// Build the trimmed box as a [Text].
  @override
  Widget build(BuildContext context) {
    TextSpan plainSpan(OcptFountainDisplayRun run) => TextSpan(
      text: isUppercase ? run.text.toUpperCase() : run.text,
      style: ocptBreakdownRunStyleOf(run.style, style),
    );

    return Text.rich(
      TextSpan(
        children: [
          for (final run in groups.leading) plainSpan(run),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              decoration: decoration,
              padding: const EdgeInsets.symmetric(vertical: _ocptWordVerticalPadding),
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final run in groups.core)
                      TextSpan(
                        text: isUppercase ? run.text.toUpperCase() : run.text,
                        style: ocptBreakdownRunStyleOf(run.style, insideStyle),
                      ),
                  ],
                ),
                style: insideStyle,
              ),
            ),
          ),
          for (final run in groups.trailing) plainSpan(run),
        ],
      ),
      style: style,
    );
  }
}
