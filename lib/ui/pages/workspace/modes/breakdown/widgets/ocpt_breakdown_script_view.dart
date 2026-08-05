// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_pending_tag.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_tag_popover.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_fountain_line_display.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_search.dart';

/// A tagged word's target selected by the caret/list, exactly as the bloc's own state holds it:
/// `(kind, id)`.
typedef OcptBreakdownSelectedTargetRef = (OcptBreakdownTargetKind, String)?;

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

/// The width of the ring `OcptBreakdownScriptView` draws around a selected target's tagged words, in
/// logical pixels — what distinguishes the selection from the plain category wash every other tag
/// of the same category still carries.
const double _ocptBreakdownSelectedTagRingWidth = 1.5;

/// The vertical padding of a clickable word's own box, in logical pixels.
///
/// This is what makes the whole band around a word clickable rather than only the glyphs
/// themselves, and what makes a tagged range read as one continuous highlight: each word's box
/// carries the whitespace that follows it, so two consecutive tagged words leave no gap between
/// their two bands. Mirrors `OcptShotCoverageDialog`'s own `_ocptWordVerticalPadding`.
const double _ocptWordVerticalPadding = 2;

/// The breakdown mode's `centre`: the whole screenplay typeset on a simulated paper sheet, centred
/// and scrollable, in Courier Prime at its true screenplay indents — one sheet, its scenes running
/// on continuously the way the raw mode's own preview reads, rather than one scene at a time.
///
/// Built scene by scene from [OcptScriptWordLayout.of], sliced out of the whole screenplay text
/// with each [OcptBreakdownScene.charStart]/`charEnd`, and rendered through
/// [ocptFountainWordDisplayRuns] so every Fountain marker (emphasis, a forcing character, a scene
/// number) stays hidden. Every word of every non-heading block is its own click target, painted per
/// word exactly as `OcptShotCoverageDialog` renders its own — one `WidgetSpan` box per word, each
/// carrying the whitespace after it, so a multi-word tag reads as one continuous band rather than a
/// row of separate boxes.
///
/// A word overlapped by a live tag whose target still resolves paints with that target's own colour
/// (`OcptBreakdownTarget.color`), unless its legend key is in [hiddenLegendKeys] — hiding a category
/// (`OcptBreakdownCategoryLegend`) is a reading aid for this highlighting alone, so a hidden word
/// still selects its target on a click, it only stops painting. The tags of [selectedTargetRef]
/// additionally carry a ring. A tag whose `OcptBreakdownTag.needsCheck` is set is underlined in the
/// workspace's warning colour, composed with the category wash rather than replacing it. A tag whose
/// target has been dropped from the snapshot (`OcptBreakdownSnapshot.build`'s own doc comment: a
/// tombstoned catalogue row keeps its tag on the scene but drops it from the snapshot's targets) has
/// no colour to paint and is left plain, never crashing.
///
/// Clicking a word that overlaps a live tag whose target resolves reports that target upward through
/// [onTargetSelected], together with the scene the click happened in — never withheld, since
/// selecting writes nothing. Clicking any other word — one covered by no tag, or by a tag whose
/// target is gone — reports its own scene-relative offsets through [onWordClicked], which drives the
/// range interaction (`OcptBreakdownBloc._onWordClicked`): a first click opens [pendingTagAnchor], a
/// second one in the same scene closes it into [pendingTagRange], the cue this view reads to open
/// [OcptBreakdownTagPopover] — through [OcptBreakdownTagPopoverAnchor], anchored under the very word
/// the second click landed on — offering [candidates] to link to or an element category to create
/// from. [onWordClicked] is null while a version is being previewed, withholding the whole gesture
/// on a read-only project: a plain word then paints and reads exactly as before, it simply stops
/// being a click target. While [pendingTagAnchor] is open in a scene, a plain word whose range with
/// it would overlap a live tag of that scene is not a click target at all either — greyed out rather
/// than merely refused on click, so the user never discovers the refusal by trying it.
///
/// Only a scene's heading row stays row-level clickable, selecting that scene — shown with a tinted
/// accent bar and its own tagged-target count on the right, exactly as before this milestone.
class OcptBreakdownScriptView extends StatelessWidget {
  /// The screenplay's whole Fountain text, sliced scene by scene below.
  final String screenplayText;

