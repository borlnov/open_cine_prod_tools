// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/ocpt_database_abort.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';

/// Make a call to another service, inside a `transaction`, abort that transaction when it answered
/// a failure.
///
/// A transaction rolls back only on an exception leaving its closure, and a service answers a
/// status instead of raising: `await other.write().okOrAbort()` is the one way to call a converted
/// service from inside a transaction, so that a failure of the other service cannot let the
/// transaction commit what was written before it.
extension OcptDatabaseOutcomeAbort on Future<OcptDatabaseOutcome> {
  /// Await the answer and raise [OcptDatabaseAbort] when it is a failure.
  Future<void> okOrAbort() async {
    final outcome = await this;
    if (outcome.isError) {
      throw OcptDatabaseAbort(outcome);
    }
  }
}
