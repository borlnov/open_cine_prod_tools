// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_roles_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';

/// Converts a [OcptRoleCandidateStatus] to and from the text stored in the
/// `role_candidates.status` column.
class OcptRoleCandidateStatusConverter extends TypeConverter<OcptRoleCandidateStatus, String> {
  /// Class constructor
  const OcptRoleCandidateStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptRoleCandidateStatus fromSql(String fromDb) => OcptRoleCandidateStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptRoleCandidateStatus value) => value.name;
}

/// One person seen for one part, and what the casting decision is being made on.
///
/// `roles.personId` is a single column: a role has an actor or it has none. Casting is the whole
/// period before that column can be filled — several people are seen for one part, notes are kept
/// on each, one is eventually retained — and this table is where that period lives.
/// `OcptRoleElementsTable`'s sibling on the casting side of the same role: a link between `roles`
/// and `people` carrying what belongs to the pairing rather than to either end of it.
///
/// **A person is one row, whatever they do on the film**: an actor seen for two parts is one
/// `people` row and two `role_candidates` rows, and their photo, their self-tape and their contact
/// details are read off their own sheet rather than copied here — which is why this table carries
/// no reference column of its own, `assets` already answering through its `personId`.
///
/// **The retained rule is `OcptRoleCandidatesService`'s, not the schema's.** Nothing here refuses a
/// second [status] of [OcptRoleCandidateStatus.retained] on the same role, and nothing here keeps
/// `roles.personId` in step with the row holding it: that is one rule about two tables agreeing,
/// and it is written once, in the service, so every caller gets the same answer. The role header's
/// own cast picker stays editable beside it and writes `roles.personId` alone — a production that
/// ran no auditions casts directly, and touches no row of this table doing it.
///
/// [notes] is **personal data about a person**, so this table joins the erasure rule
/// (`OcptPeopleService.deletePerson`, `OcptProjectVersionsService` and
/// `ocptScrubErasedPeopleFromPayload`, the three implementations kept in step by hand): erasing a
/// person blanks it and tombstones the row.
@DataClassName('OcptRoleCandidateRow')
class OcptRoleCandidatesTable extends Table {
  /// {@macro open_cine_prod_tools.OcptRoleCandidatesTable}
  @override
  String get tableName => 'role_candidates';

  /// The stable, unique id of this candidacy (a UUID).
  TextColumn get id => text()();

  /// The part this person is seen for.
  TextColumn get roleId => text().references(OcptRolesTable, #id)();

  /// The person seen — a `people` row like everybody else on the film.
  TextColumn get personId => text().references(OcptPeopleTable, #id)();

  /// Where this person stands in the casting of this part.
  // The stored literal below must match `OcptRoleCandidateStatus.seen.name` exactly, for the same
  // reason `shooting_days.status`'s default does: an enum's `.name` getter isn't a compile-time
  // constant expression, so it can't be written as `Constant(OcptRoleCandidateStatus.seen)`.
  TextColumn get status =>
      text().map(const OcptRoleCandidateStatusConverter()).withDefault(const Constant('seen'))();

  /// When this person was seen for the part, or null while nobody has said.
  ///
  /// **Typed by hand, never derived from a session**: a candidate seen before the app was opened,
  /// or seen over a self-tape, has a date and no session at all, and a date read off a block would
  /// go empty the day that block is deleted.
  DateTimeColumn get auditionedOn => dateTime().nullable()();

  /// The impressions kept on **this** person for **this** part, free text.
  ///
  /// Personal data about the person, and blanked by an erasure — see the class doc comment.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.sortKey}
  ///
  /// Unlike `role_elements`, which carries none, a role's candidates **are** a list the user ranks:
  /// a casting director's own order over the people they have seen is a reading of its own, and the
  /// card lets them arrange it.
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
