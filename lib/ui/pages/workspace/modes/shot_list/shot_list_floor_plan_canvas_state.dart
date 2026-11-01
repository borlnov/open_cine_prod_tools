// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_scope_decision.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';

/// The state of `OcptShotListFloorPlanCanvasBloc`: what the floor plans canvas holds of its own
/// while it is being drawn on.
///
/// The sets, the symbols and the arrows themselves are the mode's data
/// (`OcptShotListState.floorPlanSnapshot`): this is the tool in hand, the symbol or the arrow
/// selected among them, the first end of the arrow being drawn, the scope question a shared
/// symbol's gesture is waiting an answer to, and the character name prompt a placement asks for.
class OcptShotListFloorPlanCanvasState extends BlocStateForMixin<OcptShotListFloorPlanCanvasState> {
  /// The id of the symbol currently selected on the floor plans canvas, or null while none is.
  ///
  /// Cleared whenever the mode's selected set, shot or sequence changes: a symbol only ever
  /// belongs to the set currently shown. It is also cleared when the symbol disappears from the
  /// mode's floor plans, or is masked by a hidden override where the canvas looks. Mutually exclusive with
  /// [selectedFloorPlanArrowId]: selecting one clears the other.
  final String? selectedFloorPlanSymbolId;

  /// The id of the arrow currently selected on the floor plans canvas, or null while none is —
  /// what draws its own bendable midpoint handle. Mutually exclusive with
  /// [selectedFloorPlanSymbolId] and cleared on every occasion that field is: a different set,
  /// shot or sequence shown, the arrow itself deleted.
  final String? selectedFloorPlanArrowId;

  /// The id of a character symbol just placed by [OcptFloorPlanTool.character], asking
  /// `OcptFloorPlanCharacterNamePickerDialog` to open for it, or null while none is pending — a
  /// one-shot trigger read by the mode's own `BlocListener` exactly like
  /// `OcptShotListState.projectPackagePendingExport` is, and cleared the moment that listener
  /// opens the dialog so a later emission never stacks a second one behind it.
  ///
  /// Neither a selection move nor the mode reading its data again clears it.
  final String? pendingCharacterNamePromptSymbolId;

  /// The floor plans canvas's own currently active tool, picked from the tool bar.
  ///
  /// A **view/session state** value: never written to the project.
  final OcptFloorPlanTool floorPlanActiveTool;

  /// A set-scope move, rotate or resize awaiting the scope bubble's own answer — set the
  /// instant such a gesture ends on a symbol whose own set is linked to two or more sequences, and
  /// cleared the moment the bubble is answered (`Every sequence`/`Only sequence n`/`Cancel`) or a
  /// click elsewhere dismisses it as `Cancel`. Null the rest of the time — every set-scope gesture
  /// on a set linked to one sequence alone is written straight away, exactly as before.
  ///
  /// A **view/session state** value: never written to the project (only what it resolves into
  /// is). Cleared when the mode selects another sequence; the mode reading its data again leaves
  /// it as it is.
  final OcptFloorPlanScopeDecision? pendingFloorPlanScopeDecision;

  /// The id of the symbol picked as the arrow tool's own first end, or null while none is pending
  /// (no click yet, or the anchor was just completed into an arrow or cancelled) — the floor plans
  /// canvas's own pending anchor, mirroring the coverage dialog's own. Cleared whenever the mode's
  /// selected shot, sequence or set changes (the same sequence selected again included), and
  /// whenever [floorPlanActiveTool] is picked away from [OcptFloorPlanTool.arrow].
  final String? pendingFloorPlanArrowAnchorSymbolId;

  /// Whether the last write the canvas made failed; shown as a transient SnackBar then dismissed.
  final bool hasWriteError;

  /// Class constructor
  const OcptShotListFloorPlanCanvasState({
    required this.selectedFloorPlanSymbolId,
    required this.selectedFloorPlanArrowId,
    required this.pendingCharacterNamePromptSymbolId,
    required this.floorPlanActiveTool,
    required this.pendingFloorPlanScopeDecision,
    required this.pendingFloorPlanArrowAnchorSymbolId,
    required this.hasWriteError,
  });

