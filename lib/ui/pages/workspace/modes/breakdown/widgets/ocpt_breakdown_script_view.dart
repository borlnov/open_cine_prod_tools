// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_scene_bars.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_search_candidate.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_responsive.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_pending_tag.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_heading_block.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_script_block.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_selected_target_ref.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_tag_popover.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_fountain_line_display.dart';

export 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_selected_target_ref.dart';

/// The vertical padding kept inside the white sheet on a phone, replacing the page's own (much
/// larger) top/bottom print margins: the compact sheet fills the row and stands in for the
/// desktop's floating page, so it wants the screenplay editor's own small fluid inset rather than a
/// full inch of paper margin before the first scene.
const double _ocptCompactSheetVerticalPadding = 16;

/// The breakdown mode's `centre`: the whole screenplay typeset on a simulated paper sheet, centred
/// and scrollable, in Courier Prime at its true screenplay indents — one sheet, its scenes running
/// on continuously the way the raw mode's own preview reads, rather than one scene at a time.
///
/// On a phone the sheet fills the row instead of floating at its fixed page width, and every indent
/// and box width is scaled down by [OcptEditorPreviewLayout.compactLayoutScale] — the same factor
/// the screenplay editor's own compact fluid surface uses, so the tagging surface reads the way the
/// writing one does there rather than wasting most of the row on the print margin.
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
/// (`OcptBreakdownTarget.color`), unless its legend key is in [hiddenLegendKeys] — hiding a
/// category (`OcptBreakdownCategoryLegend`) is a reading aid for this highlighting alone, so a
/// hidden word still selects its target on a click, it only stops painting. The tags of
/// [selectedTargetRef] additionally carry a ring. A tag whose `OcptBreakdownTag.needsCheck` is set
/// is underlined in the workspace's warning colour, composed with the category wash rather than
/// replacing it. A tag whose target has been dropped from the snapshot
/// (`OcptBreakdownSnapshot.build`'s own doc comment: a tombstoned catalogue row keeps its tag on
/// the scene but drops it from the snapshot's targets) has no colour to paint and is left plain,
/// never crashing.
///
/// Clicking a word that overlaps a live tag whose target resolves reports that target upward
/// through [onTargetSelected], together with the scene the click happened in — never withheld,
/// since selecting writes nothing. Clicking any other word — one covered by no tag, or by a tag
/// whose target is gone — reports its own scene-relative offsets through [onWordClicked], which
/// drives the range interaction (`OcptBreakdownBloc._onWordClicked`): a first click opens
/// [pendingTagAnchor], a second one in the same scene closes it into [pendingTagRange], the cue
/// this view reads to open [OcptBreakdownTagPopover] — through [OcptBreakdownTagPopoverAnchor],
/// anchored under the very word the second click landed on — offering [candidates] to link to or an
/// element category to create from. [onWordClicked] is null while a version is being previewed,
/// withholding the whole gesture on a read-only project: a plain word then paints and reads exactly
/// as before, it simply stops being a click target. While [pendingTagAnchor] is open in a scene, a
/// plain word whose range with it would overlap a live tag of that scene is not a click target at
/// all either — greyed out rather than merely refused on click, so the user never discovers the
/// refusal by trying it.
///
/// Only a scene's heading row stays row-level clickable, selecting that scene — shown with a tinted
/// accent bar and its own tagged-target count on the right.
///
/// While a range selection is open (a first click with no second yet), pressing `Escape` or
/// clicking the sheet away from any word abandons it through [onSelectionCancelled]: a lone anchor
/// used to have no way out but to close a range and cancel its popover.
class OcptBreakdownScriptView extends StatefulWidget {
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

  /// Every location of the project, `(id, name)`, offered by the popover's own `Create a set`
  /// control as the place a new set goes into.
  final List<(String, String)> locations;

  /// Called with the location a new set belongs to — null for one minted along with it — and the
  /// popover's own field text, creating that set and tagging the pending range with it.
  final void Function(String? locationId, String name) onPopoverSetCreationRequested;

  /// Called when the popover's own `Open in Resources` action is clicked (shown only while its
  /// search comes back with no role and no set).
  final VoidCallback onOpenInResourcesRequested;

