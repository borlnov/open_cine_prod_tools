// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';

/// A skill of a person: driving licences, swimming, languages, instruments — shown as chips on the
/// person sheet, and the thing an assistant director searches on when a scene needs one.
@DataClassName('OcptPersonSkillRow')
class OcptPersonSkillsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptPersonSkillsTable}
  @override
  String get tableName => 'person_skills';

  /// The stable, unique id of this skill entry (a UUID).
  ///
  /// A UUID rather than {[personId], [label]} as the key: two people can share a skill label, but
  /// the same person could also type the same label twice by mistake, and a chip still needs a
  /// stable identity to be individually edited or removed either way.
  TextColumn get id => text()();

  /// The person who has this skill.
  TextColumn get personId => text().references(OcptPeopleTable, #id)();

  /// The skill itself, free text (e.g. "Permis B", "Anglais courant", "Piano").
  TextColumn get label => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
