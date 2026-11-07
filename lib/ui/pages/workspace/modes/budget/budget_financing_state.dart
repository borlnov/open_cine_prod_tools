// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The state of `OcptBudgetFinancingBloc`.
///
/// The financing plan and the logistics hold nothing of their own: the resources, the defrayals and
/// the provisioning band they show are the mode's data, which row is highlighted and which account
/// the provisioning points at are the mode's selection, and none of their fields is typed into a
/// debounce. The bloc exists for the writes these views trigger.
class OcptBudgetFinancingState extends BlocStateForMixin<OcptBudgetFinancingState> {
  /// Class constructor
  const OcptBudgetFinancingState();

  /// Build the state of a bloc that has written nothing yet.
  const OcptBudgetFinancingState.init();

  /// Copy this state: there is nothing to replace.
  @override
  OcptBudgetFinancingState copyWith() => this;

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props];
}