  /// Called when a pending range selection — a first click still waiting for its second — should be
  /// abandoned: the user pressed `Escape`, or clicked the sheet away from any word. It clears the
  /// anchor through the very same `OcptBreakdownTagRangeCancelledEvent` the popover's own
  /// `Escape`/tap-outside uses, so cancelling a lone anchor and cancelling the popover are one
  /// path.
  final VoidCallback onSelectionCancelled;

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
    required this.locations,
    required this.onPopoverSetCreationRequested,
    required this.onOpenInResourcesRequested,
    required this.onSelectionCancelled,
  });

  /// Create the [_OcptBreakdownScriptViewState] holding the state of the breakdown script view.
  @override
  State<OcptBreakdownScriptView> createState() => _OcptBreakdownScriptViewState();
}

/// [OcptBreakdownScriptView]'s state: it owns a single [FocusNode] so that, while a range selection
/// is open (a first click with no second yet), `Escape` can abandon it. The node takes focus the
/// moment such an anchor opens and never on its own otherwise, so it steals nothing from a field
/// the user is typing in until they have actually started a selection on the sheet.
class _OcptBreakdownScriptViewState extends State<OcptBreakdownScriptView> {
  /// Focused only while a range selection is open, purely to catch its `Escape`; it takes part in
  /// no traversal, so `Tab` never lands on it.
  final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: "OcptBreakdownScriptViewKeyboard",
    skipTraversal: true,
  );

  /// Whether a first click has opened a selection that no second click has closed yet — the one
  /// state in which `Escape` and a click away from a word abandon it (once the range is closed the
  /// popover owns those gestures instead).
  bool get _hasOpenSelection => widget.pendingTagAnchor != null && widget.pendingTagRange == null;

  /// Take the keyboard focus after the first frame when the view opens onto an open selection.
  @override
  void initState() {
    super.initState();
    // The view normally opens onto no selection and grabs focus only once one opens (below), but a
    // rebuild from scratch straight onto an open selection must catch its `Escape` all the same.
    if (_hasOpenSelection) {
      _grabKeyboardFocusAfterFrame();
    }
  }

  /// Take the keyboard focus after the frame when a selection has just opened.
  @override
  void didUpdateWidget(covariant OcptBreakdownScriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hadOpenSelection =
        oldWidget.pendingTagAnchor != null && oldWidget.pendingTagRange == null;
    if (_hasOpenSelection && !hadOpenSelection) {
      _grabKeyboardFocusAfterFrame();
    }
  }

  /// Build the breakdown script view as a [Focus].
  @override
  Widget build(BuildContext context) {
    if (widget.scenes.isEmpty) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.fact_check_outlined,
        message: Tr.of(context).breakdownScenesEmptyHint,
      );
    }

    final theme = Theme.of(context);
    final previewLayout = OcptEditorPreviewLayout(metrics: widget.pageSetup.toMetrics());
    // On a phone the real screenplay indents (a character cue ≈ 3.7″ from the page's left edge)
    // leave far too much margin to read, and the full page is wider than the row: the sheet fills
    // the row and every indent and box width is scaled down by the same factor the screenplay
    // editor's own compact fluid surface uses (`OcptFountainEditorStylesheet`), so the two read
    // identically.
    final isPhone = ocptIsPhoneWidth(MediaQuery.sizeOf(context).width);
    final layoutScale = isPhone ? OcptEditorPreviewLayout.compactLayoutScale : 1.0;

    return Focus(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _onKeyEvent,
      child: GestureDetector(
        // A tap that reaches here fell on the sheet away from every word — each word's own box is
        // an opaque tap target that wins the arena first — so while a selection is open, this is
        // the click to nowhere that abandons it. Translucent, so a tap over the blank paper or the
        // grey backdrop around it is caught all the same.
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_hasOpenSelection) {
            widget.onSelectionCancelled();
          }
        },
        child: ColoredBox(
          color: theme.extension<OcptSpecificColors>()!.previewBackdrop,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sheetWidth = isPhone ? constraints.maxWidth : previewLayout.pageWidth;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(3),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: sheetWidth,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: isPhone ? _ocptCompactSheetVerticalPadding : previewLayout.marginTop,
                          bottom: isPhone
                              ? _ocptCompactSheetVerticalPadding
                              : previewLayout.marginBottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final scene in widget.scenes)
                              _OcptBreakdownSceneSheet(
                                scene: scene,
                                sceneText: _sceneTextOf(scene),
                                targetById: widget.targetById,
                                previewLayout: previewLayout,
                                layoutScale: layoutScale,
                                isSelected: scene.id == widget.selectedSceneId,
                                onHeadingTapped: () => widget.onSceneSelected(scene.id),
                                hiddenLegendKeys: widget.hiddenLegendKeys,
                                selectedTargetRef: widget.selectedTargetRef,
                                onTargetSelected: widget.onTargetSelected,
                                onWordClicked: widget.onWordClicked,
                                pendingTagAnchor: widget.pendingTagAnchor,
                                pendingTagRange: widget.pendingTagRange,
                                candidates: widget.candidates,
                                onPopoverCancelled: widget.onPopoverCancelled,
                                onPopoverTargetLinked: widget.onPopoverTargetLinked,
                                onPopoverElementCreationRequested:
                                    widget.onPopoverElementCreationRequested,
                                locations: widget.locations,
                                onPopoverSetCreationRequested: widget.onPopoverSetCreationRequested,
                                onOpenInResourcesRequested: widget.onOpenInResourcesRequested,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Focuses [_keyboardFocusNode] once the current frame is done, so an open selection's `Escape`
  /// reaches it — deferred a frame because the node is not yet attached to the tree during the
  /// build that opens the selection.
  void _grabKeyboardFocusAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hasOpenSelection) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  /// Abandons an open selection on `Escape`, letting every other key (and every `Escape` while no
  /// selection is open) fall through untouched.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _hasOpenSelection) {
      widget.onSelectionCancelled();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// [scene]'s own slice of the screenplay text, clamped to its bounds: the load that read the
  /// scenes and the one that read the text are the same snapshot read, so the offsets always fit,
  /// but a scene sliced this way is never worth a `RangeError` over.
  String _sceneTextOf(OcptBreakdownScene scene) {
    final start = scene.charStart.clamp(0, widget.screenplayText.length);
    final end = scene.charEnd.clamp(start, widget.screenplayText.length);
    return widget.screenplayText.substring(start, end);
  }

  /// Dispose [_keyboardFocusNode].
  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
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

  /// The multiplier every indent and box width is scaled by — 1 on the desktop, the compact factor
  /// on a phone (`OcptEditorPreviewLayout.compactLayoutScale`).
  final double layoutScale;

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

  /// Every location of the project, `(id, name)`, offered by the popover's own `Create a set`
  /// control as the place a new set goes into.
  final List<(String, String)> locations;

  /// Called with the location a new set belongs to — null for one minted along with it — and the
  /// popover's own field text, creating that set and tagging the pending range with it.
  final void Function(String? locationId, String name) onPopoverSetCreationRequested;

  /// Forwarded from [OcptBreakdownScriptView].
  final VoidCallback onOpenInResourcesRequested;

  /// Class constructor
  const _OcptBreakdownSceneSheet({
    required this.scene,
    required this.sceneText,
    required this.targetById,
    required this.previewLayout,
    required this.layoutScale,
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
    required this.locations,
    required this.onPopoverSetCreationRequested,
    required this.onOpenInResourcesRequested,
  });

  /// Build the breakdown scene sheet as a [Padding].
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
              OcptBreakdownSceneHeadingBlock(
                block: layout.blocks[i],
                previewLayout: previewLayout,
                layoutScale: layoutScale,
                isSelected: isSelected,
                targetCount: targetCount,
                onTap: onHeadingTapped,
                isFollowedByBlankLine: _isFollowedByBlankLine(layout, i),
              )
            else
              OcptBreakdownScriptBlock(
                scene: scene,
                block: layout.blocks[i],
                targetById: targetById,
                hiddenLegendKeys: hiddenLegendKeys,
                selectedTargetRef: selectedTargetRef,
                previewLayout: previewLayout,
                layoutScale: layoutScale,
                isFollowedByBlankLine: _isFollowedByBlankLine(layout, i),
                onTargetSelected: onTargetSelected,
                onWordClicked: onWordClicked,
                pendingTagAnchor: pendingTagAnchor,
                pendingTagRange: pendingTagRange,
                candidates: candidates,
                onPopoverCancelled: onPopoverCancelled,
                onPopoverTargetLinked: onPopoverTargetLinked,
                onPopoverElementCreationRequested: onPopoverElementCreationRequested,
                locations: locations,
                onPopoverSetCreationRequested: onPopoverSetCreationRequested,
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
