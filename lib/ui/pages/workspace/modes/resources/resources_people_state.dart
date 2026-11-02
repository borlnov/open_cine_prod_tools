// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';

/// The state of `OcptResourcesPeopleBloc`: the free-text edits typed into the person sheet and not
/// yet written.
class OcptResourcesPeopleState extends BlocStateForMixin<OcptResourcesPeopleState> {
  /// Every field edit currently sitting in the field-edit autosave debounce, keyed by the person id
  /// and the field, holding the raw text last typed for it.
  ///
  /// What a field shows takes this map's entry over the person's own stored value whenever one is
  /// present, so typing is never overwritten by a reload triggered by an unrelated write. An entry
  /// is removed the moment its write lands, whether through the debounce elapsing or an explicit
  /// flush.
  final Map<(String, OcptPersonField), String> pendingFieldEdits;

  /// The `lostEditsEpoch` of the mode state this bloc last reacted to, so a mode state that still
  /// carries an epoch already handled is not taken for news. Starts at the mode's own epoch when
  /// the bloc is built: a view built after the mode lost edits has nothing to drop.
  final int lastLostEditsEpoch;

  /// Class constructor
  const OcptResourcesPeopleState({
    required this.pendingFieldEdits,
    required this.lastLostEditsEpoch,
  });

  /// Build the state of a bloc that holds no pending edit.
  const OcptResourcesPeopleState.init({this.lastLostEditsEpoch = 0}) : pendingFieldEdits = const {};

  /// Copy this state, replacing [pendingFieldEdits] when given — always replaced wholesale, the
  /// caller computing the full next map.
  @override
  OcptResourcesPeopleState copyWith({
    Map<(String, OcptPersonField), String>? pendingFieldEdits,
    int? lastLostEditsEpoch,
  }) => OcptResourcesPeopleState(
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
    lastLostEditsEpoch: lastLostEditsEpoch ?? this.lastLostEditsEpoch,
  );

  /// Copy this state with every pending field edit dropped.
  OcptResourcesPeopleState copyWithFieldEditsCleared() => copyWith(pendingFieldEdits: const {});

  /// Copy this state with [pendingFieldEdits] as the edits sitting in the debounce, a person's
  /// field having just been typed into.
  OcptResourcesPeopleState copyWithFieldEditTyped({
    required Map<(String, OcptPersonField), String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copy this state with [pendingFieldEdits] as the edits left once the pending ones were
  /// written.
  OcptResourcesPeopleState copyWithFieldEditsWritten({
    required Map<(String, OcptPersonField), String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copy this state with [pendingFieldEdits] as the edits left once a person was erased.
  OcptResourcesPeopleState copyWithPersonErased({
    required Map<(String, OcptPersonField), String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copy this state with every pending field edit dropped and [lostEditsEpoch] as the epoch
  /// reacted to, the mode having said that writing them failed somewhere.
  OcptResourcesPeopleState copyWithFieldEditsLost({required int lostEditsEpoch}) =>
      copyWith(pendingFieldEdits: const {}, lastLostEditsEpoch: lostEditsEpoch);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, pendingFieldEdits, lastLostEditsEpoch];
}
