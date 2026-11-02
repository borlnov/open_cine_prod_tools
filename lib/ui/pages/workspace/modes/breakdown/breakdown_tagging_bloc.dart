// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_tag_span.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_pending_tag.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_tagging_state.dart';

/// This is the bloc class for the breakdown mode's script tagging: the range interaction of the
/// script view, the popover it opens and the writes that answer it.
///
/// The snapshot, and which scene and which target are selected, are the mode's. This bloc owns
/// what the script view does with them: [OcptBreakdownTaggingState.pendingTagAnchor] and
/// [OcptBreakdownTaggingState.pendingTagRange], and every tag write (the service, then
/// `await modeBloc.reload(…)`, then the move of the mode's selection, then the bloc's own emit).
///
/// [_onWordClicked] owns the range interaction: a first click opens the anchor (selecting its
/// scene), a second one in the same scene closes it into the range — the script view's own cue to
/// open the tag popover — and [_onPopoverTargetLinked]/[_onPopoverElementCreationRequested]/
/// [_onPopoverSetCreationRequested] are the popover's three ways of answering it, all ending the
/// same way: the snapshot is read again, the linked or newly created target is selected on the
/// `Inspector` tab, the popover closes and the anchor clears. [_onSuggestionAccepted] is the
/// target inspector's own route onto the same service, and leaves the selection where it is.
///
/// **Reacting.** A scene or a target being selected clears nothing here: an anchor opened in one
/// scene is replaced by the next click, not by the user browsing the left dock. When the mode reads
/// everything again (entry, a version preview or a restore) the anchor, the range and the notice
/// are dropped, the script they were scoped to being another one; when the centre leaves the script
/// view (the header's switch, or a search typed from the script) the anchor and the range are
/// dropped, the popover having no sheet left to close over. An ordinary re-read after a write
/// clears nothing.
class OcptBreakdownTaggingBloc
    extends AbsOcptViewBloc<OcptBreakdownTaggingState, OcptBreakdownState, OcptBreakdownBloc> {
  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to write a tag, with the element or the set it creates.
  final OcptBreakdownService _breakdownService;

  /// {@macro open_cine_prod_tools.viewBlocConstructor}
  OcptBreakdownTaggingBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptBreakdownService? breakdownService,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _breakdownService =
           breakdownService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).breakdownService,
       super(const OcptBreakdownTaggingState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBreakdownWordClickedEvent>(_onWordClicked);
    on<OcptBreakdownTagRangeCancelledEvent>(_onTagRangeCancelled);
    on<OcptBreakdownPopoverTargetLinkedEvent>(_onPopoverTargetLinked);
    on<OcptBreakdownPopoverElementCreationRequestedEvent>(_onPopoverElementCreationRequested);
    on<OcptBreakdownPopoverSetCreationRequestedEvent>(_onPopoverSetCreationRequested);
    on<OcptBreakdownTagWriteErrorDismissedEvent>(_onTagWriteErrorDismissed);
    on<OcptBreakdownSuggestionAcceptedEvent>(_onSuggestionAccepted);
  }

  /// Drop what the mode's selection move leaves without a script to belong to.
  ///
  /// `OcptBreakdownSelectionCause.load` (entry, a version preview or a restore) drops the anchor,
  /// the range and the notice; `OcptBreakdownSelectionCause.centreView` (the centre leaving the
  /// script) drops the anchor and the range. Every other move, a scene or a target selected, clears
  /// nothing, and a data re-read alone never does.
  ///
  /// Reads the cause from the state that moved the epoch (`event.modeState`). Waits for nothing:
  /// the mode's change and this reaction must land in the same turn of the event loop.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptBreakdownState> event,
    Emitter<OcptBreakdownTaggingState> emitter,
  ) async {
    if (!event.hasSelectionMoved) {
      return;
    }

    switch (event.modeState.selectionCause) {
      case OcptBreakdownSelectionCause.load:
        emitter(state.copyWithTagInteractionReset());
      case OcptBreakdownSelectionCause.centreView:
        emitter(state.copyWithPendingTagCleared());
      case OcptBreakdownSelectionCause.none ||
          OcptBreakdownSelectionCause.scene ||
          OcptBreakdownSelectionCause.sceneHeading ||
          OcptBreakdownSelectionCause.target ||
          OcptBreakdownSelectionCause.targetCleared ||
          OcptBreakdownSelectionCause.anchorScene:
        return;
    }
  }

  /// Record a click on a plain word of the script view — one that overlaps no live tag, or one
  /// whose tag's target has been dropped from the snapshot — driving the range interaction:
  ///
  /// - **no pending anchor, or one belonging to another scene**: this word becomes the (new)
  ///   anchor, and its scene becomes the selected one — a tag belongs to one scene, so an anchor
  ///   spanning two would mean nothing;
  /// - **an anchor already open in this very scene**: the range closes on the two words,
  ///   order-insensitive exactly as `OcptScriptWordLayout.rangeBetween` is (the smaller start, the
  ///   larger end), unless it would overlap a live tag of the scene — the script view already greys
  ///   such a word out of the click target it builds, but a click that reaches here regardless (a
  ///   stale one, or a direct test) is refused the same way `OcptBreakdownService.createTag` itself
  ///   would refuse it, and the anchor is kept rather than cleared, so the user can try a different
  ///   second click without starting over. Otherwise the range is recorded as
  ///   [OcptBreakdownTaggingState.pendingTagRange] — narrowed by [ocptBreakdownTaggedSpanOf] to the
  ///   words themselves, the punctuation a clicked word is written against being the sentence's
  ///   rather than the tagged thing's, then sliced verbatim out of the scene's own text — which is
  ///   the script view's cue to open the popover, anchored under this very word.
  ///
  /// The overlap above is checked on the clicked words' own bounds rather than on that narrowed
  /// span, exactly as the script view greys a word out on them: the span can only ever be narrower,
  /// so a range this refuses is one `OcptBreakdownService.createTag` would refuse too.
  ///
  /// Ignored outright while a version is being previewed (the mode never wires this callback then,
  /// so this only guards a direct call reaching past that) or while a range is already closed and
  /// awaiting the popover's own answer: a further click on the sheet behind an open popover means
  /// nothing until that popover is resolved or cancelled.
  ///
  /// Has the mode write every pending edit first, mirroring every other selection-changing
  /// handler.
  Future<void> _onWordClicked(
    OcptBreakdownWordClickedEvent event,
    Emitter<OcptBreakdownTaggingState> emitter,
  ) async {
    final modeState = modeBloc.state;
    if (modeState.isPreviewingVersion || state.pendingTagRange != null) {
      return;
    }

    final anchor = state.pendingTagAnchor;

    if (anchor == null || anchor.sceneId != event.sceneId) {
      await addToModeAndWait(OcptBreakdownAnchorSceneSelectedEvent(sceneId: event.sceneId));

      emitter(
        state.copyWithPendingTagAnchor(
          anchor: (
            sceneId: event.sceneId,
            wordStartOffset: event.wordStartOffset,
            wordEndOffset: event.wordEndOffset,
          ),
        ),
      );
      return;
    }

    OcptBreakdownScene? scene;
    for (final candidate in modeState.scenes) {
      if (candidate.id == event.sceneId) {
        scene = candidate;
        break;
      }
    }
    if (scene == null) {
      // Stale click: the anchor's own scene disappeared from a snapshot rebuilt underneath.
      emitter(state.copyWithPendingTagAnchorCleared());
      return;
    }

    final startOffset = anchor.wordStartOffset <= event.wordStartOffset
        ? anchor.wordStartOffset
        : event.wordStartOffset;
    final endOffset = anchor.wordEndOffset >= event.wordEndOffset
        ? anchor.wordEndOffset
        : event.wordEndOffset;

    final overlapsLiveTag = scene.tags.any(
      (tag) => startOffset < tag.endOffset && tag.startOffset < endOffset,
    );
    if (overlapsLiveTag) {
      return;
    }

    final screenplayText = modeState.screenplayText;
    final sceneStart = scene.charStart.clamp(0, screenplayText.length);
    final sceneEnd = scene.charEnd.clamp(sceneStart, screenplayText.length);
    final sceneText = screenplayText.substring(sceneStart, sceneEnd);
    final tagged = ocptBreakdownTaggedSpanOf(
      sceneText: sceneText,
      startOffset: startOffset,
      endOffset: endOffset,
    );

    await modeBloc.flushAllPendingWrites();
    emitter(
      state.copyWithClosedTagRange(
        range: (
          sceneId: event.sceneId,
          startOffset: tagged.startOffset,
          endOffset: tagged.endOffset,
          taggedText: sceneText.substring(tagged.startOffset, tagged.endOffset),
          closingWordStartOffset: event.wordStartOffset,
          closingWordEndOffset: event.wordEndOffset,
        ),
      ),
    );
  }

  /// Clear the pending anchor and the closed range alike, dispatched by the popover's own × close
  /// button, `Escape`, or a tap outside it: the user changed their mind about the passage, not just
  /// about where it should go.
  Future<void> _onTagRangeCancelled(
    OcptBreakdownTagRangeCancelledEvent event,
    Emitter<OcptBreakdownTaggingState> emitter,
  ) async {
    emitter(state.copyWithTagInteractionReset());
  }

  /// Link [OcptBreakdownTaggingState.pendingTagRange]'s own passage to the existing
  /// `event.targetKind`/`event.targetId`, dispatched by a click on one of the popover's own match
  /// rows.
  ///
  /// A stale click (no pending range, or a previewed version — the popover never withstands either)
  /// is ignored. On success — `OcptBreakdownService.createTag` returning a tag id — has the mode
  /// read the snapshot again and select the linked target on the `Inspector` tab, exactly what
  /// selecting a tagged word already does: linking *is* what makes this passage a tagged word. Then
  /// the popover closes and the anchor clears. A refusal (the overlap, or a preview database that
  /// slipped past the guard above) leaves the range and the popover exactly as they were,
  /// surfacing [OcptBreakdownTaggingState.hasTagWriteError] instead of silently closing on the
  /// user.
  Future<void> _onPopoverTargetLinked(
    OcptBreakdownPopoverTargetLinkedEvent event,
    Emitter<OcptBreakdownTaggingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final range = state.pendingTagRange;
    if (project == null || range == null || modeBloc.state.isPreviewingVersion) {
      return;
    }

    await modeBloc.flushAllPendingWrites();

    final tagId = await _breakdownService.createTag(
      database: project.database,
      sceneId: range.sceneId,
      startOffset: range.startOffset,
      endOffset: range.endOffset,
      taggedText: range.taggedText,
      targetKind: event.targetKind,
      targetId: event.targetId,
    );

    if (tagId == null) {
      emitter(state.copyWithTagWriteError());
      return;
    }

    await _closeRangeOnTarget(
      emitter,
      range: range,
      targetKind: event.targetKind,
      targetId: event.targetId,
    );
  }

  /// Create a new `event.category` element named `event.name` and tag
  /// [OcptBreakdownTaggingState.pendingTagRange]'s own passage with it, in one write
  /// (`OcptBreakdownService.createElementAndTag`), dispatched by a click on one of the popover's
  /// own category chips.
  ///
  /// Mirrors [_onPopoverTargetLinked] in every other respect: a stale call is ignored, success
  /// closes the popover and hands the new element off to the `Inspector` tab, and a refusal keeps
  /// the range and the popover, surfacing [OcptBreakdownTaggingState.hasTagWriteError].
  /// `OcptElementSourceKind.owned` is the same default the resources mode's own element sheet
  /// creates with, so the two modes mint an element identically.
  Future<void> _onPopoverElementCreationRequested(
    OcptBreakdownPopoverElementCreationRequestedEvent event,
    Emitter<OcptBreakdownTaggingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final range = state.pendingTagRange;
    if (project == null || range == null || modeBloc.state.isPreviewingVersion) {
      return;
    }

    await modeBloc.flushAllPendingWrites();

    final trimmedName = event.name.trim();
    final result = await _breakdownService.createElementAndTag(
      database: project.database,
      sceneId: range.sceneId,
      startOffset: range.startOffset,
      endOffset: range.endOffset,
      taggedText: range.taggedText,
      name: trimmedName.isEmpty ? range.taggedText : trimmedName,
      category: event.category,
      sourceKind: OcptElementSourceKind.owned,
    );

    if (result == null) {
      emitter(state.copyWithTagWriteError());
      return;
    }

    await _closeRangeOnTarget(
      emitter,
      range: range,
      targetKind: OcptBreakdownTargetKind.element,
      targetId: result.elementId,
    );
  }

  /// Create a new set named `event.name` — inside `event.locationId`, or inside a location minted
  /// along with it when that is null — and tag [OcptBreakdownTaggingState.pendingTagRange]'s own
  /// passage with it, in one write (`OcptBreakdownService.createSetAndTag`), dispatched by the
  /// popover's own `Create a set` control.
  ///
  /// The exact mirror of [_onPopoverElementCreationRequested], down to the selection it lands on:
  /// the new set's own sheet, on the `Inspector` tab.
  Future<void> _onPopoverSetCreationRequested(
    OcptBreakdownPopoverSetCreationRequestedEvent event,
    Emitter<OcptBreakdownTaggingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final range = state.pendingTagRange;
    if (project == null || range == null || modeBloc.state.isPreviewingVersion) {
      return;
    }

    await modeBloc.flushAllPendingWrites();

    final trimmedName = event.name.trim();
    final result = await _breakdownService.createSetAndTag(
      database: project.database,
      sceneId: range.sceneId,
      startOffset: range.startOffset,
      endOffset: range.endOffset,
      taggedText: range.taggedText,
      name: trimmedName.isEmpty ? range.taggedText : trimmedName,
      locationId: event.locationId,
    );

    if (result == null) {
      emitter(state.copyWithTagWriteError());
      return;
    }

    await _closeRangeOnTarget(
      emitter,
      range: range,
      targetKind: OcptBreakdownTargetKind.set,
      targetId: result.setId,
    );
  }

  /// End the popover's interaction once its tag is written: has the mode read the snapshot again,
  /// then select the target of the tag in the scene of [range] on the `Inspector` tab, and only
  /// then closes the popover and clears the anchor.
  ///
  /// Stops when the mode could not read: the tag is written, but the range stays open rather than
  /// the mode selecting a target its snapshot may not hold.
  Future<void> _closeRangeOnTarget(
    Emitter<OcptBreakdownTaggingState> emitter, {
    required OcptBreakdownPendingTagRange range,
    required OcptBreakdownTargetKind targetKind,
    required String targetId,
  }) async {
    // Stored before the read, not during the selection: the read puts the tag in the mode's state,
    // and a store awaited after it would leave the popover open on a tag that is already painted.
    await modeBloc.persistInspectorAsLastRightDockTab();

    if (!await modeBloc.reload({OcptBreakdownReloadScope.snapshot})) {
      return;
    }

    await addToModeAndWait(
      OcptBreakdownTargetSelectedEvent(
        targetKind: targetKind,
        targetId: targetId,
        sceneId: range.sceneId,
      ),
    );

    emitter(state.copyWithTagInteractionReset());
  }

  /// Tag one of the selected target's own suggested occurrences, dispatched by a click on the add
  /// control of one of `OcptBreakdownTargetInspector`'s own "Suggested occurrences" rows — the
  /// writer's second route onto `OcptBreakdownService.createTag`, [_onPopoverTargetLinked] being
  /// the first, and it mirrors that handler in every respect but two: the range comes from
  /// `event`'s own fields rather than [OcptBreakdownTaggingState.pendingTagRange] (there is no
  /// popover open here), and **the selection does not change** — accepting one row of a list is
  /// meant to leave the user on that very list, ready for the next row, rather than bouncing them
  /// to the newly tagged passage's own scene.
  ///
  /// A stale call (no project open, or a preview database that slipped past the mode's own gating)
  /// is ignored. A refusal (the range now overlaps a live tag, most likely one just written by an
  /// earlier accepted suggestion) surfaces [OcptBreakdownTaggingState.hasTagWriteError], exactly as
  /// [_onPopoverTargetLinked]'s own refusal does.
  Future<void> _onSuggestionAccepted(
    OcptBreakdownSuggestionAcceptedEvent event,
    Emitter<OcptBreakdownTaggingState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null || modeBloc.state.isPreviewingVersion) {
      return;
    }

    await modeBloc.flushAllPendingWrites();

    final tagId = await _breakdownService.createTag(
      database: project.database,
      sceneId: event.sceneId,
      startOffset: event.startOffset,
      endOffset: event.endOffset,
      taggedText: event.taggedText,
      targetKind: event.targetKind,
      targetId: event.targetId,
    );

    if (tagId == null) {
      emitter(state.copyWithTagWriteError());
      return;
    }

    if (!await modeBloc.reload({OcptBreakdownReloadScope.snapshot})) {
      return;
    }

    emitter(state.copyWithTagWriteErrorCleared());
  }

  /// Dismiss the transient notice that the last tag write — the popover's own link or element
  /// creation, or a suggestion accepted from the target inspector — was refused.
  Future<void> _onTagWriteErrorDismissed(
    OcptBreakdownTagWriteErrorDismissedEvent event,
    Emitter<OcptBreakdownTaggingState> emitter,
  ) async {
    emitter(state.copyWithTagWriteErrorCleared());
  }
}
