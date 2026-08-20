// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The screenplay file format a `ScriptImportResult` was read from.
enum ScriptImportFormat {
  /// A plain Fountain screenplay (`.fountain`).
  ///
  /// Never produced by `ScriptImporter`, which only ever reads the foreign
  /// formats: reading Fountain needs no conversion at all and stays the
  /// caller's own business. This value exists so that a caller handling all
  /// three formats through one type can still name that case.
  fountain,

  /// A Final Draft screenplay (`.fdx`), read by `FdxScriptReader`.
  finalDraft,

  /// A legacy Celtx project (`.celtx`).
  celtx,
}
