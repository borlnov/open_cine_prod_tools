// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';

/// Why a screenplay file could not be read.
///
/// A reader always throws one of these rather than returning a half-wrong
/// screenplay: a conversion that silently drops the half of a file it did
/// not understand is worse than no conversion at all, since nothing
/// downstream can tell the difference.
enum ScriptImportFailure {
  /// The file's extension names no format this package reads, or the file
  /// declares itself to be something other than a screenplay (a Final Draft
  /// document whose `DocumentType` is not `Script`, for example).
  unsupportedFormat,

  /// The file's own container is broken: XML that does not parse, a zip
  /// that does not open.
  malformedFile,

  /// The container opened but holds no script document to read (a Celtx
  /// project with no readable manifest, or none listing a script).
  noScriptDocument,

  /// The script document was read but holds not one line of screenplay.
  emptyScript,
}

/// Thrown by a reader, and by `ScriptImporter`, when a file cannot be read
/// as a screenplay.
///
/// [details] is developer-facing context (a parser message, the offending
/// extension); it is never meant to be shown to a user. This package knows
/// nothing about any UI, so naming the failure in a user's language is the
/// caller's job, driven by [failure].
@immutable
class ScriptImportException implements Exception {
  /// Creates a [ScriptImportException].
  const ScriptImportException(this.failure, {this.details});

  /// Why the file could not be read.
  final ScriptImportFailure failure;

  /// Developer-facing context about the failure, or `null` when there is
  /// nothing to add to [failure] itself.
  final String? details;

  @override
  String toString() {
    final suffix = details == null ? '' : ': $details';
    return 'ScriptImportException(${failure.name})$suffix';
  }
}
