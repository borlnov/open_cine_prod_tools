// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// Loads and saves a screenplay's Fountain text, taking safety snapshots along the way, and owns
/// the episode CRUD — **there is no twelfth service**: `docs/adr/0019-one-project-several-episodes.md`
/// settles that a `screenplays` row *is* an episode, so the service that already owns screenplays
/// owns episodes too, [loadEpisodes]/[createEpisode]/[updateEpisode]/[reorderEpisode]/[deleteEpisode]
/// sitting beside the text/snapshot methods rather than in a table-per-service split this app
/// otherwise follows.
///
/// [saveScreenplayText] also reconciles the scene index and the cast (`OcptRoleIndexService`)
/// against the newly saved text, re-checks the shots' scenario coverage, and re-anchors the
/// breakdown tags (`OcptBreakdownService.reconcileTags`) — all four on the save path itself
/// rather than on the editor's parse debounce, and for the same reason each time: a director
/// does not want a scene, a role, a coverage flag or a tag appearing, disappearing or drifting
/// mid-keystroke.
///
/// [deleteEpisode]'s cascade takes [_scheduleService] through the constructor exactly as it takes
/// its other four collaborators: the schedule places shots, so the placements of an episode's shots
/// go when those shots do, and reaching for the service that owns `shooting_day_blocks` is how that
/// edge is drawn. It only ever runs this one way — `OcptScheduleService` knows nothing of
/// screenplays or episodes, and cannot reach back.
///
/// {@template open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
/// A snapshot of the text is taken:
///
/// - once, right after a project is opened (see [snapshotOnProjectOpen]), tagged
///   [OcptSnapshotReason.open], so the state the user found the project in is never lost even if
///   their very first edit goes wrong;
/// - right before every overwrite of the stored text (see [saveScreenplayText]), tagged with
///   whatever [OcptSnapshotReason] the caller passes, capturing the text as it was *before* the
///   new text replaces it.
///
/// Only the [OcptScreenplayService.maxSnapshotsPerScreenplay] most recent snapshots of a
/// screenplay are kept: [saveScreenplayText] prunes older ones after every save.
/// {@endtemplate}
class OcptScreenplayService {
  /// The maximum number of snapshots kept per screenplay: older ones are pruned after every save.
  static const maxSnapshotsPerScreenplay = 30;

  /// The parser used to rebuild the scene index from the saved Fountain text.
  static const _fountainParser = FountainParser();

  /// The service used to reconcile the scene index after every save.
  final OcptSceneIndexService _sceneIndexService;

  /// The service used to detach a screenplay's shots from any scene the save is about to remove.
  final OcptShotListService _shotListService;

  /// The service used to re-check the shots' scenario coverage against the text just saved.
  final OcptShotCoverageService _shotCoverageService;

  /// The service used to reconcile the cast against the newly saved text's speaking characters.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to re-anchor, or flag, the breakdown tags against the newly saved text.
  final OcptBreakdownService _breakdownService;

  /// The service used, by [deleteEpisode]'s cascade, to tombstone the `shooting_day_blocks` rows
  /// placing any of the episode's shots. See the class doc comment for why this edge only ever runs
  /// this way.
  final OcptScheduleService _scheduleService;

