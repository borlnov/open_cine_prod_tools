// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A document the resources mode's export panel offers, through `OcptWorkspaceExportDialog`.
///
/// A single value today — the resources mode prints one workbook — kept as an enum rather than a
/// bare boolean so the panel's own generic wiring matches every other mode's.
enum OcptResourcesExportDocument {
  /// The whole catalogue — people, roles, locations and elements — as one Excel workbook, one
  /// sheet per category.
  xlsx,
}
