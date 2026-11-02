// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expectations on the result a service answers, for the thousands of calls tests make to read a
/// value or to seed a project.
///
/// This is the one helper shared between test files, a deliberate exception to the rule that each
/// test file carries its own doubles: a call whose failure a test does not look at would otherwise
/// need an explicit `expect` of its status at each of those calls, and the extension says the same
/// thing once. A failing call stops the test with the status and the detail it answered.
extension OcptOutcomeExpectations<S extends MixinResultStatus> on Future<StatusWithExtraInfo<S>> {
  /// Await the answer and fail the test unless it is a success.
  Future<void> get okOrFail async {
    final outcome = await this;
    if (outcome.isError) {
      fail("Expected a success, got ${outcome.status} (${outcome.extraInfo}).");
    }
  }
}

/// The same for a call that answers a value.
extension OcptResultExpectations<S extends MixinResultStatus, V> on Future<ResultWithStatus<S, V>> {
  /// Await the answer and fail the test unless it is a success, then give its value, which is
  /// null when the call succeeded without one (a write a read-only preview refuses).
  Future<V?> get maybeValueOrFail async {
    final result = await this;
    if (result.isError) {
      fail("Expected a success, got ${result.status} (${result.extraInfo}).");
    }

    return result.value;
  }

  /// Await the answer and fail the test unless it is a success carrying a value.
  Future<V> get valueOrFail async {
    final value = await maybeValueOrFail;
    if (value == null) {
      fail("Expected a value, the call succeeded without one.");
    }

    return value;
  }
}
