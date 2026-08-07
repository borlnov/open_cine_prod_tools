// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_locations_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_sets_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_days_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// Converts a [OcptShootingSlotAnchorEdge] to and from the text stored in the
/// `shooting_slots.anchor_edge` column.
class OcptShootingSlotAnchorEdgeConverter
    extends TypeConverter<OcptShootingSlotAnchorEdge, String> {
  /// Class constructor
  const OcptShootingSlotAnchorEdgeConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptShootingSlotAnchorEdge fromSql(String fromDb) =>
      OcptShootingSlotAnchorEdge.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptShootingSlotAnchorEdge value) => value.name;
}

/// A convocation window inside a day — the *créneau* the reference call sheets print. A day has at
/// least one; the second reference call sheet has two, with different crews, different locations
/// and different call times.
///
/// [locationId] and [setId] are both nullable and independent of any other slot of the same day:
/// nothing here forces every slot of a day to share a location.
///
/// **A slot owns exactly one pinned edge, and no other clock.** [anchorEdge] says which of its two
/// edges is the fixed one, and the hour that edge sits at comes from exactly one of two places: a
/// typed [anchorMinute], or the **opposite** edge of another slot of the same day ([anchorSlotId]).
/// Exactly one of the two is non-null, the discriminator idiom `breakdown_tags` already uses. Every
/// other time a call sheet prints for this slot — where its blocks land, when it actually ends, a
/// crew member's or an actor's own arrival, readiness band and departure — is computed from that
/// one hour and from the slot's own chain of `shooting_day_blocks`, never stored: see
/// `lib/utils/ocpt_shooting_day_timeline.dart` (ADR 0015, amended twice) and
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0018).
///
/// **The linked edge is always the opposite one**, so nothing stores which edge is read: a `start`
/// reads its source's end, an `end` reads its source's start. A link only ever joins **two slots of
/// the same day** — a night crossing midnight is already carried by the day it starts on, in
/// minutes past 1440, so no case needs to cross two days — and never two edges of the same side:
/// "these two start together" is said by typing the same hour twice.
///
/// A stored minute **may exceed 1440**: a night slot running 19:00 → 03:00 stores `1140`, an offset
/// from the day's own midnight, nothing ever taken modulo anything — see
/// `lib/utils/ocpt_day_minute.dart`, the single place that renders one. This is written down
/// because getting it wrong only shows up on the one night shoot of a production.
///
/// The reference call sheets' "HORAIRES ÉQUIPE IMAGE 16:45 / HORAIRES ÉQUIPE TECHNIQUE 18:30" is
/// **not** a second pair of columns here: it is a fact about a slot's own convocations, read off
/// every slot a person or a role is linked to — see `OcptShootingSlotCrewTable`'s own doc comment
/// and ADR 0018. A production that wants one crew called earlier creates the slot that says so.
@DataClassName('OcptShootingSlotRow')
class OcptShootingSlotsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingSlotsTable}
  @override
  String get tableName => 'shooting_slots';

  /// The stable, unique id of this slot (a UUID).
  TextColumn get id => text()();

  /// The day this slot belongs to.
  TextColumn get shootingDayId => text().references(OcptShootingDaysTable, #id)();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// This slot's own label ("Matin", "Nuit"), free text — printed on the call sheet as the name of
  /// the convocation window.
  TextColumn get label => text().withDefault(const Constant(''))();

  /// The location this slot is shot at, or null while none is chosen.
  TextColumn get locationId => text().nullable().references(OcptLocationsTable, #id)();

  /// The set (décor) this slot is shot at, or null while none is chosen. Its own
  /// `sets.locationId` must be [locationId].
  TextColumn get setId => text().nullable().references(OcptSetsTable, #id)();

  /// Which of this slot's two edges is the pinned one — see the class doc comment.
  // The stored literal below must match `OcptShootingSlotAnchorEdge.start.name` exactly, for the
  // same reason `shooting_days.status`'s default does: an enum's `.name` getter isn't a
  // compile-time constant expression.
  TextColumn get anchorEdge => text()
      .map(const OcptShootingSlotAnchorEdgeConverter())
      .withDefault(const Constant('start'))();

  /// The hour [anchorEdge] is pinned to, typed by hand — **null exactly when [anchorSlotId] is
  /// set**. May exceed 1440, see the class doc comment.
  IntColumn get anchorMinute => integer().nullable()();

  /// The slot of the same day whose **opposite** edge [anchorEdge] reads its hour off — **null
  /// exactly when [anchorMinute] is set**. See the class doc comment.
  TextColumn get anchorSlotId => text().nullable().references(OcptShootingSlotsTable, #id)();

  /// Free-form notes about this slot.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
