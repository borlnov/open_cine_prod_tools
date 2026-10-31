// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';

/// Which direction money moves under a gesture — what the `+ New` wizard filters by when it opens
/// from a working view, transverse to the families. See [ocptBudgetGestureFlowsOf].
enum OcptBudgetGestureFlow {
  /// The gesture makes money go out, planned or paid — the `Expenses` view's own filter.
  spends,

  /// The gesture brings money in, planned or received — the `Resources` view's own filter.
  brings,
}
