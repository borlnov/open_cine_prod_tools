// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_people_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shooting_slots_table.dart';

/// Somebody attending a `shooting_slots` window who is neither crew nor cast — a mayor lending a
/// square, a journalist covering the day, an owner's cousin who wants to watch — the kind of
/// attendance a production regularly owes without ever meaning to enter that person in its address
/// book.
///
/// **A guest is convoked by the slot exactly as a crew member or a role is** — see
/// `lib/utils/ocpt_shooting_convocations.dart` (ADR 0018): this row's [slotId] is one of possibly
/// several slots the same guest is linked to on the same day, and their arrival and departure are
/// read off every live slot they are on, joined together, never typed here.
///
/// **Exactly one of [personId]/[freeName] says who the guest is** — the discriminator idiom
/// `breakdown_tags` and `shooting_slots.anchorMinute`/`anchorSlotId` already use. [personId] names
/// somebody already in the address book (an owner or a contact entered there for another reason);
/// [freeName] is what the production actually reaches for most of the time, since forcing a `people`
/// row onto a mayor invited for one afternoon would fill the address book with names nobody will
/// ever call again.
@DataClassName('OcptShootingSlotGuestRow')
class OcptShootingSlotGuestsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingSlotGuestsTable}
  @override
  String get tableName => 'shooting_slot_guests';

  /// The stable, unique id of this attendance (a UUID).
  TextColumn get id => text()();

  /// The slot this guest attends.
  TextColumn get slotId => text().references(OcptShootingSlotsTable, #id)();

  /// The address-book person this guest is, or null when [freeName] is used instead. Exactly one of
  /// the two is set.
  TextColumn get personId => text().nullable().references(OcptPeopleTable, #id)();

  /// A free-text name, used instead of [personId] when the guest is not, and will never be, a row of
  /// `people`. Empty when [personId] is set.
  TextColumn get freeName => text().withDefault(const Constant(''))();

  /// Why this guest is on set ("Maire, prête la place", "Journaliste, Ouest-France").
  TextColumn get reason => text().withDefault(const Constant(''))();

  /// Free-form notes about this attendance.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