  /// The scenes to typeset, in source order.
  final List<OcptBreakdownScene> scenes;

  /// `{(kind, id): target}`, forwarded to every scene's heading row for its own tagged-target
  /// count, and to every word to resolve the live tag (if any) covering it.
  final OcptBreakdownTargetsById targetById;

  /// The page setup the sheet is typeset with.
  final OcptPageSetup pageSetup;

  /// The id of the selected scene, or null if none is.
  final String? selectedSceneId;

  /// Called with a scene's id when its heading row is clicked.
  final ValueChanged<String> onSceneSelected;

  /// The legend keys currently hidden from this view's own highlighting
  /// (`OcptBreakdownCategoryLegend`).
  final Set<OcptBreakdownLegendKey> hiddenLegendKeys;

  /// The `(kind, id)` of the currently selected target, or null if none is — whose tagged words
  /// additionally carry a ring.
  final OcptBreakdownSelectedTargetRef selectedTargetRef;

  /// Called with a tagged word's target kind, its id and the id of the scene the click happened in,
  /// when a word overlapping a live tag whose target resolves is clicked.
  final void Function(OcptBreakdownTargetKind targetKind, String targetId, String sceneId)
  onTargetSelected;

  /// Called with a clicked word's own scene id and scene-relative start/end offsets, when the word
  /// is covered by no live tag or by one whose target is gone — or null while a version is being
  /// previewed, withholding the whole range interaction: no anchor can open, so no popover ever has
  /// a range to show either.
  final void Function(String sceneId, int wordStartOffset, int wordEndOffset)? onWordClicked;

  /// The first word clicked of a range not yet closed, or null while none is — the word it names is
  /// marked as such.
  final OcptBreakdownPendingTagAnchor? pendingTagAnchor;

  /// A range just closed by a second click, awaiting the popover's own answer, or null while none
  /// is — the cue to open [OcptBreakdownTagPopover] under the word that closed it.
  final OcptBreakdownPendingTagRange? pendingTagRange;

  /// The whole catalogue the popover searches, built once by the mode from the loaded snapshot
  /// (`ocptBreakdownSearchCandidatesOf`).
  final List<OcptBreakdownSearchCandidate> candidates;

  /// Called when the popover's own × close button, `Escape` or a tap outside it clears the pending
  /// range and the anchor alike.
  final VoidCallback onPopoverCancelled;

  /// Called with a match's own kind and id when one of the popover's match rows is clicked, linking
  /// the pending range to it.
  final void Function(OcptBreakdownTargetKind targetKind, String targetId) onPopoverTargetLinked;

  /// Called with a category and the popover's own field text when one of its category chips is
  /// clicked, creating a new element and tagging the pending range with it.
  final void Function(OcptElementCategory category, String name) onPopoverElementCreationRequested;

  /// Called when the popover's own `Open in Resources` action is clicked (shown only while its
  /// search comes back with no role and no set).
  final VoidCallback onOpenInResourcesRequested;

  /// Class constructor
  const OcptBreakdownScriptView({
    super.key,
    required this.screenplayText,
    required this.scenes,
    required this.targetById,
    required this.pageSetup,
    required this.selectedSceneId,
    required this.onSceneSelected,
    required this.hiddenLegendKeys,
    required this.selectedTargetRef,
    required this.onTargetSelected,
    required this.onWordClicked,
    required this.pendingTagAnchor,
    required this.pendingTagRange,
    required this.candidates,
    required this.onPopoverCancelled,
    required this.onPopoverTargetLinked,
    required this.onPopoverElementCreationRequested,
    required this.onOpenInResourcesRequested,
  });

