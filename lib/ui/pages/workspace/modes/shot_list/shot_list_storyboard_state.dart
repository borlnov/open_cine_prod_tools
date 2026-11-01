// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_panel_size.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';

/// The state of `OcptShotListStoryboardBloc`: what the board and the inspector's Panels group hold
/// of their own.
///
/// The panels themselves are the mode's data (`OcptShotListState.storyboardSnapshot`): this is the
/// selection made among them, the view preferences, and the typed text still waiting for its write.
class OcptShotListStoryboardState extends BlocStateForMixin<OcptShotListStoryboardState> {
  /// The id of the panel currently selected on the board, or null while none is.
  ///
  /// Cleared whenever the mode's selected shot or sequence changes: a panel only ever belongs to
  /// the shot currently shown, exactly as the floor plans canvas' selected symbol is cleared the
  /// same way. It is also cleared when the panel disappears from the mode's storyboard snapshot.
  final String? selectedPanelId;

  /// The common height every panel frame of the board's strips is drawn at, picked from the
  /// header's own `Panel size ▾` menu.
  ///
  /// A **view preference** held here for the session alone, never persisted to the project or to
  /// `OcptPropertiesManager` — see [OcptStoryboardPanelSize]'s own doc comment.
  final OcptStoryboardPanelSize boardPanelSize;

  /// The board's active annotation editing tool, or null while none is on.
  ///
  /// A **view/session state** value, like [boardPanelSize]: never written to the project. Scoped
  /// to the currently selected panel, so it is cleared — together with [selectedAnnotationId] —
  /// whenever [selectedPanelId], or the mode's selected shot or sequence, changes: a tool left on
  /// while looking at a different panel would draw onto a frame the user can no longer see is the
  /// target.
  final OcptStoryboardAnnotationTool? activeAnnotationTool;

  /// The id of the currently selected mark, or null while none is.
  ///
  /// Cleared alongside [activeAnnotationTool] — see its own doc comment — and whenever the mark
  /// itself is deleted.
  final String? selectedAnnotationId;

  /// Every panel comment and mark text currently sitting in the board's autosave debounce, keyed by
  /// [OcptShotListPendingEditKey], holding the raw text last typed for it.
  ///
  /// What a comment field shows takes this map's entry over its own stored value whenever one is
  /// present, so typing is never overwritten by a reload triggered by an unrelated write. An entry
  /// is removed the moment its write lands, and when the panel or mark it targets is deleted.
  final Map<OcptShotListPendingEditKey, String> pendingFieldEdits;

  /// Whether the last write the board made failed; shown as a transient SnackBar then dismissed.
  final bool hasWriteError;

  /// Class constructor
  const OcptShotListStoryboardState({
    required this.selectedPanelId,
    required this.boardPanelSize,
    required this.activeAnnotationTool,
    required this.selectedAnnotationId,
    required this.pendingFieldEdits,
    required this.hasWriteError,
  });

  /// Build the state of a board nothing has been done on yet.
  const OcptShotListStoryboardState.init()
    : selectedPanelId = null,
      boardPanelSize = OcptStoryboardPanelSize.medium,
      activeAnnotationTool = null,
      selectedAnnotationId = null,
      pendingFieldEdits = const {},
      hasWriteError = false;

  /// Get the panel [selectedPanelId] identifies among the selected shot of [modeState], or null if
  /// none
  /// is selected (or the selected one is not a panel of the selected shot any more, as happens for
  /// the moment between the mode moving its selection and this bloc reacting to it).
  OcptStoryboardPanel? selectedPanelIn(OcptShotListState modeState) {
    final selectedPanelId = this.selectedPanelId;
    if (selectedPanelId == null) {
      return null;
    }
    for (final panel in modeState.panelsOfSelectedShot) {
      if (panel.id == selectedPanelId) {
        return panel;
      }
    }
    return null;
  }

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [selectedPanelId], [activeAnnotationTool] and [selectedAnnotationId] legitimately go back to
  /// null while the board is alive, so each has its own force flag.
  @override
  OcptShotListStoryboardState copyWith({
    String? selectedPanelId,
    bool forceSelectedPanelIdValue = false,
    OcptStoryboardPanelSize? boardPanelSize,
    OcptStoryboardAnnotationTool? activeAnnotationTool,
    bool forceActiveAnnotationToolValue = false,
    String? selectedAnnotationId,
    bool forceSelectedAnnotationIdValue = false,
    Map<OcptShotListPendingEditKey, String>? pendingFieldEdits,
    bool? hasWriteError,
  }) => OcptShotListStoryboardState(
    selectedPanelId: selectedPanelId ?? (forceSelectedPanelIdValue ? null : this.selectedPanelId),
    boardPanelSize: boardPanelSize ?? this.boardPanelSize,
    activeAnnotationTool:
        activeAnnotationTool ?? (forceActiveAnnotationToolValue ? null : this.activeAnnotationTool),
    selectedAnnotationId:
        selectedAnnotationId ?? (forceSelectedAnnotationIdValue ? null : this.selectedAnnotationId),
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
    hasWriteError: hasWriteError ?? this.hasWriteError,
  );

