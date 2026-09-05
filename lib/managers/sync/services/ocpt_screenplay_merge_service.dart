// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_screenplay_merge_conflict.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/utils/ocpt_three_way_merge.dart';

/// The three-way line merge for a screenplay's `fountainText` — the one column `OcptMergeService`
/// never resolves generically (see its own doc comment): `docs/plans/collaboration-and-sync.md`
/// §2.4/§3.4 reconciles the whole document by content instead of picking one side outright.
///
/// [mergeIncomingFountainText] is handed the *incoming* full text a changeset carries for one
/// screenplay. It:
///
/// 1. Reads the screenplay's current local text through [screenplayService]. Identical to the
///    incoming text already (a replay, or an edit this replica made too) needs no merge at all.
/// 2. Finds the merge base — see [_nearestCommonBaseText] for the heuristic, and what happens when
///    none is found.
/// 3. Runs [ocptThreeWayMerge] against that base, the local text and the incoming text.
///    - **Clean**: the merged text is written back through
///      `OcptScreenplayService.reconcileScreenplayText` — the very same core `saveScreenplayText`
///      runs on a user's own edit — so scenes, cast, coverage and breakdown reconcile exactly as
///      they would after an ordinary save, stamped by a freshly seeded [OcptRowStampService]
///      advancing this device's own clock (tagged [OcptSnapshotReason.merge]).
///    - **Conflict**: nothing is written at all. The local text stays exactly as it stood, and an
///      [OcptScreenplayMergeConflict] is returned for the caller (`OcptMergeService`, and
///      ultimately whatever collects them for the M5 conflict view) to record.
///
/// Runs with **no [OcptProjectDatabase.refusesUserWrite] guard**: an incoming merge is the engine
/// path, not a user edit (see that guard's own doc comment), and it must go through even while a
/// version preview is open. `screenplayService.reconcileScreenplayText` never checks it either, by
/// design — see that method's own doc comment.
class OcptScreenplayMergeService {
  /// The screenplay service whose extracted reconciliation core writes a clean merge back.
  final OcptScreenplayService screenplayService;

  /// Resolves the device id a clean merge's own write is stamped with.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptScreenplayMergeService({required this.screenplayService, required this.deviceId});

  /// Merges [incomingText] into the screenplay [screenplayId]'s current text on [fileDatabase],
  /// writing a clean result back and returning `null`, or leaving the text untouched and returning
  /// the [OcptScreenplayMergeConflict] to record when the two sides overlap. See this class's own
  /// doc comment for the full algorithm.
  Future<OcptScreenplayMergeConflict?> mergeIncomingFountainText({
    required OcptProjectDatabase fileDatabase,
    required String screenplayId,
    required String incomingText,
  }) async {
    final localText = await screenplayService.loadScreenplayText(
      database: fileDatabase,
      screenplayId: screenplayId,
    );

    if (localText == incomingText) {
      // Nothing to merge: either a replay of a changeset already reflected here, or this replica
      // made the exact same edit independently.
      return null;
    }

    final baseText = await _nearestCommonBaseText(database: fileDatabase, screenplayId: screenplayId);
    if (baseText == null) {
      appLogger().w(
        "No screenplay_snapshots row found at all for screenplay '$screenplayId': an incoming "
        "text edit can't be diffed against a common base, so it is surfaced as a full-text "
        "conflict rather than guessed at",
      );
      return OcptScreenplayMergeConflict(
        screenplayId: screenplayId,
        baseText: '',
        localText: localText,
        incomingText: incomingText,
      );
    }

    final result = ocptThreeWayMerge(base: baseText, left: localText, right: incomingText);

    switch (result) {
      case OcptCleanThreeWayMerge(:final mergedText):
        await _writeMergedText(fileDatabase: fileDatabase, screenplayId: screenplayId, mergedText: mergedText);
        return null;
      case OcptThreeWayMergeConflict():
        return OcptScreenplayMergeConflict(
          screenplayId: screenplayId,
          baseText: baseText,
          localText: localText,
          incomingText: incomingText,
        );
    }
  }

  /// Writes [mergedText] back as the screenplay [screenplayId]'s new text, through
  /// `OcptScreenplayService.reconcileScreenplayText`, seeding and flushing its own
  /// [OcptRowStampService] around one transaction — nested inside `OcptMergeService.applyChangeset`'s
  /// own already-open `defer_foreign_keys` transaction when called from there, and a transaction of
  /// its own when [mergeIncomingFountainText] is called directly, as this class's own tests do.
  Future<void> _writeMergedText({
    required OcptProjectDatabase fileDatabase,
    required String screenplayId,
    required String mergedText,
  }) => fileDatabase.transaction(() async {
    final stamps = await OcptRowStampService.seed(database: fileDatabase, deviceId: await deviceId());

    await screenplayService.reconcileScreenplayText(
      database: fileDatabase,
      screenplayId: screenplayId,
      fountainText: mergedText,
      snapshotReason: OcptSnapshotReason.merge,
      stamps: stamps,
    );

    await stamps.flush(fileDatabase);
  });

  /// The nearest common ancestor text for screenplay [screenplayId]'s merge, or `null` when none
  /// can be found at all.
  ///
  /// **Heuristic:** the most recently created live (non-pruned) `screenplay_snapshots` row for
  /// [screenplayId] currently visible in [database]. This works because every whole-text overwrite
  /// of a screenplay — an ordinary save, a restore, or a previous merge — snapshots the text as it
  /// stood *immediately before* that overwrite (`OcptScreenplayService`'s own snapshot policy), and
  /// because `screenplay_snapshots` is an ordinary synchronised table: the row a replica's own last
  /// save inserted, and the row the *other* replica's last save inserted, both eventually exist on
  /// both sides. For the single-generation divergence this milestone's tests cover — each replica
  /// making exactly one offline edit from a shared, unedited starting text — both of those rows
  /// hold the very same content, so whichever one happens to be newest by `createdAt` is already
  /// the right answer.
  ///
  /// **Known limitation, left for later work:** when either replica has made *several* successive
  /// offline saves before syncing, its own newest snapshot only predates its own *last* save, not
  /// necessarily the point the two replicas last actually agreed — picking the newest available
  /// snapshot in that case can diff against a base that already includes one side's own earlier,
  /// unrelated edits. Nothing here detects that case; it simply merges against the newest text it
  /// can find, which is why this heuristic is documented rather than assumed self-evidently correct.
  ///
  /// Returns `null` when [screenplayId] has no live snapshot row at all — pruning
  /// (`OcptScreenplayService.maxSnapshotsPerScreenplay`) removed every candidate, or the screenplay
  /// was never saved through `saveScreenplayText`/a merge in the first place — which
  /// [mergeIncomingFountainText] surfaces as a full-text conflict rather than merging against a
  /// guess.
  Future<String?> _nearestCommonBaseText({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final snapshot =
        await (database.select(database.ocptScreenplaySnapshotsTable)
              ..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
              ..limit(1))
            .getSingleOrNull();

    return snapshot?.fountainText;
  }
}
