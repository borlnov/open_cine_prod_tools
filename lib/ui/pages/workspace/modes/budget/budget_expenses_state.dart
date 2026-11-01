// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';

/// The key [OcptBudgetExpensesState.pendingFieldEdits] is stored under: which poste or line, and
/// which of its own [OcptBudgetField]s — mirrors `OcptSchedulePendingFieldKey`.
typedef OcptBudgetPendingFieldKey = (String targetId, OcptBudgetField field);

/// The state of `OcptBudgetExpensesBloc`: the free-text fields of the postes and the quote lines
/// that were typed and not yet written.
///
/// [pendingFieldEdits] is this view's single pending-edit map, over every free-text field of every
/// poste and every line — see `OcptBudgetField`'s own doc comment for why one flat map rather than
/// one per entity kind.
class OcptBudgetExpensesState extends BlocStateForMixin<OcptBudgetExpensesState> {
  /// Every free-text field still sitting in the field-edit debounce, keyed by which poste or line
  /// and which of its own fields. [fieldValueOf] is what a field reads instead of its own stored
  /// value while an edit is pending here.
  final Map<OcptBudgetPendingFieldKey, String> pendingFieldEdits;

  /// [targetId]'s current value for [field] — a pending edit still sitting in [pendingFieldEdits],
  /// or [storedValue] (the record's own value, read off the call site) otherwise, exactly as
  /// `OcptScheduleDayState.fieldValueOf` resolves a day's, a slot's or a block's own fields.
  String fieldValueOf(String targetId, OcptBudgetField field, String storedValue) =>
      pendingFieldEdits[(targetId, field)] ?? storedValue;

  /// Class constructor
  const OcptBudgetExpensesState({required this.pendingFieldEdits});

  /// Builds the state of a view that holds no typed edit.
  const OcptBudgetExpensesState.init() : pendingFieldEdits = const {};

  /// Copies this state, replacing what is given. [pendingFieldEdits] is always replaced wholesale:
  /// the caller always computes the full next map.
  @override
  OcptBudgetExpensesState copyWith({Map<OcptBudgetPendingFieldKey, String>? pendingFieldEdits}) =>
      OcptBudgetExpensesState(pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits);

  /// Copies this state with every pending field edit dropped.
  OcptBudgetExpensesState copyWithFieldEditsCleared() => copyWith(pendingFieldEdits: const {});

  /// Copies this state with [pendingFieldEdits] as the edits sitting in the debounce, a field
  /// having just been typed into.
  OcptBudgetExpensesState copyWithFieldEditTyped({
    required Map<OcptBudgetPendingFieldKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Copies this state with [pendingFieldEdits] as the edits left once the pending ones were
  /// written.
  OcptBudgetExpensesState copyWithFieldEditsWritten({
    required Map<OcptBudgetPendingFieldKey, String> pendingFieldEdits,
  }) => copyWith(pendingFieldEdits: pendingFieldEdits);

  /// Object properties
  @override
  List<Object?> get props => [...super.props, pendingFieldEdits];
}
