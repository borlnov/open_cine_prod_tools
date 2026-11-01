// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_rows.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_role_origin.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:uuid/uuid.dart';

/// The reconciliation of the roles against the characters a screenplay's text names.
///
/// What `OcptRoleIndexService` forwards to; that service documents the role index whole.
abstract final class OcptRoleIndexReconcileOps {
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
  static Future<void> reconcile({
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

    final existingLinksQuery = database.select(database.ocptRoleEpisodesTable)
      ..where((table) => table.screenplayId.equals(screenplayId));
    final linkByRoleId = {for (final link in await existingLinksQuery.get()) link.roleId: link};

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
    final rejectedActionNames = {for (final row in await rejectedNamesQuery.get()) row.name};

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
      final otherLiveLinksQuery = database.select(database.ocptRoleEpisodesTable)
        ..where(
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
        final liveRoles = await OcptRoleIndexRows.liveRoleRows(database: database);
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
}
