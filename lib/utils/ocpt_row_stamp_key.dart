// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The character joining the components of a composite key in [ocptCompositeRowStampKey].
///
/// A slash is safe here — and readable in a database dump, which a control character would not be
/// — because every composite key of this schema starts with a UUID: the components can always be
/// told apart, whatever the ones after the first happen to contain.
const _ocptRowStampKeySeparator = "/";

/// The `row_field_versions.rowId` naming the row [parts] is the primary key of.
///
/// Every synchronised table of this project keys its rows by a single text column except
/// `shot_characters`, whose key is `{shotId, characterName}`: this is the one encoding the whole app
/// writes such a key with, and the one whoever parses it back must read it with. It lives in its own
/// file rather than inside the first service that needed it (`OcptProjectVersionsService`, whose
/// restore is the first writer of a version stamp) because the changeset engine of
/// `docs/plans/collaboration-and-sync.md` will be the second, and two encodings of the same key
/// would silently split the merge history of every row that has one.
///
/// A single-column key needs no encoding at all: pass it as is rather than through here.
String ocptCompositeRowStampKey(Iterable<String> parts) => parts.join(_ocptRowStampKeySeparator);

/// The SQL expression equivalent of [ocptCompositeRowStampKey]: concatenates [quotedColumns] —
/// each already the quoted SQL identifier of one primary-key column, in the same declared order
/// [ocptCompositeRowStampKey] itself receives its parts in — with the very same separator.
///
/// This is what lets a generic reader (the changeset engine of
/// `docs/plans/collaboration-and-sync.md`, M3) match a stored `row_field_versions.rowId` against a
/// table's own current row without ever parsing that id back apart: `WHERE <this> = ?` reproduces
/// exactly the same string [ocptCompositeRowStampKey] wrote, whatever a later component happens to
/// contain — even the separator itself, since nothing here ever needs to split it back out. A
/// single-column key needs no concatenation either, matching [ocptCompositeRowStampKey]'s own
/// single-part case: [quotedColumns] is simply returned as its one element.
String ocptCompositeRowStampKeySqlExpression(Iterable<String> quotedColumns) {
  final columns = quotedColumns.toList();
  if (columns.length == 1) {
    return columns.single;
  }

  return columns.join(" || '$_ocptRowStampKeySeparator' || ");
}