  /// Resolves the device id every stamp this class' own writes carry, and every stamp its
  /// collaborators make from the single [OcptRowStampService] a top-level method here seeds for its
  /// own transaction — see [OcptDeviceIdGetter]. [saveScreenplayText] and [deleteEpisode] hand that
  /// one instance to [_shotListService]/[_shotCoverageService]/[_roleIndexService]/
  /// [_breakdownService]/[_scheduleService] as well as stamping `screenplays` and
  /// `screenplay_snapshots` themselves with it; every other method that writes either table
  /// ([createEpisode], [updateEpisode], [reorderEpisode], [snapshotOnProjectOpen]) seeds and flushes
  /// its own, since none of them run inside another method's transaction. [snapshotBeforeRestore] is
  /// the one exception: it always runs inside `OcptProjectVersionsService._applyPayload`'s own
  /// already-seeded transaction, so it takes that caller's instance instead of resolving a device id
  /// of its own.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptScreenplayService({
    required OcptSceneIndexService sceneIndexService,
    required OcptShotListService shotListService,
    required OcptShotCoverageService shotCoverageService,
    required OcptRoleIndexService roleIndexService,
    required OcptBreakdownService breakdownService,
    required OcptScheduleService scheduleService,
    required this.deviceId,
  }) : _sceneIndexService = sceneIndexService,
       _shotListService = shotListService,
       _shotCoverageService = shotCoverageService,
       _roleIndexService = roleIndexService,
       _breakdownService = breakdownService,
       _scheduleService = scheduleService;

  /// Loads the current Fountain text of the screenplay [screenplayId] in [database].
  Future<String> loadScreenplayText({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final row = await (database.select(database.ocptScreenplaysTable)
          ..where((table) => table.id.equals(screenplayId) & table.isDeleted.not()))
        .getSingle();

    return row.fountainText;
  }

  /// Takes the project-open safety snapshot of the screenplay [screenplayId] in [database]: unlike
  /// [snapshotBeforeRestore], nothing has already opened a transaction or seeded an
  /// [OcptRowStampService] around this call, so [_snapshotCurrentText] seeds and flushes its own.
  ///
  /// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> snapshotOnProjectOpen({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _snapshotCurrentText(
    database: database,
    screenplayId: screenplayId,
    reason: OcptSnapshotReason.open,
    operation: "snapshotOnProjectOpen",
    stamps: null,
  );

  /// Takes the safety snapshot of the screenplay [screenplayId] in [database] that a project
  /// version's restore owes the merge, right before that restore writes the version's own text
  /// over it.
  ///
  /// Called by `OcptProjectVersionsService._applyPayload`, from inside the restore's own
  /// transaction, and by nothing else: unlike every other snapshot here, this one is not about
  /// recovering from a mistake — see [OcptSnapshotReason.restore] for what it is about. It hands
  /// [_snapshotCurrentText] [stamps] — that caller's own, already-seeded [OcptRowStampService] —
  /// rather than one seeded here, so the snapshot it takes stamps into the very same instance the
  /// restore itself flushes once, at the end.
  ///
  /// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> snapshotBeforeRestore({
    required OcptProjectDatabase database,
    required String screenplayId,
    required OcptRowStampService stamps,
  }) => _snapshotCurrentText(
    database: database,
    screenplayId: screenplayId,
    reason: OcptSnapshotReason.restore,
    operation: "snapshotBeforeRestore",
    stamps: stamps,
  );

  /// Saves [fountainText] as the new text of the screenplay [screenplayId] in [database].
  ///
  /// This is the user path onto [reconcileScreenplayText] — see its own doc comment for what the
  /// reconciliation actually does. All this method adds on top: refusing the write outright when
  /// [database] is a version preview ([OcptProjectDatabase.refusesUserWrite]), and seeding and
  /// flushing the [OcptRowStampService] the reconciliation stamps into, around one transaction.
  ///
  /// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> saveScreenplayText({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String fountainText,
    required OcptSnapshotReason snapshotReason,
  }) async {
    if (database.refusesUserWrite("saveScreenplayText")) {
      return;
    }

    await database.transaction(() async {
      // Seeded once for the whole save, and flushed once at the end: `detachShotsFromDeletedScenes`
      // and `refreshStaleness` both stamp into it below, and a version's own floor is never folded
      // in here — that is `OcptProjectVersionsService.raiseFloor`'s job, not an ordinary save's.
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await reconcileScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: fountainText,
        snapshotReason: snapshotReason,
        stamps: stamps,
      );

      await stamps.flush(database);
    });
  }

  /// Overwrites the screenplay [screenplayId]'s stored text with [fountainText] in [database] and
  /// reruns everything that depends on it — the shared core of every screenplay text write in the
  /// app, on **both** of its callers:
  ///
  /// - [saveScreenplayText], the user path: called from inside its own transaction, behind its own
  ///   [OcptProjectDatabase.refusesUserWrite] guard, against the user's own [database];
  /// - `OcptScreenplayMergeService`, the engine path: called from inside the merge's own
  ///   `defer_foreign_keys` transaction, against `OcptOpenProjectModel.fileDatabase`, with **no**
  ///   preview guard at all — an incoming merge is not a user edit (see that guard's own doc
  ///   comment) and must go through even while a version preview is up.
  ///
  /// This snapshots the text as it was before the overwrite (tagged [snapshotReason]), updates
  /// the screenplay's text and `updatedAt`, reconciles its scene index from the new text — passing
  /// `OcptShotListService.detachShotsFromDeletedScenes` as `onScenesDeleted`, so a scene removed by
  /// this save orphans its shots rather than silently dropping them — reconciles the cast against
  /// the same parsed document (`OcptRoleIndexService.reconcile`), re-checks the shots' scenario
  /// coverage against the text just saved, re-anchors the breakdown tags against the same text
  /// (`OcptBreakdownService.reconcileTags`), and prunes old snapshots.
  ///
  /// The coverage re-check, the cast reconciliation and the tag reconciliation deliberately happen
  /// here, on save, and never on the editor's parse debounce: staleness is what raises a shot's
  /// `needsCheck` flag, a speaking character's appearance or disappearance is what raises or clears
  /// a role's `orphanedName`, and a shifted or vanished passage is what re-anchors or flags a tag —
  /// in every case a director does not want the flag flickering mid-keystroke. The cast is
  /// reconciled right after the scene index (it reads the parsed [FountainDocument], not the scenes
  /// the scene index just wrote); the coverage re-check and the tag reconciliation both come after
  /// that, since both read the scenes' `charStart`/`charEnd` as the new text has just redefined
  /// them, and both re-check stored anchors against the text just saved.
  ///
  /// Neither the transaction nor [stamps] is this method's own: it must run inside an
  /// already-open transaction, [stamps] must already be seeded, and the caller flushes it exactly
  /// once, after this returns — never twice inside the same transaction.
  Future<void> reconcileScreenplayText({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String fountainText,
    required OcptSnapshotReason snapshotReason,
    required OcptRowStampService stamps,
  }) async {
    final currentScreenplay = await (database.select(database.ocptScreenplaysTable)
          ..where((table) => table.id.equals(screenplayId) & table.isDeleted.not()))
        .getSingle();

    await _createSnapshot(
      database: database,
      screenplayId: screenplayId,
      fountainText: currentScreenplay.fountainText,
      reason: snapshotReason,
      stamps: stamps,
    );

    await OcptRowStampService.writeAndStamp(
      database: database,
      table: database.ocptScreenplaysTable,
      rowId: screenplayId,
      current: currentScreenplay,
      next: currentScreenplay.copyWith(fountainText: fountainText, updatedAt: DateTime.now()),
      stamps: stamps,
    );

    final document = _fountainParser.parse(fountainText);
    await _sceneIndexService.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: document,
      onScenesDeleted: (scenesAboutToBeDeleted) => _shotListService.detachShotsFromDeletedScenes(
        database: database,
        scenesAboutToBeDeleted: scenesAboutToBeDeleted,
        stamps: stamps,
      ),
    );

    await _roleIndexService.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: document,
      stamps: stamps,
    );

    await _shotCoverageService.refreshStaleness(
      database: database,
      screenplayId: screenplayId,
      currentFountainText: fountainText,
      stamps: stamps,
    );

    await _breakdownService.reconcileTags(
      database: database,
      screenplayId: screenplayId,
      currentFountainText: fountainText,
      stamps: stamps,
    );

    await _pruneSnapshots(database: database, screenplayId: screenplayId, stamps: stamps);
  }

  /// Loads every live episode of the project in [database] — every live `screenplays` row — in
  /// `sortKey` order.
  Future<List<OcptEpisode>> loadEpisodes({required OcptProjectDatabase database}) async {
    final rows = await _liveEpisodeRows(database: database);
    return rows.map(OcptEpisode.fromRow).toList(growable: false);
  }

  /// Creates a new, empty episode in [database], appended after the last live episode, and returns
  /// its freshly generated id — the project settings page's "add an episode" action.
  ///
  /// A fresh `sortKey` is allocated through `ocptFractionalKeyBetween`, appending it at the tail of
  /// the project's episodes, exactly as every other append in this app does. [title] defaults to
  /// the empty string — an ordinary state, see `OcptEpisode`'s own doc comment — and [number]
  /// defaults to the last live episode's own number plus one when not given, which is the plain
  /// reading of "the next episode" for a series numbered in order; a caller renumbering as it goes
  /// (inserting "episode 2.5") passes [number] itself. `fountainText` is left at its column default,
  /// the empty string, and `updatedAt` is stamped now: a freshly minted screenplay's text was, in a
  /// sense, just "saved" as empty.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createEpisode({
    required OcptProjectDatabase database,
    String title = "",
    int? number,
  }) async {
    if (database.refusesUserWrite("createEpisode")) {
      return null;
    }

    final existing = await _liveEpisodeRows(database: database);
    final id = const Uuid().v4();
    // Every column `OcptScreenplaysTable` declares a default for is spelled out here to match it
    // exactly: `OcptRowStampService.writeAndStamp` stamps a fresh insert from the full row it is
    // handed, never from what SQLite would fill in on its own.
    final row = OcptScreenplayRow(
      id: id,
      title: title,
      fountainText: "",
      updatedAt: DateTime.now(),
      number: number ?? (existing.isEmpty ? 1 : existing.last.number + 1),
      sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
      isDeleted: false,
    );

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptScreenplaysTable,
        rowId: id,
        current: null,
        next: row,
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates the fields of episode [screenplayId] in [database] that are passed as something other
  /// than [Value.absent].
  ///
  /// Never touches `sortKey` ([reorderEpisode] owns it), `fountainText` or `updatedAt`
  /// ([saveScreenplayText] owns those — `updatedAt` is when the episode's *text* was last saved, and
  /// renaming an episode or renumbering it is not saving its text). Follows the shape of
  /// `OcptRoleIndexService.updateRole`.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateEpisode({
    required OcptProjectDatabase database,
    required String screenplayId,
    Value<String> title = const Value.absent(),
    Value<int> number = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateEpisode")) {
      return;
    }

    final companion = OcptScreenplaysTableCompanion(title: title, number: number);

    await database.transaction(() async {
      final current =
          await (database.select(database.ocptScreenplaysTable)
                ..where((table) => table.id.equals(screenplayId) & table.isDeleted.not()))
              .getSingleOrNull();
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptScreenplaysTable,
        rowId: screenplayId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves episode [screenplayId] to [newPosition] (0-based) among the project's live episodes, by
  /// giving it a `sortKey` sitting between the two episodes it lands between. Writes **exactly one
  /// row**, following `OcptRoleIndexService.reorderRole`'s own shape.
  ///
  /// **`number` is never renumbered here.** `sortKey` orders, `number` prints, and the two are
  /// deliberately independent (`docs/adr/0019-one-project-several-episodes.md`): two episodes
  /// numbered 4 is a state the user can reach by a reorder and repair by hand, not a state this
  /// method refuses to produce.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderEpisode({
    required OcptProjectDatabase database,
    required String screenplayId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderEpisode")) {
      return;
    }

    await database.transaction(() async {
      final all = await _liveEpisodeRows(database: database);
      OcptScreenplayRow? current;
      for (final row in all) {
        if (row.id == screenplayId) {
          current = row;
          break;
        }
      }
      if (current == null) {
        return;
      }

      final others = all..removeWhere((row) => row.id == screenplayId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptScreenplaysTable,
        rowId: screenplayId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones episode [screenplayId] and everything it alone owns — its safety snapshots, its
  /// scenes, its shots and their coverage, its breakdown (tags, scene statuses, and — through the
  /// elements and locations services `OcptBreakdownService` itself holds — the
  /// `scene_elements`/`scene_sets` links its scenes carried), the `shooting_day_blocks` rows placing
  /// any of its shots, and the `role_episodes` links naming it — in one transaction, and returns
  /// whether it did.
  ///
  /// **What is left alone is just as much the point** (`docs/adr/0019-one-project-several-episodes.md`):
  /// the people, the locations, the elements and **the shooting days**, none of which were ever this
  /// episode's. A shooting day that placed one of the episode's shots loses that one block; the day
  /// itself, its other slots and every other block on it are untouched, since the schedule belongs
  /// to the production, never to one screenplay. A role that spoke only in this episode keeps its
  /// row, its casting and its notes — it is simply named in no episode any more, which is not the
  /// same state as [OcptRoleIndexService.reconcile]'s `orphanedName` (see
  /// [OcptRoleIndexService.tombstoneEpisodeLinks]'s own doc comment). **A `hold` block whose
  /// `sceneId` names one of this episode's scenes is left exactly as it is**: a scene tombstoned by
  /// `OcptSceneIndexService.reconcile` already leaves such a block alone today (its `sceneId` simply
  /// stops resolving to a live scene), and a hold is a reservation on a day this deletion does not
  /// touch — there is no new behaviour to invent for it here.
  ///
  /// Returns `false`, writing nothing, when the preview guard refuses the write, when
  /// [screenplayId] names no live episode, or when it is **the last live episode of the project** —
  /// a project always holds at least one screenplay (`OcptProjectsManager.openProject` treats a file
  /// with none as corrupted) — logging that last refusal through `appLogger().w`, the way
  /// `OcptProjectsManager.deleteProjectVersion` logs its own.
  ///
  /// The cascade is orchestrated here, but each table is tombstoned **by the service that owns
  /// it** — the rule `OcptRoleIndexService.deleteRole` already follows when it reaches for
  /// `OcptElementsService.tombstoneRoleLinksOfRole` — so this method itself writes only
  /// `screenplay_snapshots` and the `screenplays` row, the two tables that are
  /// [OcptScreenplayService]'s own, the screenplay row written **last**: every dependent must have
  /// already lost its reason to exist before the row it hung off does.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<bool> deleteEpisode({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    if (database.refusesUserWrite("deleteEpisode")) {
      return false;
    }

    return database.transaction(() async {
      final liveEpisodes = await _liveEpisodeRows(database: database);
      OcptScreenplayRow? episode;
      for (final row in liveEpisodes) {
        if (row.id == screenplayId) {
          episode = row;
          break;
        }
      }
      if (episode == null) {
        return false;
      }

      if (liveEpisodes.length <= 1) {
        appLogger().w("The episode $screenplayId can't be deleted: it's the project's last live "
            "one, and a project always holds at least one screenplay");
        return false;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final sceneIds = await _sceneIndexService.tombstoneScenesOfScreenplay(
        database: database,
        screenplayId: screenplayId,
      );
      final shotIds = await _shotListService.tombstoneShotsOfScreenplay(
        database: database,
        screenplayId: screenplayId,
        stamps: stamps,
      );

      await _breakdownService.tombstoneBreakdownOfScenes(
        database: database,
        sceneIds: sceneIds,
        stamps: stamps,
      );
      await _scheduleService.tombstoneShotBlocks(
        database: database,
        shotIds: shotIds,
        stamps: stamps,
      );
      await _roleIndexService.tombstoneEpisodeLinks(
        database: database,
        screenplayId: screenplayId,
        stamps: stamps,
      );

      final snapshotRows = await (database.select(
        database.ocptScreenplaySnapshotsTable,
      )..where((table) => table.screenplayId.equals(screenplayId))).get();
      for (final snapshotRow in snapshotRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptScreenplaySnapshotsTable,
          rowId: snapshotRow.id,
          current: snapshotRow,
          next: snapshotRow.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptScreenplaysTable,
        rowId: screenplayId,
        current: episode,
        next: episode.copyWith(isDeleted: true),
        stamps: stamps,
      );

      await stamps.flush(database);

      return true;
    });
  }

  /// Snapshots the text the screenplay [screenplayId] currently holds in [database], tagged
  /// [reason], and prunes the older snapshots — both within one transaction.
  ///
  /// [operation] is what the preview guard names in the log when it refuses the write. [stamps] is
  /// `null` for [snapshotOnProjectOpen], which has nothing else seeded yet, so a fresh
  /// [OcptRowStampService] is seeded and flushed around the whole transaction here; it is the
  /// caller's own, already-seeded instance for [snapshotBeforeRestore], which stamps into it and
  /// leaves flushing it to that caller.
  Future<void> _snapshotCurrentText({
    required OcptProjectDatabase database,
    required String screenplayId,
    required OcptSnapshotReason reason,
    required String operation,
    required OcptRowStampService? stamps,
  }) async {
    if (database.refusesUserWrite(operation)) {
      return;
    }

    final currentText = await loadScreenplayText(database: database, screenplayId: screenplayId);

    await database.transaction(() async {
      final ownStamps =
          stamps ?? await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await _createSnapshot(
        database: database,
        screenplayId: screenplayId,
        fountainText: currentText,
        reason: reason,
        stamps: ownStamps,
      );
      await _pruneSnapshots(database: database, screenplayId: screenplayId, stamps: ownStamps);

      if (stamps == null) {
        await ownStamps.flush(database);
      }
    });
  }

  /// Inserts a new snapshot row for [screenplayId] in [database], capturing [fountainText], and
  /// stamps every column of it through [stamps].
  Future<void> _createSnapshot({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String fountainText,
    required OcptSnapshotReason reason,
    required OcptRowStampService? stamps,
  }) async {
    final id = const Uuid().v4();

    await OcptRowStampService.writeAndStamp(
      database: database,
      table: database.ocptScreenplaySnapshotsTable,
      rowId: id,
      current: null,
      next: OcptScreenplaySnapshotRow(
        id: id,
        screenplayId: screenplayId,
        createdAt: DateTime.now(),
        reason: reason,
        fountainText: fountainText,
        isDeleted: false,
      ),
      stamps: stamps,
    );
  }

  /// Prunes the snapshots of [screenplayId] in [database] beyond the
  /// [maxSnapshotsPerScreenplay] most recent ones, stamping each pruned row through [stamps].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// The pruned rows also have their `fountainText` cleared, in the same write: this is the one
  /// tombstone in the app that discards what it tombstones, because pruning exists precisely to
  /// bound the project file's size and a tombstone still carrying a whole screenplay would defeat
  /// it. Nothing reads a tombstoned snapshot's text — the merge base a three-way screenplay merge
  /// looks for is by definition one both replicas still hold.
  Future<void> _pruneSnapshots({
    required OcptProjectDatabase database,
    required String screenplayId,
    required OcptRowStampService? stamps,
  }) async {
    final snapshots =
        await (database.select(database.ocptScreenplaySnapshotsTable)
              ..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
            .get();

    if (snapshots.length <= maxSnapshotsPerScreenplay) {
      return;
    }

    for (final snapshot in snapshots.skip(maxSnapshotsPerScreenplay)) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptScreenplaySnapshotsTable,
        rowId: snapshot.id,
        current: snapshot,
        next: snapshot.copyWith(fountainText: "", isDeleted: true),
        stamps: stamps,
      );
    }
  }

  /// Every live episode (`screenplays` row) of the project in [database], in `sortKey` order — the
  /// read every episode CRUD method above builds its plan from, exactly as
  /// `OcptRoleIndexService._liveRoleRows` does for the cast.
  Future<List<OcptScreenplayRow>> _liveEpisodeRows({required OcptProjectDatabase database}) =>
      (database.select(database.ocptScreenplaysTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();
}
