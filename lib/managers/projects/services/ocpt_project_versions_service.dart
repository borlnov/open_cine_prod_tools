// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';
import 'package:uuid/uuid.dart';

/// Creates, lists and deletes a project's named versions: the production history the user drives
/// from the workspace's `Versions` dock tab.
///
/// {@macro open_cine_prod_tools.OcptProjectVersionsTable.versusSnapshots}
///
/// Everything about the payload's *shape* belongs to [OcptProjectVersionCodec]; this service is
/// what reads the rows out of a project and writes a version's row back. The two facts about a
/// version that no caller may work around:
///
/// - a version captures **every row** of the tables it covers, tombstones included, exactly as
///   they stand — no read here filters `isDeleted` out, unlike every other read in the app;
/// - versions are **never pruned**. Unlike `screenplay_snapshots`, only the user deletes one.
class OcptProjectVersionsService {
  /// The tables a payload carries every row of, as `row_field_versions.table_name` spells them.
  ///
  /// The stamps of those tables — and of no others — travel with a version (see
  /// [_captureRowFieldVersions]).
  static const _payloadTableNames = [
    'screenplays',
    'scenes',
    'shots',
    'shot_characters',
    'shot_coverages',
  ];

  /// The codec turning the captured state into the text stored in `project_versions.payload`.
  final OcptProjectVersionCodec _codec;

  /// Class constructor
  const OcptProjectVersionsService({required OcptProjectVersionCodec codec}) : _codec = codec;

  /// Lists every version of the project in [database], newest first.
  ///
  /// Deliberately does **not** deserialize any payload: a card renders from the counters stored
  /// with the version, and a payload is hundreds of kilobytes.
  Future<List<OcptProjectVersion>> listVersions({required OcptProjectDatabase database}) async {
    final rows =
        await (database.select(database.ocptProjectVersionsTable)
              ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
            .get();

    final info = await database.select(database.ocptProjectInfoTable).getSingleOrNull();

    return [
      for (final row in rows)
        OcptProjectVersion.fromRow(row: row, isCurrent: row.id == info?.currentVersionId),
    ];
  }

  /// Captures the current state of the project in [database] as a new version named [name], with
  /// the user's [note], and makes it the version the working copy descends from.
  ///
  /// [appVersion] and [deviceId] are recorded on the row for provenance; [pageMargins] completes
  /// the page setup the version is measured and, later, restored against — the format is project
  /// data, the margins are the app-wide preference, and only the caller knows the latter.
  ///
  /// The capture, the insertion and the pointer update all happen in one transaction, so a version
  /// can never describe a project state that never existed.
  Future<OcptProjectVersion> createVersion({
    required OcptProjectDatabase database,
    required String name,
    required String note,
    required String appVersion,
    required String deviceId,
    required FountainPageMargins pageMargins,
  }) {
    final id = const Uuid().v4();
    final createdAt = DateTime.now();

    return database.transaction(() async {
      final payload = await _capturePayload(database: database, pageMargins: pageMargins);
      final summary = OcptProjectVersionSummary.of(payload);

      await database
          .into(database.ocptProjectVersionsTable)
          .insert(
            OcptProjectVersionsTableCompanion.insert(
              id: id,
              name: name,
              note: Value(note),
              createdAt: createdAt,
              appVersion: appVersion,
              payloadFormat: OcptProjectVersionCodec.currentPayloadFormat,
              payload: _codec.encode(payload),
              summaryJson: jsonEncode(summary.toJson()),
              createdByDeviceId: deviceId,
            ),
          );

      await database
          .update(database.ocptProjectInfoTable)
          .write(OcptProjectInfoTableCompanion(currentVersionId: Value(id)));

      return OcptProjectVersion(
        id: id,
        name: name,
        note: note,
        createdAt: createdAt,
        summary: summary,
        isCurrent: true,
      );
    });
  }

  /// Deletes the version [id] of the project in [database], clearing the project header's pointer
  /// first when it is the one being deleted.
  ///
  /// This is a **real** `delete()`, and the only one left in the app: `project_versions` is local
  /// and never synchronised, so there is no replica to tell about the deletion and nothing to
  /// tombstone (see the table's doc comment — do not read this as a precedent for a synchronised
  /// table). The pointer is cleared inside the same transaction and before the row goes, since
  /// `project_info.currentVersionId` references it and the `foreign_keys` pragma is on.
  ///
  /// Deleting the version *currently being previewed* has to be refused, but that is a matter of
  /// the open project's state rather than of the database, so it belongs to `OcptProjectsManager`
  /// alongside the preview it owns — which doesn't exist yet.
  Future<void> deleteVersion({
    required OcptProjectDatabase database,
    required String id,
  }) async {
    await database.transaction(() async {
      final info = await database.select(database.ocptProjectInfoTable).getSingleOrNull();

      if (info?.currentVersionId == id) {
        await database
            .update(database.ocptProjectInfoTable)
            .write(const OcptProjectInfoTableCompanion(currentVersionId: Value(null)));
      }

      await (database.delete(
        database.ocptProjectVersionsTable,
      )..where((table) => table.id.equals(id))).go();
    });
  }

  /// Reads the whole state of the project in [database] into a payload, at [pageMargins].
  ///
  /// One query per table, none of them filtering tombstones: a version that carried only the live
  /// rows would, on restore, resurrect everything the user had deleted since.
  Future<OcptProjectVersionPayload> _capturePayload({
    required OcptProjectDatabase database,
    required FountainPageMargins pageMargins,
  }) async {
    final info = await database.select(database.ocptProjectInfoTable).getSingle();

    return OcptProjectVersionPayload(
      screenplays: await database.select(database.ocptScreenplaysTable).get(),
      scenes: await database.select(database.ocptScenesTable).get(),
      shots: await database.select(database.ocptShotsTable).get(),
      shotCharacters: await database.select(database.ocptShotCharactersTable).get(),
      shotCoverages: await database.select(database.ocptShotCoveragesTable).get(),
      rowFieldVersions: await _captureRowFieldVersions(database: database),
      pageSetup: OcptPageSetup(format: info.pageFormat, margins: pageMargins),
      settingsJson: info.settingsJson,
    );
  }

  /// Reads the version stamps of the rows the payload carries.
  ///
  /// Scoped by table rather than row by row, which comes to the same thing: a capture takes every
  /// row of [_payloadTableNames], so every stamp of those tables describes a row the payload holds.
  /// Scoping by row id would additionally need the encoding `shot_characters`' composite key is
  /// written with, which belongs to the changeset engine that writes stamps — and which doesn't
  /// exist yet.
  Future<List<OcptRowFieldVersionRow>> _captureRowFieldVersions({
    required OcptProjectDatabase database,
  }) => (database.select(
    database.ocptRowFieldVersionsTable,
  )..where((table) => table.targetTableName.isIn(_payloadTableNames))).get();
}
