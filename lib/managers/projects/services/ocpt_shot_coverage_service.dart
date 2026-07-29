// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:uuid/uuid.dart';

/// Adds, removes and clears a shot's scenario coverage ranges, and keeps them honest against the
/// screenplay's actual text.
///
/// **Digest.** `coveredTextDigest` columns store [digestOf] a range's exact covered substring: the
/// SHA-256 (hex) of that substring's UTF-8 bytes, computed when the range is recorded or
/// confirmed.
///
/// **A range may span several blocks.** The interaction this backs closes a range wherever the
/// second click lands, so a range can start in an action paragraph and end inside the dialogue
/// below it; nothing here constrains it beyond being non-empty and starting inside its scene. A
/// range is always confined to a single scene all the same, since that is what its offsets are
/// relative to.
///
/// **Staleness.** [refreshStaleness] must run right after `OcptSceneIndexService.reconcile` has
/// refreshed the scenes' `charStart`/`charEnd` for the save that just happened, in the same
/// transaction/save pass — never on the editor's 150 ms parse debounce, so a shot is never flagged
/// mid-keystroke. It re-reads every range's substring from the freshly saved text and compares
/// digests; a mismatch, or a range that no longer fits inside its scene at all (clamped back
/// inside it and counted as changed regardless of what its new substring's digest turns out to
/// be), sets `needsCheck` and an [OcptShotCheckReason] on the owning shot. [markAsChecked] is the
/// only way back to quiet: it clears that flag and re-stamps every one of the shot's ranges'
/// digests to the current text, so nothing fires again until a real further change.
class OcptShotCoverageService {
  /// Class constructor
  const OcptShotCoverageService();

  /// Adds a coverage range covering the scene-relative `[startOffset, endOffset)` of scene
  /// [sceneId] to shot [shotId], with its digest computed from [coveredText] (the exact substring
  /// the range currently covers), and returns the freshly generated id of the new range.
  ///
  Future<String> addRange({
    required OcptProjectDatabase database,
    required String shotId,
    required String sceneId,
    required int startOffset,
    required int endOffset,
    required String coveredText,
  }) async {
    if (startOffset < 0 || endOffset <= startOffset) {
      throw ArgumentError(
        "A coverage range must be non-empty and start at or after 0 "
        "(startOffset: $startOffset, endOffset: $endOffset)",
      );
    }
    final id = const Uuid().v4();
    await database
        .into(database.ocptShotCoveragesTable)
        .insert(
          OcptShotCoveragesTableCompanion.insert(
            id: id,
            shotId: shotId,
            sceneId: sceneId,
            startOffset: startOffset,
            endOffset: endOffset,
            coveredTextDigest: digestOf(coveredText),
          ),
        );

    return id;
  }

  /// Removes the single coverage range [rangeId].
  Future<void> removeRange({required OcptProjectDatabase database, required String rangeId}) =>
      (database.delete(
        database.ocptShotCoveragesTable,
      )..where((table) => table.id.equals(rangeId))).go();

  /// Removes every coverage range of shot [shotId]: the inspector's `Clear all` action.
  Future<void> clearRangesOfShot({
    required OcptProjectDatabase database,
    required String shotId,
  }) => (database.delete(
    database.ocptShotCoveragesTable,
  )..where((table) => table.shotId.equals(shotId))).go();

