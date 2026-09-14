// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/utils/ocpt_role_origin.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';
import 'package:uuid/uuid.dart';

/// Reconciles the `roles` table of the project against each episode's **whole screenplay cast** —
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
/// the same normalisation `speakingCharactersOf` applies to a cue and `charactersIntroducedInActionOf`
/// to a name standing in the action, the same normalisation `OcptShotListService`'s
/// `attachCharacter` applies to a shot's characters and `FountainScriptStatistics` applies to its
/// speaking-character count — a role, a shot character and a statistic must never disagree about
/// whether two cues are the same person.
///
/// A live, `isFromScreenplay` role's two origins — cued, or only ever read out of the action — are
/// told apart by [ocptRoleIsActionDetected] (`lib/utils/`) over its own `isFromScreenplay` and
/// `kind` rather than by a column of their own: see that function's doc comment for why "not
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
class OcptRoleIndexService {
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
    required this.elementsService,
    required this.roleCandidatesService,
    required this.deviceId,
  });

  /// Reconciles the `roles` table of the project against the whole screenplay cast of [document]
  /// (`screenplayCharactersOf(document.blocks)`, already normalised, deduplicated and in
  /// first-appearance order) — every character cued in dialogue, together with every one only ever
  /// introduced in capitals in the action — which is [screenplayId]'s own parsed text. It also
  /// reads `speakingCharactersOf(document.blocks)` as a second, narrower pass: [reconcile] needs to
  /// know which of those names came from a cue rather than infer it, so it asks rather than
  /// guessing. But it **only ever writes [screenplayId]'s own `role_episodes` links**, whatever it
  /// finds.
  ///
  /// Only rows with `isFromScreenplay` true are read or written by this method — a row the user
  /// added by hand is never touched, whatever character names later appear or disappear in any
  /// episode. Three rules, matching by exact name across every live, from-screenplay role of the
  /// **whole project**:
  ///
  /// 1. A cast member matching such a role: the live link from that role to [screenplayId] is
  ///    ensured (created, or its tombstone lifted), and `orphanedName` is cleared if it was set —
  ///    ensuring the link is exactly what means the role now has at least one live link somewhere.
  ///    A name that is cued this time but had so far only ever stood in the action is
  ///    **promoted**: its `kind` becomes [OcptRoleKind.speaking]. Writing a mute character's first
  ///    line must not split them in two. There is **no demotion** the other way: a role that has
  ///    spoken stays `speaking` even if the line naming it is later cut — it may have been cast in
  ///    the meantime, and losing every link (rule 2) is what already handles a character leaving
  ///    the script.
  /// 2. A live, from-screenplay role linked to [screenplayId] that the episode no longer names,
  ///    speaking or not: that link, and only that one, is **tombstoned**. If the role has no live
  ///    link left anywhere afterwards, and it is not already orphaned, `orphanedName` is set to its
  ///    name and the mode shows an `OcptRemovedRoleAlert` banner. A character cut from episode 2
  ///    but still speaking in episode 3 therefore loses one link and keeps its casting — it is
  ///    **not** orphaned, because losing this link is not losing its last one.
  /// 3. A cast member matching no live, from-screenplay role at all (new, or renamed into
  ///    existence): a fresh, project-scoped row is due — [OcptRoleKind.speaking] for a name that is
  ///    cued, [OcptRoleKind.silent] for one only ever found in the action — uncast, appended after
  ///    every live role of the project (hand-added ones included, since the role numbering
  ///    [OcptRole.number] derives is shared across every kind), plus the `role_episodes` row
  ///    linking it to [screenplayId]. **Unless** the name is not cued this episode and matches a
  ///    **tombstoned** action-detected role ([ocptRoleIsActionDetected] true, `isDeleted` true):
  ///    reading a name out of an action line is a convention, not a syntax, so an acronym or a
  ///    shouted word (`OK`, `STOP`, `INTERPOL`) will occasionally be read as a character, and
  ///    deleting it has to be the last word on it — a fresh row is refused instead. This check
  ///    never applies to a name that is cued this episode, whatever tombstone bears it: the cue is
  ///    still in the script, and the script is the source of truth.
  ///
  /// Two live, from-screenplay roles cannot legitimately share a name; when more than one somehow
  /// does, the first in `sortKey` order is matched against deterministically (`putIfAbsent`).
  ///
  /// Renames are still not detected: a rename reads as one disappearance (rule 2) and one
  /// appearance (rule 3), the same trade `OcptSceneIndexService.reconcile` makes for a heading with
  /// no scene number, and for the same reason — nothing about a screenplay cue, or a name standing
  /// in the action, is a stable identifier a rename could be matched through. What changes with
  /// several episodes is only the blast radius: a rename in episode 2 reads as one disappearance
  /// and one appearance **within episode 2's own links**, and a role still named elsewhere keeps
  /// its casting either way.
  ///
  /// This runs on every save, so it computes its plan first and **writes nothing at all when
  /// nothing changed** — the transaction below only opens once there is at least one row to touch.
  ///
  /// Called from inside `OcptScreenplayService.saveScreenplayText`'s own transaction, and stamps
  /// through [stamps] — the caller's own instance — rather than resolving a device id of its own.
  Future<void> reconcile({
    required OcptProjectDatabase database,
    required String screenplayId,
    required FountainDocument document,
    required OcptRowStampService? stamps,
  }) async {
    final screenplayCharacters = screenplayCharactersOf(document.blocks);
    final speakingSet = speakingCharactersOf(document.blocks).toSet();
    final screenplaySet = screenplayCharacters.toSet();

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

    // Rule 3's rejection: every tombstoned, action-detected role's name, matched only when this
    // episode does not cue it (a cued name is never rejected, see the doc comment above). The
    // `isFromScreenplay & kind != speaking` pair mirrors [ocptRoleIsActionDetected], expressed as a
    // query rather than called on a row because the database only has SQL to filter with.
    final rejectedNamesQuery = database.select(database.ocptRolesTable)
      ..where(
        (table) =>
            table.isDeleted.equals(true) &
            table.isFromScreenplay.equals(true) &
            table.kind.equalsValue(OcptRoleKind.speaking).not(),
      );
    final rejectedActionNames = {
      for (final row in await rejectedNamesQuery.get()) row.name,
    };

    // Rule 1 and rule 3: every cast member either matches a live, from-screenplay role of the
    // project (its link to this episode is ensured, its orphan mark lifted, and it is promoted to
    // speaking when it is cued this time) or matches none (a fresh role is due, unless rejected).
    final linksToRevive = <OcptRoleEpisodeRow>[];
    final roleIdsNeedingNewLink = <String>[];
    final roleIdsToClearOrphan = <String>{};
    final roleIdsToPromote = <String>{};
    final newRoleNames = <(String name, bool isSpeaking)>[];

    for (final name in screenplayCharacters) {
      final isSpeaking = speakingSet.contains(name);
      final role = roleByName[name];
      if (role == null) {
        if (!isSpeaking && rejectedActionNames.contains(name)) {
          continue;
        }
        newRoleNames.add((name, isSpeaking));
        continue;
      }

      final existingLink = linkByRoleId[role.id];
      if (existingLink == null) {
        roleIdsNeedingNewLink.add(role.id);
      } else if (existingLink.isDeleted) {
        linksToRevive.add(existingLink);
      }

      if (role.orphanedName != null) {
        roleIdsToClearOrphan.add(role.id);
      }

      if (isSpeaking &&
          ocptRoleIsActionDetected(isFromScreenplay: role.isFromScreenplay, kind: role.kind)) {
        roleIdsToPromote.add(role.id);
      }
    }

    // Rule 2: every live, from-screenplay role linked to this episode whose name this document no
    // longer names at all — cue or action — loses that link.
    final linksToDrop = <OcptRoleEpisodeRow>[];
    final droppedRoleIds = <String>[];
    for (final role in projectRoles) {
      final link = linkByRoleId[role.id];
      if (link != null && !link.isDeleted && !screenplaySet.contains(role.name)) {
        linksToDrop.add(link);
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
        linksToRevive.isNotEmpty ||
        roleIdsNeedingNewLink.isNotEmpty ||
        roleIdsToClearOrphan.isNotEmpty ||
        roleIdsToPromote.isNotEmpty ||
        linksToDrop.isNotEmpty ||
        roleIdsToOrphan.isNotEmpty ||
        newRoleNames.isNotEmpty;
    if (!hasWork) {
      return;
    }

    await database.transaction(() async {
      for (final link in linksToRevive) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptRoleEpisodesTable,
          rowId: link.id,
          current: link,
          next: link.copyWith(isDeleted: false),
          stamps: stamps,
        );
      }

      for (final roleId in roleIdsNeedingNewLink) {
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
      }

      for (final roleId in roleIdsToClearOrphan) {
        final current = roleById[roleId]!;
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptRolesTable,
          rowId: roleId,
          current: current,
          next: current.copyWith(orphanedName: const Value(null)),
          stamps: stamps,
        );
      }

      for (final roleId in roleIdsToPromote) {
        final current = roleById[roleId]!;
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptRolesTable,
          rowId: roleId,
          current: current,
          next: current.copyWith(kind: OcptRoleKind.speaking),
          stamps: stamps,
        );
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

      for (final roleId in roleIdsToOrphan) {
        final current = roleById[roleId]!;
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptRolesTable,
          rowId: roleId,
          current: current,
          next: current.copyWith(orphanedName: Value(current.name)),
          stamps: stamps,
        );
      }

      if (newRoleNames.isNotEmpty) {
        final liveRoles = await _liveRoleRows(database: database);
        var previousSortKey = liveRoles.isEmpty ? null : liveRoles.last.sortKey;

        for (final (name, isSpeaking) in newRoleNames) {
          previousSortKey = ocptFractionalKeyBetween(before: previousSortKey);
          final roleId = const Uuid().v4();
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptRolesTable,
            rowId: roleId,
            current: null,
            next: OcptRoleRow(
              id: roleId,
              name: name,
              sortKey: previousSortKey,
              isDeleted: false,
              kind: isSpeaking ? OcptRoleKind.speaking : OcptRoleKind.silent,
              isFromScreenplay: true,
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
              roleId: roleId,
              screenplayId: screenplayId,
              isDeleted: false,
            ),
            stamps: stamps,
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
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRolesTable,
        rowId: id,
        current: null,
        next: OcptRoleRow(
          id: id,
          name: name,
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
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
  }

  /// Merges role [sourceRoleId] into role [targetRoleId] (`docs/adr/0030-…`, decision 3): every row
  /// naming *source* is re-pointed onto *target* — deduped where *target* already has the
  /// equivalent — *source*'s casting and notes are carried onto *target* where *target* lacks them,
  /// and *source* is tombstoned last.
  ///
  /// **This method is purely mechanical.** It merges *source* into *target* exactly as given: it
  /// never decides which of the two survives. "The reconciled speaking role wins" (decision 3) is
  /// the **caller's** rule — the caller picks which id is [targetRoleId] before calling this, so
  /// that when one of the two roles is a live, `isFromScreenplay` one, it is passed as
  /// [targetRoleId] and stays owned by [reconcile]. A no-op if [sourceRoleId] equals [targetRoleId],
  /// or if either role is missing or already tombstoned.
  ///
  /// What moves, table by table:
  /// - `shot_characters` (`{shotId, roleId}` primary key): every live row naming *source* is
  ///   tombstoned; the `{shotId, targetRoleId}` row is created, or revived if it exists only as a
  ///   tombstone, keeping the moved row's `position`/`sortKey` — a plain tombstone-and-recreate,
  ///   the only way to re-point a composite primary key. A shot that already has *target* live
  ///   simply drops *source*'s row instead.
  /// - `shooting_slot_cast` (own-id primary key, `roleId` an ordinary column): a live row naming
  ///   *source* has its `roleId` updated to *target* in place, unless that slot already convokes
  ///   *target* live, in which case *source*'s row is tombstoned instead — a convocation must never
  ///   be lost to the merge, which is the one thing that sets this cascade apart from [deleteRole]'s
  ///   (decision 3's own contrast with decision 5).
  /// - `breakdown_tags` (own-id primary key, `roleId` a nullable column): every live tag naming
  ///   *source* has its `roleId` updated to *target*. Tags never dedupe against each other — each is
  ///   its own passage of the screenplay — so every one of them simply moves.
  /// - `role_elements` / `role_candidates` / `role_episodes` (own-id primary keys, `roleId` an
  ///   ordinary column on each): a live link naming *source* is re-pointed to *target* by updating
  ///   its `roleId`, unless *target* already has the equivalent link (same `elementId`, same
  ///   `personId`, same `screenplayId` respectively) live, in which case *source*'s link is
  ///   tombstoned instead.
  /// - `roles`: if *target*'s `personId` is null and *source*'s is not, *target* takes it; if
  ///   *target*'s `castingNotes` is empty and *source*'s is not, *target* takes it too. *Target*'s
  ///   `kind`, `sortKey`, `isFromScreenplay` and `orphanedName` are never touched by a merge.
  ///
  /// No other table of this schema names a role beside these six and `roles` itself.
  ///
  /// One transaction, one [OcptRowStampService] seeded once and flushed once at the end, passed
  /// through every write above — the normal convention, never a nested seed/flush.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> mergeRole({
    required OcptProjectDatabase database,
    required String sourceRoleId,
    required String targetRoleId,
  }) async {
    if (database.refusesUserWrite("mergeRole")) {
      return;
    }

    if (sourceRoleId == targetRoleId) {
      return;
    }

    await database.transaction(() async {
      final source = await (database.select(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(sourceRoleId) & table.isDeleted.not())).getSingleOrNull();
      final target = await (database.select(
        database.ocptRolesTable,
      )..where((table) => table.id.equals(targetRoleId) & table.isDeleted.not())).getSingleOrNull();
      if (source == null || target == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      // shot_characters: {shotId, roleId} primary key, so a re-point is tombstone-and-recreate —
      // there is no other way to move a composite primary key's row onto a different key.
      final sourceShotCharacters =
          await (database.select(database.ocptShotCharactersTable)..where(
                (table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not(),
              ))
              .get();
      for (final row in sourceShotCharacters) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShotCharactersTable,
          rowId: ocptCompositeRowStampKey([row.shotId, sourceRoleId]),
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );

        final existingTarget =
            await (database.select(database.ocptShotCharactersTable)..where(
                  (table) => table.shotId.equals(row.shotId) & table.roleId.equals(targetRoleId),
                ))
                .getSingleOrNull();
        final targetRowId = ocptCompositeRowStampKey([row.shotId, targetRoleId]);

        if (existingTarget == null) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShotCharactersTable,
            rowId: targetRowId,
            current: null,
            next: OcptShotCharacterRow(
              shotId: row.shotId,
              roleId: targetRoleId,
              position: row.position,
              sortKey: row.sortKey,
              isDeleted: false,
            ),
            stamps: stamps,
          );
        } else if (existingTarget.isDeleted) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptShotCharactersTable,
            rowId: targetRowId,
            current: existingTarget,
            next: existingTarget.copyWith(sortKey: row.sortKey, isDeleted: false),
            stamps: stamps,
          );
        }
        // else target is already live on this shot: dropping source's row (above) is enough.
      }

      // shooting_slot_cast: own-id primary key, so a re-point updates the roleId column in place —
      // unless the slot already convokes target, in which case source's convocation is tombstoned
      // rather than duplicating one, since a role is convoked at most once per slot.
      final sourceSlotCast =
          await (database.select(database.ocptShootingSlotCastTable)..where(
                (table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not(),
              ))
              .get();
      for (final row in sourceSlotCast) {
        final targetAlreadyConvoked =
            await (database.select(database.ocptShootingSlotCastTable)..where(
                  (table) =>
                      table.slotId.equals(row.slotId) &
                      table.roleId.equals(targetRoleId) &
                      table.isDeleted.not(),
                ))
                .getSingleOrNull() !=
            null;

        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptShootingSlotCastTable,
          rowId: row.id,
          current: row,
          next: targetAlreadyConvoked
              ? row.copyWith(isDeleted: true)
              : row.copyWith(roleId: targetRoleId),
          stamps: stamps,
        );
      }

      // breakdown_tags: own-id primary key, nullable roleId column, no dedup — each tag is its own
      // passage of the screenplay.
      final sourceTags =
          await (database.select(database.ocptBreakdownTagsTable)..where(
                (table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not(),
              ))
              .get();
      for (final row in sourceTags) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptBreakdownTagsTable,
          rowId: row.id,
          current: row,
          next: row.copyWith(roleId: Value(targetRoleId)),
          stamps: stamps,
        );
      }

      // role_elements: own-id primary key, deduped by elementId.
      final sourceElements =
          await (database.select(database.ocptRoleElementsTable)..where(
                (table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not(),
              ))
              .get();
      if (sourceElements.isNotEmpty) {
        final targetElementIds =
            (await (database.select(database.ocptRoleElementsTable)..where(
                      (table) => table.roleId.equals(targetRoleId) & table.isDeleted.not(),
                    ))
                    .get())
                .map((row) => row.elementId)
                .toSet();
        for (final row in sourceElements) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptRoleElementsTable,
            rowId: row.id,
            current: row,
            next: targetElementIds.contains(row.elementId)
                ? row.copyWith(isDeleted: true)
                : row.copyWith(roleId: targetRoleId),
            stamps: stamps,
          );
        }
      }

      // role_candidates: own-id primary key, deduped by personId.
      final sourceCandidates =
          await (database.select(database.ocptRoleCandidatesTable)..where(
                (table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not(),
              ))
              .get();
      if (sourceCandidates.isNotEmpty) {
        final targetPersonIds =
            (await (database.select(database.ocptRoleCandidatesTable)..where(
                      (table) => table.roleId.equals(targetRoleId) & table.isDeleted.not(),
                    ))
                    .get())
                .map((row) => row.personId)
                .toSet();
        for (final row in sourceCandidates) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptRoleCandidatesTable,
            rowId: row.id,
            current: row,
            next: targetPersonIds.contains(row.personId)
                ? row.copyWith(isDeleted: true)
                : row.copyWith(roleId: targetRoleId),
            stamps: stamps,
          );
        }
      }

      // role_episodes: own-id primary key, deduped by screenplayId.
      final sourceEpisodes =
          await (database.select(database.ocptRoleEpisodesTable)..where(
                (table) => table.roleId.equals(sourceRoleId) & table.isDeleted.not(),
              ))
              .get();
      if (sourceEpisodes.isNotEmpty) {
        final targetScreenplayIds =
            (await (database.select(database.ocptRoleEpisodesTable)..where(
                      (table) => table.roleId.equals(targetRoleId) & table.isDeleted.not(),
                    ))
                    .get())
                .map((row) => row.screenplayId)
                .toSet();
        for (final row in sourceEpisodes) {
          await OcptRowStampService.writeAndStamp(
            database: database,
            table: database.ocptRoleEpisodesTable,
            rowId: row.id,
            current: row,
            next: targetScreenplayIds.contains(row.screenplayId)
                ? row.copyWith(isDeleted: true)
                : row.copyWith(roleId: targetRoleId),
            stamps: stamps,
          );
        }
      }

      // roles: target carries source's personId/castingNotes where it lacks them of its own; kind,
      // sortKey, isFromScreenplay and orphanedName are never touched by a merge. writeAndStamp is a
      // no-op when nothing actually changes, so this is safe to call unconditionally.
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRolesTable,
        rowId: targetRoleId,
        current: target,
        next: target.copyWith(
          personId: target.personId == null && source.personId != null
              ? Value(source.personId)
              : const Value.absent(),
          castingNotes: target.castingNotes.isEmpty && source.castingNotes.isNotEmpty
              ? source.castingNotes
              : target.castingNotes,
        ),
        stamps: stamps,
      );

      // source is tombstoned last, once everything it carried has moved.
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptRolesTable,
        rowId: sourceRoleId,
        current: source,
        next: source.copyWith(isDeleted: true),
        stamps: stamps,
      );

      await stamps.flush(database);
    });
  }

  /// Tombstones role [roleId], the `shot_characters` rows and the `breakdown_tags` rows naming it
  /// (decision 5), the `role_elements` links naming it, the `role_candidates` rows naming it and
  /// every `role_episodes` link it carries: the removed-role banner's "delete" action, and the plain
  /// way to remove a hand-added role.
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
  /// [mergeRole], which must not drop a convocation, a deletion is the user saying the part is gone,
  /// and the convocation naming an uncast (or now-gone) role is reported by a schedule-side alert
  /// rather than silently removed here.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteRole({required OcptProjectDatabase database, required String roleId}) async {
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

      final shotCharacterRows =
          await (database.select(
                database.ocptShotCharactersTable,
              )..where((table) => table.roleId.equals(roleId) & table.isDeleted.not()))
              .get();
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

      final breakdownTagRows =
          await (database.select(
                database.ocptBreakdownTagsTable,
              )..where((table) => table.roleId.equals(roleId) & table.isDeleted.not()))
              .get();
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

      final linkRows =
          await (database.select(
                database.ocptRoleEpisodesTable,
              )..where((table) => table.roleId.equals(roleId) & table.isDeleted.not()))
              .get();
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
      final rows = await _liveRoleRows(database: database);
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
  /// Stamps through [stamps] — that caller's own instance — rather than resolving a device id of
  /// its own.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> tombstoneEpisodeLinks({
    required OcptProjectDatabase database,
    required String screenplayId,
    required OcptRowStampService? stamps,
  }) async {
    final rows =
        await (database.select(
              database.ocptRoleEpisodesTable,
            )..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not()))
            .get();

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
