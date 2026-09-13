// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The names of the columns [to] holds a different value in than [from], as the Dart side of the
/// schema spells them — which is exactly how `row_field_versions.columnName` spells them too.
///
/// [from] and [to] are a row's own `DataClass.toJson()` map, read off rather than compared field
/// by field per table: a column added to a synchronised table is then stamped by whoever writes it
/// — a restore today, an ordinary domain write once the changeset engine lands
/// (`docs/plans/collaboration-and-sync.md`, M3) — without anybody having to remember to add it
/// here. Taking plain `Map<String, dynamic>`s rather than two `DataClass`es keeps this rule free of
/// any drift import: the one column this schema's own diffing rule needs is the row's already-JSON
/// shape, not the row itself.
List<String> ocptChangedColumnNames({
  required Map<String, dynamic> from,
  required Map<String, dynamic> to,
}) => [
  for (final column in to.entries)
    if (from[column.key] != column.value) column.key,
];
