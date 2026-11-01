// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';

/// The key [OcptScheduleDayState.pendingFieldEdits] is stored under: which entity, and which of its
/// own [OcptScheduleField]s.
typedef OcptSchedulePendingFieldKey = (String targetId, OcptScheduleField field);

/// The state of `OcptScheduleDayBloc`: the free-text edits typed into the day view and the
/// inspector and not yet written.
///
/// [pendingFieldEdits] is one flat map over every free-text field of every entity the day view
/// edits text on — see `OcptScheduleField`'s own doc comment for why one flat map rather than one
/// per entity.
class OcptScheduleDayState extends BlocStateForMixin<OcptScheduleDayState> {
  /// The raw text of every free-text field edited and not yet written, keyed by entity and field.
  /// A field shows its entry here instead of its stored value until the edit is written.
  final Map<OcptSchedulePendingFieldKey, String> pendingFieldEdits;

  /// Class constructor
  const OcptScheduleDayState({required this.pendingFieldEdits});

  /// Builds the state of a bloc that holds no pending edit.
  const OcptScheduleDayState.init() : pendingFieldEdits = const {};

  /// What [field] of entity [targetId] shows: its pending edit if it has one, else [storedValue].
  String fieldValueOf(String targetId, OcptScheduleField field, String storedValue) =>
      pendingFieldEdits[(targetId, field)] ?? storedValue;

  /// Copies this state, replacing [pendingFieldEdits] when given — always replaced wholesale, the
  /// caller (the bloc's own field-edit handler) computing the full next map.
  @override
  OcptScheduleDayState copyWith({Map<OcptSchedulePendingFieldKey, String>? pendingFieldEdits}) =>
      OcptScheduleDayState(pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits);

  /// Copies this state with [pendingFieldEdits] as what is still pending once the rows that are
  /// gone lost their edits.
  OcptScheduleDayState copyWithPrunedFieldEdits({
    required Map<OcptSchedulePendingFieldKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copies this state with [pendingFieldEdits] as the edits waiting in the debounce, a keystroke
  /// later.
  OcptScheduleDayState copyWithTypedFieldEdits({
    required Map<OcptSchedulePendingFieldKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copies this state with no field edit left pending.
  OcptScheduleDayState copyWithFieldEditsCleared() => copyWith(pendingFieldEdits: const {});

  /// Copies this state with [pendingFieldEdits] as what the write that just landed left pending.
  OcptScheduleDayState copyWithFlushedFieldEdits({
    required Map<OcptSchedulePendingFieldKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Object properties
  @override
  List<Object?> get props => [...super.props, pendingFieldEdits];
}
