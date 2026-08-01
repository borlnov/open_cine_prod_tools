// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:uuid/uuid.dart';

/// A parsed scene heading paired with the character range of the scene it opens.
///
/// This is an implementation detail of [OcptSceneIndexService.reconcile]: it's the unit the
/// matching algorithm works on, built once per call from a [FountainDocument] before any matching
/// happens.
class _ParsedScene {
  /// The parsed scene heading.
  final FountainSceneHeading heading;

  /// The character offset, in the screenplay's Fountain text, at which the scene starts.
  final int charStart;

  /// The character offset, in the screenplay's Fountain text, one past the last character of the
  /// scene.
  final int charEnd;

  /// Class constructor
  const _ParsedScene({required this.heading, required this.charStart, required this.charEnd});
}

/// Reconciles the `scenes` table of a screenplay against a freshly parsed [FountainDocument].
///
/// {@macro open_cine_prod_tools.OcptSceneIndexService.stability}
///
/// This is the single place responsible for deciding which parsed scene heading corresponds to
/// which existing `scenes` row, so a scene's id stays stable across edits: other features (e.g.
/// scene notes, shot lists) can hold onto that id.
///
/// This service knows nothing about what else references a scene by id: **dependencies never
/// reference their dependents**, so it cannot call into, say, the shot list service directly.
/// [reconcile]'s optional `onScenesDeleted` callback is the one place it offers a dependent a hook
/// at the single moment the information a dependent might need (a scene row about to disappear)
/// still exists, without this service ever importing or knowing the shape of what that dependent
/// does with it.
class OcptSceneIndexService {
  /// Class constructor
  const OcptSceneIndexService();

