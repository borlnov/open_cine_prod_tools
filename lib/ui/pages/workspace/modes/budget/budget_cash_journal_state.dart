// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The state of `OcptBudgetCashJournalBloc`.
///
/// The cash journal holds nothing of its own: the entries and the commitments it shows are the
/// mode's data, which row is selected is the mode's selection, and none of its fields is typed into
/// a debounce. The bloc exists for the writes the view triggers.
class OcptBudgetCashJournalState extends BlocStateForMixin<OcptBudgetCashJournalState> {
  /// Class constructor
  const OcptBudgetCashJournalState();

  /// Build the state of a bloc that has written nothing yet.
  const OcptBudgetCashJournalState.init();

  /// Copy this state: there is nothing to replace.
  @override
  OcptBudgetCashJournalState copyWith() => this;

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props];
}
