// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:uuid/uuid.dart';

/// Thrown inside [OcptBreakdownService.createElementAndTag]'s transaction to unwind the element
/// it just minted when the tag half of that call is refused, and caught right outside the
/// transaction so the method still returns null rather than letting the exception escape.
class _OcptBreakdownTagRefused implements Exception {
  /// Class constructor
  const _OcptBreakdownTagRefused();
}

/// Anchors a passage of the screenplay, tagged during the breakdown pass, to the catalogue row it
/// calls for — an element, a role or a set — and tracks how far the pass has got, scene by scene.
///
/// Takes [OcptElementsService] and [OcptLocationsService] through its constructor, exactly as
/// `OcptScreenplayService` takes its own collaborators, so a caller cannot mint an element or a
/// scene ↔ catalogue link by a second, divergent route: [createTag], [createElementAndTag] and
/// [createSetAndTag] all go through the same two services the resources mode itself uses.
///
/// **A tag removal never removes the link it once ensured.** [deleteTag] tombstones the tag alone:
/// the resources mode lets a user link an element to a scene, or a scene to a set, by hand with no
/// tag at all, so silently dropping the `scene_elements`/`scene_sets` row a tag once created would
/// destroy work the breakdown pass never did. Removing that link is a separate question, asked
/// wherever the caller means it — this service is not where it is answered.
///
/// **Reconciliation re-anchors silently, and only flags when it cannot.** [reconcileTags] runs on
/// the screenplay save path, right after the scene index has been rebuilt: an edit that shifted a
/// tagged passage within its own scene is followed there automatically when the shifted words are
/// found exactly once, and only left for the user to sort out (`needsCheck`) when they cannot be
/// found unambiguously — see its own doc comment for why this must run there rather than on the
/// editor's parse debounce. [clearTagNeedsCheck] is the user's own answer to a flag reconciliation
/// left behind: it clears `needsCheck` alone, never touching the offsets — see its own doc comment
/// for why.
///
/// {@macro open_cine_prod_tools.tombstones}
class OcptBreakdownService {
  /// The service used to mint the element a category chip creates, exactly as the resources mode's
  /// own element sheet would.
  final OcptElementsService _elementsService;

