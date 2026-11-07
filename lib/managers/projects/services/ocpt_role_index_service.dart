// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:meta/meta.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_merge_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_reconcile_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_rows.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_role_origin.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:uuid/uuid.dart';

/// Reconcile the `roles` table of the project against each episode's **whole screenplay cast** —
/// the characters cued in dialogue together with the ones only ever introduced in capitals in the
/// action — and CRUD over the cast.
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
/// `screenplayCharactersOf`'s own normalisation (`fountain_kit`, trimmed/collapsed/upper-cased) —
/// the same normalisation `speakingCharactersOf` applies to a cue and
/// `charactersIntroducedInActionOf` to a name standing in the action, the same normalisation
/// `OcptShotListService`'s `attachCharacter` applies to a shot's characters and
/// `FountainScriptStatistics` applies to its speaking-character count — a role, a shot character
/// and a statistic must never disagree about whether two cues are the same person.
///
/// A live, `isFromScreenplay` role's two origins — cued, or only ever read out of the action — are
/// told apart by [ocptRoleIsActionDetected] (`lib/models/rules/`) over its own `isFromScreenplay`
/// and `kind` rather than by a column of their own: see that function's doc comment for why "not
/// `speaking`" and not "`silent`" is the right test.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`** — `roles` carries no `position` column at all, unlike
/// the legacy one `shots` keeps for ADR 0007's sake: this table is new in the same schema version
/// that stops needing it. [OcptRole.number] is this role's rank among the **project's** live
/// roles, one list over the whole cast rather than one per episode — a shooting day regularly
/// covers two episodes, and two roles numbered 3 on the call sheet it prints would make the
/// `RÔLES` column unreadable.
class OcptRoleIndexService extends AbsOcptService {
  /// The service owning the `role_elements` links, held so [deleteRole] can carry them off with
  /// the role it removes.
  ///
  /// Held rather than reached for, the way `OcptBreakdownService` holds this very service's
  /// siblings. The edge only ever runs this way: `OcptElementsService` knows nothing of roles
  /// beyond the ids its links carry, so nothing here can close a circle.
  final OcptElementsService elementsService;