  /// Builds the state of a canvas nothing has been done on yet.
  const OcptShotListFloorPlanCanvasState.init()
    : selectedFloorPlanSymbolId = null,
      selectedFloorPlanArrowId = null,
      pendingCharacterNamePromptSymbolId = null,
      floorPlanActiveTool = OcptFloorPlanTool.select,
      pendingFloorPlanScopeDecision = null,
      pendingFloorPlanArrowAnchorSymbolId = null,
      hasWriteError = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// Every nullable field legitimately goes back to null while the canvas is alive, so each has its
  /// own force flag.
  @override
  OcptShotListFloorPlanCanvasState copyWith({
    String? selectedFloorPlanSymbolId,
    bool forceSelectedFloorPlanSymbolIdValue = false,
    String? selectedFloorPlanArrowId,
    bool forceSelectedFloorPlanArrowIdValue = false,
    String? pendingCharacterNamePromptSymbolId,
    bool forcePendingCharacterNamePromptSymbolIdValue = false,
    OcptFloorPlanTool? floorPlanActiveTool,
    OcptFloorPlanScopeDecision? pendingFloorPlanScopeDecision,
    bool forcePendingFloorPlanScopeDecisionValue = false,
    String? pendingFloorPlanArrowAnchorSymbolId,
    bool forcePendingFloorPlanArrowAnchorSymbolIdValue = false,
    bool? hasWriteError,
  }) => OcptShotListFloorPlanCanvasState(
    selectedFloorPlanSymbolId:
        selectedFloorPlanSymbolId ??
        (forceSelectedFloorPlanSymbolIdValue ? null : this.selectedFloorPlanSymbolId),
    selectedFloorPlanArrowId:
        selectedFloorPlanArrowId ??
        (forceSelectedFloorPlanArrowIdValue ? null : this.selectedFloorPlanArrowId),
    pendingCharacterNamePromptSymbolId:
        pendingCharacterNamePromptSymbolId ??
        (forcePendingCharacterNamePromptSymbolIdValue
            ? null
            : this.pendingCharacterNamePromptSymbolId),
    floorPlanActiveTool: floorPlanActiveTool ?? this.floorPlanActiveTool,
    pendingFloorPlanScopeDecision:
        pendingFloorPlanScopeDecision ??
        (forcePendingFloorPlanScopeDecisionValue ? null : this.pendingFloorPlanScopeDecision),
    pendingFloorPlanArrowAnchorSymbolId:
        pendingFloorPlanArrowAnchorSymbolId ??
        (forcePendingFloorPlanArrowAnchorSymbolIdValue
            ? null
            : this.pendingFloorPlanArrowAnchorSymbolId),
    hasWriteError: hasWriteError ?? this.hasWriteError,
  );

  /// Copies this state with the selection, the arrow anchor and the scope decision pruned.
  ///
  /// The symbol selection goes when [isSymbolCleared] or [isSymbolGone], the arrow selection when
  /// any of the four selection flags is set (the arrow goes with the symbol: the two are never
  /// selected together), the anchor when [isAnchorCleared] and the decision when [isDecisionCleared].
  OcptShotListFloorPlanCanvasState copyWithPrunedSelection({
    required bool isSymbolCleared,
    required bool isArrowCleared,
    required bool isSymbolGone,
    required bool isArrowGone,
    required bool isAnchorCleared,
    required bool isDecisionCleared,
  }) => copyWith(
    forceSelectedFloorPlanSymbolIdValue: isSymbolCleared || isSymbolGone,
    forceSelectedFloorPlanArrowIdValue:
        isArrowCleared || isSymbolCleared || isSymbolGone || isArrowGone,
    forcePendingFloorPlanArrowAnchorSymbolIdValue: isAnchorCleared,
    forcePendingFloorPlanScopeDecisionValue: isDecisionCleared,
  );

  /// Copies this state with [tool] active; leaving the arrow tool drops its pending anchor.
  OcptShotListFloorPlanCanvasState copyWithActiveTool({required OcptFloorPlanTool tool}) =>
      copyWith(
        floorPlanActiveTool: tool,
        forcePendingFloorPlanArrowAnchorSymbolIdValue: tool != OcptFloorPlanTool.arrow,
      );