  /// Re-checks every coverage range of screenplay [screenplayId] against [currentFountainText] (the
  /// text just saved, after `OcptSceneIndexService.reconcile` has refreshed the scenes'
  /// `charStart`/`charEnd` from it), flagging the owning shot of any range that disagrees.
  ///
  /// A range whose scene no longer contains it at all (its stored offsets fall outside
  /// `[0, scene length)`) is first clamped back inside the scene's current bounds and persisted as
  /// such, and is always counted as changed regardless of what its clamped substring's digest turns
  /// out to be: the fact that it needed clamping is itself the sign something moved. A shot with
  /// more than one disagreeing range is flagged once, preferring
  /// [OcptShotCheckReason.coverageOutOfBounds] over [OcptShotCheckReason.coveredTextChanged] when
  /// both occur among its ranges.
  ///
  /// A flag a shot is *already* carrying is never weakened or cleared by this pass: [markAsChecked]
  /// is the only way back to quiet. That matters because clamping is self-erasing — once a range
  /// has been pulled back inside its scene it fits again, so a later save would only ever see the
  /// digest mismatch, and without this rule would quietly downgrade a still-unaddressed
  /// [OcptShotCheckReason.coverageOutOfBounds] to [OcptShotCheckReason.coveredTextChanged].
  Future<void> refreshStaleness({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String currentFountainText,
  }) async {
    final shotRows =
        await (database.select(
          database.ocptShotsTable,
        )..where((table) => table.screenplayId.equals(screenplayId))).get();
    final shotIds = shotRows.map((row) => row.id).toList(growable: false);
    if (shotIds.isEmpty) {
      return;
    }

    final sceneRows =
        await (database.select(
          database.ocptScenesTable,
        )..where((table) => table.screenplayId.equals(screenplayId))).get();
    final sceneById = {for (final scene in sceneRows) scene.id: scene};

    final coverageRows = await (database.select(
      database.ocptShotCoveragesTable,
    )..where((table) => table.shotId.isIn(shotIds))).get();

    // Seeded with what each shot is already flagged for, so this pass can only ever strengthen a
    // pending reason, never weaken one the user has not addressed yet.
    final reasonByShotId = {
      for (final row in shotRows)
        if (row.needsCheck && row.checkReason != null) row.id: row.checkReason!,
    };

    await database.transaction(() async {
      for (final range in coverageRows) {
        final scene = sceneById[range.sceneId];
        if (scene == null) {
          // The scene itself is gone: `OcptShotListService.detachShotsFromDeletedScenes` already
          // deletes a shot's coverage ranges when its scene is removed, so this shouldn't normally
          // happen, but skipping defensively is cheaper than crashing a save over a stale row.
          continue;
        }

        final sceneLength = scene.charEnd - scene.charStart;
        var start = range.startOffset;
        var end = range.endOffset;
        var outOfBounds = false;
        if (start < 0) {
          start = 0;
          outOfBounds = true;
        }
        if (end > sceneLength) {
          end = sceneLength;
          outOfBounds = true;
        }
        if (start > end) {
          start = end;
          outOfBounds = true;
        }

        if (outOfBounds) {
          await (database.update(
            database.ocptShotCoveragesTable,
          )..where((table) => table.id.equals(range.id))).write(
            OcptShotCoveragesTableCompanion(startOffset: Value(start), endOffset: Value(end)),
          );
          _upgradeReason(reasonByShotId, range.shotId, OcptShotCheckReason.coverageOutOfBounds);
          continue;
        }

        final absoluteStart = scene.charStart + start;
        final absoluteEnd = scene.charStart + end;
        final currentSubstring = currentFountainText.substring(absoluteStart, absoluteEnd);
        if (digestOf(currentSubstring) != range.coveredTextDigest) {
          _upgradeReason(reasonByShotId, range.shotId, OcptShotCheckReason.coveredTextChanged);
        }
      }

      for (final entry in reasonByShotId.entries) {
        await (database.update(
          database.ocptShotsTable,
        )..where((table) => table.id.equals(entry.key))).write(
          OcptShotsTableCompanion(needsCheck: const Value(true), checkReason: Value(entry.value)),
        );
      }
    });
  }

