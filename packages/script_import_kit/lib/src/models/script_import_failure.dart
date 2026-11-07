// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

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