  /// Copies this state with the freshly placed [symbolId] selected, and asking for a character
  /// name when [isCharacter].
  OcptShotListFloorPlanCanvasState copyWithPlacedSymbol({
    required String symbolId,
    required bool isCharacter,
  }) => copyWith(
    selectedFloorPlanSymbolId: symbolId,
    forceSelectedFloorPlanArrowIdValue: true,
    pendingCharacterNamePromptSymbolId: isCharacter ? symbolId : null,
    forcePendingCharacterNamePromptSymbolIdValue: !isCharacter,
  );

  /// Copies this state with [symbolId] selected, or no selection when it is null; selecting a
  /// symbol clears the arrow selection.
  OcptShotListFloorPlanCanvasState copyWithSelectedSymbol({required String? symbolId}) => copyWith(
    selectedFloorPlanSymbolId: symbolId,
    forceSelectedFloorPlanSymbolIdValue: symbolId == null,
    forceSelectedFloorPlanArrowIdValue: symbolId != null,
  );

  /// Copies this state with [decision] waiting for the user's choice of scope.
  OcptShotListFloorPlanCanvasState copyWithScopeDecision({
    required OcptFloorPlanScopeDecision decision,
  }) => copyWith(pendingFloorPlanScopeDecision: decision);

  /// Copies this state with the scope decision dropped.
  OcptShotListFloorPlanCanvasState copyWithScopeDecisionDismissed() =>
      copyWith(forcePendingFloorPlanScopeDecisionValue: true);

  /// Copies this state with the write error raised and the scope decision dropped.
  OcptShotListFloorPlanCanvasState copyToScopeDecisionFailed() =>
      copyWith(hasWriteError: true, forcePendingFloorPlanScopeDecisionValue: true);

  /// Copies this state with [symbolId] as the first end of the arrow being drawn.
  OcptShotListFloorPlanCanvasState copyWithArrowAnchor({required String symbolId}) =>
      copyWith(pendingFloorPlanArrowAnchorSymbolId: symbolId);

  /// Copies this state with no arrow being drawn.
  OcptShotListFloorPlanCanvasState copyWithArrowAnchorCleared() =>
      copyWith(forcePendingFloorPlanArrowAnchorSymbolIdValue: true);

  /// Copies this state with the write error raised and no arrow being drawn.
  OcptShotListFloorPlanCanvasState copyToArrowAddFailed() =>
      copyWith(hasWriteError: true, forcePendingFloorPlanArrowAnchorSymbolIdValue: true);

  /// Copies this state with arrow [arrowId] selected, or no selection when it is null; selecting
  /// an arrow clears the symbol selection.
  OcptShotListFloorPlanCanvasState copyWithSelectedArrow({required String? arrowId}) => copyWith(
    selectedFloorPlanArrowId: arrowId,
    forceSelectedFloorPlanArrowIdValue: arrowId == null,
    forceSelectedFloorPlanSymbolIdValue: arrowId != null,
  );

  /// Copies this state with the duplicate [symbolId] selected and no arrow selected.
  OcptShotListFloorPlanCanvasState copyWithDuplicatedSymbol({required String symbolId}) =>
      copyWith(selectedFloorPlanSymbolId: symbolId, forceSelectedFloorPlanArrowIdValue: true);

  /// Copies this state with the character name prompt dismissed.
  OcptShotListFloorPlanCanvasState copyWithCharacterNamePromptDismissed() =>
      copyWith(forcePendingCharacterNamePromptSymbolIdValue: true);

  /// Copies this state with the write error raised.
  OcptShotListFloorPlanCanvasState copyToWriteFailed() => copyWith(hasWriteError: true);

  /// Copies this state with the write error dismissed.
  OcptShotListFloorPlanCanvasState copyWithWriteErrorDismissed() => copyWith(hasWriteError: false);

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    selectedFloorPlanSymbolId,
    selectedFloorPlanArrowId,
    pendingCharacterNamePromptSymbolId,
    floorPlanActiveTool,
    pendingFloorPlanScopeDecision,
    pendingFloorPlanArrowAnchorSymbolId,
    hasWriteError,
  ];
}
