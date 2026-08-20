// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';

/// Converts a [OcptShootingDayKind] to and from the text stored in the `shooting_days.kind` column.
class OcptShootingDayKindConverter extends TypeConverter<OcptShootingDayKind, String> {
  /// Class constructor
  const OcptShootingDayKindConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptShootingDayKind fromSql(String fromDb) => OcptShootingDayKind.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptShootingDayKind value) => value.name;
}

/// Converts a [OcptShootingDayStatus] to and from the text stored in the `shooting_days.status`
/// column.
class OcptShootingDayStatusConverter extends TypeConverter<OcptShootingDayStatus, String> {
  /// Class constructor
  const OcptShootingDayStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptShootingDayStatus fromSql(String fromDb) => OcptShootingDayStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptShootingDayStatus value) => value.name;
}

/// One day of the shooting schedule.
///
/// A day belongs to **no episode** (`docs/adr/0019-one-project-several-episodes.md`): it regularly
/// covers two of them at one location, which is the whole point of shooting a series out of order,
/// and the shared schedule is what makes that possible. Filing a day under one episode would make
/// the schedule mode lie about the plan it actually holds, so nothing here says which screenplay a
/// day is "for" — the schedule reads across every episode of the project.
///
/// A day is not necessarily a day that **shoots**: [kind] says whether it auditions or rehearses
/// instead, and a day of either sort is planned, convoked, alerted on and printed like the shooting
/// days beside it. Each kind is numbered in its own series, so `J3` still counts shooting days
/// alone.
///
/// A day is placed in the calendar by [date], never by a free-text label: the week and month
/// agenda views, the sun and twilight block and every crossing against a person's or a location's
/// availability all depend on it being real and never null. The *day number* printed on a call
/// sheet (`J3`) is, like `OcptShot.position`, never stored: it is a read-time rank over [sortKey].
///
/// Sunrise, sunset and the three twilights are **not columns here**: they are computed offline,
/// for the date this row carries, from the coordinates of the day's first slot's location — see
/// `lib/utils/ocpt_sun_times.dart` (a sibling table, `shooting_slots`, is what actually names a
/// location).
@DataClassName('OcptShootingDayRow')
class OcptShootingDaysTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShootingDaysTable}
  @override
  String get tableName => 'shooting_days';

  /// The stable, unique id of this day (a UUID).
  TextColumn get id => text()();

  /// The calendar date of this day. **Never null**: see the class doc comment.
  DateTimeColumn get date => dateTime()();

  /// {@macro open_cine_prod_tools.sortKey}
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// What this day is for: it shoots, it sees candidates, or it rehearses.
  // The stored literal below must match `OcptShootingDayKind.shoot.name` exactly, for the same
  // reason [status]'s own default does — an enum's `.name` getter isn't a compile-time constant
  // expression. Every day a project already held is a day that shoots, which this default answers
  // on its own, with nothing to backfill.
  TextColumn get kind =>
      text().map(const OcptShootingDayKindConverter()).withDefault(const Constant('shoot'))();

  /// Where this day stands.
  // The stored literal below must match `OcptShootingDayStatus.planned.name` exactly, for the same
  // reason `shots.status`'s default does: an enum's `.name` getter isn't a compile-time constant
  // expression, so it can't be written as `Constant(OcptShootingDayStatus.planned)`.
  TextColumn get status =>
      text().map(const OcptShootingDayStatusConverter()).withDefault(const Constant('planned'))();

  /// The call sheet's "NOTE À L'ÉQUIPE": free multi-line text printed for the whole crew.
  TextColumn get crewNote => text().withDefault(const Constant(''))();

  /// The weather forecast for this day, typed by hand — the app never reaches the network.
  TextColumn get weatherNote => text().withDefault(const Constant(''))();

  /// Internal notes about this day, never printed on a call sheet.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// {@macro open_cine_prod_tools.isDeleted}
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