  /// The service owning the `role_candidates` rows, held so [deleteRole] can carry a part's
  /// candidates off with the part.
  ///
  /// Held for the same reason [elementsService] is, and the edge runs the same way: that service
  /// knows nothing of this one, and reads `roles` only to keep `roles.personId` in step with the
  /// candidacy that wrote it.
  final OcptRoleCandidatesService roleCandidatesService;

  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter]. [reconcile] and [tombstoneEpisodeLinks] never call it: they write
  /// inside a caller's own transaction, and take that caller's own [OcptRowStampService] instead.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptRoleIndexService({
    required super.logger,
    required this.elementsService,
    required this.roleCandidatesService,
    required this.deviceId,
  });

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  ///
  /// Initialises the services this one owns, in the order they are listed in its constructor.
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
    await elementsService.initLifeCycle();
    await roleCandidatesService.initLifeCycle();
  }

  /// Forward to [OcptRoleIndexReconcileOps.reconcile].
  Future<void> reconcile({
    required OcptProjectDatabase database,
    required String screenplayId,
    required FountainDocument document,
    required OcptRowStampService? stamps,
  }) => OcptRoleIndexReconcileOps.reconcile(
    database: database,
    screenplayId: screenplayId,
    document: document,
    stamps: stamps,
  );

  /// Load every live role of the project in [database], in `sortKey` order, each carrying its
  /// 1-based [OcptRole.number] among that whole list and its [OcptRole.episodeIds] — the episodes
  /// naming it, in the episodes' own `sortKey` order.
  @useResult
  Future<OcptDatabaseResult<List<OcptRole>>> loadRoles({required OcptProjectDatabase database}) =>
      guardResult("loadRoles", () async {
        final rows = await OcptRoleIndexRows.liveRoleRows(database: database);
        final episodeIdsByRoleId = await OcptRoleIndexRows.liveEpisodeIdsByRoleId(
          database: database,
        );

        return [
          for (var i = 0; i < rows.length; i++)
            OcptRole.fromRow(
              row: rows[i],
              number: i + 1,
              episodeIds: episodeIdsByRoleId[rows[i].id] ?? const [],
            ),
        ];
      });

  /// Add a hand-added role of [kind] (never [OcptRoleKind.speaking] — that kind is only ever
  /// created by [reconcile]) named [name], appended after every live role of the **project**, link
  /// it to episode [screenplayId] (a hand-added role is created on the selected episode) with a
  /// freshly generated `role_episodes` row, and return the role's own freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseResult<String>> addRole({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String name,
    required OcptRoleKind kind,
  }) => guardResult("addRole", () async {
    if (database.refusesUserWrite("addRole")) {
      return null;
    }

    final existing = await OcptRoleIndexRows.liveRoleRows(database: database);
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRolesTable,
        rowId: id,
        current: null,
        next: OcptRoleRow(
          id: id,
          name: name,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          isDeleted: false,
          kind: kind,
          isFromScreenplay: false,
          castingNotes: '',
        ),
        stamps: stamps,
      );

      final linkId = const Uuid().v4();
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleEpisodesTable,
        rowId: linkId,
        current: null,
        next: OcptRoleEpisodeRow(
          id: linkId,
          roleId: id,
          screenplayId: screenplayId,
          isDeleted: false,
        ),
        stamps: stamps,
      );

      await stamps.flush(database);
    });

    return id;
  });

  /// Update the fields of role [roleId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey`, `isFromScreenplay` or `orphanedName`: those only
  /// change through [reorderRole], [reconcile] and [keepOrphanedRoleAsSilent].
  ///
  /// Passing [name] is meaningful for a hand-added role only: a `isFromScreenplay` role's name is
  /// owned by [reconcile], which overwrites it right back on the next save were it changed here —
  /// this method itself does not refuse the write, gating that is the mode's job. [setRoleEpisodes]
  /// is the same story for a hand-added role's episodes.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> updateRole({
    required OcptProjectDatabase database,
    required String roleId,
    Value<String> name = const Value.absent(),
    Value<String?> personId = const Value.absent(),
    Value<OcptRoleKind> kind = const Value.absent(),
    Value<String> castingNotes = const Value.absent(),
  }) => guardOutcome("updateRole", () async {
    if (database.refusesUserWrite("updateRole")) {
      return;
    }

    final companion = OcptRolesTableCompanion(
      name: name,
      personId: personId,
      kind: kind,
      castingNotes: castingNotes,
    );

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(roleId) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRolesTable,
        rowId: roleId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  });

  /// Set the exact episodes role [roleId] is named in to [screenplayIds]: for a hand-added role,
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
  @useResult
  Future<OcptDatabaseOutcome> setRoleEpisodes({
    required OcptProjectDatabase database,
    required String roleId,
    required Set<String> screenplayIds,
  }) => guardOutcome("setRoleEpisodes", () async {
    if (database.refusesUserWrite("setRoleEpisodes")) {
      return;
    }

    await database.transaction(() async {
      final existingLinksQuery = database.select(database.ocptRoleEpisodesTable)
        ..where((table) => table.roleId.equals(roleId));
      final existingLinks = await existingLinksQuery.get();
      final linkByScreenplayId = {for (final link in existingLinks) link.screenplayId: link};

      final linksToDrop = [
        for (final link in existingLinks)
          if (!link.isDeleted && !screenplayIds.contains(link.screenplayId)) link,
      ];

      final hasWork =
          linksToDrop.isNotEmpty ||
          screenplayIds.any(
            (screenplayId) =>
                linkByScreenplayId[screenplayId] == null ||
                linkByScreenplayId[screenplayId]!.isDeleted,
          );
      if (!hasWork) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      for (final screenplayId in screenplayIds) {
        final existingLink = linkByScreenplayId[screenplayId];
        if (existingLink == null) {
          final linkId = const Uuid().v4();
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptRoleEpisodesTable,
            rowId: linkId,
            current: null,
            next: OcptRoleEpisodeRow(
              id: linkId,
              roleId: roleId,
              screenplayId: screenplayId,
              isDeleted: false,
            ),
            stamps: stamps,
          );
        } else if (existingLink.isDeleted) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptRoleEpisodesTable,
            rowId: existingLink.id,
            current: existingLink,
            next: existingLink.copyWith(isDeleted: false),
            stamps: stamps,
          );
        }
      }

      for (final link in linksToDrop) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptRoleEpisodesTable,
          rowId: link.id,
          current: link,
          next: link.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  });

  /// Forward to [OcptRoleIndexMergeOps.mergeRole].
  @useResult
  Future<OcptDatabaseOutcome> mergeRole({
    required OcptProjectDatabase database,
    required String sourceRoleId,
    required String targetRoleId,
  }) => guardOutcome(
    "mergeRole",
    () => OcptRoleIndexMergeOps.mergeRole(
      database: database,
      sourceRoleId: sourceRoleId,
      targetRoleId: targetRoleId,
      deviceId: deviceId,
    ),
  );

  /// Tombstone role [roleId], the `shot_characters` rows and the `breakdown_tags` rows naming it
  /// (decision 5), the `role_elements` links naming it, the `role_candidates` rows naming it and
  /// every `role_episodes` link it carries: the removed-role banner's "delete" action, and the
  /// plain way to remove a hand-added role.
  ///
  /// The links go with it for the reason `OcptElementsService.deleteElement` takes its own along:
  /// nothing can reach a link whose role is gone any more, which makes it an orphan rather than
  /// history. The **element** it pointed at is of course untouched — a coat outlives the character
  /// who wore it, and it is still in the catalogue — the **person** a candidacy named is untouched
  /// for exactly the same reason, an address book outliving a part being cut, and so is every
  /// **episode** a `role_episodes` link named: deleting a role is not deleting the screenplays it
  /// spoke in, and so is every **shot** a `shot_characters` row named: deleting a role empties the
  /// shot of that character rather than deleting the shot.
  ///
  /// **`shooting_slot_cast` is deliberately left untouched** — decision 5's own scope: unlike
  /// [mergeRole], which must not drop a convocation, a deletion is the user saying the part is
  /// gone, and the convocation naming an uncast (or now-gone) role is reported by a schedule-side
  /// alert rather than silently removed here.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> deleteRole({
    required OcptProjectDatabase database,
    required String roleId,
  }) => guardOutcome("deleteRole", () async {
    if (database.refusesUserWrite("deleteRole")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await elementsService.tombstoneRoleLinksOfRole(
        database: database,
        roleId: roleId,
        stamps: stamps,
      );

      await roleCandidatesService.tombstoneCandidatesOfRole(
        database: database,
        roleId: roleId,
        stamps: stamps,
      );

      final shotCharacterRows = await (database.select(
        database.ocptShotCharactersTable,
      )..where((table) => table.roleId.equals(roleId) & table.isDeleted.not())).get();
      for (final row in shotCharacterRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotCharactersTable,
          rowId: ocptCompositeRowStampKey([row.shotId, roleId]),
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final breakdownTagRows = await (database.select(
        database.ocptBreakdownTagsTable,
      )..where((table) => table.roleId.equals(roleId) & table.isDeleted.not())).get();
      for (final row in breakdownTagRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptBreakdownTagsTable,
          rowId: row.id,
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final linkRows = await (database.select(
        database.ocptRoleEpisodesTable,
      )..where((table) => table.roleId.equals(roleId) & table.isDeleted.not())).get();
      for (final link in linkRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptRoleEpisodesTable,
          rowId: link.id,
          current: link,
          next: link.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final current = await (database.select(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(roleId))).getSingleOrNull();
      if (current != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptRolesTable,
          rowId: roleId,
          current: current,
          next: current.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  });

  /// Handle the removed-role banner's "keep it" action: role [roleId] stops being owned by
  /// [reconcile]
  /// (`isFromScreenplay` becomes false), becomes [OcptRoleKind.silent], and its `orphanedName` is
  /// cleared — its casting, its notes and its `role_episodes` links are untouched, and it now
  /// behaves exactly like a role the user added by hand from the start, its episode pills editable
  /// through [setRoleEpisodes].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> keepOrphanedRoleAsSilent({
    required OcptProjectDatabase database,
    required String roleId,
  }) => guardOutcome("keepOrphanedRoleAsSilent", () async {
    if (database.refusesUserWrite("keepOrphanedRoleAsSilent")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(roleId) & table.isDeleted.not())).getSingleOrNull();

      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRolesTable,
        rowId: roleId,
        current: current,
        next: current.copyWith(
          kind: OcptRoleKind.silent,
          isFromScreenplay: false,
          orphanedName: const Value(null),
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  });

  /// Move role [roleId] to [newPosition] (0-based) within the **project's** whole cast, by giving
  /// it a `sortKey` sitting between the two roles it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> reorderRole({
    required OcptProjectDatabase database,
    required String roleId,
    required int newPosition,
  }) => guardOutcome("reorderRole", () async {
    if (database.refusesUserWrite("reorderRole")) {
      return;
    }

    await database.transaction(() async {
      final rows = await OcptRoleIndexRows.liveRoleRows(database: database);
      final current = rows.where((row) => row.id == roleId).firstOrNull;
      if (current == null) {
        return;
      }

      final others = rows.where((row) => row.id != roleId).toList(growable: false);

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
        table: database.ocptRolesTable,
        rowId: roleId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  });

  /// Tombstone every `role_episodes` row naming episode [screenplayId]:
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
  /// **Unguarded**, exactly as [OcptElementsService.tombstoneRoleLinksOfRole] is: its only caller
  /// has already refused the write on a preview connection and is already inside the transaction
  /// removing the episode, so a second guard here would only be able to disagree with the first.
  /// Stamps through [stamps] — that caller's own instance — rather than resolving a device id of
  /// its own.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> tombstoneEpisodeLinks({
    required OcptProjectDatabase database,
    required String screenplayId,
    required OcptRowStampService? stamps,
  }) async {
    final rows = await (database.select(
      database.ocptRoleEpisodesTable,
    )..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())).get();

    for (final row in rows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRoleEpisodesTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// Disposes the services this one owns, in the reverse order they were initialised.
  @override
  Future<void> disposeLifeCycle() async {
    await roleCandidatesService.disposeLifeCycle();
    await elementsService.disposeLifeCycle();

    return super.disposeLifeCycle();
  }
}