  /// Copy this state with [pendingFieldEdits] as what is still pending once the panels that are
  /// gone lost theirs, and the panel selection, the annotation tool and the annotation selection
  /// dropped when [isCleared].
  ///
  /// A null [pendingFieldEdits] keeps the current edits.
  OcptShotListStoryboardState copyWithPrunedPanels({
    required Map<OcptShotListPendingEditKey, String>? pendingFieldEdits,
    required bool isCleared,
  }) => copyWith(
    pendingFieldEdits: pendingFieldEdits,
    forceSelectedPanelIdValue: isCleared,
    forceActiveAnnotationToolValue: isCleared,
    forceSelectedAnnotationIdValue: isCleared,
  );

  /// Copy this state with panel [panelId] selected, the annotation tool and the annotation
  /// selection dropped.
  ///
  /// A null [panelId] keeps the current panel selection.
  OcptShotListStoryboardState copyWithSelectedPanel({required String? panelId}) => copyWith(
    selectedPanelId: panelId,
    forceActiveAnnotationToolValue: true,
    forceSelectedAnnotationIdValue: true,
  );

  /// Copy this state with [size] as the board's common panel height.
  OcptShotListStoryboardState copyWithBoardPanelSize({required OcptStoryboardPanelSize size}) =>
      copyWith(boardPanelSize: size);

  /// Copy this state after a panel was deleted: [pendingFieldEdits] is what is still pending,
  /// and the panel selection, the annotation tool and the annotation selection are dropped when
  /// [wasSelected].
  OcptShotListStoryboardState copyWithDeletedPanelEdits({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
    required bool wasSelected,
  }) => copyWith(
    pendingFieldEdits: pendingFieldEdits,
    forceSelectedPanelIdValue: wasSelected,
    forceActiveAnnotationToolValue: wasSelected,
    forceSelectedAnnotationIdValue: wasSelected,
  );

  /// Copy this state with [tool] as the active annotation tool, or none when it is null.
  OcptShotListStoryboardState copyWithActiveAnnotationTool({
    required OcptStoryboardAnnotationTool? tool,
  }) => copyWith(activeAnnotationTool: tool, forceActiveAnnotationToolValue: tool == null);

  /// Copy this state with annotation [annotationId] selected.
  ///
  /// A null [annotationId] keeps the current annotation selection.
  OcptShotListStoryboardState copyWithSelectedAnnotation({required String? annotationId}) =>
      copyWith(selectedAnnotationId: annotationId);

  /// Copy this state after an annotation was deleted: [pendingFieldEdits] is what is still
  /// pending, and the annotation selection is dropped when [wasSelected].
  OcptShotListStoryboardState copyWithDeletedAnnotationEdits({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
    required bool wasSelected,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits, forceSelectedAnnotationIdValue: wasSelected);

  /// Copy this state with [pendingFieldEdits] as the comments and texts waiting in the debounce,
  /// a keystroke later.
  OcptShotListStoryboardState copyWithTypedFieldEdits({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copy this state with no field edit left pending.
  OcptShotListStoryboardState copyWithFieldEditsCleared() => copyWith(pendingFieldEdits: const {});

  /// Copy this state with [pendingFieldEdits] as what the write that just landed left pending.
  OcptShotListStoryboardState copyWithFlushedFieldEdits({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copy this state with the write error raised, [pendingFieldEdits] being what the failed
  /// flush left pending.
  OcptShotListStoryboardState copyToFlushFailed({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
  }) => copyWith(hasWriteError: true, pendingFieldEdits: pendingFieldEdits);

  /// Copy this state with the write error raised.
  OcptShotListStoryboardState copyToWriteFailed() => copyWith(hasWriteError: true);

  /// Copy this state with the write error dismissed.
  OcptShotListStoryboardState copyWithWriteErrorDismissed() => copyWith(hasWriteError: false);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    selectedPanelId,
    boardPanelSize,
    activeAnnotationTool,
    selectedAnnotationId,
    pendingFieldEdits,
    hasWriteError,
  ];
}
