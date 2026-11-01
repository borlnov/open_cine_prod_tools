// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_shots_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';

/// The values already typed in the shot list's free-text columns, offered back as suggestions.
///
/// What `OcptShotListService` forwards to; see `OcptShotListCharacterOps`.
abstract final class OcptShotListSuggestionOps {
  /// Every distinct, non-empty value of `shots.shotSize` across screenplay [screenplayId], for the
  /// field's project-wide suggestion list.
  static Future<List<String>> distinctShotSizes({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _distinctValuesOf(
    database: database,
    screenplayId: screenplayId,
    column: (table) => table.shotSize,
  );

  /// Every distinct, non-empty value of `shots.framing` across screenplay [screenplayId], for the
  /// field's project-wide suggestion list.
  static Future<List<String>> distinctFramings({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _distinctValuesOf(
    database: database,
    screenplayId: screenplayId,
    column: (table) => table.framing,
  );

  /// Every distinct, non-empty value of `shots.cameraMove` across screenplay [screenplayId], for
  /// the field's project-wide suggestion list.
  static Future<List<String>> distinctCameraMoves({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _distinctValuesOf(
    database: database,
    screenplayId: screenplayId,
    column: (table) => table.cameraMove,
  );

  /// Every distinct, non-empty value of `shots.lens` across screenplay [screenplayId], for the
  /// field's project-wide suggestion list.
  static Future<List<String>> distinctLenses({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _distinctValuesOf(
    database: database,
    screenplayId: screenplayId,
    column: (table) => table.lens,
  );

  /// Every distinct, non-empty value of `shots.recordingFormat` across screenplay [screenplayId],
  /// for the field's project-wide suggestion list.
  static Future<List<String>> distinctRecordingFormats({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _distinctValuesOf(
    database: database,
    screenplayId: screenplayId,
    column: (table) => table.recordingFormat,
  );

  /// Every distinct, non-empty value of `shots.sound` across screenplay [screenplayId], for the
  /// field's project-wide suggestion list.
  static Future<List<String>> distinctSounds({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _distinctValuesOf(
    database: database,
    screenplayId: screenplayId,
    column: (table) => table.sound,
  );

  /// Every free-text field's suggestion list, scoped to screenplay [screenplayId]: what has already
  /// been entered elsewhere in *this* screenplay, not the whole project's.
  static Future<OcptShotFieldSuggestions> loadFieldSuggestions({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async => OcptShotFieldSuggestions(
    shotSizes: await distinctShotSizes(database: database, screenplayId: screenplayId),
    framings: await distinctFramings(database: database, screenplayId: screenplayId),
    cameraMoves: await distinctCameraMoves(database: database, screenplayId: screenplayId),
    lenses: await distinctLenses(database: database, screenplayId: screenplayId),
    recordingFormats: await distinctRecordingFormats(
      database: database,
      screenplayId: screenplayId,
    ),
    sounds: await distinctSounds(database: database, screenplayId: screenplayId),
  );

  /// Collects the distinct, non-empty values of a single free-text column of `shots` across
  /// screenplay [screenplayId], sorted alphabetically.
  static Future<List<String>> _distinctValuesOf({
    required OcptProjectDatabase database,
    required String screenplayId,
    required TextColumn Function(OcptShotsTable table) column,
  }) async {
    final query = database.selectOnly(database.ocptShotsTable, distinct: true)
      ..addColumns([column(database.ocptShotsTable)])
      ..where(
        database.ocptShotsTable.screenplayId.equals(screenplayId) &
            database.ocptShotsTable.isDeleted.not() &
            column(database.ocptShotsTable).equals("").not(),
      )
      ..orderBy([OrderingTerm.asc(column(database.ocptShotsTable))]);

    final rows = await query.get();
    return [for (final row in rows) row.read(column(database.ocptShotsTable))!];
  }
}
