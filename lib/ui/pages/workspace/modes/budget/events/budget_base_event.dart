// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The events of the budget mode, the common base of its per-domain sealed hierarchies (each in
/// its own file, since a sealed class's subclasses must share its library).
abstract class OcptBudgetEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptBudgetEvent();
}
