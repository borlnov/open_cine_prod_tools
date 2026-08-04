// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';

/// The ids of every person this replica has erased: what makes decision 6's erasure survive a
/// project version restore.
///
/// **This table is local and is never synchronised**, on the exact model of
/// `OcptProjectVersionsTable` — read that table's own doc comment first, and its warning that this
/// is not a precedent for a table that *is* synchronised. It carries no `isDeleted`, no `sortKey`
/// and no `row_field_versions` stamp, and it is the one other table of this schema whose rows may
/// be deleted for real (the app never does, but nothing here forbids it, unlike every synchronised
/// table).
///
/// A version payload is a hand-written mirror of the schema (`OcptProjectVersionCodec`'s own doc
/// comment), and a version captured before a person was erased still holds their full row — phone
/// number, address, allergies included — inside its stored payload, indefinitely: a version is
/// never rewritten once captured. Restoring that version must not resurrect the person, which is
/// exactly what this table is for: `OcptProjectVersionsService.restoreVersion` reads it and scrubs
/// every listed person back out as it hydrates the payload, rather than reintroducing them. This is
/// also why the list cannot live inside `project_info.settingsJson` — the codec captures that
/// column into every payload and writes it back on restore, which would rewind the very fact that
/// an erasure ever happened.
@DataClassName('OcptLocalErasureRow')
class OcptLocalErasuresTable extends Table {
  /// {@macro open_cine_prod_tools.OcptLocalErasuresTable}
  @override
  String get tableName => 'local_erasures';

  /// The id of the erased person. References [OcptPeopleTable]: erasure blanks and tombstones the
  /// person's row, it does not remove it, so the row this points at still exists.
  TextColumn get personId => text().references(OcptPeopleTable, #id)();

  /// The date and time at which this person was erased.
  DateTimeColumn get erasedAt => dateTime()();

  /// {@macro drift.Table.primaryKey}
  ///
  /// [personId] alone: a person is erased at most once — erasing them again is idempotent, not a
  /// second event to record.
  @override
  Set<Column> get primaryKey => {personId};
}
