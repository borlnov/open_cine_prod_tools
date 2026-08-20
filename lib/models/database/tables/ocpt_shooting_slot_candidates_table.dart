// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_role_candidates_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slots_table.dart';

/// Which candidate is convoked during a slot: the fourth kind of link a `shooting_slots` row
/// carries, beside its crew, its cast and its guests.
///
/// **ADR 0018 is untouched by this table** — it is what applies it one step earlier: you are
/// convoked because you are **linked to a slot**, never because a block names you. An
/// `OcptShootingBlockKind.audition` block says *what happens at this hour*; this row says *this
/// person is expected on this unit*, and every clock about them — their arrival, their PAT band
/// over the slot's shooting blocks, their departure — is read off the slots they are linked to,
/// exactly as everybody else's is (`lib/utils/ocpt_shooting_convocations.dart`). It is also what
/// that ADR's own cost buys: convoking twelve candidates at twenty-minute intervals is twelve
/// slots, because twelve people arriving at twelve different hours is what a slot *is*.
///
/// **A candidacy is named, not a person** — [roleCandidateId] rather than a `personId` — for the
/// same reason `OcptShootingSlotCastTable` names a role rather than an actor: the convocation is
/// about somebody being seen *for a part*, and one person seen for two parts on one day is two
/// convocations, each about a different twenty minutes. The person, their photo and their phone
/// number are read through that candidacy's own `role_candidates.personId`.
///
/// A row whose candidacy has since been removed is **read defensively and drops out**, no cascade
/// being written for it — the same treatment a `shooting_slot_cast` row gets when its role is
/// deleted under it.
@DataClassName('OcptShootingSlotCandidateRow')
class OcptShootingSlotCandidatesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingSlotCandidatesTable}
  @override
  String get tableName => 'shooting_slot_candidates';

  /// The stable, unique id of this convocation (a UUID).
  TextColumn get id => text()();

  /// The slot this convocation is for.
  TextColumn get slotId => text().references(OcptShootingSlotsTable, #id)();

  /// The candidacy convoked during the slot — who, for which part.
  TextColumn get roleCandidateId => text().references(OcptRoleCandidatesTable, #id)();

  /// {@macro open_cine_prod_tools.sortKey}
  ///
  /// The order the candidates were added to this slot, which is the order the band draws them in —
  /// `shooting_slot_cast` carries one for the same reason, a convocation list being read down.
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// Free-form notes about this convocation, the sibling of `shooting_slot_cast.notes`.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
