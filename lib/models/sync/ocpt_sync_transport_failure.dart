// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What an `OcptRemoteStorage` transport caught when a call failed for a reason that is not a sync
/// error the relay answered: the [error] itself and the [stackTrace] it was caught with, kept so
/// the caller that decides what the failure means (a sync session going offline) can log both.
class OcptSyncTransportFailure extends Equatable {
  /// The error the transport caught.
  final Object error;

  /// The stack trace [error] was caught with, when there was one.
  final StackTrace? stackTrace;

  /// Class constructor
  const OcptSyncTransportFailure({required this.error, this.stackTrace});

  /// The caught error's own text, which is what a diagnostics line quotes.
  @override
  String toString() => error.toString();

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [error];
}
