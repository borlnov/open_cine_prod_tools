// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_pending_edit_key.dart';

/// The state of `OcptShotListFloorPlanPlacementsBloc`: what the inspector's Placements group holds
/// of its own.
///
/// The symbols and the arrows themselves are the mode's data
/// (`OcptShotListState.floorPlanSnapshot`): this is the symbol labels typed and still waiting for
/// their write, and whether the last write failed.
class OcptShotListFloorPlanPlacementsState
    extends BlocStateForMixin<OcptShotListFloorPlanPlacementsState> {
  /// Every symbol label currently sitting in the placements' autosave debounce, keyed by
  /// [OcptShotListPendingEditKey], holding the raw text last typed for it.
  ///
  /// What a symbol label shows takes this map's entry over its own stored value whenever one is
  /// present, so typing is never overwritten by a reload triggered by an unrelated write. An entry
  /// is removed the moment its write lands, and when the mode's floor plans no longer hold the
  /// symbol.
  final Map<OcptShotListPendingEditKey, String> pendingFieldEdits;

  /// Whether the last write the placements bloc made failed; shown as a transient SnackBar then
  /// dismissed.
  final bool hasWriteError;

  /// Class constructor
  const OcptShotListFloorPlanPlacementsState({
    required this.pendingFieldEdits,
    required this.hasWriteError,
  });

  /// Build the state of placements nothing has been done on yet.
  const OcptShotListFloorPlanPlacementsState.init()
    : pendingFieldEdits = const {},
      hasWriteError = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  @override
  OcptShotListFloorPlanPlacementsState copyWith({
    Map<OcptShotListPendingEditKey, String>? pendingFieldEdits,
    bool? hasWriteError,
  }) => OcptShotListFloorPlanPlacementsState(
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
    hasWriteError: hasWriteError ?? this.hasWriteError,
  );

  /// Copy this state with [pendingFieldEdits] as what is still pending after the floor plan
  /// lost symbols.
  OcptShotListFloorPlanPlacementsState copyWithPrunedFieldEdits({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copy this state with [pendingFieldEdits] as the labels waiting in the debounce, a keystroke
  /// later.
  OcptShotListFloorPlanPlacementsState copyWithTypedFieldEdits({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copy this state with no field edit left pending.
  OcptShotListFloorPlanPlacementsState copyWithFieldEditsCleared() =>
      copyWith(pendingFieldEdits: const {});

  /// Copy this state with [pendingFieldEdits] as what the write that just landed left pending.
  OcptShotListFloorPlanPlacementsState copyWithFlushedFieldEdits({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copy this state with the write error raised, [pendingFieldEdits] being what the failed
  /// flush left pending.
  OcptShotListFloorPlanPlacementsState copyToFlushFailed({
    required Map<OcptShotListPendingEditKey, String> pendingFieldEdits,
  }) => copyWith(hasWriteError: true, pendingFieldEdits: pendingFieldEdits);

  /// Copy this state with the write error raised.
  OcptShotListFloorPlanPlacementsState copyToWriteFailed() => copyWith(hasWriteError: true);

  /// Copy this state with the write error dismissed.
  OcptShotListFloorPlanPlacementsState copyWithWriteErrorDismissed() =>
      copyWith(hasWriteError: false);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, pendingFieldEdits, hasWriteError];
}
