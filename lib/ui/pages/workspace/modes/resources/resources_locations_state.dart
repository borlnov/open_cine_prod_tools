// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';

/// The state of `OcptResourcesLocationsBloc`: the free-text edits typed into the location sheet and
/// its sets card and not yet written.
class OcptResourcesLocationsState extends BlocStateForMixin<OcptResourcesLocationsState> {
  /// Every location field edit currently sitting in the field-edit autosave debounce, keyed by the
  /// location id and the field, holding the raw text last typed for it.
  ///
  /// What a field shows takes this map's entry over the location's own stored value whenever one is
  /// present, so typing is never overwritten by a reload triggered by an unrelated write.
  final Map<(String, OcptLocationField), String> pendingLocationFieldEdits;

  /// Every set field edit currently sitting in the field-edit autosave debounce, keyed by the
  /// **set** id and the field, holding the raw text last typed for it.
  ///
  /// Keyed by the set rather than by the location holding it: a location sheet shows every one of
  /// its sets at once, each with its own code, name and notes, so two sets being typed into are two
  /// pending edits (see `OcptSetField`). Rides the same debounce as [pendingLocationFieldEdits].
  final Map<(String, OcptSetField), String> pendingSetFieldEdits;

  /// The `lostEditsEpoch` of the mode state this bloc last reacted to, so a mode state that still
  /// carries an epoch already handled is not taken for news. Starts at the mode's own epoch when the
  /// bloc is built: a view built after the mode lost edits has nothing to drop.
  final int lastLostEditsEpoch;

  /// Class constructor
  const OcptResourcesLocationsState({
    required this.pendingLocationFieldEdits,
    required this.pendingSetFieldEdits,
    required this.lastLostEditsEpoch,
  });

  /// Builds the state of a bloc that holds no pending edit.
  const OcptResourcesLocationsState.init({this.lastLostEditsEpoch = 0})
    : pendingLocationFieldEdits = const {},
      pendingSetFieldEdits = const {};

  /// Copies this state, replacing what is given — each map always replaced wholesale, the caller
  /// computing the full next map.
  @override
  OcptResourcesLocationsState copyWith({
    Map<(String, OcptLocationField), String>? pendingLocationFieldEdits,
    Map<(String, OcptSetField), String>? pendingSetFieldEdits,
    int? lastLostEditsEpoch,
  }) => OcptResourcesLocationsState(
    pendingLocationFieldEdits: pendingLocationFieldEdits ?? this.pendingLocationFieldEdits,
    pendingSetFieldEdits: pendingSetFieldEdits ?? this.pendingSetFieldEdits,
    lastLostEditsEpoch: lastLostEditsEpoch ?? this.lastLostEditsEpoch,
  );

  /// Copies this state with every pending field edit dropped, of the locations and of their sets.
  OcptResourcesLocationsState copyWithFieldEditsCleared() =>
      copyWith(pendingLocationFieldEdits: const {}, pendingSetFieldEdits: const {});

  /// Copies this state with [pendingLocationFieldEdits] as the edits sitting in the debounce, a
  /// location's field having just been typed into.
  OcptResourcesLocationsState copyWithLocationFieldEditTyped({
    required Map<(String, OcptLocationField), String> pendingLocationFieldEdits,
  }) => copyWith(pendingLocationFieldEdits: pendingLocationFieldEdits);

  /// Copies this state with [pendingSetFieldEdits] as the edits sitting in the debounce, a set's
  /// field having just been typed into.
  OcptResourcesLocationsState copyWithSetFieldEditTyped({
    required Map<(String, OcptSetField), String> pendingSetFieldEdits,
  }) => copyWith(pendingSetFieldEdits: pendingSetFieldEdits);

  /// Copies this state with the edits left once the pending ones were written, each map replaced.
  OcptResourcesLocationsState copyWithFieldEditsWritten({
    required Map<(String, OcptLocationField), String> pendingLocationFieldEdits,
    required Map<(String, OcptSetField), String> pendingSetFieldEdits,
  }) => copyWith(
    pendingLocationFieldEdits: pendingLocationFieldEdits,
    pendingSetFieldEdits: pendingSetFieldEdits,
  );

  /// Copies this state with the edits left once a location was deleted, each map replaced.
  OcptResourcesLocationsState copyWithLocationDeleted({
    required Map<(String, OcptLocationField), String> pendingLocationFieldEdits,
    required Map<(String, OcptSetField), String> pendingSetFieldEdits,
  }) => copyWith(
    pendingLocationFieldEdits: pendingLocationFieldEdits,
    pendingSetFieldEdits: pendingSetFieldEdits,
  );

  /// Copies this state with [pendingSetFieldEdits] as the edits left once a set was removed.
  OcptResourcesLocationsState copyWithSetRemoved({
    required Map<(String, OcptSetField), String> pendingSetFieldEdits,
  }) => copyWith(pendingSetFieldEdits: pendingSetFieldEdits);

  /// Copies this state with every pending field edit dropped and [lostEditsEpoch] as the epoch
  /// reacted to, the mode having said that writing them failed somewhere.
  OcptResourcesLocationsState copyWithFieldEditsLost({required int lostEditsEpoch}) => copyWith(
    pendingLocationFieldEdits: const {},
    pendingSetFieldEdits: const {},
    lastLostEditsEpoch: lostEditsEpoch,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    pendingLocationFieldEdits,
    pendingSetFieldEdits,
    lastLostEditsEpoch,
  ];
}
