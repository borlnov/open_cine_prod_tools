// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';

/// The characters attached to a shot: its screenplay speaking characters, plus any free addition
/// for a silent role or an extra.
///
/// This is what makes the shot list's deleted-character banner meaningful: a character removed
/// from the screenplay still has its rows here until a user explicitly detaches or replaces it.
@DataClassName('OcptShotCharacterRow')
class OcptShotCharactersTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShotCharactersTable}
  @override
  String get tableName => 'shot_characters';

  /// The shot this character is attached to.
  TextColumn get shotId => text().references(OcptShotsTable, #id)();

  /// The character's name, normalised through `fountain_kit`'s `normalizeCharacterName` so it
  /// compares exactly against the screenplay's speaking characters.
  TextColumn get characterName => text()();

  /// The 0-based display order of this character among the shot's characters.
  IntColumn get position => integer()();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {shotId, characterName};
}
