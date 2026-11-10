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

  /// Class constructor
  const OcptResourcesElementsState({required this.pendingElementFieldEdits});

  /// Build the state of a bloc that holds no pending edit.
  const OcptResourcesElementsState.init() : pendingElementFieldEdits = const {};

  /// Copy this state, replacing [pendingElementFieldEdits] when given — always replaced
  /// wholesale, the caller computing the full next map.
  @override
  OcptResourcesElementsState copyWith({
    Map<(String, OcptElementField), String>? pendingElementFieldEdits,
  }) => OcptResourcesElementsState(
    pendingElementFieldEdits: pendingElementFieldEdits ?? this.pendingElementFieldEdits,
  );

  /// Copy this state with every pending field edit dropped.
  OcptResourcesElementsState copyWithFieldEditsCleared() =>
      copyWith(pendingElementFieldEdits: const {});

  /// Copy this state with [pendingElementFieldEdits] as the edits sitting in the debounce, an
  /// element's field having just been typed into.
  OcptResourcesElementsState copyWithFieldEditTyped({
    required Map<(String, OcptElementField), String> pendingElementFieldEdits,
  }) => copyWith(pendingElementFieldEdits: pendingElementFieldEdits);

  /// Copy this state with [pendingElementFieldEdits] as the edits left once the pending ones
  /// were written.
  OcptResourcesElementsState copyWithFieldEditsWritten({
    required Map<(String, OcptElementField), String> pendingElementFieldEdits,
  }) => copyWith(pendingElementFieldEdits: pendingElementFieldEdits);

  /// Copy this state with [pendingElementFieldEdits] as the edits left once an element was
  /// deleted.
  OcptResourcesElementsState copyWithElementDeleted({
    required Map<(String, OcptElementField), String> pendingElementFieldEdits,
  }) => copyWith(pendingElementFieldEdits: pendingElementFieldEdits);

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, pendingElementFieldEdits];
}