  /// Clears `needsCheck`/`checkReason` on shot [shotId] and re-stamps every one of its coverage
  /// ranges' digests to [currentFountainText], so the shot goes quiet until the next real change.
  Future<void> markAsChecked({
    required OcptProjectDatabase database,
    required String shotId,
    required String currentFountainText,
  }) async {
    await database.transaction(() async {
      final ranges = await (database.select(
        database.ocptShotCoveragesTable,
      )..where((table) => table.shotId.equals(shotId))).get();

      final sceneCache = <String, OcptSceneRow>{};
      for (final range in ranges) {
        final scene = sceneCache[range.sceneId] ??= await (database.select(
          database.ocptScenesTable,
        )..where((table) => table.id.equals(range.sceneId))).getSingle();

        final absoluteStart = scene.charStart + range.startOffset;
        final absoluteEnd = scene.charStart + range.endOffset;
        final substring = currentFountainText.substring(absoluteStart, absoluteEnd);

        await (database.update(
          database.ocptShotCoveragesTable,
        )..where((table) => table.id.equals(range.id))).write(
          OcptShotCoveragesTableCompanion(coveredTextDigest: Value(digestOf(substring))),
        );
      }

      await (database.update(
        database.ocptShotsTable,
      )..where((table) => table.id.equals(shotId))).write(
        const OcptShotsTableCompanion(needsCheck: Value(false), checkReason: Value(null)),
      );
    });
  }

  /// The ids of every shot (other than [excludingShotId], when given) that has a coverage range of
  /// scene [sceneId] overlapping the scene-relative `[startOffset, endOffset)` range — the
  /// inspector's "also covered by" set for a block or sub-range of one.
  Future<List<String>> shotIdsCoveringRange({
    required OcptProjectDatabase database,
    required String sceneId,
    required int startOffset,
    required int endOffset,
    String? excludingShotId,
  }) async {
    final rows = await (database.select(
      database.ocptShotCoveragesTable,
    )..where((table) => table.sceneId.equals(sceneId))).get();

    final overlappingShotIds = <String>{};
    for (final row in rows) {
      if (row.shotId == excludingShotId) {
        continue;
      }
      final overlaps = row.startOffset < endOffset && row.endOffset > startOffset;
      if (overlaps) {
        overlappingShotIds.add(row.shotId);
      }
    }

    return overlappingShotIds.toList(growable: false);
  }

  /// Sets `reasonByShotId[shotId]` to [reason], unless it already holds
  /// [OcptShotCheckReason.coverageOutOfBounds]: that reason always wins over
  /// [OcptShotCheckReason.coveredTextChanged] when a shot has ranges disagreeing for both causes.
  static void _upgradeReason(
    Map<String, OcptShotCheckReason> reasonByShotId,
    String shotId,
    OcptShotCheckReason reason,
  ) {
    if (reasonByShotId[shotId] == OcptShotCheckReason.coverageOutOfBounds) {
      return;
    }
    reasonByShotId[shotId] = reason;
  }

  /// The hex SHA-256 digest of [text]'s UTF-8 bytes.
  static String digestOf(String text) => sha256.convert(utf8.encode(text)).toString();

  /// Whether [range] disagrees with [sceneText] (its owning scene's current, already-sliced
  /// text): either it no longer fits inside `[0, sceneText.length)` at all, or the substring it
  /// covers no longer digests to [OcptShotCoverageRange.coveredTextDigest].
  ///
  /// This is the same rule [refreshStaleness] applies to every range of a screenplay at save
  /// time, expressed instead over a single, already-loaded scene text with no database at all: a
  /// caller that only has the scene's text in hand (the shot inspector, working off the layout it
  /// already loaded) can use this to decide staleness range by range, rather than reading back the
  /// coarser, shot-wide [OcptShotCoverageRange.isStale] that mirrors the owning shot's whole
  /// `needsCheck` flag (see `OcptShotListService.loadShotList`'s doc comment for why that one is
  /// deliberately coarse).
  static bool isRangeStale({required OcptShotCoverageRange range, required String sceneText}) {
    if (range.startOffset < 0 || range.endOffset > sceneText.length) {
      return true;
    }
    final coveredSubstring = sceneText.substring(range.startOffset, range.endOffset);
    return digestOf(coveredSubstring) != range.coveredTextDigest;
  }
}
