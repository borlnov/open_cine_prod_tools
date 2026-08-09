// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// Reconciles the `roles` table of a screenplay against its speaking characters, and CRUD over the
/// cast.
///
/// [reconcile] mirrors `OcptSceneIndexService.reconcile`, run on the same save path: a speaking
/// role's name and existence are owned by the screenplay, exactly as a scene's heading is, and the
/// same trade-off applies — a rename reads as one disappearance and one appearance rather than
/// being detected as such, and the removed-role banner (built from `OcptRemovedRoleAlert.buildAll`)
/// is how the user repairs it. Unlike scenes, matching is by **exact name only**: there is no
/// scene-number-style unique identifier a screenplay cue carries, and no third "relative order"
/// pass either, since two characters swapping their relative cue order is not a rename either side
/// of it should follow.
///
/// The exactness of the name match matters beyond this service: [reconcile] matches against
/// `speakingCharactersOf`'s own normalisation (`fountain_kit`, trimmed/collapsed/upper-cased), the
/// same normalisation `OcptShotListService`'s `attachCharacter` applies to a shot's characters and
/// `FountainScriptStatistics` applies to its speaking-character count — a role, a shot character
/// and a statistic must never disagree about whether two cues are the same person.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`** — `roles` carries no `position` column at all, unlike
/// the legacy one `shots` keeps for ADR 0007's sake: this table is new in the same schema version
/// that stops needing it.
class OcptRoleIndexService {
  /// The service owning the `role_elements` links, held so [deleteRole] can carry them off with
  /// the role it removes.
  ///
  /// Held rather than reached for, the way `OcptBreakdownService` holds this very service's
  /// siblings. The edge only ever runs this way: `OcptElementsService` knows nothing of roles
  /// beyond the ids its links carry, so nothing here can close a circle.
  final OcptElementsService elementsService;

  /// Class constructor
  const OcptRoleIndexService({this.elementsService = const OcptElementsService()});

  /// Reconciles the `roles` table of [screenplayId] in [database] against the speaking characters
  /// of [document] (`speakingCharactersOf(document.blocks)`, already normalised, deduplicated and
  /// in first-appearance order).
  ///
  /// Only rows with `isFromScreenplay` true are read or written by this method — a row the user
  /// added by hand is never touched, whatever character names later appear or disappear, per
  /// decision 3 of the plan this service ships under (§4.4):
  ///
  /// 1. A live, from-screenplay row is matched to a speaking character by exact name. A match
  ///    clears `orphanedName` if the row had it set (the character reappeared, e.g. an edit was
  ///    reverted): nothing else about the row changes.
  /// 2. A from-screenplay row whose name matches no speaking character gets `orphanedName` set to
  ///    that same name — and nothing else: its casting and its notes survive, and the mode shows an
  ///    `OcptRemovedRoleAlert` banner. A row already orphaned is left alone.
  /// 3. A speaking character matching no row (new or renamed-into-existence) gets a freshly
  ///    inserted [OcptRoleKind.speaking] row, uncast, appended after every live role of the
  ///    screenplay (hand-added ones included, since the role numbering `OcptRole.number` derives is
  ///    shared across every kind).
  ///
  /// Renames are not detected: a rename reads as one disappearance (step 2) and one appearance
  /// (step 3), the same trade `OcptSceneIndexService.reconcile` makes for a heading with no scene
  /// number, and for the same reason — nothing about a screenplay cue is a stable identifier a
  /// rename could be matched through.
  Future<void> reconcile({
    required OcptProjectDatabase database,
    required String screenplayId,
    required FountainDocument document,
  }) async {
    final speakingCharacters = speakingCharactersOf(document.blocks);
    final speakingSet = speakingCharacters.toSet();

    final existingRows =
        await (database.select(database.ocptRolesTable)..where(
              (table) =>
                  table.screenplayId.equals(screenplayId) &
                  table.isFromScreenplay.equals(true) &
                  table.isDeleted.not(),
            ))
            .get();

    final rowByName = <String, OcptRoleRow>{};
    for (final row in existingRows) {
      rowByName.putIfAbsent(row.name, () => row);
    }

    await database.transaction(() async {
      for (final row in existingRows) {
        final isPresent = speakingSet.contains(row.name);
        if (!isPresent && row.orphanedName == null) {
          await (database.update(
            database.ocptRolesTable,
          )..where((table) => table.id.equals(row.id))).write(
            OcptRolesTableCompanion(orphanedName: Value(row.name)),
          );
        } else if (isPresent && row.orphanedName != null) {
          await (database.update(
            database.ocptRolesTable,
          )..where((table) => table.id.equals(row.id))).write(
            const OcptRolesTableCompanion(orphanedName: Value(null)),
          );
        }
      }

      final newNames = [
        for (final name in speakingCharacters)
          if (!rowByName.containsKey(name)) name,
      ];

      if (newNames.isEmpty) {
        return;
      }

      final liveRoles = await _liveRoleRows(database: database, screenplayId: screenplayId);
      var previousSortKey = liveRoles.isEmpty ? null : liveRoles.last.sortKey;

      for (final name in newNames) {
        previousSortKey = ocptFractionalKeyBetween(before: previousSortKey);
        await database
            .into(database.ocptRolesTable)
            .insert(
              OcptRolesTableCompanion.insert(
                id: const Uuid().v4(),
                screenplayId: screenplayId,
                name: name,
                kind: OcptRoleKind.speaking,
                isFromScreenplay: const Value(true),
                sortKey: Value(previousSortKey),
              ),
            );
      }
    });
  }

