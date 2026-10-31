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

  /// Class constructor
  const OcptResourcesPeopleState({required this.pendingFieldEdits});

  /// Builds the state of a bloc that holds no pending edit.
  const OcptResourcesPeopleState.init() : pendingFieldEdits = const {};

  /// Copies this state, replacing [pendingFieldEdits] when given — always replaced wholesale, the
  /// caller computing the full next map.
  @override
  OcptResourcesPeopleState copyWith({Map<(String, OcptPersonField), String>? pendingFieldEdits}) =>
      OcptResourcesPeopleState(pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits);

  /// Object properties
  @override
  List<Object?> get props => [...super.props, pendingFieldEdits];
}