  @override
  Widget build(BuildContext context) {
    if (scenes.isEmpty) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.fact_check_outlined,
        message: Tr.of(context).breakdownScenesEmptyHint,
      );
    }

    final theme = Theme.of(context);
    final previewLayout = OcptEditorPreviewLayout(metrics: pageSetup.toMetrics());

    return ColoredBox(
      color: theme.extension<OcptSpecificColors>()!.previewBackdrop,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Material(
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
                    for (final scene in scenes)
                      _OcptBreakdownSceneSheet(
                        scene: scene,
                        sceneText: _sceneTextOf(scene),
                        targetById: targetById,
                        previewLayout: previewLayout,
                        isSelected: scene.id == selectedSceneId,
                        onHeadingTapped: () => onSceneSelected(scene.id),
                        hiddenLegendKeys: hiddenLegendKeys,
                        selectedTargetRef: selectedTargetRef,
                        onTargetSelected: onTargetSelected,
                        onWordClicked: onWordClicked,
                        pendingTagAnchor: pendingTagAnchor,
                        pendingTagRange: pendingTagRange,
                        candidates: candidates,
                        onPopoverCancelled: onPopoverCancelled,
                        onPopoverTargetLinked: onPopoverTargetLinked,
                        onPopoverElementCreationRequested: onPopoverElementCreationRequested,
                        onOpenInResourcesRequested: onOpenInResourcesRequested,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [scene]'s own slice of [screenplayText], clamped to its bounds: the load that read [scenes]
  /// and the one that read [screenplayText] are the same snapshot read, so the offsets always fit,
  /// but a scene sliced this way is never worth a `RangeError` over.
  String _sceneTextOf(OcptBreakdownScene scene) {
    final start = scene.charStart.clamp(0, screenplayText.length);
    final end = scene.charEnd.clamp(start, screenplayText.length);
    return screenplayText.substring(start, end);
  }
}

/// One scene's sheet: its heading row, then every other block of its text, laid out exactly as the
/// raw mode's own preview lays the same text out.
class _OcptBreakdownSceneSheet extends StatelessWidget {
  /// The scene this sheet shows.
  final OcptBreakdownScene scene;

  /// [scene]'s own text, already sliced out of the screenplay.
  final String sceneText;

  /// `{(kind, id): target}`, forwarded from [OcptBreakdownScriptView].
  final OcptBreakdownTargetsById targetById;

  /// The pixel geometry the sheet is typeset with.
  final OcptEditorPreviewLayout previewLayout;

  /// Whether [scene] is the selected one.
  final bool isSelected;

  /// Called when the heading row is clicked.
  final VoidCallback onHeadingTapped;

  /// Forwarded from [OcptBreakdownScriptView].
  final Set<OcptBreakdownLegendKey> hiddenLegendKeys;

  /// Forwarded from [OcptBreakdownScriptView].
  final OcptBreakdownSelectedTargetRef selectedTargetRef;

  /// Forwarded from [OcptBreakdownScriptView].
  final void Function(OcptBreakdownTargetKind targetKind, String targetId, String sceneId)
  onTargetSelected;

  /// Forwarded from [OcptBreakdownScriptView].
  final void Function(String sceneId, int wordStartOffset, int wordEndOffset)? onWordClicked;

  /// Forwarded from [OcptBreakdownScriptView].
  final OcptBreakdownPendingTagAnchor? pendingTagAnchor;

  /// Forwarded from [OcptBreakdownScriptView].
  final OcptBreakdownPendingTagRange? pendingTagRange;

  /// Forwarded from [OcptBreakdownScriptView].
  final List<OcptBreakdownSearchCandidate> candidates;

  /// Forwarded from [OcptBreakdownScriptView].
  final VoidCallback onPopoverCancelled;

  /// Forwarded from [OcptBreakdownScriptView].
  final void Function(OcptBreakdownTargetKind targetKind, String targetId) onPopoverTargetLinked;

  /// Forwarded from [OcptBreakdownScriptView].
  final void Function(OcptElementCategory category, String name) onPopoverElementCreationRequested;

  /// Forwarded from [OcptBreakdownScriptView].
  final VoidCallback onOpenInResourcesRequested;

  /// Class constructor
  const _OcptBreakdownSceneSheet({
    required this.scene,
    required this.sceneText,
    required this.targetById,
    required this.previewLayout,
    required this.isSelected,
    required this.onHeadingTapped,
    required this.hiddenLegendKeys,
    required this.selectedTargetRef,
    required this.onTargetSelected,
    required this.onWordClicked,
    required this.pendingTagAnchor,
    required this.pendingTagRange,
    required this.candidates,
    required this.onPopoverCancelled,
    required this.onPopoverTargetLinked,
    required this.onPopoverElementCreationRequested,
    required this.onOpenInResourcesRequested,
  });

  @override
  Widget build(BuildContext context) {
    final layout = OcptScriptWordLayout.of(sceneId: scene.id, sceneText: sceneText);
    final targetCount = ocptBreakdownSceneTargetsOf(scene, targetById).length;

    return Padding(
      // The gap to the next scene's own heading: a scene's last block never sees the heading that
      // follows it (they belong to different `OcptScriptWordLayout`s), so this closes that gap the
      // way `isFollowedByBlankLine` closes every gap inside one scene's own blocks below.
      padding: EdgeInsets.only(bottom: previewLayout.blockSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < layout.blocks.length; i++)
            if (layout.blocks[i].type == FountainLineType.sceneHeading)
              _OcptBreakdownSceneHeadingBlock(
                block: layout.blocks[i],
                previewLayout: previewLayout,
                isSelected: isSelected,
                targetCount: targetCount,
                onTap: onHeadingTapped,
                isFollowedByBlankLine: _isFollowedByBlankLine(layout, i),
              )
            else
              _OcptBreakdownScriptBlock(
                scene: scene,
                block: layout.blocks[i],
                targetById: targetById,
                hiddenLegendKeys: hiddenLegendKeys,
                selectedTargetRef: selectedTargetRef,
                previewLayout: previewLayout,
                isFollowedByBlankLine: _isFollowedByBlankLine(layout, i),
                onTargetSelected: onTargetSelected,
                onWordClicked: onWordClicked,
                pendingTagAnchor: pendingTagAnchor,
                pendingTagRange: pendingTagRange,
                candidates: candidates,
                onPopoverCancelled: onPopoverCancelled,
                onPopoverTargetLinked: onPopoverTargetLinked,
                onPopoverElementCreationRequested: onPopoverElementCreationRequested,
                onOpenInResourcesRequested: onOpenInResourcesRequested,
              ),
        ],
      ),
    );
  }

  /// Whether [layout]'s block at [index] is followed by a blank source line — the only place the
  /// sheet leaves a vertical gap, mirroring `OcptShotCoverageDialog`'s own block spacing.
  bool _isFollowedByBlankLine(OcptScriptWordLayout layout, int index) =>
      index + 1 < layout.blocks.length &&
      layout.blocks[index + 1].startOffset - layout.blocks[index].endOffset > 1;
}

