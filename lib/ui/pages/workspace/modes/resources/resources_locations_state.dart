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

  /// Class constructor
  const OcptResourcesLocationsState({
    required this.pendingLocationFieldEdits,
    required this.pendingSetFieldEdits,
  });

  /// Builds the state of a bloc that holds no pending edit.
  const OcptResourcesLocationsState.init()
    : pendingLocationFieldEdits = const {},
      pendingSetFieldEdits = const {};

  /// Copies this state, replacing what is given — each map always replaced wholesale, the caller
  /// computing the full next map.
  @override
  OcptResourcesLocationsState copyWith({
    Map<(String, OcptLocationField), String>? pendingLocationFieldEdits,
    Map<(String, OcptSetField), String>? pendingSetFieldEdits,
  }) => OcptResourcesLocationsState(
    pendingLocationFieldEdits: pendingLocationFieldEdits ?? this.pendingLocationFieldEdits,
    pendingSetFieldEdits: pendingSetFieldEdits ?? this.pendingSetFieldEdits,
  );

  /// Object properties
  @override
  List<Object?> get props => [...super.props, pendingLocationFieldEdits, pendingSetFieldEdits];
}
