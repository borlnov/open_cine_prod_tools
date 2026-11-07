// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_foundation/act_foundation.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:open_cine_prod_tools/managers/ocpt_database_abort.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';

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
  /// a logged no-op that answers `ok` with no value. Only an [AssertionError], a mistake of the
  /// programmer that a release build never raises, goes through. Everything else becomes
  /// `databaseError`, an [ArgumentError] and a [RangeError] included: a caller that used to catch
  /// one of those around the call acts on the failed status at the same point, and letting it
  /// through would skip the caller's own stop, and whatever followed it.
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
      if (error is AssertionError) {
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