  /// Reconciles the `scenes` table of [screenplayId] in [database] against the scene headings of
  /// [document].
  ///
  /// The matching happens in three passes, each only considering rows/headings that the previous
  /// pass left unmatched:
  ///
  /// 1. By explicit [FountainSceneHeading.sceneNumber]: an existing row and a parsed heading that
  ///    carry the same non-null scene number are matched, even if their heading text differs.
  /// 2. By exact heading text: an existing row and a parsed heading with the same
  ///    [FountainSceneHeading.headingText] are matched.
  /// 3. By relative order: whatever is left of both sides is paired up in the order it appears
  ///    (i-th still-unmatched existing row with the i-th still-unmatched parsed heading), so a
  ///    plain rename (no number involved) is treated as an edit of the scene at that position
  ///    rather than a delete followed by an insert.
  ///
  /// Matched rows keep their id and get their `position`/`heading`/`sceneNumber`/`charStart`/
  /// `charEnd` refreshed. Parsed headings left unmatched after all three passes become new rows,
  /// with a freshly generated UUID. Existing rows left unmatched after all three passes are
  /// deleted: their scene is gone from the screenplay.
  ///
  /// [onScenesDeleted], when given, is awaited inside this method's own transaction, immediately
  /// before those rows are deleted, and only when there is at least one to delete: it is the single
  /// hook a dependent (e.g. `OcptShotListService`, detaching a scene's shots) gets at the one moment
  /// the about-to-vanish rows' data (their heading, in particular) is still available to copy
  /// elsewhere. See the class doc comment for why this is a callback rather than a direct call.
  Future<void> reconcile({
    required OcptProjectDatabase database,
    required String screenplayId,
    required FountainDocument document,
    Future<void> Function(List<OcptSceneRow> scenesAboutToBeDeleted)? onScenesDeleted,
  }) async {
    final existingRows =
        await (database.select(database.ocptScenesTable)
              ..where((row) => row.screenplayId.equals(screenplayId))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();

    final parsedScenes = _buildParsedScenes(document);
    final matches = _matchScenes(existingRows: existingRows, parsedScenes: parsedScenes);

    await database.transaction(() async {
      if (matches.rowsToDelete.isNotEmpty && onScenesDeleted != null) {
        await onScenesDeleted(matches.rowsToDelete);
      }

      for (final row in matches.rowsToDelete) {
        await (database.delete(
          database.ocptScenesTable,
        )..where((table) => table.id.equals(row.id))).go();
      }

      for (var position = 0; position < parsedScenes.length; position++) {
        final parsedScene = parsedScenes[position];
        final matchedId = matches.idsByHeadingIndex[position];

        await database
            .into(database.ocptScenesTable)
            .insertOnConflictUpdate(
              OcptScenesTableCompanion.insert(
                id: matchedId ?? const Uuid().v4(),
                screenplayId: screenplayId,
                position: position,
                heading: parsedScene.heading.headingText,
                sceneNumber: Value(parsedScene.heading.sceneNumber),
                charStart: parsedScene.charStart,
                charEnd: parsedScene.charEnd,
              ),
            );
      }
    });
  }

  /// Builds the ordered list of [_ParsedScene] for [document], computing each scene's character
  /// range as spanning from its heading's start offset to the next scene heading's start offset
  /// (or the end of the document's source text for the last scene).
  static List<_ParsedScene> _buildParsedScenes(FountainDocument document) {
    final headings = document.scenes;

    return [
      for (var i = 0; i < headings.length; i++)
        _ParsedScene(
          heading: headings[i],
          charStart: headings[i].sourceRange.startOffset,
          charEnd: i + 1 < headings.length
              ? headings[i + 1].sourceRange.startOffset
              : document.sourceText.length,
        ),
    ];
  }

  /// Runs the three matching passes described in [reconcile] and returns the resulting plan.
  static _SceneMatchPlan _matchScenes({
    required List<OcptSceneRow> existingRows,
    required List<_ParsedScene> parsedScenes,
  }) {
    final unmatchedRows = List<OcptSceneRow>.of(existingRows);
    final idsByHeadingIndex = List<String?>.filled(parsedScenes.length, null);

    // Pass 1: match by explicit scene number.
    for (var i = 0; i < parsedScenes.length; i++) {
      final sceneNumber = parsedScenes[i].heading.sceneNumber;
      if (sceneNumber == null) {
        continue;
      }

      final matchIndex = unmatchedRows.indexWhere((row) => row.sceneNumber == sceneNumber);
      if (matchIndex != -1) {
        idsByHeadingIndex[i] = unmatchedRows.removeAt(matchIndex).id;
      }
    }

    // Pass 2: match by exact heading text.
    for (var i = 0; i < parsedScenes.length; i++) {
      if (idsByHeadingIndex[i] != null) {
        continue;
      }

      final headingText = parsedScenes[i].heading.headingText;
      final matchIndex = unmatchedRows.indexWhere((row) => row.heading == headingText);
      if (matchIndex != -1) {
        idsByHeadingIndex[i] = unmatchedRows.removeAt(matchIndex).id;
      }
    }

    // Pass 3: match whatever is left, in relative order.
    final unmatchedHeadingIndexes = [
      for (var i = 0; i < parsedScenes.length; i++)
        if (idsByHeadingIndex[i] == null) i,
    ];
    final pairCount = unmatchedHeadingIndexes.length < unmatchedRows.length
        ? unmatchedHeadingIndexes.length
        : unmatchedRows.length;
    for (var k = 0; k < pairCount; k++) {
      idsByHeadingIndex[unmatchedHeadingIndexes[k]] = unmatchedRows[k].id;
    }

    final rowsToDelete = unmatchedRows.skip(pairCount).toList(growable: false);

    return _SceneMatchPlan(idsByHeadingIndex: idsByHeadingIndex, rowsToDelete: rowsToDelete);
  }
}

/// The outcome of [OcptSceneIndexService._matchScenes]: which existing row (if any) each parsed
/// heading was matched to, and which existing rows are left over and must be deleted.
class _SceneMatchPlan {
  /// The id of the existing row matched to the parsed heading at the same index, or null if that
  /// heading didn't match any existing row and needs a freshly generated id.
  final List<String?> idsByHeadingIndex;

  /// The existing rows that weren't matched to any parsed heading: their scene is gone.
  final List<OcptSceneRow> rowsToDelete;

  /// Class constructor
  const _SceneMatchPlan({required this.idsByHeadingIndex, required this.rowsToDelete});
}
