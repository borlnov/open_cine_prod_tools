// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:meta/meta.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_version_codec.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_payload_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_versions_restore_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_restore_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_payload_status.dart';
import 'package:uuid/uuid.dart';

/// Create, lists, delete and restore a project's named versions: the production history the user
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
class OcptProjectVersionsService extends AbsOcptService {
  /// The codec turning the captured state into the text stored in `project_versions.payload`.
  final OcptProjectVersionCodec _codec;

  /// The service taking the screenplay snapshot a restore owes the merge before it overwrites a
  /// screenplay's text (see [restoreVersion]).
  final OcptScreenplayService _screenplayService;

  /// Class constructor
  const OcptProjectVersionsService({
    required super.logger,
    required OcptProjectVersionCodec codec,
    required OcptScreenplayService screenplayService,
  }) : _codec = codec,
       _screenplayService = screenplayService;

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  ///
  /// Initialises the services this one owns, in the order they are listed in its constructor.
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
    await _screenplayService.initLifeCycle();
  }

  /// List every version of the project in [database], newest first.
  ///
  /// Deliberately does **not** deserialize any payload: a card renders from the counters stored
  /// with the version, and a payload is hundreds of kilobytes.
  @useResult
  Future<OcptDatabaseResult<List<OcptProjectVersion>>> listVersions({
    required OcptProjectDatabase database,
  }) => guardResult("listVersions", () async {
    final rows = await (database.select(
      database.ocptProjectVersionsTable,
    )..orderBy([(table) => OrderingTerm.desc(table.createdAt)])).get();

    final info = await database.select(database.ocptProjectInfoTable).getSingleOrNull();

    return [
      for (final row in rows)
        OcptProjectVersion.fromRow(row: row, isBase: row.id == info?.currentVersionId),
    ];
  });

  /// Capture the current state of the project in [database] as a new version named [name], with
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
  @useResult
  Future<OcptDatabaseResult<OcptProjectVersion>> createVersion({
    required OcptProjectDatabase database,
    required String name,
    required String note,
    required String appVersion,
    required String deviceId,
    required FountainPageMargins pageMargins,
  }) => guardResult(
    "createVersion",
    () => database.transaction(
      () async => _insertVersion(
        database: database,
        payload: await OcptProjectVersionsPayloadOps.capturePayload(
          database: database,
          pageMargins: pageMargins,
        ),
        name: name,
        note: note,
        appVersion: appVersion,
        deviceId: deviceId,
      ),
    ),
  );

  /// Rename the version [id] of the project in [database] to [name], replacing its [note].
  ///
  /// A plain update of the two columns, unlike every other version operation: it reads nothing
  /// about the project's *data*, only writes to the version's own row, so — unlike restoring or
  /// deleting — it stays available while a preview is up. Renaming the card the user happens to be
  /// looking at, or any other, changes nothing about what a preview reads.
  @useResult
  Future<OcptDatabaseOutcome> renameVersion({
    required OcptProjectDatabase database,
    required String id,
    required String name,
    required String note,
  }) => guardOutcome("renameVersion", () async {
    await (database.update(database.ocptProjectVersionsTable)
          ..where((table) => table.id.equals(id)))
        .write(OcptProjectVersionsTableCompanion(name: Value(name), note: Value(note)));
  });

  /// Load the single version [id] of the project in [database], or null if it has no such
  /// version.
  ///
  /// Reads the card's columns alone, deliberately leaving `payload` in the file: this is what the
  /// preview asks for the version's *identity* with, and it must stay as cheap as [listVersions]
  /// even though the payload of that same row is about to be read by [loadPayload].
  @useResult
  Future<OcptDatabaseResult<OcptProjectVersion>> loadVersion({
    required OcptProjectDatabase database,
    required String id,
  }) => guardResult("loadVersion", () => _readVersion(database: database, id: id));

  /// Read and decode the payload of the version [id] of the project in [database].
  ///
  /// This is the one read that does deserialize a payload, and it exists for the two operations
  /// that need the state itself rather than the card: entering a version's preview, and restoring
  /// it. Every failure comes back as a status — a version whose payload can't be read is a version
  /// the user must be told about, never an exception thrown at whichever screen asked. A payload
  /// that can't be decoded is the status of the answer's value, and a database that can't be read
  /// is the status of the answer itself.
  ///
  /// **This is also where an erased person is scrubbed back out**
  /// ([OcptProjectVersionsPayloadOps.scrubErasedPeople]), and being the single door both operations
  /// come through is the whole reason it belongs here rather than in the restore alone. The answer
  /// to "a version captured before an erasure still holds that person's row, forever" is to scrub
  /// **on decode**, not on disk: the stored text stays byte-identical, and no reader of it ever
  /// sees the person again. A preview is a reader — it hydrates the payload into a database the
  /// modes draw every sheet from — so a scrub that only guarded the restore would put the phone
  /// number, the address and the allergies of somebody who asked to be removed straight back on
  /// screen, one click away, for as long as the version exists.
  @useResult
  Future<
    OcptDatabaseResult<ResultWithStatus<OcptProjectVersionPayloadStatus, OcptProjectVersionPayload>>
  >
  loadPayload({required OcptProjectDatabase database, required String id}) =>
      guardResult("loadPayload", () => _readPayload(database: database, id: id));

  /// Write [payload] into [database], an empty [OcptProjectDatabase.memory] opened for a preview,
  /// so the modes find the version's state exactly where they usually find the working copy's.
  ///
  /// [projectInfo] is the working copy's own header: the preview keeps the project's name, its
  /// creation date and the app version that created it, and takes only what the payload owns — the
  /// page format, the currency and the free-form settings. Its `currentVersionId` is deliberately
  /// left null, since the preview database holds no `project_versions` row for it to point at.
  ///
  /// The rows go in verbatim, tombstones and primary keys included, in dependency order and within
  /// a single transaction: a half-hydrated preview must never be shown. The page **margins** the
  /// payload carries are not written here — they are an app-wide preference, and a preview never
  /// touches the user's preferences (they travel on `OcptOpenProjectModel.previewedPageSetup`
  /// instead).
  @useResult
  Future<OcptDatabaseOutcome> hydratePreview({
    required OcptProjectDatabase database,
    required OcptProjectInfoRow projectInfo,
    required OcptProjectVersionPayload payload,
  }) => guardOutcome(
    "hydratePreview",
    () => OcptProjectVersionsRestoreOps.hydratePreview(
      database: database,
      projectInfo: projectInfo,
      payload: payload,
    ),
  );

  /// Measure the working copy of the project in [database] exactly as a stored version would be,
  /// at [pageMargins], without writing anything: the counters a working-copy card shows, and
  /// whether that content actually differs from the version it descends from.
  ///
  /// One capture answers both, which matters because it isn't a cheap one: it reads the same
  /// tables [createVersion] does. [restoreVersion] needs the very same two facts to decide whether
  /// it owes a safety version, and reuses this method's private half so it never pays for that
  /// read twice.
  @useResult
  Future<OcptDatabaseResult<OcptProjectWorkingCopyState>> captureWorkingCopyState({
    required OcptProjectDatabase database,
    required FountainPageMargins pageMargins,
  }) => guardResult(
    "captureWorkingCopyState",
    () async =>
        (await _captureWorkingCopySnapshot(database: database, pageMargins: pageMargins)).state,
  );

  /// Put the project in [database] back into the state the version [id] captured, and makes it the
  /// version the working copy descends from.
  ///
  /// This is the one destructive operation of the app that isn't a file deletion, so everything it
  /// does happens inside a single transaction. It starts by weighing whether the working copy it is
  /// about to overwrite needs protecting at all: [_captureWorkingCopySnapshot] reads it and
  /// compares its digest against the version it currently descends from, and only when the two
  /// differ — or there is no base to compare against, or that base's digest is unknown — does the
  /// transaction also capture it as a version of its own named [safetyVersionName]. Restoring a
  /// working copy that already matches its base would otherwise mint a byte-for-byte duplicate of a
  /// card already in the list. Either way, **a restore can itself be undone**: when no safety
  /// version is taken, the state it replaces is exactly the base version's, which is still there. A
  /// failure at any point rolls the whole thing back, the safety version included when one was
  /// taken.
  ///
  /// The value returned on success is the page setup the version was captured with, which the
  /// caller **must** finish restoring: the format half of it has just been written to the project
  /// header here, but the margins are an app-wide preference rather than project data, so they are
  /// written through `OcptPropertiesManager` by the caller, and only once this transaction has
  /// committed — margins pointing at a restore that failed would leave the whole app paginating
  /// against a state no project holds.
  ///
  /// The currency is written here too, **except when the payload doesn't carry one** — a version
  /// captured before currencies existed — in which case the project's own currency is left exactly
  /// as it stood: see `OcptProjectVersionPayload.currencyCode`. The minimum rest, the screenplay
  /// language, the default VAT rate and the two catering prices are all written
  /// **unconditionally**, null included: unlike the currency, a null here is never "this payload
  /// predates the column" — every one of these five columns is nullable by design and null is one
  /// of their truthful values on a live capture too — so there is no live value to leave alone.
  ///
  /// {@template open_cine_prod_tools.OcptProjectVersionsService.restoreIsAnEdit}
  /// **A restore is an edit, not a reset**, and that distinction is what the whole of
  /// [OcptProjectVersionsRestoreOps.applyPayload] is about. The obvious implementation — empty the
  /// tables, bulk-insert the payload's rows — is wrong twice over, and both failures are silent
  /// (see `docs/adr/0010-sync-ready-data-model-prerequisites.md`): it hard-deletes rows a replica
  /// that was offline would then re-insert, having never learnt they were gone, and it leaves the
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

    if (await _readVersion(database: database, id: id) == null) {
      logger.w("The project version $id can't be restored: no such version in this project");
      return const ResultWithStatus(status: OcptProjectRestoreStatus.versionNotFound);
    }

    final payloadResult = await _readPayload(database: database, id: id);
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

    final workingCopy = await _captureWorkingCopySnapshot(
      database: database,
      pageMargins: pageMargins,
    );

    var isRestored = false;
    try {
      await database.transaction(() async {
        // The payload's rows legitimately arrive in an order that violates a foreign key part way
        // through (a scene reinstated after the shot pointing at it, say), so the checks are
        // deferred to the commit rather than run statement by statement.
        await database.customStatement('PRAGMA defer_foreign_keys = ON');

        if (workingCopy.state.isModifiedSinceBase) {
          await _insertVersion(
            database: database,
            payload: workingCopy.payload,
            name: safetyVersionName,
            note: "",
            appVersion: appVersion,
            deviceId: deviceId,
          );
        }

        await OcptProjectVersionsRestoreOps.applyPayload(
          database: database,
          payload: payload,
          screenplayService: _screenplayService,
          deviceId: deviceId,
        );

        await database
            .update(database.ocptProjectInfoTable)
            .write(
              OcptProjectInfoTableCompanion(
                pageFormat: Value(payload.pageSetup.format),
                settingsJson: Value(payload.settingsJson),
                // Absent rather than written when the payload predates currencies: leaving the
                // column out of a partial `.write()` keeps whatever the project already holds,
                // which is the fail-safe direction — see `OcptProjectVersionPayload.currencyCode`.
                currencyCode: switch (payload.currencyCode) {
                  final code? => Value(code),
                  null => const Value.absent(),
                },
                minimumRestMinutes: Value(payload.minimumRestMinutes),
                screenplayLanguage: Value(payload.screenplayLanguage),
                defaultVatRateBasisPoints: Value(payload.defaultVatRateBasisPoints),
                mealPriceCents: Value(payload.mealPriceCents),
                snackPriceCents: Value(payload.snackPriceCents),
                currentVersionId: Value(id),
              ),
            );
      });
      isRestored = true;
    } catch (error, stackTrace) {
      logger.e(
        "A problem occurred when tried to restore the project version $id: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }

    if (!isRestored) {
      return const ResultWithStatus(status: OcptProjectRestoreStatus.writeFailed);
    }

    logger.i("The project version $id was restored");

    return ResultWithStatus(status: OcptProjectRestoreStatus.ok, value: payload.pageSetup);
  }

  /// Delete the version [id] of the project in [database], clearing the project header's pointer
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
  @useResult
  Future<OcptDatabaseOutcome> deleteVersion({
    required OcptProjectDatabase database,
    required String id,
  }) => guardOutcome("deleteVersion", () async {
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

    logger.i("The project version $id was deleted");
  });

  /// Read the single version [id] of the project in [database], or null if it has no such version.
  ///
  /// What [loadVersion] answers, raising when the database fails: [restoreVersion] reads it too and
  /// lets the failure leave it, exactly as it always has.
  Future<OcptProjectVersion?> _readVersion({
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
      isBase: info?.currentVersionId == id,
    );
  }

  /// Read and decode the payload of the version [id] of the project in [database].
  ///
  /// What [loadPayload] answers, raising when the database fails: [restoreVersion] reads it too and
  /// lets the failure leave it, exactly as it always has.
  Future<ResultWithStatus<OcptProjectVersionPayloadStatus, OcptProjectVersionPayload>>
  _readPayload({required OcptProjectDatabase database, required String id}) async {
    final row = await (database.select(
      database.ocptProjectVersionsTable,
    )..where((table) => table.id.equals(id))).getSingleOrNull();

    if (row == null) {
      logger.w("The project version $id can't be loaded: no such version in this project");
      return const ResultWithStatus(status: OcptProjectVersionPayloadStatus.malformedPayload);
    }

    final decoded = _codec.decode(row.payload);
    final payload = decoded.value;
    if (payload == null) {
      return decoded;
    }

    return ResultWithStatus(
      status: decoded.status,
      value: await OcptProjectVersionsPayloadOps.scrubErasedPeople(
        database: database,
        payload: payload,
      ),
    );
  }

  /// Write [payload] as a new version row named [name], with the user's [note], and makes it the
  /// version the working copy descends from.
  ///
  /// The half of [createVersion] that doesn't capture: shared with [restoreVersion]'s safety
  /// version, which has to capture the working copy anyway to decide whether it even needs one (see
  /// [captureWorkingCopyState]), so writing that same payload here spares it from capturing the
  /// whole project a second time. The caller owns the transaction.
  Future<OcptProjectVersion> _insertVersion({
    required OcptProjectDatabase database,
    required OcptProjectVersionPayload payload,
    required String name,
    required String note,
    required String appVersion,
    required String deviceId,
  }) async {
    final id = const Uuid().v4();
    final createdAt = DateTime.now();
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

    logger.i("A project version was captured: $id");

    return OcptProjectVersion(
      id: id,
      name: name,
      note: note,
      createdAt: createdAt,
      summary: summary,
      isBase: true,
    );
  }

  /// Read the `contentDigest` column alone of the version [id] of the project in [database], or
  /// null when that version doesn't exist, or exists but carries no digest, which [restoreVersion]
  /// and [captureWorkingCopyState] both treat as "unknown" rather than assume it matches anything.
  Future<String?> _loadContentDigest({
    required OcptProjectDatabase database,
    required String id,
  }) async {
    final table = database.ocptProjectVersionsTable;

    final row =
        await (database.selectOnly(table)
              ..addColumns([table.contentDigest])
              ..where(table.id.equals(id)))
            .getSingleOrNull();

    return row?.read(table.contentDigest);
  }

  /// Run the shared half of [captureWorkingCopyState]: everything it reports, plus the payload it
  /// was
  /// measured from, which only [restoreVersion] needs — to write it out as a safety version without
  /// capturing the project a second time.
  Future<_OcptWorkingCopySnapshot> _captureWorkingCopySnapshot({
    required OcptProjectDatabase database,
    required FountainPageMargins pageMargins,
  }) async {
    final payload = await OcptProjectVersionsPayloadOps.capturePayload(
      database: database,
      pageMargins: pageMargins,
    );
    final digest = _codec.contentDigest(payload);

    final info = await database.select(database.ocptProjectInfoTable).getSingleOrNull();
    final baseVersionId = info?.currentVersionId;
    final baseDigest = baseVersionId == null
        ? null
        : await _loadContentDigest(database: database, id: baseVersionId);

    return _OcptWorkingCopySnapshot(
      payload: payload,
      state: OcptProjectWorkingCopyState(
        summary: OcptProjectVersionSummary.of(payload),
        contentDigest: digest,
        baseVersionId: baseVersionId,
        isModifiedSinceBase: baseDigest == null || baseDigest != digest,
      ),
    );
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// Disposes the services this one owns, in the reverse order they were initialised.
  @override
  Future<void> disposeLifeCycle() async {
    await _screenplayService.disposeLifeCycle();

    return super.disposeLifeCycle();
  }
}

/// The payload [OcptProjectVersionsService._captureWorkingCopySnapshot] captures, paired with the
/// state derived from it.
///
/// A private pairing rather than putting the payload on [OcptProjectWorkingCopyState] itself: the
/// public state is meant for a working-copy card and for a dedupe check alike, neither of which
/// has any business holding hundreds of kilobytes of row data — only
/// [OcptProjectVersionsService.restoreVersion]'s safety version does, and only for as long as its
/// own capture stays in scope.
class _OcptWorkingCopySnapshot {
  /// The payload captured from the working copy.
  final OcptProjectVersionPayload payload;

  /// What [payload] says about the working copy: its counters, its digest, and whether it differs
  /// from the version it descends from.
  final OcptProjectWorkingCopyState state;

  /// Class constructor
  const _OcptWorkingCopySnapshot({required this.payload, required this.state});
}
