// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/ocpt_database_abort.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';

/// Make a call to another service that answers a value, inside a `transaction`, abort that
/// transaction when it answered a failure (the counterpart of `OcptDatabaseOutcomeAbort`).
extension OcptDatabaseResultAbort<T> on Future<OcptDatabaseResult<T>> {
  /// Await the answer and raise [OcptDatabaseAbort] when it is a failure, else give its value,
  /// which is null when the call succeeded without one (a write the read-only preview refuses).
  Future<T?> valueOrAbort() async {
    final result = await this;
    if (result.isError) {
      throw OcptDatabaseAbort(result);
    }

    return result.value;
  }
}