  /// The service used to ensure the `scene_sets` link a set tag implies.
  final OcptLocationsService _locationsService;

  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter]. [reconcileTags] and [tombstoneBreakdownOfScenes] never call it: both
  /// write inside a caller's own transaction, and take that caller's own [OcptRowStampService]
  /// instead.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptBreakdownService({
    required OcptElementsService elementsService,
    required OcptLocationsService locationsService,
    required this.deviceId,
  }) : _elementsService = elementsService,
       _locationsService = locationsService;

  /// Loads every live breakdown tag of [database], restricted to [screenplayId]'s scenes when
  /// given, ordered by the owning scene's own `position` and then by
  /// [OcptBreakdownTagRow.startOffset] — the order the tagged passages are read in.
  ///
  /// A tag whose scene is tombstoned is left out, for the reason `OcptElementsService.loadElements`
  /// gives about a link onto a vanished scene: the scene may well come back under the same id on a
  /// later reconciliation, and the tag comes back with it.
  Future<List<OcptBreakdownTagRow>> loadTags({
    required OcptProjectDatabase database,
    String? screenplayId,
  }) async {
    final positionBySceneId = await _liveScenePositions(
      database: database,
      screenplayId: screenplayId,
    );
    if (positionBySceneId.isEmpty) {
      return const [];
    }

    final rows =
        await (database.select(database.ocptBreakdownTagsTable)..where(
              (table) => table.sceneId.isIn(positionBySceneId.keys) & table.isDeleted.not(),
            ))
            .get();

    rows.sort((a, b) {
      final positionCompare = positionBySceneId[a.sceneId]!.compareTo(positionBySceneId[b.sceneId]!);
      return positionCompare != 0 ? positionCompare : a.startOffset.compareTo(b.startOffset);
    });

    return rows;
  }

  /// Loads every live `scene_breakdowns` row of [database], restricted to [screenplayId]'s scenes
  /// when given, ordered by the owning scene's own `position`.
  ///
  /// A scene with no row simply has none: the caller reads a missing row as
  /// [OcptBreakdownSceneStatus.toDo] rather than this method synthesizing one, exactly as a scene's
  /// tagged-element count cannot stand in for its breakdown status (§3.5 of the plan this ships
  /// under). A row whose scene is tombstoned is left out, for the same reason [loadTags] leaves out
  /// a tag whose scene is gone.
  Future<List<OcptSceneBreakdownRow>> loadSceneBreakdowns({
    required OcptProjectDatabase database,
    String? screenplayId,
  }) async {
    final positionBySceneId = await _liveScenePositions(
      database: database,
      screenplayId: screenplayId,
    );
    if (positionBySceneId.isEmpty) {
      return const [];
    }

    final rows =
        await (database.select(database.ocptSceneBreakdownsTable)..where(
              (table) => table.sceneId.isIn(positionBySceneId.keys) & table.isDeleted.not(),
            ))
            .get();

    rows.sort((a, b) => positionBySceneId[a.sceneId]!.compareTo(positionBySceneId[b.sceneId]!));

    return rows;
  }

  /// Loads every live scene of [screenplayId] in [database], in `position` order, each joined with
  /// its live `scene_breakdowns` row through [loadSceneBreakdowns] — never re-queried here — and
  /// carrying an empty [OcptBreakdownScene.tags] list.
  ///
  /// The tags are left for `OcptBreakdownSnapshot.build` to attach: this method mirrors
  /// `OcptLocationsService.loadScenes` in reading only the scenes, and [loadTags] already exists to
  /// read the other half — reading it twice, once per caller, would be the two ways of building a
  /// snapshot silently drifting apart.
  ///
  /// [episodeNumber] is [screenplayId]'s own episode number, or null when the project holds a
  /// single episode; it is only carried onto each [OcptBreakdownScene] for `displayNumber` to read,
  /// never resolved here — this service has no reason to depend on `OcptScreenplayService`, which
  /// already depends on it (dependencies never reference their dependents).
  Future<List<OcptBreakdownScene>> loadScenes({
    required OcptProjectDatabase database,
    required String screenplayId,
    required int? episodeNumber,
  }) async {
    final sceneRows =
        await (database.select(database.ocptScenesTable)
              ..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();

    final breakdownRowsBySceneId = {
      for (final row in await loadSceneBreakdowns(database: database, screenplayId: screenplayId))
        row.sceneId: row,
    };

    return [
      for (final sceneRow in sceneRows)
        OcptBreakdownScene.fromRows(
          sceneRow: sceneRow,
          episodeNumber: episodeNumber,
          breakdownRow: breakdownRowsBySceneId[sceneRow.id],
        ),
    ];
  }

  /// Tags the scene-relative `[startOffset, endOffset)` passage [taggedText] of scene [sceneId],
  /// pointing it at [targetId] — read as an `elements`, `roles` or `sets` id according to
  /// [targetKind] — and returns the new tag's id.
  ///
  /// In one transaction: refuses (returns null, logged) when the range overlaps a live tag of the
  /// same scene — two ranges overlap when `a.start < b.end && b.start < a.end`, so touching end to
  /// end is not an overlap (§3.9 of the plan this ships under) — otherwise writes [targetId] into
  /// whichever of `elementId`/`roleId`/`setId` [targetKind] names, leaving the other two null, and
  /// **ensures the link the tag implies**: `OcptElementsService.addSceneElement` for
  /// [OcptBreakdownTargetKind.element], `OcptLocationsService.assignSceneToSet` for
  /// [OcptBreakdownTargetKind.set]. A [OcptBreakdownTargetKind.role] tag creates no link row: there
  /// is no `scene_roles` table, and the tag itself is that link.
  ///
  /// Throws [ArgumentError] for a malformed range (`startOffset < 0` or `endOffset <= startOffset`),
  /// exactly as `OcptShotCoverageService.addRange` does: a malformed range is a caller bug, while an
  /// overlap is a refusal a real user action can reach, and the two must not be reported the same
  /// way.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createTag({
    required OcptProjectDatabase database,
    required String sceneId,
    required int startOffset,
    required int endOffset,
    required String taggedText,
    required OcptBreakdownTargetKind targetKind,
    required String targetId,
  }) async {
    if (database.refusesUserWrite("createTag")) {
      return null;
    }

    if (startOffset < 0 || endOffset <= startOffset) {
      throw ArgumentError(
        "A breakdown tag must be non-empty and start at or after 0 "
        "(startOffset: $startOffset, endOffset: $endOffset)",
      );
    }

    return database.transaction(() async {
      if (await _overlapsLiveTag(
        database: database,
        sceneId: sceneId,
        startOffset: startOffset,
        endOffset: endOffset,
      )) {
        appLogger().w(
          "createTag refused: range [$startOffset, $endOffset) of scene $sceneId overlaps a "
          "live tag already there",
        );
        return null;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      final tagId = await _insertTagAndEnsureLink(
        database: database,
        sceneId: sceneId,
        startOffset: startOffset,
        endOffset: endOffset,
        taggedText: taggedText,
        targetKind: targetKind,
        targetId: targetId,
        stamps: stamps,
      );
      await stamps.flush(database);

      return tagId;
    });
  }

  /// Tombstones tag [tagId] — the range stops being highlighted and its target stops being
  /// selectable through it.
  ///
  /// **Never removes the `scene_elements`/`scene_sets` row it once ensured** — see this class's own
  /// doc comment for why. The inspector offers removing that link as a separate action.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteTag({required OcptProjectDatabase database, required String tagId}) async {
    if (database.refusesUserWrite("deleteTag")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptBreakdownTagsTable,
      )..where((table) => table.id.equals(tagId))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBreakdownTagsTable,
        rowId: tagId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Clears `needsCheck` on tag [tagId] alone, leaving its `startOffset`/`endOffset` exactly where
  /// they are.
  ///
  /// The honest answer to the common flagged case: [reconcileTags] could not find the tagged text
  /// exactly once in its own scene (it now occurs twice, or nowhere), yet the passage the tag
  /// already points at is still the right one — the user looked at it and confirmed it, rather
  /// than the tag having actually moved. Clearing the flag is therefore deliberately **not** a
  /// re-anchor: only [reconcileTags], on the next save, ever moves a tag's offsets.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> clearTagNeedsCheck({
    required OcptProjectDatabase database,
    required String tagId,
  }) async {
    if (database.refusesUserWrite("clearTagNeedsCheck")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptBreakdownTagsTable,
      )..where((table) => table.id.equals(tagId))).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBreakdownTagsTable,
        rowId: tagId,
        current: current,
        next: current.copyWith(needsCheck: false),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Creates a new [category]/[sourceKind] element named [name] and tags the scene-relative
  /// `[startOffset, endOffset)` passage [taggedText] of scene [sceneId] with it, in one
  /// transaction — the one write the popover's category chips perform (§2.1/§3.8 of the plan this
  /// ships under).
  ///
  /// The element is minted through `OcptElementsService.createElement` rather than by reaching into
  /// `elements` directly, so the resources mode and this one mint an element exactly the same way,
  /// generated code included, and then tagged through [createTag] itself, so the two ways of
  /// creating a tag never drift apart. New elements get `OcptElementStatus.toFind`, the column's own
  /// default.
  ///
  /// Returns null, and rolls **both** writes back, when either half refuses: a preview database (the
  /// element is never even minted, since the preview guard trips before either write), or a range
  /// that overlaps a live tag of the scene — an element minted for a tag that was refused would be
  /// an orphan nobody asked for.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<({String elementId, String tagId})?> createElementAndTag({
    required OcptProjectDatabase database,
    required String sceneId,
    required int startOffset,
    required int endOffset,
    required String taggedText,
    required String name,
    required OcptElementCategory category,
    required OcptElementSourceKind sourceKind,
  }) async {
    if (database.refusesUserWrite("createElementAndTag")) {
      return null;
    }

    try {
      return await database.transaction(() async {
        final elementId = await _elementsService.createElement(
          database: database,
          name: name,
          category: category,
          sourceKind: sourceKind,
        );
        if (elementId == null) {
          // The preview guard tripped inside createElement: nothing was written, so there is
          // nothing to unwind.
          return null;
        }

        final tagId = await createTag(
          database: database,
          sceneId: sceneId,
          startOffset: startOffset,
          endOffset: endOffset,
          taggedText: taggedText,
          targetKind: OcptBreakdownTargetKind.element,
          targetId: elementId,
        );
        if (tagId == null) {
          // The range overlaps a live tag: the element just minted must not survive without the
          // tag that was the whole point of creating it, so the transaction it was written in is
          // unwound rather than left half-done.
          throw const _OcptBreakdownTagRefused();
        }

        return (elementId: elementId, tagId: tagId);
      });
    } on _OcptBreakdownTagRefused {
      return null;
    }
  }

  /// Creates a new set named [name] and tags the scene-relative `[startOffset, endOffset)` passage
  /// [taggedText] of scene [sceneId] with it, in one transaction — the sibling of
  /// [createElementAndTag], for the one catalogue row the breakdown pass may also mint.
  ///
  /// [locationId] names the place holding it. Passing null creates **a location of its own**, named
  /// [name] too: a set has no existence outside a location, and a user reading the script and
  /// meeting a place the project has never heard of should not have to leave for the resources mode
  /// to invent one first. The two are renamed apart there afterwards, `Cuisine` in `Cuisine` being
  /// the honest first guess and not a claim.
  ///
  /// Both writes go through `OcptLocationsService`, exactly as [createElementAndTag] mints its
  /// element through `OcptElementsService`, and the tag itself through [createTag] — so the
  /// `scene_sets` link the tag implies is ensured by the one code path that ensures it everywhere.
  ///
  /// Returns null, and rolls **every** write back, when any of them refuses: a preview database, or
  /// a range overlapping a live tag of the scene.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<({String setId, String tagId})?> createSetAndTag({
    required OcptProjectDatabase database,
    required String sceneId,
    required int startOffset,
    required int endOffset,
    required String taggedText,
    required String name,
    String? locationId,
  }) async {
    if (database.refusesUserWrite("createSetAndTag")) {
      return null;
    }

    try {
      return await database.transaction(() async {
        final holdingLocationId =
            locationId ?? await _locationsService.createLocation(database: database, name: name);
        if (holdingLocationId == null) {
          // The preview guard tripped inside createLocation: nothing was written yet.
          return null;
        }

        final setId = await _locationsService.createSet(
          database: database,
          locationId: holdingLocationId,
          name: name,
        );
        if (setId == null) {
          return null;
        }

        final tagId = await createTag(
          database: database,
          sceneId: sceneId,
          startOffset: startOffset,
          endOffset: endOffset,
          taggedText: taggedText,
          targetKind: OcptBreakdownTargetKind.set,
          targetId: setId,
        );
        if (tagId == null) {
          // The range overlaps a live tag: the set — and the location minted to hold it, if one
          // was — must not survive the tag that was the whole point of creating them.
          throw const _OcptBreakdownTagRefused();
        }

        return (setId: setId, tagId: tagId);
      });
    } on _OcptBreakdownTagRefused {
      return null;
    }
  }

  /// Creates, or updates, the `scene_breakdowns` row of scene [sceneId], writing whichever of
  /// [status]/[notes] are passed as something other than [Value.absent].
  ///
  /// The row is created on the first write for a scene, never eagerly for every scene the
  /// screenplay holds. A row tombstoned earlier is **revived** rather than duplicated, exactly as
  /// `OcptElementsService.addSceneElement` revives a dropped link: a tombstone is how this app
  /// deletes, so the scene may well already have a row saying it is gone. If, somehow, more than
  /// one live row exists for the scene, only the first is written and the rest are left alone with
  /// a warning logged, rather than crashing the write.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateSceneBreakdown({
    required OcptProjectDatabase database,
    required String sceneId,
    Value<OcptBreakdownSceneStatus> status = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSceneBreakdown")) {
      return;
    }

    await database.transaction(() async {
      final existingRows =
          await (database.select(
            database.ocptSceneBreakdownsTable,
          )..where((table) => table.sceneId.equals(sceneId))).get();

      OcptSceneBreakdownRow? liveRow;
      OcptSceneBreakdownRow? droppedRow;
      var extraLiveRowCount = 0;
      for (final row in existingRows) {
        if (row.isDeleted) {
          droppedRow ??= row;
          continue;
        }
        if (liveRow == null) {
          liveRow = row;
        } else {
          extraLiveRowCount++;
        }
      }

      if (extraLiveRowCount > 0) {
        appLogger().w(
          "Scene $sceneId has ${extraLiveRowCount + 1} live scene_breakdowns rows; writing only "
          "the first and leaving the rest alone",
        );
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      if (liveRow != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptSceneBreakdownsTable,
          rowId: liveRow.id,
          current: liveRow,
          next: liveRow.copyWithCompanion(OcptSceneBreakdownsTableCompanion(status: status, notes: notes)),
          stamps: stamps,
        );
        await stamps.flush(database);
        return;
      }

      if (droppedRow != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptSceneBreakdownsTable,
          rowId: droppedRow.id,
          current: droppedRow,
          next: droppedRow.copyWithCompanion(
            OcptSceneBreakdownsTableCompanion(isDeleted: const Value(false), status: status, notes: notes),
          ),
          stamps: stamps,
        );
        await stamps.flush(database);
        return;
      }

      final id = const Uuid().v4();
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSceneBreakdownsTable,
        rowId: id,
        current: null,
        next: OcptSceneBreakdownRow(
          id: id,
          sceneId: sceneId,
          status: status.present ? status.value : OcptBreakdownSceneStatus.toDo,
          notes: notes.present ? notes.value : '',
          isDeleted: false,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Re-anchors, or flags, every live breakdown tag of screenplay [screenplayId] against
  /// [currentFountainText], the text just saved.
  ///
  /// Must run right after `OcptSceneIndexService.reconcile` has refreshed the scenes'
  /// `charStart`/`charEnd` for the save that just happened, in the same save pass — never on the
  /// editor's parse debounce, for the reason `OcptShotCoverageService.refreshStaleness`'s own doc
  /// comment gives: a director does not want a tag flickering `needsCheck` mid-keystroke.
  ///
  /// For each live tag:
  ///
  /// 1. slice the scene's current text at `[startOffset, endOffset)`. Equal to
  ///    [OcptBreakdownTagRow.taggedText] → nothing to do, clearing `needsCheck` if it was set;
  /// 2. otherwise search the scene's current text for [OcptBreakdownTagRow.taggedText]. **Exactly
  ///    one** occurrence → the tag is re-anchored to it silently and `needsCheck` is cleared — the
  ///    common case, an edit earlier in the same scene having shifted everything after it. A tag
  ///    shifted only by an edit in a **preceding scene** needs no re-anchoring at all, since its
  ///    offsets are scene-relative to begin with;
  /// 3. zero, or more than one, occurrence → `needsCheck` is set (if not already) and the offsets
  ///    are left alone;
  /// 4. a tag whose scene is gone (tombstoned, or no longer in the index) is tombstoned along with
  ///    it.
  ///
  /// The slice in step 1 is guarded against offsets that no longer fit inside the scene at all: such
  /// a tag is treated as though it did not match (skipping straight to step 2) rather than risking a
  /// `RangeError` that would crash the save.
  ///
  /// Writes nothing when nothing changed: this runs on every save.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reconcileTags({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String currentFountainText,
    required OcptRowStampService? stamps,
  }) async {
    if (database.refusesUserWrite("reconcileTags")) {
      return;
    }

    final sceneRows =
        await (database.select(
          database.ocptScenesTable,
        )..where((table) => table.screenplayId.equals(screenplayId))).get();
    if (sceneRows.isEmpty) {
      return;
    }
    final sceneById = {for (final scene in sceneRows) scene.id: scene};

    final tagRows =
        await (database.select(database.ocptBreakdownTagsTable)..where(
              (table) => table.sceneId.isIn(sceneById.keys) & table.isDeleted.not(),
            ))
            .get();
    if (tagRows.isEmpty) {
      return;
    }

    await database.transaction(() async {
      for (final tag in tagRows) {
        final scene = sceneById[tag.sceneId];
        if (scene == null || scene.isDeleted) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptBreakdownTagsTable,
            rowId: tag.id,
            current: tag,
            next: tag.copyWith(isDeleted: true),
            stamps: stamps,
          );
          continue;
        }

        final sceneText = currentFountainText.substring(scene.charStart, scene.charEnd);
        final fitsInBounds =
            tag.startOffset >= 0 &&
            tag.startOffset <= tag.endOffset &&
            tag.endOffset <= sceneText.length;

        if (fitsInBounds && sceneText.substring(tag.startOffset, tag.endOffset) == tag.taggedText) {
          if (tag.needsCheck) {
            await OcptRowStampService.writeAndStamp(
              database: database,
              table: database.ocptBreakdownTagsTable,
              rowId: tag.id,
              current: tag,
              next: tag.copyWith(needsCheck: false),
              stamps: stamps,
            );
          }
          continue;
        }

        final occurrences = _occurrencesOf(needle: tag.taggedText, haystack: sceneText);
        if (occurrences.length == 1) {
          final newStart = occurrences.single;
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptBreakdownTagsTable,
            rowId: tag.id,
            current: tag,
            next: tag.copyWith(
              startOffset: newStart,
              endOffset: newStart + tag.taggedText.length,
              needsCheck: false,
            ),
            stamps: stamps,
          );
          continue;
        }

        if (!tag.needsCheck) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptBreakdownTagsTable,
            rowId: tag.id,
            current: tag,
            next: tag.copyWith(needsCheck: true),
            stamps: stamps,
          );
        }
      }
    });
  }

  /// Tombstones every live `breakdown_tags` row and every live `scene_breakdowns` row of any of
  /// [sceneIds], and — through [_elementsService] and [_locationsService] — every live
  /// `scene_elements` and `scene_sets` row of those same scenes: `OcptScreenplayService.deleteEpisode`'s
  /// cascade, once `OcptSceneIndexService.tombstoneScenesOfScreenplay` has handed it the ids of the
  /// scenes going with the episode.
  ///
  /// **This is not [deleteTag]'s question.** [deleteTag] deliberately leaves the `scene_elements`/
  /// `scene_sets` link a tag once ensured, because the user may have made the same link by hand and
  /// removing a tag must not destroy work the breakdown pass never did. Here the scene those links
  /// point at is **itself** going away with the episode, for good — a different fact, and the one
  /// this method exists to act on rather than defer.
  ///
  /// **Unguarded**, exactly as `OcptElementsService.tombstoneRoleLinksOfRole` is: its only caller has
  /// already refused the write on a preview connection and is already inside the transaction
  /// removing the episode, so a second guard here would only be able to disagree with the first.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> tombstoneBreakdownOfScenes({
    required OcptProjectDatabase database,
    required List<String> sceneIds,
    required OcptRowStampService? stamps,
  }) async {
    if (sceneIds.isEmpty) {
      return;
    }

    final tagRows =
        await (database.select(database.ocptBreakdownTagsTable)..where(
              (table) => table.sceneId.isIn(sceneIds) & table.isDeleted.not(),
            ))
            .get();
    for (final row in tagRows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBreakdownTagsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }

    final sceneBreakdownRows =
        await (database.select(database.ocptSceneBreakdownsTable)..where(
              (table) => table.sceneId.isIn(sceneIds) & table.isDeleted.not(),
            ))
            .get();
    for (final row in sceneBreakdownRows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptSceneBreakdownsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }

    await _elementsService.tombstoneSceneElementsOfScenes(
      database: database,
      sceneIds: sceneIds,
      stamps: stamps,
    );
    await _locationsService.tombstoneSceneSetsOfScenes(
      database: database,
      sceneIds: sceneIds,
      stamps: stamps,
    );
  }

  /// Inserts the tag row itself and ensures the link it implies, without checking for an overlap:
  /// the caller ([createTag]) has already done that. Stamps the tag insert through [stamps] —
  /// [createTag]'s own instance — while the link ensured below is stamped by whichever of
  /// [_elementsService]/[_locationsService] writes it, through its own nested transaction.
  Future<String> _insertTagAndEnsureLink({
    required OcptProjectDatabase database,
    required String sceneId,
    required int startOffset,
    required int endOffset,
    required String taggedText,
    required OcptBreakdownTargetKind targetKind,
    required String targetId,
    required OcptRowStampService? stamps,
  }) async {
    final id = const Uuid().v4();

    await OcptRowStampService.writeAndStamp(
      database: database,
      table: database.ocptBreakdownTagsTable,
      rowId: id,
      current: null,
      next: OcptBreakdownTagRow(
        id: id,
        sceneId: sceneId,
        targetKind: targetKind,
        elementId: targetKind == OcptBreakdownTargetKind.element ? targetId : null,
        roleId: targetKind == OcptBreakdownTargetKind.role ? targetId : null,
        setId: targetKind == OcptBreakdownTargetKind.set ? targetId : null,
        startOffset: startOffset,
        endOffset: endOffset,
        taggedText: taggedText,
        needsCheck: false,
        isDeleted: false,
      ),
      stamps: stamps,
    );

    switch (targetKind) {
      case OcptBreakdownTargetKind.element:
        await _elementsService.addSceneElement(
          database: database,
          sceneId: sceneId,
          elementId: targetId,
        );
      case OcptBreakdownTargetKind.set:
        await _locationsService.assignSceneToSet(database: database, sceneId: sceneId, setId: targetId);
      case OcptBreakdownTargetKind.role:
      // There is no `scene_roles` table: the tag itself is the link.
    }

    return id;
  }

  /// Whether the scene-relative `[startOffset, endOffset)` range overlaps any live tag of scene
  /// [sceneId] already in [database]. Two ranges overlap when `a.start < b.end && b.start < a.end`;
  /// touching end to end is not an overlap.
  Future<bool> _overlapsLiveTag({
    required OcptProjectDatabase database,
    required String sceneId,
    required int startOffset,
    required int endOffset,
  }) async {
    final liveTags =
        await (database.select(database.ocptBreakdownTagsTable)..where(
              (table) => table.sceneId.equals(sceneId) & table.isDeleted.not(),
            ))
            .get();

    return liveTags.any((tag) => startOffset < tag.endOffset && tag.startOffset < endOffset);
  }

  /// The 0-based `position` of every live scene of [database], restricted to [screenplayId] when
  /// given, keyed by scene id.
  Future<Map<String, int>> _liveScenePositions({
    required OcptProjectDatabase database,
    String? screenplayId,
  }) async {
    final query = database.select(database.ocptScenesTable)
      ..where(
        (table) =>
            screenplayId == null
                ? table.isDeleted.not()
                : table.screenplayId.equals(screenplayId) & table.isDeleted.not(),
      );
    final rows = await query.get();

    return {for (final row in rows) row.id: row.position};
  }

  /// Every start offset in [haystack] at which [needle] occurs, allowing overlapping matches — the
  /// occurrence count [OcptBreakdownService.reconcileTags] re-anchors on when it is exactly one, and
  /// flags when it is zero or more than one.
  static List<int> _occurrencesOf({required String needle, required String haystack}) {
    if (needle.isEmpty) {
      return const [];
    }

    final offsets = <int>[];
    var searchStart = 0;
    while (true) {
      final index = haystack.indexOf(needle, searchStart);
      if (index == -1) {
        break;
      }
      offsets.add(index);
      searchStart = index + 1;
    }

    return offsets;
  }
}
