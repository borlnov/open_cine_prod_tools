// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';
import 'package:script_import_kit/src/models/script_import_failure.dart';

/// Thrown by a reader, and by `ScriptImporter`, when a file cannot be read
/// as a screenplay.
///
/// [details] is developer-facing context (a parser message, the offending
/// extension); it is never meant to be shown to a user. This package knows
/// nothing about any UI, so naming the failure in a user's language is the
/// caller's job, driven by [failure].
@immutable
class ScriptImportException implements Exception {
  /// Why the file could not be read.
  final ScriptImportFailure failure;

  /// Developer-facing context about the failure, or `null` when there is
  /// nothing to add to [failure] itself.
  final String? details;

  /// Creates a [ScriptImportException].
  const ScriptImportException(this.failure, {this.details});

  @override
  String toString() {
    final suffix = details == null ? '' : ': $details';
    return 'ScriptImportException(${failure.name})$suffix';
  }
}
