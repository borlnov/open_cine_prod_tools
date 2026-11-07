// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of a call to a project service that reads or writes the project database.
///
/// A service never lets a database failure out as an exception: it answers [databaseError].
/// [ok] says the database did not fail, not that a row was written: a write the read-only preview
/// refuses is a logged no-op, and answers [ok] with no value.
enum OcptDatabaseStatus with MixinResultStatus {
  /// The call ran: what it answers is in the value, or there was nothing to answer.
  ok(isSuccess: true, canBeRetried: false),

  /// The database refused or failed the call. A call that runs several transactions in turn may
  /// have committed the first ones before the failure, so this does not say that nothing was
  /// written. The `extraInfo` is the type of what failed, never its text, which can quote a query.
  databaseError(isSuccess: false, canBeRetried: true);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptDatabaseStatus({required this.isSuccess, required this.canBeRetried});
}

/// What a project service answers when the call has no value to give back.
typedef OcptDatabaseOutcome = StatusWithExtraInfo<OcptDatabaseStatus>;

/// What a project service answers when the call reads or creates a value of type [T].
typedef OcptDatabaseResult<T> = ResultWithStatus<OcptDatabaseStatus, T>;
