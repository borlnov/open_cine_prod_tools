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

/// Reconciles the `roles` table of the project against each episode's speaking characters, and
/// CRUD over the cast.
///
/// A role belongs to the **production**, not to any one screenplay
/// (`docs/adr/0019-one-project-several-episodes.md`): `roles` carries no `screenplayId`, and
/// `role_episodes` (`OcptRoleEpisodesTable`) is the link table saying which episodes name a role.
/// [reconcile] is still handed one screenplay and that screenplay's parsed document, on the same
/// save path `OcptSceneIndexService` already runs on, but it matches by name across **every live,
/// `isFromScreenplay` role of the whole project** and only ever writes **that episode's own
/// links** — a character speaking in three episodes is one row, one casting and one set of casting
/// notes, not three. Unlike scenes, matching is by **exact name only**: there is no
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
/// that stops needing it. [OcptRole.number] is this role's rank among the **project's** live
/// roles, one list over the whole cast rather than one per episode — a shooting day regularly
/// covers two episodes, and two roles numbered 3 on the call sheet it prints would make the
/// `RÔLES` column unreadable.
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

  /// Reconciles the `roles` table of the project against the speaking characters of [document]
  /// (`speakingCharactersOf(document.blocks)`, already normalised, deduplicated and in
  /// first-appearance order), which is [screenplayId]'s own parsed text — but **only ever writes
  /// [screenplayId]'s own `role_episodes` links**, whatever it finds.
  ///
  /// Only rows with `isFromScreenplay` true are read or written by this method — a row the user
  /// added by hand is never touched, whatever character names later appear or disappear in any
  /// episode. Three rules, matching by exact name across every live, from-screenplay role of the
  /// **whole project**:
  ///
  /// 1. A speaking character matching such a role: the live link from that role to [screenplayId]
  ///    is ensured (created, or its tombstone lifted), and `orphanedName` is cleared if it was set
  ///    — ensuring the link is exactly what means the role now has at least one live link
  ///    somewhere. Nothing else about the row changes.
  /// 2. A live, from-screenplay role linked to [screenplayId] that the episode no longer names:
  ///    that link, and only that one, is **tombstoned**. If the role has no live link left
  ///    anywhere afterwards, and it is not already orphaned, `orphanedName` is set to its name and
  ///    the mode shows an `OcptRemovedRoleAlert` banner. A character cut from episode 2 but still
  ///    speaking in episode 3 therefore loses one link and keeps its casting — it is **not**
  ///    orphaned, because losing this link is not losing its last one.
  /// 3. A speaking character matching no live, from-screenplay role at all (new, or renamed into
  ///    existence): a fresh, project-scoped [OcptRoleKind.speaking] row, uncast, appended after
  ///    every live role of the project (hand-added ones included, since the role numbering
  ///    [OcptRole.number] derives is shared across every kind), plus the `role_episodes` row
  ///    linking it to [screenplayId].
  ///
  /// Two live, from-screenplay roles cannot legitimately share a name; when more than one somehow
  /// does, the first in `sortKey` order is matched against deterministically (`putIfAbsent`).
  ///
  /// Renames are still not detected: a rename reads as one disappearance (rule 2) and one
  /// appearance (rule 3), the same trade `OcptSceneIndexService.reconcile` makes for a heading with
  /// no scene number, and for the same reason — nothing about a screenplay cue is a stable
  /// identifier a rename could be matched through. What changes with several episodes is only the
  /// blast radius: a rename in episode 2 reads as one disappearance and one appearance **within
  /// episode 2's own links**, and a role still speaking elsewhere keeps its casting either way.
  ///
  /// This runs on every save, so it computes its plan first and **writes nothing at all when
  /// nothing changed** — the transaction below only opens once there is at least one row to touch.
  Future<void> reconcile({
    required OcptProjectDatabase database,
    required String screenplayId,
    required FountainDocument document,
  }) async {
    final speakingCharacters = speakingCharactersOf(document.blocks);
    final speakingSet = speakingCharacters.toSet();

    final projectRolesQuery = database.select(database.ocptRolesTable)
      ..where((table) => table.isFromScreenplay.equals(true) & table.isDeleted.not())
      ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]);
    final projectRoles = await projectRolesQuery.get();

    final roleByName = <String, OcptRoleRow>{};
    for (final role in projectRoles) {
      roleByName.putIfAbsent(role.name, () => role);
    }
    final roleById = {for (final role in projectRoles) role.id: role};

    final existingLinksQuery = database.select(
      database.ocptRoleEpisodesTable,
    )..where((table) => table.screenplayId.equals(screenplayId));
    final linkByRoleId = {
      for (final link in await existingLinksQuery.get()) link.roleId: link,
    };

    // Rule 1 and rule 3: every speaking character either matches a live, from-screenplay role of
    // the project (its link to this episode is ensured, its orphan mark lifted) or matches none
    // (a fresh role is due).
    final linkIdsToRevive = <String>[];
    final roleIdsNeedingNewLink = <String>[];
    final roleIdsToClearOrphan = <String>[];
    final newRoleNames = <String>[];

    for (final name in speakingCharacters) {
      final role = roleByName[name];
      if (role == null) {
        newRoleNames.add(name);
        continue;
      }

      final existingLink = linkByRoleId[role.id];
      if (existingLink == null) {
        roleIdsNeedingNewLink.add(role.id);
      } else if (existingLink.isDeleted) {
        linkIdsToRevive.add(existingLink.id);
      }

      if (role.orphanedName != null) {
        roleIdsToClearOrphan.add(role.id);
      }
    }

    // Rule 2: every live, from-screenplay role linked to this episode whose name this document no
    // longer speaks loses that link.
    final linkIdsToDrop = <String>[];
    final droppedRoleIds = <String>[];
    for (final role in projectRoles) {
      final link = linkByRoleId[role.id];
      if (link != null && !link.isDeleted && !speakingSet.contains(role.name)) {
        linkIdsToDrop.add(link.id);
        droppedRoleIds.add(role.id);
      }
    }

    // Of those, only the ones left with no live link anywhere else become orphaned.
    final roleIdsToOrphan = <String>{};
    if (droppedRoleIds.isNotEmpty) {
      final otherLiveLinksQuery = database.select(database.ocptRoleEpisodesTable)..where(
        (table) =>
            table.roleId.isIn(droppedRoleIds) &
            table.isDeleted.not() &
            table.screenplayId.equals(screenplayId).not(),
      );
      final roleIdsWithOtherLiveLinks = {
        for (final link in await otherLiveLinksQuery.get()) link.roleId,
      };
      for (final roleId in droppedRoleIds) {
        if (!roleIdsWithOtherLiveLinks.contains(roleId) && roleById[roleId]!.orphanedName == null) {
          roleIdsToOrphan.add(roleId);
        }
      }
    }

    final hasWork =
        linkIdsToRevive.isNotEmpty ||
        roleIdsNeedingNewLink.isNotEmpty ||
        roleIdsToClearOrphan.isNotEmpty ||
        linkIdsToDrop.isNotEmpty ||
        roleIdsToOrphan.isNotEmpty ||
        newRoleNames.isNotEmpty;
    if (!hasWork) {
      return;
    }

    await database.transaction(() async {
      if (linkIdsToRevive.isNotEmpty) {
        await (database.update(
          database.ocptRoleEpisodesTable,
        )..where((table) => table.id.isIn(linkIdsToRevive))).write(
          const OcptRoleEpisodesTableCompanion(isDeleted: Value(false)),
        );
      }

      for (final roleId in roleIdsNeedingNewLink) {
        await database
            .into(database.ocptRoleEpisodesTable)
            .insert(
              OcptRoleEpisodesTableCompanion.insert(
                id: const Uuid().v4(),
                roleId: roleId,
                screenplayId: screenplayId,
              ),
            );
      }

      if (roleIdsToClearOrphan.isNotEmpty) {
        await (database.update(
          database.ocptRolesTable,
        )..where((table) => table.id.isIn(roleIdsToClearOrphan))).write(
          const OcptRolesTableCompanion(orphanedName: Value(null)),
        );
      }

      if (linkIdsToDrop.isNotEmpty) {
        await (database.update(
          database.ocptRoleEpisodesTable,
        )..where((table) => table.id.isIn(linkIdsToDrop))).write(
          const OcptRoleEpisodesTableCompanion(isDeleted: Value(true)),
        );
      }

      for (final roleId in roleIdsToOrphan) {
        await (database.update(
          database.ocptRolesTable,
        )..where((table) => table.id.equals(roleId))).write(
          OcptRolesTableCompanion(orphanedName: Value(roleById[roleId]!.name)),
        );
      }

      if (newRoleNames.isNotEmpty) {
        final liveRoles = await _liveRoleRows(database: database);
        var previousSortKey = liveRoles.isEmpty ? null : liveRoles.last.sortKey;

        for (final name in newRoleNames) {
          previousSortKey = ocptFractionalKeyBetween(before: previousSortKey);
          final roleId = const Uuid().v4();
          await database
              .into(database.ocptRolesTable)
              .insert(
                OcptRolesTableCompanion.insert(
                  id: roleId,
                  name: name,
                  kind: OcptRoleKind.speaking,
                  isFromScreenplay: const Value(true),
                  sortKey: Value(previousSortKey),
                ),
              );
          await database
              .into(database.ocptRoleEpisodesTable)
              .insert(
                OcptRoleEpisodesTableCompanion.insert(
                  id: const Uuid().v4(),
                  roleId: roleId,
                  screenplayId: screenplayId,
                ),
              );
        }
      }
    });
  }

  /// Loads every live role of the project in [database], in `sortKey` order, each carrying its
  /// 1-based [OcptRole.number] among that whole list and its [OcptRole.episodeIds] — the episodes
  /// naming it, in the episodes' own `sortKey` order.
  Future<List<OcptRole>> loadRoles({required OcptProjectDatabase database}) async {
    final rows = await _liveRoleRows(database: database);
    final episodeIdsByRoleId = await _liveEpisodeIdsByRoleId(database: database);

    return [
      for (var i = 0; i < rows.length; i++)
        OcptRole.fromRow(
          row: rows[i],
          number: i + 1,
          episodeIds: episodeIdsByRoleId[rows[i].id] ?? const [],
        ),
    ];
  }

  /// Adds a hand-added role of [kind] (never [OcptRoleKind.speaking] — that kind is only ever
  /// created by [reconcile]) named [name], appended after every live role of the **project**, links
  /// it to episode [screenplayId] (a hand-added role is created on the selected episode) with a
  /// freshly generated `role_episodes` row, and returns the role's own freshly generated id.
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

    final existing = await _liveRoleRows(database: database);
    final id = const Uuid().v4();

    await database.transaction(() async {
      await database
          .into(database.ocptRolesTable)
          .insert(
            OcptRolesTableCompanion.insert(
              id: id,
              name: name,
              kind: kind,
              sortKey: Value(
                ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
              ),
            ),
          );
      await database
          .into(database.ocptRoleEpisodesTable)
          .insert(
            OcptRoleEpisodesTableCompanion.insert(
              id: const Uuid().v4(),
              roleId: id,
              screenplayId: screenplayId,
            ),
          );
    });

    return id;
  }

  /// Updates the fields of role [roleId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey`, `isFromScreenplay` or `orphanedName`: those only
  /// change through [reorderRole], [reconcile] and [keepOrphanedRoleAsSilent].
  ///
  /// Passing [name] is meaningful for a hand-added role only: a `isFromScreenplay` role's name is
  /// owned by [reconcile], which overwrites it right back on the next save were it changed here —
  /// this method itself does not refuse the write, gating that is the mode's job. [setRoleEpisodes]
  /// is the same story for a hand-added role's episodes.
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

  /// Sets the exact episodes role [roleId] is named in to [screenplayIds]: for a hand-added role,
  /// the one place in the app a `role_episodes` row is written by a gesture rather than by
  /// [reconcile] (`docs/adr/0019-one-project-several-episodes.md` §4.3) — a `silent` or `extra`
  /// role is named by no cue, so nothing else can decide where it speaks. Gating this to a
  /// hand-added role is the **mode's** job, exactly as [updateRole]'s doc comment says about a
  /// from-screenplay role's name: [reconcile] owns a from-screenplay role's links and would
  /// overwrite them right back on the next save.
  ///
  /// Every id in [screenplayIds] gets a live link — a tombstoned one is revived rather than
  /// duplicated, the same way [reconcile] ensures a link — and every live link this role held that
  /// is not in [screenplayIds] is tombstoned. An empty set is allowed and means the role is named
  /// in no episode. Runs in one transaction.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> setRoleEpisodes({
    required OcptProjectDatabase database,
    required String roleId,
    required Set<String> screenplayIds,
  }) async {
    if (database.refusesUserWrite("setRoleEpisodes")) {
      return;
    }

    await database.transaction(() async {
      final existingLinksQuery = database.select(
        database.ocptRoleEpisodesTable,
      )..where((table) => table.roleId.equals(roleId));
      final existingLinks = await existingLinksQuery.get();
      final linkByScreenplayId = {for (final link in existingLinks) link.screenplayId: link};

      for (final screenplayId in screenplayIds) {
        final existingLink = linkByScreenplayId[screenplayId];
        if (existingLink == null) {
          await database
              .into(database.ocptRoleEpisodesTable)
              .insert(
                OcptRoleEpisodesTableCompanion.insert(
                  id: const Uuid().v4(),
                  roleId: roleId,
                  screenplayId: screenplayId,
                ),
              );
        } else if (existingLink.isDeleted) {
          await (database.update(
            database.ocptRoleEpisodesTable,
          )..where((table) => table.id.equals(existingLink.id))).write(
            const OcptRoleEpisodesTableCompanion(isDeleted: Value(false)),
          );
        }
      }

      final linkIdsToDrop = [
        for (final link in existingLinks)
          if (!link.isDeleted && !screenplayIds.contains(link.screenplayId)) link.id,
      ];
      if (linkIdsToDrop.isNotEmpty) {
        await (database.update(
          database.ocptRoleEpisodesTable,
        )..where((table) => table.id.isIn(linkIdsToDrop))).write(
          const OcptRoleEpisodesTableCompanion(isDeleted: Value(true)),
        );
      }
    });
  }

  /// Tombstones role [roleId], the `role_elements` links naming it, and every `role_episodes` link
  /// it carries: the removed-role banner's "delete" action, and the plain way to remove a
  /// hand-added role.
  ///
  /// The links go with it for the reason `OcptElementsService.deleteElement` takes its own along:
  /// nothing can reach a link whose role is gone any more, which makes it an orphan rather than
  /// history. The **element** it pointed at is of course untouched — a coat outlives the character
  /// who wore it, and it is still in the catalogue — and so is every **episode** a `role_episodes`
  /// link named: deleting a role is not deleting the screenplays it spoke in.
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
        database.ocptRoleEpisodesTable,
      )..where((table) => table.roleId.equals(roleId))).write(
        const OcptRoleEpisodesTableCompanion(isDeleted: Value(true)),
      );

      await (database.update(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(roleId))).write(
        const OcptRolesTableCompanion(isDeleted: Value(true)),
      );
    });
  }

  /// The removed-role banner's "keep it" action: role [roleId] stops being owned by [reconcile]
  /// (`isFromScreenplay` becomes false), becomes [OcptRoleKind.silent], and its `orphanedName` is
  /// cleared — its casting, its notes and its `role_episodes` links are untouched, and it now
  /// behaves exactly like a role the user added by hand from the start, its episode pills editable
  /// through [setRoleEpisodes].
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

  /// Moves role [roleId] to [newPosition] (0-based) within the **project's** whole cast, by giving
  /// it a `sortKey` sitting between the two roles it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderRole({
    required OcptProjectDatabase database,
    required String roleId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderRole")) {
      return;
    }

    await database.transaction(() async {
      final others = (await _liveRoleRows(database: database))
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

  /// Tombstones every `role_episodes` row naming episode [screenplayId]:
  /// `OcptScreenplayService.deleteEpisode`'s cascade, the last of the links it takes before
  /// tombstoning the screenplay row itself.
  ///
  /// **The roles themselves are untouched — a role belongs to the production, not to a script**
  /// (`docs/adr/0019-one-project-several-episodes.md`). A role that spoke only in the deleted
  /// episode keeps its row, its casting and its notes; it simply ends up named in no episode at
  /// all. This is **not** the same state [reconcile] calls orphaned: `orphanedName` is what a cue
  /// disappearing from a screenplay still being edited leaves behind, offering the removed-role
  /// banner's choice to delete or keep the role — an episode being deleted outright asks nothing,
  /// because there is no screenplay left to have stopped naming the role.
  ///
  /// **Unguarded**, exactly as [OcptElementsService.tombstoneRoleLinksOfRole] is: its only caller has
  /// already refused the write on a preview connection and is already inside the transaction
  /// removing the episode, so a second guard here would only be able to disagree with the first.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> tombstoneEpisodeLinks({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => (database.update(
    database.ocptRoleEpisodesTable,
  )..where((table) => table.screenplayId.equals(screenplayId))).write(
    const OcptRoleEpisodesTableCompanion(isDeleted: Value(true)),
  );

  /// Every live role row of the project, ordered by `sortKey` — the cast is one list over the
  /// project now, not one per screenplay, so no `screenplayId` filters it.
  Future<List<OcptRoleRow>> _liveRoleRows({required OcptProjectDatabase database}) async {
    final query = database.select(database.ocptRolesTable)
      ..where((table) => table.isDeleted.not())
      ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]);

    return query.get();
  }

  /// Every live `role_episodes` link of the project, joined onto its live `screenplays` row and
  /// grouped by `roleId`, each group in the episodes' own `sortKey` order — the read behind
  /// [OcptRole.episodeIds], which the table itself carries no order for (see
  /// `OcptRoleEpisodesTable`'s doc comment).
  Future<Map<String, List<String>>> _liveEpisodeIdsByRoleId({
    required OcptProjectDatabase database,
  }) async {
    final query = database.select(database.ocptRoleEpisodesTable).join([
      innerJoin(
        database.ocptScreenplaysTable,
        database.ocptScreenplaysTable.id.equalsExp(database.ocptRoleEpisodesTable.screenplayId),
      ),
    ])
      ..where(
        database.ocptRoleEpisodesTable.isDeleted.not() &
            database.ocptScreenplaysTable.isDeleted.not(),
      )
      ..orderBy([OrderingTerm.asc(database.ocptScreenplaysTable.sortKey)]);

    final episodeIdsByRoleId = <String, List<String>>{};
    for (final row in await query.get()) {
      final link = row.readTable(database.ocptRoleEpisodesTable);
      episodeIdsByRoleId.putIfAbsent(link.roleId, () => []).add(link.screenplayId);
    }

    return episodeIdsByRoleId;
  }
}
