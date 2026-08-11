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
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
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
    'people',
    'person_positions',
    'person_skills',
    'person_unavailabilities',
    'roles',
    'role_episodes',
    'locations',
    'location_availabilities',
    'sets',
    'scene_sets',
    'elements',
    'scene_elements',
    'role_elements',
    'assets',
    'breakdown_tags',
    'scene_breakdowns',
    'shooting_days',
    'shooting_slots',
    'shooting_slot_crew',
    'shooting_slot_cast',
    'shooting_day_blocks',
    'shooting_slot_guests',
    'shooting_day_events',
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
        OcptProjectVersion.fromRow(row: row, isBase: row.id == info?.currentVersionId),
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
  }) => database.transaction(
    () async => _insertVersion(
      database: database,
      payload: await _capturePayload(database: database, pageMargins: pageMargins),
      name: name,
      note: note,
      appVersion: appVersion,
      deviceId: deviceId,
    ),
  );

  /// Writes [payload] as a new version row named [name], with the user's [note], and makes it the
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

    return OcptProjectVersion(
      id: id,
      name: name,
      note: note,
      createdAt: createdAt,
      summary: summary,
      isBase: true,
    );
  }

  /// Renames the version [id] of the project in [database] to [name], replacing its [note].
  ///
  /// A plain update of the two columns, unlike every other version operation: it reads nothing
  /// about the project's *data*, only writes to the version's own row, so — unlike restoring or
  /// deleting — it stays available while a preview is up. Renaming the card the user happens to be
  /// looking at, or any other, changes nothing about what a preview reads.
  Future<void> renameVersion({
    required OcptProjectDatabase database,
    required String id,
    required String name,
    required String note,
  }) async {
    await (database.update(
      database.ocptProjectVersionsTable,
    )..where((table) => table.id.equals(id))).write(
      OcptProjectVersionsTableCompanion(name: Value(name), note: Value(note)),
    );
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
      isBase: info?.currentVersionId == id,
    );
  }

  /// Reads the `contentDigest` column alone of the version [id] of the project in [database], or
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

  /// Reads and decodes the payload of the version [id] of the project in [database].
  ///
  /// This is the one read that does deserialize a payload, and it exists for the two operations
  /// that need the state itself rather than the card: entering a version's preview, and restoring
  /// it. Every failure comes back as a status — a version whose payload can't be read is a version
  /// the user must be told about, never an exception thrown at whichever screen asked.
  ///
  /// **This is also where an erased person is scrubbed back out** ([_scrubErasedPeople]), and being
  /// the single door both operations come through is the whole reason it belongs here rather than
  /// in the restore alone. §4.9's answer to "a version captured before an erasure still holds that
  /// person's row, forever" is to scrub **on decode**, not on disk: the stored text stays
  /// byte-identical, and no reader of it ever sees the person again. A preview is a reader — it
  /// hydrates the payload into a database the modes draw every sheet from — so a scrub that only
  /// guarded the restore would put the phone number, the address and the allergies of somebody who
  /// asked to be removed straight back on screen, one click away, for as long as the version
  /// exists.
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

    final decoded = _codec.decode(row.payload);
    final payload = decoded.value;
    if (payload == null) {
      return decoded;
    }

    return ResultWithStatus(
      status: decoded.status,
      value: await _scrubErasedPeople(database: database, payload: payload),
    );
  }

  /// Writes [payload] into [database], an empty [OcptProjectDatabase.memory] opened for a preview,
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
            // A payload predating currencies (format 2 or earlier) carries no currency of its own
            // to preview: the schema's own default reads as truthfully as anything else can for a
            // moment currencies didn't exist yet.
            currencyCode: Value(payload.currencyCode ?? ocptDefaultCurrencyCode),
            // Unlike the currency, a null here is never "this payload predates the column" — it is
            // exactly as truthful on a live capture as on an old one — so it previews verbatim,
            // null included.
            minimumRestMinutes: Value(payload.minimumRestMinutes),
          ),
        );

    await database.batch((batch) {
      batch
        ..insertAll(database.ocptScreenplaysTable, payload.screenplays)
        ..insertAll(database.ocptScenesTable, payload.scenes)
        ..insertAll(database.ocptShotsTable, payload.shots)
        ..insertAll(database.ocptShotCharactersTable, payload.shotCharacters)
        ..insertAll(database.ocptShotCoveragesTable, payload.shotCoverages)
        ..insertAll(database.ocptPeopleTable, payload.people)
        ..insertAll(database.ocptPersonPositionsTable, payload.personPositions)
        ..insertAll(database.ocptPersonSkillsTable, payload.personSkills)
        ..insertAll(database.ocptPersonUnavailabilitiesTable, payload.personUnavailabilities)
        ..insertAll(database.ocptRolesTable, payload.roles)
        ..insertAll(database.ocptRoleEpisodesTable, payload.roleEpisodes)
        ..insertAll(database.ocptLocationsTable, payload.locations)
        ..insertAll(database.ocptLocationAvailabilitiesTable, payload.locationAvailabilities)
        ..insertAll(database.ocptSetsTable, payload.sets)
        ..insertAll(database.ocptSceneSetsTable, payload.sceneSets)
        ..insertAll(database.ocptElementsTable, payload.elements)
        ..insertAll(database.ocptSceneElementsTable, payload.sceneElements)
        ..insertAll(database.ocptRoleElementsTable, payload.roleElements)
        ..insertAll(database.ocptAssetsTable, payload.assets)
        // Both breakdown tables follow every table they may reference (scenes, roles, sets and
        // elements are all written above), so this is not a forward reference — unlike the
        // asset-referencing trio above it, `breakdown_tags` closes no foreign-key cycle of its own.
        ..insertAll(database.ocptBreakdownTagsTable, payload.breakdownTags)
        ..insertAll(database.ocptSceneBreakdownsTable, payload.sceneBreakdowns)
        // The schedule tables follow every table they may reference too — screenplays, shots,
        // people, roles, locations and sets are all written above — so none of these is a forward
        // reference either: shootingDays before shootingSlots (which may name a location or a set),
        // before shootingSlotCrew/shootingSlotCast/shootingSlotGuests (which each point at a slot,
        // and a guest at a person too) and
        // shootingDayBlocks (which points at a slot, and a block may also point at a shot), and
        // shootingDayEvents last, referencing only a day.
        ..insertAll(database.ocptShootingDaysTable, payload.shootingDays)
        ..insertAll(database.ocptShootingSlotsTable, payload.shootingSlots)
        ..insertAll(database.ocptShootingSlotCrewTable, payload.shootingSlotCrew)
        ..insertAll(database.ocptShootingSlotCastTable, payload.shootingSlotCast)
        ..insertAll(database.ocptShootingSlotGuestsTable, payload.shootingSlotGuests)
        ..insertAll(database.ocptShootingDayBlocksTable, payload.shootingDayBlocks)
        ..insertAll(database.ocptShootingDayEventsTable, payload.shootingDayEvents)
        ..insertAll(database.ocptRowFieldVersionsTable, payload.rowFieldVersions);
    });
  });

  /// Measures the working copy of the project in [database] exactly as a stored version would be,
  /// at [pageMargins], without writing anything: the counters a working-copy card shows, and
  /// whether that content actually differs from the version it descends from.
  ///
  /// One capture answers both, which matters because it isn't a cheap one: it reads the same
  /// tables [createVersion] does. [restoreVersion] needs the very same two facts to decide whether
  /// it owes a safety version, and reuses this method's private half so it never pays for that
  /// read twice.
  Future<OcptProjectWorkingCopyState> captureWorkingCopyState({
    required OcptProjectDatabase database,
    required FountainPageMargins pageMargins,
  }) async => (await _captureWorkingCopySnapshot(database: database, pageMargins: pageMargins)).state;

  /// The shared half of [captureWorkingCopyState]: everything it reports, plus the payload it was
  /// measured from, which only [restoreVersion] needs — to write it out as a safety version without
  /// capturing the project a second time.
  Future<_OcptWorkingCopySnapshot> _captureWorkingCopySnapshot({
    required OcptProjectDatabase database,
    required FountainPageMargins pageMargins,
  }) async {
    final payload = await _capturePayload(database: database, pageMargins: pageMargins);
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

  /// Puts the project in [database] back into the state the version [id] captured, and makes it
  /// the version the working copy descends from.
  ///
  /// This is the one destructive operation of the app that isn't a file deletion, so everything it
  /// does happens inside a single transaction. It starts by weighing whether the working copy it is
  /// about to overwrite needs protecting at all: [_captureWorkingCopySnapshot] reads it and compares
  /// its digest against the version it currently descends from, and only when the two differ — or
  /// there is no base to compare against, or that base's digest is unknown — does the transaction
  /// also capture it as a version of its own named [safetyVersionName]. Restoring a working copy
  /// that already matches its base would otherwise mint a byte-for-byte duplicate of a card already
  /// in the list. Either way, **a restore can itself be undone**: when no safety version is taken,
  /// the state it replaces is exactly the base version's, which is still there. A failure at any
  /// point rolls the whole thing back, the safety version included when one was taken.
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
  /// as it stood: see `OcptProjectVersionPayload.currencyCode`. The minimum rest is written
  /// **unconditionally**, null included: unlike the currency, a null here is never "this payload
  /// predates the column" — the column is nullable by design and null is one of its truthful
  /// values on a live capture too — so there is no live value to leave alone.
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

    final workingCopy = await _captureWorkingCopySnapshot(
      database: database,
      pageMargins: pageMargins,
    );

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

        await _applyPayload(database: database, payload: payload, deviceId: deviceId);

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
      people: await database.select(database.ocptPeopleTable).get(),
      personPositions: await database.select(database.ocptPersonPositionsTable).get(),
      personSkills: await database.select(database.ocptPersonSkillsTable).get(),
      personUnavailabilities: await database.select(database.ocptPersonUnavailabilitiesTable).get(),
      roles: await database.select(database.ocptRolesTable).get(),
      roleEpisodes: await database.select(database.ocptRoleEpisodesTable).get(),
      locations: await database.select(database.ocptLocationsTable).get(),
      locationAvailabilities: await database
          .select(database.ocptLocationAvailabilitiesTable)
          .get(),
      sets: await database.select(database.ocptSetsTable).get(),
      sceneSets: await database.select(database.ocptSceneSetsTable).get(),
      elements: await database.select(database.ocptElementsTable).get(),
      sceneElements: await database.select(database.ocptSceneElementsTable).get(),
      roleElements: await database.select(database.ocptRoleElementsTable).get(),
      assets: await database.select(database.ocptAssetsTable).get(),
      breakdownTags: await database.select(database.ocptBreakdownTagsTable).get(),
      sceneBreakdowns: await database.select(database.ocptSceneBreakdownsTable).get(),
      shootingDays: await database.select(database.ocptShootingDaysTable).get(),
      shootingSlots: await database.select(database.ocptShootingSlotsTable).get(),
      shootingSlotCrew: await database.select(database.ocptShootingSlotCrewTable).get(),
      shootingSlotCast: await database.select(database.ocptShootingSlotCastTable).get(),
      shootingDayBlocks: await database.select(database.ocptShootingDayBlocksTable).get(),
      shootingSlotGuests: await database.select(database.ocptShootingSlotGuestsTable).get(),
      shootingDayEvents: await database.select(database.ocptShootingDayEventsTable).get(),
      rowFieldVersions: await _captureRowFieldVersions(database: database),
      pageSetup: OcptPageSetup(format: info.pageFormat, margins: pageMargins),
      settingsJson: info.settingsJson,
      currencyCode: info.currencyCode,
      minimumRestMinutes: info.minimumRestMinutes,
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
  ///
  /// The eleven resources tables follow, in the same dependency order the schema's own migration
  /// creates them in: `people` (and its `person_positions`/`person_skills`/
  /// `person_unavailabilities` siblings, each pointing at it) before `roles` (which may cast one),
  /// before `locations` (whose contact may be one) before the `sets` inside them, before
  /// `scene_sets` linking a scene to one, before `elements` (whose owner and bringer may be a
  /// person) before `scene_elements` linking a scene to one and `role_elements` linking a role to
  /// one, and `assets` last, since a person, a
  /// location or an element may name one as its photo or document before that row itself exists.
  /// `role_episodes` — which episode each role is named in
  /// (`docs/adr/0019-one-project-several-episodes.md`) — is restored right after `roles`, the table
  /// it names alongside `screenplays`: both are already restored by this point (`screenplays` at
  /// the very top, `roles` immediately above), so this is not a forward reference, and — unlike the
  /// asset trio below — it closes no foreign-key cycle of its own: nothing restored after
  /// `role_episodes` ever references it back.
  /// That last point is also where the ordering stops being fully satisfiable: `people`,
  /// `locations` and `elements` each reference `assets` (a photo, a permit, a document) while
  /// `assets` references all three back (whose photo or document it is) — a genuine foreign-key
  /// cycle, the same one `OcptAssetsTable`'s own doc comment describes for `CREATE TABLE`. No
  /// statement-by-statement ordering can satisfy every reference in a cycle, which is exactly why
  /// [restoreVersion] runs this under `PRAGMA defer_foreign_keys = ON`: every constraint is only
  /// checked at the transaction's commit, by which point every table above has been written in
  /// full.
  ///
  /// `breakdown_tags` and `scene_breakdowns` follow the resources tables, since a tag may point at
  /// an element, a role or a set, and both tables reference `scenes`: every one of those exists by
  /// this point, so — unlike `assets` — neither closes a foreign-key cycle of its own; the deferred
  /// pragma above is what the asset trio needs, not these two.
  ///
  /// The schedule tables follow last, in the same dependency order the schema's own v11 migration
  /// creates the five of them it still carries in, `shooting_slot_guests` and `shooting_day_events`
  /// (schema v17) slotted in beside the sibling each one follows: `shooting_days` (which may
  /// reference a screenplay already restored
  /// above) before `shooting_slots` (which may name a location or a set), before
  /// `shooting_slot_crew`/`shooting_slot_cast`/`shooting_slot_guests` (which each point at a slot,
  /// and at a person, a role, or — nullable — a person respectively) and `shooting_day_blocks`
  /// (which points at a slot and, for a shot block, at
  /// a shot), and `shooting_day_events` last, referencing only a day. Every table it
  /// could possibly reference is restored by this point, so this is not a forward reference and
  /// closes no cycle of its own — the deferred pragma above is still what the asset trio further up
  /// needs, not this group.
  ///
  /// [payload] arrives already scrubbed of every erased person: [loadPayload] is what does it, once,
  /// for every reader of a payload alike — see [_scrubErasedPeople]. None of the schedule
  /// tables holds a person's own data (a phone number, an address, an allergy) — only ids pointing
  /// at `people` and `roles`, `shooting_slot_guests.freeName` naming somebody the address book has
  /// never heard of — so there is nothing in them for that scrub to touch.
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

    await _restoreTable(
      database: database,
      table: database.ocptPeopleTable,
      payloadRows: payload.people,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptPersonPositionsTable,
      payloadRows: payload.personPositions,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptPersonSkillsTable,
      payloadRows: payload.personSkills,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptPersonUnavailabilitiesTable,
      payloadRows: payload.personUnavailabilities,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptRolesTable,
      payloadRows: payload.roles,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptRoleEpisodesTable,
      payloadRows: payload.roleEpisodes,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptLocationsTable,
      payloadRows: payload.locations,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptLocationAvailabilitiesTable,
      payloadRows: payload.locationAvailabilities,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptSetsTable,
      payloadRows: payload.sets,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptSceneSetsTable,
      payloadRows: payload.sceneSets,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptElementsTable,
      payloadRows: payload.elements,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptSceneElementsTable,
      payloadRows: payload.sceneElements,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptRoleElementsTable,
      payloadRows: payload.roleElements,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptAssetsTable,
      payloadRows: payload.assets,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptBreakdownTagsTable,
      payloadRows: payload.breakdownTags,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptSceneBreakdownsTable,
      payloadRows: payload.sceneBreakdowns,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptShootingDaysTable,
      payloadRows: payload.shootingDays,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptShootingSlotsTable,
      payloadRows: payload.shootingSlots,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptShootingSlotCrewTable,
      payloadRows: payload.shootingSlotCrew,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptShootingSlotCastTable,
      payloadRows: payload.shootingSlotCast,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptShootingSlotGuestsTable,
      payloadRows: payload.shootingSlotGuests,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptShootingDayBlocksTable,
      payloadRows: payload.shootingDayBlocks,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await _restoreTable(
      database: database,
      table: database.ocptShootingDayEventsTable,
      payloadRows: payload.shootingDayEvents,
      rowIdOf: (row) => row.id,
      tombstonedOf: (row) => row.copyWith(isDeleted: true),
      stamps: stamps,
    );

    await stamps.flush(database);
  }

  /// Rewrites [payload]'s `people` rows — and the `person_positions`/`person_skills`/
  /// `person_unavailabilities`/`assets` rows hanging off them — for every person `local_erasures`
  /// names in [database], so no reader of a payload ever sees an erased person again: neither [_applyPayload]
  /// writing one back into the working copy, nor [hydratePreview] putting one on screen. [loadPayload]
  /// is the single door both come through, which is why the scrub lives there.
  ///
  /// A version is captured before knowing about an erasure made later, so its stored payload still
  /// holds that person's personal data verbatim, forever: a version is never rewritten once
  /// captured (`OcptProjectVersionCodec`'s own doc comment). `local_erasures` is what lets this
  /// replica remember the erasure happened without the payload that predates it ever having to
  /// become untruthful about the moment it captured — decode-time scrubbing, not a rewrite on disk
  /// (§4.9 of the plan this ships under, option 3). It is read fresh from [database] rather than
  /// from [payload] on purpose: that is what lets a restore of an *old* version still honour an
  /// erasure recorded strictly after that version was taken, and `local_erasures` itself is never
  /// part of a payload — carrying it there would let this very restore rewind the fact that the
  /// erasure ever happened.
  ///
  /// Every erased person's row is put back through exactly the blanking-and-tombstoning
  /// [_erasedPersonRow] performs — chosen over dropping the row outright, since nothing in this
  /// schema is ever hard-deleted, and other rows this same payload may carry (`roles.personId`,
  /// `elements.ownerPersonId`/`broughtByPersonId`, `assets.personId`, `locations.contactPersonId`)
  /// can still reference the id: the row they point at must keep existing, merely empty, or the
  /// restore's own `PRAGMA defer_foreign_keys` commit would have nothing to resolve them against.
  /// **This must be kept in step with `OcptPeopleService.deletePerson` by hand** — the two
  /// implement the very same erasure from two different starting points (a live row there, a
  /// captured one here), and a column blanked by one but not the other reopens exactly the leak
  /// this method exists to close.
  Future<OcptProjectVersionPayload> _scrubErasedPeople({
    required OcptProjectDatabase database,
    required OcptProjectVersionPayload payload,
  }) async {
    final erasedPersonIds = {
      for (final row in await database.select(database.ocptLocalErasuresTable).get()) row.personId,
    };

    if (erasedPersonIds.isEmpty) {
      return payload;
    }

    return OcptProjectVersionPayload(
      screenplays: payload.screenplays,
      scenes: payload.scenes,
      shots: payload.shots,
      shotCharacters: payload.shotCharacters,
      shotCoverages: payload.shotCoverages,
      people: [
        for (final row in payload.people)
          erasedPersonIds.contains(row.id) ? _erasedPersonRow(row) : row,
      ],
      personPositions: [
        for (final row in payload.personPositions)
          erasedPersonIds.contains(row.personId) ? row.copyWith(isDeleted: true) : row,
      ],
      // person_skills.label and person_unavailabilities.reason are blanked along with the
      // tombstone, exactly as OcptPeopleService.deletePerson blanks them: both routinely hold
      // something personal about the person (a driving licence, a language, why they were away on
      // a date), and an erasure is about what the file stops holding, not only what a screen stops
      // showing.
      personSkills: [
        for (final row in payload.personSkills)
          erasedPersonIds.contains(row.personId)
              ? row.copyWith(isDeleted: true, label: '')
              : row,
      ],
      personUnavailabilities: [
        for (final row in payload.personUnavailabilities)
          erasedPersonIds.contains(row.personId)
              ? row.copyWith(isDeleted: true, reason: '')
              : row,
      ],
      roles: payload.roles,
      // A role_episodes row names a role and a screenplay, never a person: an actor is reached
      // through `roles.personId`, which the `roles` list above already answers for. Nothing here
      // to scrub.
      roleEpisodes: payload.roleEpisodes,
      locations: payload.locations,
      locationAvailabilities: payload.locationAvailabilities,
      sets: payload.sets,
      sceneSets: payload.sceneSets,
      elements: payload.elements,
      sceneElements: payload.sceneElements,
      // A `role_elements` row names a role and an element, never a person: an actor is reached
      // through `roles.personId`, which the `roles` list above already answers for. Nothing here
      // to scrub.
      roleElements: payload.roleElements,
      // An asset's `path` is personal data in its own right: an absolute path routinely names the
      // person (`…/cession-droits-Jean-Dupont.pdf`) and always says where a photograph of them
      // sits on this machine. So a row belonging to an erased person is tombstoned **and blanked**,
      // exactly as `OcptAssetsService.erasePersonAssets` does it live — the mirror this comment's
      // method doc warns must be kept in step. A row belonging to a location or an element is
      // nobody's personal data and travels through untouched.
      assets: [
        for (final row in payload.assets)
          row.personId != null && erasedPersonIds.contains(row.personId)
              ? row.copyWith(isDeleted: true, path: '', label: '')
              : row,
      ],
      // A breakdown tag never names a person — only an element, a role or a set — and a scene
      // breakdown carries nothing about anyone either, so neither list has anything for this method
      // to scrub: both travel through unchanged.
      breakdownTags: payload.breakdownTags,
      sceneBreakdowns: payload.sceneBreakdowns,
      // None of the schedule tables holds a person's own data either — only ids pointing at
      // `people` or `roles`, which stay valid (an erased person's row is blanked and tombstoned,
      // never dropped, so a `shooting_slot_crew.personId` or a `shooting_slot_guests.personId`
      // referencing it still resolves) — so all of them travel through unchanged too.
      // `shooting_slot_guests.freeName` names somebody who was never a `people` row in the first
      // place, so there is nothing there for this scrub to reach either, and `shooting_day_events`
      // carries nobody's data at all.
      shootingDays: payload.shootingDays,
      shootingSlots: payload.shootingSlots,
      shootingSlotCrew: payload.shootingSlotCrew,
      shootingSlotCast: payload.shootingSlotCast,
      shootingDayBlocks: payload.shootingDayBlocks,
      shootingSlotGuests: payload.shootingSlotGuests,
      shootingDayEvents: payload.shootingDayEvents,
      rowFieldVersions: payload.rowFieldVersions,
      pageSetup: payload.pageSetup,
      settingsJson: payload.settingsJson,
      currencyCode: payload.currencyCode,
      minimumRestMinutes: payload.minimumRestMinutes,
    );
  }

  /// [row], blanked exactly as `OcptPeopleService.deletePerson`'s own erasure blanks a live row:
  /// every column held something about the person except `id`, `sortKey`, `isDeleted` (set to true
  /// here rather than left alone) and `colorIndex`. `maxDailyPresenceMinutes` is blanked with the
  /// rest, being personal data of the same nature as `minorNotes`. See [_scrubErasedPeople] for why
  /// the two must stay in step by hand.
  static OcptPersonRow _erasedPersonRow(OcptPersonRow row) => row.copyWith(
    isDeleted: true,
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    addressLine1: '',
    addressLine2: '',
    postalCode: '',
    city: '',
    region: '',
    country: '',
    birthDate: const Value(null),
    minorNotes: '',
    maxDailyPresenceMinutes: const Value(null),
    isTransportAutonomous: const Value(null),
    accommodationNotes: '',
    travelNotes: '',
    dietaryNotes: '',
    allergies: '',
    measurementHeight: '',
    measurementChest: '',
    measurementWaist: '',
    measurementHips: '',
    sizeTop: '',
    sizeBottom: '',
    sizeShoes: '',
    hmcNotes: '',
    imageRightsStatus: OcptImageRightsStatus.notApplicable,
    imageRightsDate: const Value(null),
    imageRightsAssetId: const Value(null),
    photoAssetId: const Value(null),
    notes: '',
  );

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
