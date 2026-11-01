// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';

/// The state of `OcptResourcesElementsBloc`: the free-text edits typed into the element sheet and
/// not yet written.
class OcptResourcesElementsState extends BlocStateForMixin<OcptResourcesElementsState> {
  /// Every element field edit currently sitting in the field-edit autosave debounce, keyed by the
  /// element id and the field, holding the raw text last typed for it.
  ///
  /// What a field shows takes this map's entry over the element's own stored value whenever one is
  /// present, so typing is never overwritten by a reload triggered by an unrelated write.
  final Map<(String, OcptElementField), String> pendingElementFieldEdits;

  /// The `lostEditsEpoch` of the mode state this bloc last reacted to, so a mode state that still
  /// carries an epoch already handled is not taken for news. Starts at the mode's own epoch when the
  /// bloc is built: a view built after the mode lost edits has nothing to drop.
  final int lastLostEditsEpoch;

  /// Class constructor
  const OcptResourcesElementsState({
    required this.pendingElementFieldEdits,
    required this.lastLostEditsEpoch,
  });

  /// Builds the state of a bloc that holds no pending edit.
  const OcptResourcesElementsState.init({this.lastLostEditsEpoch = 0})
    : pendingElementFieldEdits = const {};

  /// Copies this state, replacing [pendingElementFieldEdits] when given — always replaced
  /// wholesale, the caller computing the full next map.
  @override
  OcptResourcesElementsState copyWith({
    Map<(String, OcptElementField), String>? pendingElementFieldEdits,
    int? lastLostEditsEpoch,
  }) => OcptResourcesElementsState(
    pendingElementFieldEdits: pendingElementFieldEdits ?? this.pendingElementFieldEdits,
    lastLostEditsEpoch: lastLostEditsEpoch ?? this.lastLostEditsEpoch,
  );

  /// Copies this state with every pending field edit dropped.
  OcptResourcesElementsState copyWithFieldEditsCleared() =>
      copyWith(pendingElementFieldEdits: const {});

  /// Copies this state with [pendingElementFieldEdits] as the edits sitting in the debounce, an
  /// element's field having just been typed into.
  OcptResourcesElementsState copyWithFieldEditTyped({
    required Map<(String, OcptElementField), String> pendingElementFieldEdits,
  }) => copyWith(pendingElementFieldEdits: pendingElementFieldEdits);

  /// Copies this state with [pendingElementFieldEdits] as the edits left once the pending ones
  /// were written.
  OcptResourcesElementsState copyWithFieldEditsWritten({
    required Map<(String, OcptElementField), String> pendingElementFieldEdits,
  }) => copyWith(pendingElementFieldEdits: pendingElementFieldEdits);

  /// Copies this state with [pendingElementFieldEdits] as the edits left once an element was
  /// deleted.
  OcptResourcesElementsState copyWithElementDeleted({
    required Map<(String, OcptElementField), String> pendingElementFieldEdits,
  }) => copyWith(pendingElementFieldEdits: pendingElementFieldEdits);

  /// Copies this state with every pending field edit dropped and [lostEditsEpoch] as the epoch
  /// reacted to, the mode having said that writing them failed somewhere.
  OcptResourcesElementsState copyWithFieldEditsLost({required int lostEditsEpoch}) =>
      copyWith(pendingElementFieldEdits: const {}, lastLostEditsEpoch: lostEditsEpoch);

  /// Object properties
  @override
  List<Object?> get props => [...super.props, pendingElementFieldEdits, lastLostEditsEpoch];
}