  /// Loads every live role of screenplay [screenplayId] in [database], in `sortKey` order, each
  /// carrying its 1-based [OcptRole.number].
  Future<List<OcptRole>> loadRoles({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final rows = await _liveRoleRows(database: database, screenplayId: screenplayId);

    return [
      for (var i = 0; i < rows.length; i++) OcptRole.fromRow(row: rows[i], number: i + 1),
    ];
  }

  /// Adds a hand-added role of [kind] (never [OcptRoleKind.speaking] — that kind is only ever
  /// created by [reconcile]) named [name] to screenplay [screenplayId], appended after every live
  /// role, and returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addRole({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String name,
    required OcptRoleKind kind,
  }) async {
    if (database.refusesUserWrite("addRole")) {
      return null;
    }

    final existing = await _liveRoleRows(database: database, screenplayId: screenplayId);
    final id = const Uuid().v4();

    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(
            id: id,
            screenplayId: screenplayId,
            name: name,
            kind: kind,
            sortKey: Value(
              ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
            ),
          ),
        );

    return id;
  }

  /// Updates the fields of role [roleId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey`, `isFromScreenplay` or `orphanedName`: those only
  /// change through [reorderRole], [reconcile] and [keepOrphanedRoleAsSilent].
  ///
  /// Passing [name] is meaningful for a hand-added role only: a `isFromScreenplay` role's name is
  /// owned by [reconcile], which overwrites it right back on the next save were it changed here —
  /// this method itself does not refuse the write, gating that is the mode's job.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateRole({
    required OcptProjectDatabase database,
    required String roleId,
    Value<String> name = const Value.absent(),
    Value<String?> personId = const Value.absent(),
    Value<OcptRoleKind> kind = const Value.absent(),
    Value<String> castingNotes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateRole")) {
      return;
    }

    await (database.update(
      database.ocptRolesTable,
    )..where((table) => table.id.equals(roleId) & table.isDeleted.not())).write(
      OcptRolesTableCompanion(name: name, personId: personId, kind: kind, castingNotes: castingNotes),
    );
  }

  /// Tombstones role [roleId] and the `role_elements` links naming it: the removed-role banner's
  /// "delete" action, and the plain way to remove a hand-added role.
  ///
  /// The links go with it for the reason `OcptElementsService.deleteElement` takes its own along:
  /// nothing can reach a link whose role is gone any more, which makes it an orphan rather than
  /// history. The **element** it pointed at is of course untouched — a coat outlives the character
  /// who wore it, and it is still in the catalogue.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteRole({required OcptProjectDatabase database, required String roleId}) async {
    if (database.refusesUserWrite("deleteRole")) {
      return;
    }

    await database.transaction(() async {
      await elementsService.tombstoneRoleLinksOfRole(database: database, roleId: roleId);

      await (database.update(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(roleId))).write(
        const OcptRolesTableCompanion(isDeleted: Value(true)),
      );
    });
  }

  /// The removed-role banner's "keep it" action: role [roleId] stops being owned by [reconcile]
  /// (`isFromScreenplay` becomes false), becomes [OcptRoleKind.silent], and its `orphanedName` is
  /// cleared — its casting and notes are untouched, and it now behaves exactly like a role the user
  /// added by hand from the start.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> keepOrphanedRoleAsSilent({
    required OcptProjectDatabase database,
    required String roleId,
  }) async {
    if (database.refusesUserWrite("keepOrphanedRoleAsSilent")) {
      return;
    }

    await (database.update(
      database.ocptRolesTable,
    )..where((table) => table.id.equals(roleId) & table.isDeleted.not())).write(
      const OcptRolesTableCompanion(
        kind: Value(OcptRoleKind.silent),
        isFromScreenplay: Value(false),
        orphanedName: Value(null),
      ),
    );
  }

  /// Moves role [roleId] to [newPosition] (0-based) within screenplay [screenplayId]'s whole cast,
  /// by giving it a `sortKey` sitting between the two roles it lands between. Writes **exactly one
  /// row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderRole({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String roleId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderRole")) {
      return;
    }

    await database.transaction(() async {
      final others =
          (await _liveRoleRows(database: database, screenplayId: screenplayId))
            ..removeWhere((row) => row.id == roleId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      await (database.update(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(roleId))).write(
        OcptRolesTableCompanion(sortKey: Value(sortKey)),
      );
    });
  }

  /// Every live role row of screenplay [screenplayId], ordered by `sortKey`.
  Future<List<OcptRoleRow>> _liveRoleRows({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => (database.select(database.ocptRolesTable)
        ..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();
}
