// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';

/// The state of `OcptResourcesRolesBloc`: the free-text edits typed into the role sheet and its
/// candidates card and not yet written.
class OcptResourcesRolesState extends BlocStateForMixin<OcptResourcesRolesState> {
  /// Every role field edit currently sitting in the field-edit autosave debounce, keyed by the
  /// role id and the field, holding the raw text last typed for it.
  ///
  /// What a field shows takes this map's entry over the role's own stored value whenever one is
  /// present, so typing is never overwritten by a reload triggered by an unrelated write.
  final Map<(String, OcptRoleField), String> pendingRoleFieldEdits;

  /// Every candidacy field edit currently sitting in the field-edit autosave debounce, keyed by the
  /// **candidacy** id (`role_candidates.id`) and the field, holding the raw text last typed for it.
  ///
  /// Keyed by the candidacy rather than by the role it names: a role's candidates card shows every
  /// one of its candidates at once, each with its own note, so two candidates being typed into are
  /// two pending edits (see `OcptRoleCandidateField`). Rides the same debounce as
  /// [pendingRoleFieldEdits].
  final Map<(String, OcptRoleCandidateField), String> pendingCandidateFieldEdits;

  /// The `lostEditsEpoch` of the mode state this bloc last reacted to, so a mode state that still
  /// carries an epoch already handled is not taken for news. Starts at the mode's own epoch when the
  /// bloc is built: a view built after the mode lost edits has nothing to drop.
  final int lastLostEditsEpoch;

  /// Class constructor
  const OcptResourcesRolesState({
    required this.pendingRoleFieldEdits,
    required this.pendingCandidateFieldEdits,
    required this.lastLostEditsEpoch,
  });

  /// Builds the state of a bloc that holds no pending edit.
  const OcptResourcesRolesState.init({this.lastLostEditsEpoch = 0})
    : pendingRoleFieldEdits = const {},
      pendingCandidateFieldEdits = const {};

  /// Copies this state, replacing what is given — each map always replaced wholesale, the caller
  /// computing the full next map.
  @override
  OcptResourcesRolesState copyWith({
    Map<(String, OcptRoleField), String>? pendingRoleFieldEdits,
    Map<(String, OcptRoleCandidateField), String>? pendingCandidateFieldEdits,
    int? lastLostEditsEpoch,
  }) => OcptResourcesRolesState(
    pendingRoleFieldEdits: pendingRoleFieldEdits ?? this.pendingRoleFieldEdits,
    pendingCandidateFieldEdits: pendingCandidateFieldEdits ?? this.pendingCandidateFieldEdits,
    lastLostEditsEpoch: lastLostEditsEpoch ?? this.lastLostEditsEpoch,
  );

  /// Copies this state with every pending field edit dropped, of the roles and of their candidates.
  OcptResourcesRolesState copyWithFieldEditsCleared() =>
      copyWith(pendingRoleFieldEdits: const {}, pendingCandidateFieldEdits: const {});

  /// Copies this state with [pendingRoleFieldEdits] as the edits sitting in the debounce, a role's
  /// field having just been typed into.
  OcptResourcesRolesState copyWithRoleFieldEditTyped({
    required Map<(String, OcptRoleField), String> pendingRoleFieldEdits,
  }) => copyWith(pendingRoleFieldEdits: pendingRoleFieldEdits);

  /// Copies this state with [pendingCandidateFieldEdits] as the edits sitting in the debounce, a
  /// candidacy's field having just been typed into.
  OcptResourcesRolesState copyWithCandidateFieldEditTyped({
    required Map<(String, OcptRoleCandidateField), String> pendingCandidateFieldEdits,
  }) => copyWith(pendingCandidateFieldEdits: pendingCandidateFieldEdits);

  /// Copies this state with the edits left once the pending ones were written, each map replaced.
  OcptResourcesRolesState copyWithFieldEditsWritten({
    required Map<(String, OcptRoleField), String> pendingRoleFieldEdits,
    required Map<(String, OcptRoleCandidateField), String> pendingCandidateFieldEdits,
  }) => copyWith(
    pendingRoleFieldEdits: pendingRoleFieldEdits,
    pendingCandidateFieldEdits: pendingCandidateFieldEdits,
  );

  /// Copies this state with [pendingRoleFieldEdits] as the edits left once a role was deleted.
  OcptResourcesRolesState copyWithRoleDeleted({
    required Map<(String, OcptRoleField), String> pendingRoleFieldEdits,
  }) => copyWith(pendingRoleFieldEdits: pendingRoleFieldEdits);

  /// Copies this state with [pendingCandidateFieldEdits] as the edits left once a candidacy was
  /// removed.
  OcptResourcesRolesState copyWithCandidateRemoved({
    required Map<(String, OcptRoleCandidateField), String> pendingCandidateFieldEdits,
  }) => copyWith(pendingCandidateFieldEdits: pendingCandidateFieldEdits);

  /// Copies this state with every pending field edit dropped and [lostEditsEpoch] as the epoch
  /// reacted to, the mode having said that writing them failed somewhere.
  OcptResourcesRolesState copyWithFieldEditsLost({required int lostEditsEpoch}) => copyWith(
    pendingRoleFieldEdits: const {},
    pendingCandidateFieldEdits: const {},
    lastLostEditsEpoch: lostEditsEpoch,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    pendingRoleFieldEdits,
    pendingCandidateFieldEdits,
    lastLostEditsEpoch,
  ];
}
