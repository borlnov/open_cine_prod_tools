// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The state of `OcptBudgetSharingBloc`.
///
/// The revenue sharing view holds nothing of its own: the takings and the shares it shows are the
/// mode's data, which row is selected is the mode's selection, and none of its fields is typed
/// into a debounce. The bloc exists for the writes the view triggers.
class OcptBudgetSharingState extends BlocStateForMixin<OcptBudgetSharingState> {
  /// Class constructor
  const OcptBudgetSharingState();

  /// Builds the state of a bloc that has written nothing yet.
  const OcptBudgetSharingState.init();

  /// Copies this state: there is nothing to replace.
  @override
  OcptBudgetSharingState copyWith() => this;

  /// Object properties
  @override
  List<Object?> get props => [...super.props];
}
