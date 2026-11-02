// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_foundation/act_foundation.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';

/// Thrown inside a transaction when a call to another service answered a failure: the transaction
/// must not commit what was written before it.
///
/// Only [AbsOcptService.guardResult] and [AbsOcptService.guardOutcome] catch it, and they answer
/// its [failure] as a `databaseError` without logging it again, since whoever answered the failure
/// has logged it.
class OcptDatabaseAbort implements Exception {
  /// The failure the other service answered.
  final StatusWithExtraInfo<MixinResultStatus> failure;

  /// Class constructor
  const OcptDatabaseAbort(this.failure);
}

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

/// The same for a call that answers a value.
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

/// The base of every `Ocpt…Service`.
///
/// A service is the unit of domain logic a manager is split into: it reads and writes one area of a
/// project (a database passed to each call), or builds one kind of document or file, and holds no
/// UI and no registration in `globalGetIt()` — the manager that owns it builds it and exposes it as
/// a field. It is not a manager: it is never registered, and its life cycle is driven by whoever
/// builds it, not by the global manager.
///
/// The life cycle is the one of [AbsWithLifeCycle]: its owner calls [initLifeCycle] when the owner
/// is itself initialised and [disposeLifeCycle] when it is disposed, in reverse order of building.
/// A service that builds services of its own owns them and drives theirs the same way. Both are
/// no-ops here and the constructor is `const`, so a service holding nothing to set up or release
/// stays `const` and needs neither call.
///
/// A service logs through the [logger] its owner hands it: a sub-logger of the owner's own, so the
/// category of a line reads `owner / service`. The owner builds it; a service never builds a
/// top-level logger of its own. It is typed by the interface rather than by the concrete helper so
/// a test can hand in a silent or a recording double.
///
/// A service that reads or writes the project database answers a result instead of raising: its
/// public method hands its whole body to [guardResult] or [guardOutcome], which catch what the
/// database raises, log it once and answer `databaseError`. Inside that boundary nothing changes,
/// and a failure must still raise so that a `transaction` rolls back.
abstract class AbsOcptService extends AbsWithLifeCycle {
  /// The logger this service writes to: a sub-logger built by its owner.
  @protected
  final MixinActLogger logger;

  /// Class constructor
  const AbsOcptService({required this.logger});

  /// Run [body], a read or a write called [operation], and answer what it produced, or
  /// `databaseError` when the database failed it. The failure is logged once, here, by type.
  ///
  /// A `null` from [body] is an answer like any other: a write the read-only preview refuses is
  /// a logged no-op that answers `ok` with no value. A mistake of the programmer
  /// ([ArgumentError], [AssertionError]) is not a failure of the database and goes through; a
  /// [RangeError], which is an [ArgumentError] too, does not: an index or an offset that falls
  /// outside what a read returned is a failure of the call, answered as `databaseError`.
  @protected
  Future<OcptDatabaseResult<T>> guardResult<T>(String operation, Future<T?> Function() body) async {
    OcptDatabaseResult<T> result;
    try {
      result = OcptDatabaseResult<T>(status: OcptDatabaseStatus.ok, value: await body());
    } on OcptDatabaseAbort catch (abort) {
      result = OcptDatabaseResult<T>(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: abort.failure.extraInfo,
      );
    } catch (error, stackTrace) {
      if ((error is ArgumentError && error is! RangeError) || error is AssertionError) {
        rethrow;
      }

      logger.e("The database failed '$operation': ${error.runtimeType}", null, stackTrace);
      result = OcptDatabaseResult<T>(
        status: OcptDatabaseStatus.databaseError,
        extraInfo: error.runtimeType,
      );
    }

    return result;
  }

  /// Run [body], a write called [operation] that answers nothing, and answer `ok`, or
  /// `databaseError` when the database failed it. See [guardResult].
  @protected
  Future<OcptDatabaseOutcome> guardOutcome(String operation, Future<void> Function() body) async {
    final result = await guardResult<void>(operation, body);

    return OcptDatabaseOutcome(status: result.status, extraInfo: result.extraInfo);
  }
}
