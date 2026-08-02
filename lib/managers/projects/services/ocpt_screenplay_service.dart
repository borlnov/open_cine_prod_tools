// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:uuid/uuid.dart';

/// Loads and saves a screenplay's Fountain text, taking safety snapshots along the way.
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

  /// Class constructor
  const OcptScreenplayService({
    required OcptSceneIndexService sceneIndexService,
    required OcptShotListService shotListService,
    required OcptShotCoverageService shotCoverageService,
  }) : _sceneIndexService = sceneIndexService,
       _shotListService = shotListService,
       _shotCoverageService = shotCoverageService;

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

  /// Takes the project-open safety snapshot of the screenplay [screenplayId] in [database].
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
  );

  /// Takes the safety snapshot of the screenplay [screenplayId] in [database] that a project
  /// version's restore owes the merge, right before that restore writes the version's own text
  /// over it.
  ///
  /// Called by `OcptProjectVersionsService.restoreVersion`, from inside the restore's own
  /// transaction, and by nothing else: unlike every other snapshot here, this one is not about
  /// recovering from a mistake — see [OcptSnapshotReason.restore] for what it is about.
  ///
  /// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> snapshotBeforeRestore({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => _snapshotCurrentText(
    database: database,
    screenplayId: screenplayId,
    reason: OcptSnapshotReason.restore,
    operation: "snapshotBeforeRestore",
  );

  /// Saves [fountainText] as the new text of the screenplay [screenplayId] in [database].
  ///
  /// This snapshots the text as it was before the overwrite (tagged [snapshotReason]), updates
  /// the screenplay's text and `updatedAt`, reconciles its scene index from the new text — passing
  /// `OcptShotListService.detachShotsFromDeletedScenes` as `onScenesDeleted`, so a scene removed by
  /// this save orphans its shots rather than silently dropping them — re-checks the shots' scenario
  /// coverage against the text just saved, and prunes old snapshots, all within a single
  /// transaction.
  ///
  /// The coverage re-check deliberately happens here, on save, and never on the editor's parse
  /// debounce: staleness is what raises a shot's `needsCheck` flag, and a director does not want a
  /// shot flagged mid-keystroke. It runs after the reconciliation so it reads the scenes'
  /// `charStart`/`charEnd` as the new text has just redefined them.
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
      final previousText = await loadScreenplayText(
        database: database,
        screenplayId: screenplayId,
      );

      await _createSnapshot(
        database: database,
        screenplayId: screenplayId,
        fountainText: previousText,
        reason: snapshotReason,
      );

      await (database.update(database.ocptScreenplaysTable)
            ..where((table) => table.id.equals(screenplayId) & table.isDeleted.not()))
          .write(
            OcptScreenplaysTableCompanion(
              fountainText: Value(fountainText),
              updatedAt: Value(DateTime.now()),
            ),
          );

      final document = _fountainParser.parse(fountainText);
      await _sceneIndexService.reconcile(
        database: database,
        screenplayId: screenplayId,
        document: document,
        onScenesDeleted: (scenesAboutToBeDeleted) => _shotListService.detachShotsFromDeletedScenes(
          database: database,
          scenesAboutToBeDeleted: scenesAboutToBeDeleted,
        ),
      );

      await _shotCoverageService.refreshStaleness(
        database: database,
        screenplayId: screenplayId,
        currentFountainText: fountainText,
      );

      await _pruneSnapshots(database: database, screenplayId: screenplayId);
    });
  }

  /// Snapshots the text the screenplay [screenplayId] currently holds in [database], tagged
  /// [reason], and prunes the older snapshots — both within one transaction.
  ///
  /// [operation] is what the preview guard names in the log when it refuses the write.
  Future<void> _snapshotCurrentText({
    required OcptProjectDatabase database,
    required String screenplayId,
    required OcptSnapshotReason reason,
    required String operation,
  }) async {
    if (database.refusesUserWrite(operation)) {
      return;
    }

    final currentText = await loadScreenplayText(database: database, screenplayId: screenplayId);

    await database.transaction(() async {
      await _createSnapshot(
        database: database,
        screenplayId: screenplayId,
        fountainText: currentText,
        reason: reason,
      );
      await _pruneSnapshots(database: database, screenplayId: screenplayId);
    });
  }

  /// Inserts a new snapshot row for [screenplayId] in [database], capturing [fountainText].
  Future<void> _createSnapshot({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String fountainText,
    required OcptSnapshotReason reason,
  }) async {
    await database
        .into(database.ocptScreenplaySnapshotsTable)
        .insert(
          OcptScreenplaySnapshotsTableCompanion.insert(
            id: const Uuid().v4(),
            screenplayId: screenplayId,
            createdAt: DateTime.now(),
            reason: reason,
            fountainText: fountainText,
          ),
        );
  }

  /// Prunes the snapshots of [screenplayId] in [database] beyond the
  /// [maxSnapshotsPerScreenplay] most recent ones.
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
  }) async {
    final snapshots =
        await (database.select(database.ocptScreenplaySnapshotsTable)
              ..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
            .get();

    if (snapshots.length <= maxSnapshotsPerScreenplay) {
      return;
    }

    final idsToPrune = snapshots
        .skip(maxSnapshotsPerScreenplay)
        .map((snapshot) => snapshot.id)
        .toList(growable: false);

    await (database.update(
      database.ocptScreenplaySnapshotsTable,
    )..where((table) => table.id.isIn(idsToPrune))).write(
      const OcptScreenplaySnapshotsTableCompanion(
        fountainText: Value(""),
        isDeleted: Value(true),
      ),
    );
  }
}
