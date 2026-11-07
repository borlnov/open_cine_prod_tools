// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// Why an incoming changeset could not be merged into the project's file: the [error] that stood
/// for it and the [stackTrace] it was met with, kept so the sync session that decides what the
/// failure means (going offline) can log both, exactly as it does for an
/// `OcptSyncTransportFailure`.
class OcptSyncMergeFailure extends Equatable {
  /// The error that stands for the failure.
  final Object error;

  /// The stack trace [error] was met with, when there was one.
  final StackTrace? stackTrace;

  /// Class constructor
  const OcptSyncMergeFailure({required this.error, this.stackTrace});

  /// Get the error's own text, which is what a diagnostics line quotes.
  @override
  String toString() => error.toString();

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [error];
}
