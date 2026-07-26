// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
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

  /// Class constructor
  const OcptScreenplayService({required OcptSceneIndexService sceneIndexService})
    : _sceneIndexService = sceneIndexService;

  /// Loads the current Fountain text of the screenplay [screenplayId] in [database].
  Future<String> loadScreenplayText({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final row = await (database.select(
      database.ocptScreenplaysTable,
    )..where((table) => table.id.equals(screenplayId))).getSingle();

    return row.fountainText;
  }

  /// Takes the project-open safety snapshot of the screenplay [screenplayId] in [database].
  ///
  /// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
  Future<void> snapshotOnProjectOpen({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final currentText = await loadScreenplayText(database: database, screenplayId: screenplayId);

    await database.transaction(() async {
      await _createSnapshot(
        database: database,
        screenplayId: screenplayId,
        fountainText: currentText,
        reason: OcptSnapshotReason.open,
      );
      await _pruneSnapshots(database: database, screenplayId: screenplayId);
    });
  }

  /// Saves [fountainText] as the new text of the screenplay [screenplayId] in [database].
  ///
  /// This snapshots the text as it was before the overwrite (tagged [snapshotReason]), updates
  /// the screenplay's text and `updatedAt`, reconciles its scene index from the new text, and
  /// prunes old snapshots, all within a single transaction.
  ///
  /// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
  Future<void> saveScreenplayText({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String fountainText,
    required OcptSnapshotReason snapshotReason,
  }) async {
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
            ..where((table) => table.id.equals(screenplayId)))
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

  /// Deletes the snapshots of [screenplayId] in [database] beyond the
  /// [maxSnapshotsPerScreenplay] most recent ones.
  Future<void> _pruneSnapshots({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final snapshots =
        await (database.select(database.ocptScreenplaySnapshotsTable)
              ..where((table) => table.screenplayId.equals(screenplayId))
              ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
            .get();

    if (snapshots.length <= maxSnapshotsPerScreenplay) {
      return;
    }

    final idsToDelete = snapshots
        .skip(maxSnapshotsPerScreenplay)
        .map((snapshot) => snapshot.id)
        .toList(growable: false);

    await (database.delete(
      database.ocptScreenplaySnapshotsTable,
    )..where((table) => table.id.isIn(idsToDelete))).go();
  }
}