/// A scene's heading row: clickable, tinted with the accent wash while [OcptBreakdownScriptView]'s
/// selection names this scene, and carrying its own tagged-target count on the right.
class _OcptBreakdownSceneHeadingBlock extends StatelessWidget {
  /// The heading's own block.
  final OcptScriptWordBlock block;

  /// The pixel geometry the sheet is typeset with.
  final OcptEditorPreviewLayout previewLayout;

  /// Whether this heading's scene is the selected one.
  final bool isSelected;

  /// The number of distinct targets tagged in this heading's scene.
  final int targetCount;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Whether the source leaves a blank line right after this heading.
  final bool isFollowedByBlankLine;

  /// Class constructor
  const _OcptBreakdownSceneHeadingBlock({
    required this.block,
    required this.previewLayout,
    required this.isSelected,
    required this.targetCount,
    required this.onTap,
    required this.isFollowedByBlankLine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final element = previewLayout.metrics.sceneHeading;
    final printStyle = FountainPrintStyle.of(FountainLineType.sceneHeading);
    final baseStyle = TextStyle(
      fontFamily: OcptEditorPreviewLayout.fontFamily,
      fontSize: OcptEditorPreviewLayout.fontSize,
      height: previewLayout.lineHeightFactor,
      color: Colors.black,
      fontWeight: printStyle.isBold ? FontWeight.bold : null,
      fontStyle: printStyle.isItalic ? FontStyle.italic : null,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isFollowedByBlankLine ? previewLayout.blockSpacing : 0),
      child: InkWell(
        onTap: onTap,
        mouseCursor: ocptClickableCursor,
        child: Container(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : null,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 3,
                height: previewLayout.lineHeight,
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: previewLayout.indentOf(element)),
                  child: Text.rich(
                    TextSpan(children: _spansOf(block, printStyle.isUppercase, baseStyle)),
                    style: baseStyle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: Text(
                  tr.breakdownSceneElementsCount(targetCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One non-heading block of the sheet: every word its own click target, painted per the live tag
/// (if any) covering it — see [OcptBreakdownScriptView]'s own doc comment for the painting and
/// click-routing rules this class implements.
class _OcptBreakdownScriptBlock extends StatelessWidget {
  /// The scene this block belongs to, whose [OcptBreakdownScene.tags] every word is resolved
  /// against.
  final OcptBreakdownScene scene;

  /// The block rendered.
  final OcptScriptWordBlock block;

  /// `{(kind, id): target}`, forwarded from [OcptBreakdownScriptView].
  final OcptBreakdownTargetsById targetById;

  /// Forwarded from [OcptBreakdownScriptView].
  final Set<OcptBreakdownLegendKey> hiddenLegendKeys;

  /// Forwarded from [OcptBreakdownScriptView].
  final OcptBreakdownSelectedTargetRef selectedTargetRef;

  /// The pixel geometry the sheet is typeset with.
  final OcptEditorPreviewLayout previewLayout;

  /// Whether the source leaves a blank line right after this block.
  final bool isFollowedByBlankLine;

  /// Forwarded from [OcptBreakdownScriptView].
  final void Function(OcptBreakdownTargetKind targetKind, String targetId, String sceneId)
  onTargetSelected;

  /// Forwarded from [OcptBreakdownScriptView].
  final void Function(String sceneId, int wordStartOffset, int wordEndOffset)? onWordClicked;

  /// Forwarded from [OcptBreakdownScriptView].
  final OcptBreakdownPendingTagAnchor? pendingTagAnchor;

  /// Forwarded from [OcptBreakdownScriptView].
  final OcptBreakdownPendingTagRange? pendingTagRange;

  /// Forwarded from [OcptBreakdownScriptView].
  final List<OcptBreakdownSearchCandidate> candidates;

  /// Forwarded from [OcptBreakdownScriptView].
  final VoidCallback onPopoverCancelled;

  /// Forwarded from [OcptBreakdownScriptView].
  final void Function(OcptBreakdownTargetKind targetKind, String targetId) onPopoverTargetLinked;

  /// Forwarded from [OcptBreakdownScriptView].
  final void Function(OcptElementCategory category, String name) onPopoverElementCreationRequested;

  /// Forwarded from [OcptBreakdownScriptView].
  final VoidCallback onOpenInResourcesRequested;

  /// Class constructor
  const _OcptBreakdownScriptBlock({
    required this.scene,
    required this.block,
    required this.targetById,
    required this.hiddenLegendKeys,
    required this.selectedTargetRef,
    required this.previewLayout,
    required this.isFollowedByBlankLine,
    required this.onTargetSelected,
    required this.onWordClicked,
    required this.pendingTagAnchor,
    required this.pendingTagRange,
    required this.candidates,
    required this.onPopoverCancelled,
    required this.onPopoverTargetLinked,
    required this.onPopoverElementCreationRequested,
    required this.onOpenInResourcesRequested,
  });

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
          padding: EdgeInsets.only(left: previewLayout.indentOf(element)),
          child: SizedBox(
            width: previewLayout.widthOf(element),
            child: Text.rich(
              TextSpan(
                children: [
                  for (var i = 0; i < block.words.length; i++)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: _wordWidgetAt(block.words[i], displayRuns[i], printStyle, baseStyle),
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

  /// The live tag of [scene] covering [word], or null if none does.
  ///
  /// Tags never overlap (breakdown plan §3.9), so at most one can ever cover a given word.
  OcptBreakdownTag? _tagCovering(OcptScriptWord word) {
    for (final tag in scene.tags) {
      if (tag.startOffset < word.endOffset && tag.endOffset > word.startOffset) {
        return tag;
      }
    }
    return null;
  }

  /// Whether [word] is the very word [pendingTagAnchor] names in this scene.
  bool _isPendingAnchor(OcptScriptWord word) {
    final anchor = pendingTagAnchor;
    return anchor != null &&
        anchor.sceneId == scene.id &&
        anchor.wordStartOffset == word.startOffset &&
        anchor.wordEndOffset == word.endOffset;
  }

  /// Whether [word] is the exact word [pendingTagRange] closed on — where
  /// [OcptBreakdownTagPopoverAnchor] mounts the popover.
  bool _isPopoverAnchorWord(OcptScriptWord word) {
    final range = pendingTagRange;
    return range != null &&
        range.sceneId == scene.id &&
        range.closingWordStartOffset == word.startOffset &&
        range.closingWordEndOffset == word.endOffset;
  }

  /// Whether closing a range between [pendingTagAnchor] and [word] would overlap a live tag of
  /// [scene] — computed cheaply, straight over the scene's own (typically short) tag list, exactly
  /// as `OcptBreakdownBloc._onWordClicked` itself refuses the same overlap. False while no anchor is
  /// open in this scene, or for a word already covered by a live tag: a tagged word is never this
  /// kind of click target to begin with, it is always ordinary tagged word instead.
  bool _isBlockedByAnchor(OcptScriptWord word) {
    final anchor = pendingTagAnchor;
    if (anchor == null || anchor.sceneId != scene.id) {
      return false;
    }

    final startOffset = anchor.wordStartOffset <= word.startOffset
        ? anchor.wordStartOffset
        : word.startOffset;
    final endOffset = anchor.wordEndOffset >= word.endOffset ? anchor.wordEndOffset : word.endOffset;

    return scene.tags.any((tag) => startOffset < tag.endOffset && tag.startOffset < endOffset);
  }

  /// How [word] is painted: the tagged rules `OcptBreakdownScriptView`'s own doc comment describes,
  /// then — for a plain word — the pending anchor's own distinct mark, then the greyed-out mark of a
  /// word blocked by it, and plain otherwise.
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
      );
    }

    if (_isPendingAnchor(word)) {
      return _OcptBreakdownWordPaint.pendingAnchor;
    }

    if (_isBlockedByAnchor(word)) {
      return _OcptBreakdownWordPaint.blocked;
    }

    return _OcptBreakdownWordPaint.plain;
  }

  /// [word]'s own click callback: its tag's target through [onTargetSelected] when one resolves —
  /// selecting it, and (per `OcptBreakdownBloc._onTargetSelected`) the scene the click happened in,
  /// so the left dock and the sheet stay in step — never null, since selecting writes nothing. A
  /// hidden legend key never changes this: hiding a category withholds its paint, not its click.
  ///
  /// Otherwise null while [onWordClicked] itself is (a previewed version withholding the whole range
  /// interaction) or while [_isBlockedByAnchor] says so — neither is a click target at all, not
  /// merely one whose click is refused — and [onWordClicked] with the word's own scene-relative
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

  /// The widget rendered for [word] at its [runs]/[printStyle]/[baseStyle]: the plain click target,
  /// or — for the one word [_isPopoverAnchorWord] names — that same target anchoring
  /// [OcptBreakdownTagPopover] under it through [OcptBreakdownTagPopoverAnchor].
  Widget _wordWidgetAt(
    OcptScriptWord word,
    List<OcptFountainDisplayRun> runs,
    FountainPrintStyle printStyle,
    TextStyle baseStyle,
  ) {
    final wordWidget = _OcptBreakdownWord(
      runs: runs,
      isUppercase: printStyle.isUppercase,
      style: baseStyle,
      paint: _paintOf(word),
      onTap: _onTapFor(word),
    );

    if (!_isPopoverAnchorWord(word)) {
      return wordWidget;
    }

    final range = pendingTagRange!;
    return OcptBreakdownTagPopoverAnchor(
      popover: OcptBreakdownTagPopover(
        taggedText: range.taggedText,
        candidates: candidates,
        onCandidateSelected: (candidate) => onPopoverTargetLinked(candidate.kind, candidate.id),
        onCategorySelected: onPopoverElementCreationRequested,
        onOpenInResourcesRequested: onOpenInResourcesRequested,
        onClose: onPopoverCancelled,
      ),
      child: wordWidget,
    );
  }
}

/// The screenplay layout box a line of [type] is typeset in, mirroring
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

/// The horizontal alignment [element] is typeset with.
TextAlign _textAlignOf(FountainElementLayout element) => switch (element.alignment) {
  FountainLayoutAlignment.center => TextAlign.center,
  FountainLayoutAlignment.right => TextAlign.right,
  FountainLayoutAlignment.left => TextAlign.left,
};

/// [block]'s printed words, flattened into one run of spans: every Fountain marker hidden, every
/// inline emphasis applied on top of [base]. Used for the heading row alone, which stays row-level
/// clickable rather than word-level — every other block renders through [_OcptBreakdownWord]
/// instead, one per word, so a tag can hang its own click target and its own highlight off it.
List<InlineSpan> _spansOf(OcptScriptWordBlock block, bool isUppercase, TextStyle base) => [
  for (final wordRuns in ocptFountainWordDisplayRuns(block))
    for (final run in wordRuns)
      TextSpan(text: isUppercase ? run.text.toUpperCase() : run.text, style: _runStyleOf(run.style, base)),
];

/// Applies a run's own inline emphasis on top of [base], mirroring `OcptShotCoverageDialog`'s own
/// `_styleOf`.
TextStyle _runStyleOf(FountainInlineStyle style, TextStyle base) => switch (style) {
  FountainInlineStyle.italic => base.copyWith(fontStyle: FontStyle.italic),
  FountainInlineStyle.bold => base.copyWith(fontWeight: FontWeight.bold),
  FountainInlineStyle.boldItalic => base.copyWith(
    fontWeight: FontWeight.bold,
    fontStyle: FontStyle.italic,
  ),
  FountainInlineStyle.underline => base.copyWith(decoration: TextDecoration.underline),
  // A note never reaches here: `ocptFountainWordDisplayRuns` drops its text entirely.
  FountainInlineStyle.plain || FountainInlineStyle.note => base,
};

/// How one word of the sheet is painted, decided once by `_OcptBreakdownScriptBlock` per word from
/// its own tag (if any) — see that class's own `_paintOf` for the rules.
class _OcptBreakdownWordPaint {
  /// The tagged target's own colour, or null for a plain word (untagged, or its target gone) and for
  /// the two transient marks below, which never use a category colour.
  final Color? color;

  /// Whether this word's tag belongs to the currently selected target.
  final bool isSelected;

  /// Whether this word's tag needs a check (`OcptBreakdownTag.needsCheck`).
  final bool needsCheck;

  /// The tagged target's own name, shown as this word's tooltip — null for a plain word.
  final String? tooltipTargetName;

  /// Whether this word is the pending anchor of a range not yet closed — a distinct, obviously
  /// transient mark, never a category colour, since the anchor itself is not yet any category at
  /// all.
  final bool isPendingAnchor;

  /// Whether this word is not a click target because closing a range on it, from the pending
  /// anchor, would overlap a live tag — greyed out rather than merely refused on click.
  final bool isBlocked;

  /// Class constructor
  const _OcptBreakdownWordPaint({
    this.color,
    this.isSelected = false,
    this.needsCheck = false,
    this.tooltipTargetName,
    this.isPendingAnchor = false,
    this.isBlocked = false,
  });

  /// A plain word: no tag, or one whose target does not resolve.
  static const plain = _OcptBreakdownWordPaint();

  /// The first word clicked of a range not yet closed.
  static const pendingAnchor = _OcptBreakdownWordPaint(isPendingAnchor: true);

  /// A word that would overlap a live tag if the pending anchor's range closed on it.
  static const blocked = _OcptBreakdownWordPaint(isBlocked: true);
}

/// One clickable word of the sheet, painted per its [paint], its whole box (the glyphs, the
/// whitespace that follows them and [_ocptWordVerticalPadding] above and below) being the click
/// target.
///
/// The word is drawn from its printed display [runs] rather than from the source text it covers, so
/// the Fountain markers around it (`*italic*`, a forced line's leading character) are resolved into
/// real emphasis instead of being shown — exactly as the raw mode's paper preview resolves them. The
/// offsets the click reports are the source ones all the same, markers included.
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
  /// being previewed withholding the whole range interaction, or [_OcptBreakdownWordPaint.isBlocked]
  /// saying closing a range on it would overlap a live tag.
  final VoidCallback? onTap;

  /// Class constructor
  const _OcptBreakdownWord({
    required this.runs,
    required this.isUppercase,
    required this.style,
    required this.paint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final color = paint.color;

    Color? background;
    var textStyle = style;
    String? tooltip;

    if (paint.isPendingAnchor) {
      background = theme.colorScheme.primary;
      textStyle = textStyle.copyWith(color: theme.colorScheme.onPrimary);
      tooltip = tr.breakdownPendingAnchorTooltip;
    } else if (paint.isBlocked) {
      textStyle = textStyle.copyWith(color: textStyle.color?.withValues(alpha: 0.35));
      tooltip = tr.breakdownBlockedWordTooltip;
    } else {
      background = color?.withValues(
        alpha: paint.isSelected ? _ocptBreakdownSelectedTagAlpha : _ocptBreakdownTagAlpha,
      );
      if (paint.needsCheck) {
        textStyle = textStyle.copyWith(
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

    final content = MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            border: paint.isSelected && color != null
                ? Border.all(color: color, width: _ocptBreakdownSelectedTagRingWidth)
                : null,
            borderRadius: BorderRadius.circular(2),
          ),
          padding: const EdgeInsets.symmetric(vertical: _ocptWordVerticalPadding),
          child: Text.rich(
            TextSpan(
              children: [
                for (final run in runs)
                  TextSpan(
                    text: isUppercase ? run.text.toUpperCase() : run.text,
                    style: _runStyleOf(run.style, textStyle),
                  ),
              ],
            ),
            style: textStyle,
          ),
        ),
      ),
    );

    if (tooltip == null) {
      return content;
    }

    return Tooltip(message: tooltip, child: content);
  }
}
