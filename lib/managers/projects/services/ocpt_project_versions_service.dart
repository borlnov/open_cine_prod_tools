// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';
import 'package:uuid/uuid.dart';

/// Creates, lists, deletes and restores a project's named versions: the production history the user
/// drives from the workspace's `Versions` dock tab.
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

  /// The name, as the Dart side of the schema spells it, of the tombstone column every
  /// synchronised table carries: the one column a restore stamps on a row the payload doesn't hold.
  static const _isDeletedColumnName = "isDeleted";

  /// The codec turning the captured state into the text stored in `project_versions.payload`.
  final OcptProjectVersionCodec _codec;

  /// The service taking the screenplay snapshot a restore owes the merge before it overwrites a
  /// screenplay's text (see [restoreVersion]).
  final OcptScreenplayService _screenplayService;

  /// Class constructor
  const OcptProjectVersionsService({
    required OcptProjectVersionCodec codec,
    required OcptScreenplayService screenplayService,
  }) : _codec = codec,
       _screenplayService = screenplayService;

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
  /// data, the margins are the app-wide preference, and only the caller knows the latter. The row
  /// is also stamped with `OcptProjectVersionCodec.contentDigest` of the very payload it stores,
  /// so a later caller can tell whether the working copy has drifted from this version without
  /// decoding its payload back out.
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
              contentDigest: Value(_codec.contentDigest(payload)),
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

  /// Loads the single version [id] of the project in [database], or null if it has no such
  /// version.
  ///
  /// Reads the card's columns alone, deliberately leaving `payload` in the file: this is what the
  /// preview asks for the version's *identity* with, and it must stay as cheap as [listVersions]
  /// even though the payload of that same row is about to be read by [loadPayload].
  Future<OcptProjectVersion?> loadVersion({
    required OcptProjectDatabase database,
    required String id,
  }) async {
    final table = database.ocptProjectVersionsTable;

    final row =
        await (database.selectOnly(table)
              ..addColumns([table.id, table.name, table.note, table.createdAt, table.summaryJson])
              ..where(table.id.equals(id)))
            .getSingleOrNull();

    if (row == null) {
      return null;
    }

    final info = await database.select(database.ocptProjectInfoTable).getSingleOrNull();

    return OcptProjectVersion(
      id: row.read(table.id)!,
      name: row.read(table.name)!,
      note: row.read(table.note)!,
      createdAt: row.read(table.createdAt)!,
      summary: OcptProjectVersionSummary.parse(row.read(table.summaryJson)!),
      isCurrent: info?.currentVersionId == id,
    );
  }

  /// Reads and decodes the payload of the version [id] of the project in [database].
  ///
  /// This is the one read that does deserialize a payload, and it exists for the two operations
  /// that need the state itself rather than the card: entering a version's preview, and restoring
  /// it. Every failure comes back as a status — a version whose payload can't be read is a version
  /// the user must be told about, never an exception thrown at whichever screen asked.
  Future<ResultWithStatus<OcptProjectVersionPayloadStatus, OcptProjectVersionPayload>> loadPayload({
    required OcptProjectDatabase database,
    required String id,
  }) async {
    final row = await (database.select(
      database.ocptProjectVersionsTable,
    )..where((table) => table.id.equals(id))).getSingleOrNull();

    if (row == null) {
      appLogger().w("The project version $id can't be loaded: no such version in this project");
      return const ResultWithStatus(status: OcptProjectVersionPayloadStatus.malformedPayload);
    }

    return _codec.decode(row.payload);
  }

  /// Writes [payload] into [database], an empty [OcptProjectDatabase.memory] opened for a preview,
  /// so the modes find the version's state exactly where they usually find the working copy's.
  ///
  /// [projectInfo] is the working copy's own header: the preview keeps the project's name, its
  /// creation date and the app version that created it, and takes only what the payload owns — the
  /// page format and the free-form settings. Its `currentVersionId` is deliberately left null,
  /// since the preview database holds no `project_versions` row for it to point at.
  ///
  /// The rows go in verbatim, tombstones and primary keys included, in dependency order and within
  /// a single transaction: a half-hydrated preview must never be shown. The page **margins** the
  /// payload carries are not written here — they are an app-wide preference, and a preview never
  /// touches the user's preferences (they travel on `OcptOpenProjectModel.previewedPageSetup`
  /// instead).
  Future<void> hydratePreview({
    required OcptProjectDatabase database,
    required OcptProjectInfoRow projectInfo,
    required OcptProjectVersionPayload payload,
  }) => database.transaction(() async {
    await database
        .into(database.ocptProjectInfoTable)
        .insert(
          OcptProjectInfoTableCompanion.insert(
            name: projectInfo.name,
            createdAt: projectInfo.createdAt,
            appVersionAtCreation: projectInfo.appVersionAtCreation,
            pageFormat: payload.pageSetup.format,
            settingsJson: Value(payload.settingsJson),
          ),
        );

    await database.batch((batch) {
      batch
        ..insertAll(database.ocptScreenplaysTable, payload.screenplays)
        ..insertAll(database.ocptScenesTable, payload.scenes)
        ..insertAll(database.ocptShotsTable, payload.shots)
        ..insertAll(database.ocptShotCharactersTable, payload.shotCharacters)
        ..insertAll(database.ocptShotCoveragesTable, payload.shotCoverages)
        ..insertAll(database.ocptRowFieldVersionsTable, payload.rowFieldVersions);
    });
  });

  /// Puts the project in [database] back into the state the version [id] captured, and makes it
  /// the version the working copy descends from.
  ///
  /// This is the one destructive operation of the app that isn't a file deletion, so everything it
  /// does happens inside a single transaction, and it starts by capturing the working copy as a
  /// version of its own named [safetyVersionName] — a restore can itself be undone. A failure at any
  /// point rolls the whole thing back, the safety version included.
  ///
  /// The value returned on success is the page setup the version was captured with, which the
  /// caller **must** finish restoring: the format half of it has just been written to the project
  /// header here, but the margins are an app-wide preference rather than project data, so they are
  /// written through `OcptPropertiesManager` by the caller, and only once this transaction has
  /// committed — margins pointing at a restore that failed would leave the whole app paginating
  /// against a state no project holds.
  ///
  /// {@template open_cine_prod_tools.OcptProjectVersionsService.restoreIsAnEdit}
  /// **A restore is an edit, not a reset**, and that distinction is what the whole of
  /// [_applyPayload] is about. The obvious implementation — empty the tables, bulk-insert the
  /// payload's rows — is wrong twice over, and both failures are silent (see
  /// `docs/adr/0010-sync-ready-data-model-prerequisites.md`): it hard-deletes rows a replica that
  /// was offline would then re-insert, having never learnt they were gone, and it leaves the
  /// per-column version stamps behind, so the next merge would replace the restored project with
  /// the very state the user had just deliberately abandoned. The restore therefore expresses
  /// itself in the same vocabulary as any other write: rows are inserted, updated or tombstoned,
  /// and every column it actually changes is stamped anew.
  /// {@endtemplate}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<ResultWithStatus<OcptProjectRestoreStatus, OcptPageSetup>> restoreVersion({
    required OcptProjectDatabase database,
    required String id,
    required String safetyVersionName,
    required String appVersion,
    required String deviceId,
    required FountainPageMargins pageMargins,
  }) async {
    if (database.refusesUserWrite("restoreVersion")) {
      return const ResultWithStatus(status: OcptProjectRestoreStatus.writeFailed);
    }

    if (await loadVersion(database: database, id: id) == null) {
      appLogger().w("The project version $id can't be restored: no such version in this project");
      return const ResultWithStatus(status: OcptProjectRestoreStatus.versionNotFound);
    }

    final payloadResult = await loadPayload(database: database, id: id);
    final payload = payloadResult.value;
    if (payload == null) {
      return ResultWithStatus(
        status: switch (payloadResult.status) {
          OcptProjectVersionPayloadStatus.unsupportedFutureFormat =>
            OcptProjectRestoreStatus.unsupportedFutureFormat,
          _ => OcptProjectRestoreStatus.malformedPayload,
        },
      );
    }

    try {
      await database.transaction(() async {
        // The payload's rows legitimately arrive in an order that violates a foreign key part way
        // through (a scene reinstated after the shot pointing at it, say), so the checks are
        // deferred to the commit rather than run statement by statement.
        await database.customStatement('PRAGMA defer_foreign_keys = ON');

        await createVersion(
          database: database,
          name: safetyVersionName,
          note: "",
          appVersion: appVersion,
          deviceId: deviceId,
          pageMargins: pageMargins,
        );

        await _applyPayload(database: database, payload: payload, deviceId: deviceId);

        await database
            .update(database.ocptProjectInfoTable)
            .write(
              OcptProjectInfoTableCompanion(
                pageFormat: Value(payload.pageSetup.format),
                settingsJson: Value(payload.settingsJson),
                currentVersionId: Value(id),
              ),
            );
      });
    } catch (error) {
      appLogger().e("A problem occurred when tried to restore the project version $id: $error");
      return const ResultWithStatus(status: OcptProjectRestoreStatus.writeFailed);
    }

    return ResultWithStatus(status: OcptProjectRestoreStatus.ok, value: payload.pageSetup);
  }

  /// Restores the version [id] over the project in [database], then captures the result as a new
  /// version named [forkName] with the user's [forkNote]: the branch the user starts from an older
  /// state is itself a named entry of the list rather than an unmarked rewrite.
  ///
  /// The fork's own capture is measured against the page setup the restore has just put back, not
  /// the one the app was showing a moment ago — the state it describes is the restored one.
  ///
  /// Everything [restoreVersion] guarantees holds here: a fork that fails leaves the project
  /// untouched. A fork whose *capture* fails leaves the restore in place, since that transaction has
  /// committed by then — the project is then simply restored without a card marking the branch, and
  /// the safety version is still there.
  Future<ResultWithStatus<OcptProjectRestoreStatus, OcptPageSetup>> forkFromVersion({
    required OcptProjectDatabase database,
    required String id,
    required String safetyVersionName,
    required String forkName,
    required String forkNote,
    required String appVersion,
    required String deviceId,
    required FountainPageMargins pageMargins,
  }) async {
    final restored = await restoreVersion(
      database: database,
      id: id,
      safetyVersionName: safetyVersionName,
      appVersion: appVersion,
      deviceId: deviceId,
      pageMargins: pageMargins,
    );

    final restoredPageSetup = restored.value;
    if (restoredPageSetup == null) {
      return restored;
    }

    await createVersion(
      database: database,
      name: forkName,
      note: forkNote,
      appVersion: appVersion,
      deviceId: deviceId,
      pageMargins: restoredPageSetup.margins,
    );

    return restored;
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
  /// row of [_payloadTableNames], so every stamp of those tables describes a row the payload holds
  /// — and it saves matching each stamp's [OcptRowFieldVersionRow.rowId] against a composite key
  /// rebuilt through [ocptCompositeRowStampKey].
  Future<List<OcptRowFieldVersionRow>> _captureRowFieldVersions({
    required OcptProjectDatabase database,
  }) => (database.select(
    database.ocptRowFieldVersionsTable,
  )..where((table) => table.targetTableName.isIn(_payloadTableNames))).get();

  /// Writes [payload] over the project in [database], from inside [restoreVersion]'s transaction.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectVersionsService.restoreIsAnEdit}
  ///
  /// The tables are walked in dependency order — a screenplay before its scenes, a scene before the
  /// shots pointing at it — and `scenes` is the one that carries no stamp at all: ADR 0010 keeps it
  /// out of the merge entirely, since it is derived from the screenplay text and recomputed
  /// locally. Its rows still go back **verbatim, ids included**, which is what stops the restored
  /// `shots.sceneId` and `shot_coverages.sceneId` references from dangling; and a scene the payload
  /// doesn't carry is tombstoned rather than deleted, for the reason `OcptScenesTable.isDeleted`
  /// gives — the tombstoned shots and coverages still left over from the working copy reference it,
  /// and `PRAGMA foreign_keys` is on.
  Future<void> _applyPayload({
    required OcptProjectDatabase database,
    required OcptProjectVersionPayload payload,
    required String deviceId,
  }) async {
    final stamps = await _OcptRestoreStamps.of(
      database: database,
      payload: payload,
      deviceId: deviceId,
    );

    await _snapshotScreenplaysAboutToChange(database: database, payload: payload);

    await _restoreTable(
      database: database,
      table: database.ocptScreenplaysTable,
      payloadRows: payload.screenplays,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptScenesTable,
      payloadRows: payload.scenes,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: null,
    );

    await _restoreTable(
      database: database,
      table: database.ocptShotsTable,
      payloadRows: payload.shots,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptShotCharactersTable,
      payloadRows: payload.shotCharacters,
      rowIdOf: (row) => ocptCompositeRowStampKey([row.shotId, row.characterName]),
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptShotCoveragesTable,
      payloadRows: payload.shotCoverages,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await stamps.flush(database);
  }

  /// Snapshots the text of every screenplay [payload] is about to overwrite in [database].
  ///
  /// This is what a restore owes the merge rather than the user (see [OcptSnapshotReason.restore]),
  /// and it has to happen before a single character of `screenplays.fountainText` changes. Only the
  /// screenplays whose text actually differs are snapshotted: a restore that changes nothing must
  /// not push thirty real snapshots out of the rolling window for nothing.
  Future<void> _snapshotScreenplaysAboutToChange({
    required OcptProjectDatabase database,
    required OcptProjectVersionPayload payload,
  }) async {
    final currentRows = {
      for (final row in await database.select(database.ocptScreenplaysTable).get()) row.id: row,
    };

    for (final screenplay in payload.screenplays) {
      final current = currentRows[screenplay.id];

      // A screenplay the working copy doesn't hold live has no text to protect: either it is about
      // to be inserted, or it is a tombstone the restore only reinstates as one.
      if (current == null || current.isDeleted || current.fountainText == screenplay.fountainText) {
        continue;
      }

      await _screenplayService.snapshotBeforeRestore(
        database: database,
        screenplayId: screenplay.id,
      );
    }
  }

  /// Restores one table of a payload: [payloadRows] are written over whatever [table] currently
  /// holds in [database], and whatever it holds beyond them is tombstoned.
  ///
  /// The three cases, each stamped through [stamps] unless the table is one no merge ever sees (see
  /// [_applyPayload]):
  ///
  /// - a row the payload holds and the working copy doesn't is **inserted**, and every one of its
  ///   columns stamped;
  /// - a row both hold is **updated**, and only the columns whose value actually changes are
  ///   stamped. A column that already matches the payload is left alone: that is what keeps a
  ///   restore from stomping an unrelated concurrent edit that happened to agree with it;
  /// - a row the working copy holds and the payload doesn't is **tombstoned**, never deleted, and
  ///   its tombstone column stamped. One already tombstoned is left untouched, stamp included.
  ///
  /// [rowIdOf] names a row both in the map matching the two sides up and in
  /// `row_field_versions.rowId`, so a composite primary key goes through
  /// [ocptCompositeRowStampKey]. [tombstonedOf] returns the row as its own tombstone — returning it
  /// unchanged is how a table with no tombstone column would opt out.
  Future<void> _restoreTable<D extends DataClass>({
    required OcptProjectDatabase database,
    required TableInfo<Table, D> table,
    required List<D> payloadRows,
    required String Function(D row) rowIdOf,
    required D Function(D row) tombstonedOf,
    required _OcptRestoreStamps? stamps,
  }) async {
    final leftovers = {
      for (final row in await database.select(table).get()) rowIdOf(row): row,
    };

    for (final row in payloadRows) {
      final rowId = rowIdOf(row);
      final current = leftovers.remove(rowId);

      if (current == null) {
        await database.into(table).insert(_insertable(row));
        stamps?.stamp(table: table, rowId: rowId, columnNames: row.toJson().keys);
        continue;
      }

      final changedColumnNames = _changedColumnNames(from: current, to: row);
      if (changedColumnNames.isEmpty) {
        continue;
      }

      await database.into(table).insertOnConflictUpdate(_insertable(row));
      stamps?.stamp(table: table, rowId: rowId, columnNames: changedColumnNames);
    }

    for (final leftover in leftovers.entries) {
      final tombstone = tombstonedOf(leftover.value);
      if (tombstone == leftover.value) {
        continue;
      }

      await database.into(table).insertOnConflictUpdate(_insertable(tombstone));
      stamps?.stamp(
        table: table,
        rowId: leftover.key,
        columnNames: const [_isDeletedColumnName],
      );
    }
  }

  /// [row] seen as what drift's generator always makes a data class — an `Insertable` of its own
  /// type — which [DataClass] itself doesn't declare.
  ///
  /// Generic code over a table's rows needs both halves of that pair: [DataClass] to read a row's
  /// columns back ([_changedColumnNames]), and `Insertable` to write it. Every generated row class
  /// implements the two; only their common supertype doesn't say so.
  static Insertable<D> _insertable<D extends DataClass>(D row) => row as Insertable<D>;

  /// The names of the columns [to] holds a different value in than [from], as the Dart side of the
  /// schema spells them — which is exactly how `row_field_versions.columnName` spells them too.
  ///
  /// Read off the rows' own JSON representation rather than compared field by field per table: a
  /// column added to a synchronised table is then stamped by a restore without anybody having to
  /// remember to add it here. (The payload's column list is the hand-written mirror of the schema,
  /// and one such list is enough — see [OcptProjectVersionCodec].)
  static List<String> _changedColumnNames({required DataClass from, required DataClass to}) {
    final before = from.toJson();

    return [
      for (final column in to.toJson().entries)
        if (before[column.key] != column.value) column.key,
    ];
  }
}

/// The per-column version stamps one restore writes, accumulated as it walks the tables and written
/// in one batch at the end of its transaction.
///
/// A stamp says, per column, *whose* value wins a merge and *when* it was written, so a restore has
/// to leave every column it changed carrying a version strictly above the one that column already
/// held, under this replica's own device id: anything less and the next merge would treat the
/// restored value as older than the edit the restore was meant to supersede — undoing it, minutes
/// later, from a machine nobody touched.
///
/// The payload's own stamps are a **floor**, not the values written: they describe the state the
/// restore comes back to, so a column whose payload stamp is somehow above the working copy's still
/// ends up strictly above both. What they never do is get written as they stand — that would be the
/// exact failure above, spelled with more steps.
class _OcptRestoreStamps {
  /// The device id every stamp this restore writes carries: this replica's own.
  final String deviceId;

  /// The highest version known for each `(table, row, column)`, whether it comes from the working
  /// copy, from the payload's floor, or from a stamp this restore has already handed out.
  final Map<(String, String, String), int> _versions;

  /// The stamps written so far, waiting for [flush].
  final _pending = <OcptRowFieldVersionsTableCompanion>[];

  /// Class constructor
  _OcptRestoreStamps._({required this.deviceId, required Map<(String, String, String), int> versions})
    : _versions = versions;

  /// Reads the stamps the project in [database] currently holds, raised to the floor [payload]
  /// carries for the same columns.
  static Future<_OcptRestoreStamps> of({
    required OcptProjectDatabase database,
    required OcptProjectVersionPayload payload,
    required String deviceId,
  }) async {
    final versions = <(String, String, String), int>{};

    for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get()) {
      versions[(stamp.targetTableName, stamp.rowId, stamp.columnName)] = stamp.version;
    }

    for (final stamp in payload.rowFieldVersions) {
      final key = (stamp.targetTableName, stamp.rowId, stamp.columnName);
      final known = versions[key];
      if (known == null || known < stamp.version) {
        versions[key] = stamp.version;
      }
    }

    return _OcptRestoreStamps._(deviceId: deviceId, versions: versions);
  }

  /// Stamps [columnNames] of the row [rowId] of [table] as written, now, by this replica.
  void stamp({
    required TableInfo<Table, DataClass> table,
    required String rowId,
    required Iterable<String> columnNames,
  }) {
    for (final columnName in columnNames) {
      final key = (table.actualTableName, rowId, columnName);
      final version = (_versions[key] ?? 0) + 1;
      _versions[key] = version;

      _pending.add(
        OcptRowFieldVersionsTableCompanion.insert(
          targetTableName: table.actualTableName,
          rowId: rowId,
          columnName: columnName,
          version: version,
          deviceId: deviceId,
        ),
      );
    }
  }

  /// Writes every stamp handed out since this object was built into [database].
  Future<void> flush(OcptProjectDatabase database) async {
    if (_pending.isEmpty) {
      return;
    }

    await database.batch(
      (batch) => batch.insertAllOnConflictUpdate(database.ocptRowFieldVersionsTable, _pending),
    );
  }
}
