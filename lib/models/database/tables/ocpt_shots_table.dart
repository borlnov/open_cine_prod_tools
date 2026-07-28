// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_scenes_table.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_screenplays_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Converts a [OcptShotStatus] to and from the text stored in the `shots.status` column.
class OcptShotStatusConverter extends TypeConverter<OcptShotStatus, String> {
  /// Class constructor
  const OcptShotStatusConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptShotStatus fromSql(String fromDb) => OcptShotStatus.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptShotStatus value) => value.name;
}

/// Converts a [OcptShotCheckReason] to and from the text stored in the `shots.checkReason`
/// column.
class OcptShotCheckReasonConverter extends TypeConverter<OcptShotCheckReason, String> {
  /// Class constructor
  const OcptShotCheckReasonConverter();

  /// {@macro drift.TypeConverter.fromSql}
  @override
  OcptShotCheckReason fromSql(String fromDb) => OcptShotCheckReason.values.byName(fromDb);

  /// {@macro drift.TypeConverter.toSql}
  @override
  String toSql(OcptShotCheckReason value) => value.name;
}

/// A single shot of a screenplay's shot list (découpage technique).
///
/// A shot belongs to a scene ([sceneId]), which the shot list treats as its "sequence": a
/// sequence is strictly a screenplay scene, never a free-standing row of its own. The shot
/// **code** shown to the user (e.g. `4/2`) is never stored here: it is derived at read time from
/// the scene's number and this shot's [position], recomputed on every insertion, deletion and
/// reorder, so it is always in step with the scene index.
@DataClassName('OcptShotRow')
class OcptShotsTable extends Table {
  /// {@macro open_cine_prod_tools.OcptShotsTable}
  @override
  String get tableName => 'shots';

  /// The stable, unique id of this shot (a UUID).
  TextColumn get id => text()();

  /// The screenplay this shot belongs to: the shot list is per screenplay, like the scene index.
  TextColumn get screenplayId => text().references(OcptScreenplaysTable, #id)();

  /// The scene this shot belongs to, or null if the scene was deleted from the screenplay: the
  /// shot is then orphaned rather than destroyed (see [orphanedHeading]).
  TextColumn get sceneId => text().nullable().references(OcptScenesTable, #id)();

  /// The heading the scene had at the moment it was deleted, so an orphaned shot still shows
  /// which scene it used to belong to. Null while [sceneId] is still set.
  TextColumn get orphanedHeading => text().nullable()();

  /// The 0-based rank of this shot within its scene (or, once orphaned, within the orphan group),
  /// used together with the scene's number to derive the shot's code.
  IntColumn get position => integer()();

  /// The shot size ("valeur de plan"), free text.
  TextColumn get shotSize => text().withDefault(const Constant(''))();

  /// The framing and composition ("angle et composition du cadre"), free text.
  TextColumn get framing => text().withDefault(const Constant(''))();

  /// The camera move ("mouvement d'appareil"), free text.
  TextColumn get cameraMove => text().withDefault(const Constant(''))();

  /// The lens/focal length ("focale / objectif"), free text.
  TextColumn get lens => text().withDefault(const Constant(''))();

  /// The recording format/frame rate (e.g. `4K · 25 fps`), free text.
  TextColumn get recordingFormat => text().withDefault(const Constant(''))();

  /// The estimated duration of the shot, in milliseconds, rendered `m:ss`; null until estimated.
  IntColumn get estimatedDurationMs => integer().nullable()();

  /// The shooting day this shot is planned for, free text until the schedule mode exists to
  /// reference it properly; null until planned.
  TextColumn get shootingDay => text().nullable()();

  /// The number of takes planned for this shot; null until planned.
  IntColumn get plannedTakes => integer().nullable()();

  /// Sound notes for this shot, free text.
  TextColumn get sound => text().withDefault(const Constant(''))();

  /// The shooting status of this shot.
  // The stored literal below must match `OcptShotStatus.toShoot.name` exactly: `withDefault`
  // requires a `Constant` of the column's raw SQL type, and an enum's `.name` getter is not a
  // compile-time constant expression, so it cannot be used inside `const Constant(...)` directly.
  TextColumn get status =>
      text().map(const OcptShotStatusConverter()).withDefault(const Constant('toShoot'))();

  /// The difficulty of the set/location, on a 0-5 scale.
  IntColumn get difficultySet => integer().withDefault(const Constant(1))();

  /// The difficulty of the camera move, on a 0-5 scale.
  IntColumn get difficultyCamera => integer().withDefault(const Constant(1))();

  /// The difficulty of the acting, on a 0-5 scale.
  IntColumn get difficultyActing => integer().withDefault(const Constant(1))();

  /// The difficulty of the sound recording, on a 0-5 scale.
  IntColumn get difficultySound => integer().withDefault(const Constant(1))();

  /// The director's notes for this shot, free multi-line text.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Location scouting notes for this shot, free multi-line text: a deliberate placeholder for a
  /// future locations module rather than a modelled relation.
  TextColumn get locationNotes => text().withDefault(const Constant(''))();

  /// Whether this shot needs checking by a human before it can be trusted (see [checkReason]).
  BoolColumn get needsCheck => boolean().withDefault(const Constant(false))();

  /// Why [needsCheck] is set, or null while it is false. See [OcptShotCheckReason] for why this
  /// is a stable reason code rather than a localised string.
  TextColumn get checkReason => text().nullable().map(const OcptShotCheckReasonConverter())();

  /// {@macro drift.Table.primaryKey}
  @override
  Set<Column> get primaryKey => {id};
}
