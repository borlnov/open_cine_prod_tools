// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A document the breakdown mode's export panel offers, through `OcptWorkspaceExportDialog`.
///
/// A single value today — the breakdown mode prints one document — kept as an enum rather than a
/// bare boolean so the panel's own generic wiring matches every other mode's.
enum OcptBreakdownExportDocument {
  /// One printed sheet per scene, everything tagged in it.
  sheets,
}
