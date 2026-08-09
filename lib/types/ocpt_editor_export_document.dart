// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A document the screenplay mode's export panel offers, through `OcptWorkspaceExportDialog`.
///
/// Both values are always available — never carrying an `OcptWorkspaceExportEntry.unavailableReason`
/// — since a screenplay, whatever version is being previewed, always has a text and a page count to
/// print: unlike the other four modes' documents, nothing here depends on the project holding any
/// particular data.
enum OcptEditorExportDocument {
  /// The screenplay's own Fountain source, exported as plain text.
  fountain,

  /// The screenplay typeset on paper, exported as a PDF.
  pdf,
}
