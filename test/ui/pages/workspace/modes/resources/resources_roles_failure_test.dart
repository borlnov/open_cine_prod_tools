// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_roles_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _RecordingRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// The ids of what the handlers work on.
typedef _Seeded = ({
  String personId,
  String roleId,
  String otherRoleId,
  String orphanedRoleId,
  String screenplayId,
});

/// What the roles bloc does when the database refuses a write on the cast: the handler raises the
/// mode's write error, reads nothing again, and goes on once the refusal is lifted; a flush stops
/// at the first write that fails.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptResourcesBloc modeBloc;
  late OcptResourcesRolesBloc rolesBloc;
  late _Seeded seeded;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Give the blocs time to handle whatever was dispatched.
  Future<void> settle() => pumpEventQueue(times: 200);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_roles_failure_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);

    final project = projectsManager.currentProject!;
    final personId = (await projectsManager.peopleService
        .createPerson(database: project.database)
        .valueOrFail);
    Future<String> role(String name) => projectsManager.roleIndexService
        .addRole(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          name: name,
          kind: OcptRoleKind.silent,
        )
        .valueOrFail;
    final roleId = await role("PASSERBY");
    final otherRoleId = await role("DRIVER");
    final orphanedRoleId = await role("GHOST");
    await project.database.customStatement(
      "UPDATE roles SET is_from_screenplay = 1, orphaned_name = 'GHOST' "
      "WHERE id = '$orphanedRoleId'",
    );

    modeBloc = OcptResourcesBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _RecordingRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    rolesBloc = OcptResourcesRolesBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    await modeBloc.stream
        .firstWhere((state) => !state.isLoading)
        .timeout(const Duration(seconds: 5));
    await modeBloc.reload({OcptResourcesReloadScope.snapshot});
    seeded = (
      personId: personId,
      roleId: roleId,
      otherRoleId: otherRoleId,
      orphanedRoleId: orphanedRoleId,
      screenplayId: project.primaryScreenplayId,
    );
  });

  tearDown(() async {
    await rolesBloc.close();
    await modeBloc.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Make every [verb] on [table] fail with a database error.
  Future<void> refuse(String verb, String table) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  /// Lift what [refuse] put.
  Future<void> allow(String verb, String table) => projectsManager.currentProject!.database
      .customStatement("DROP TRIGGER refuse_${verb.toLowerCase()}_$table");

  /// Read straight from the database the casting notes of every role by name.
  Future<Map<String, String>> castingNotes() async {
    final rows = await projectsManager.currentProject!.database
        .customSelect("SELECT name, casting_notes FROM roles WHERE is_deleted = 0")
        .get();

    return {for (final row in rows) row.read<String>("name"): row.read<String>("casting_notes")};
  }

  /// The handlers, each with the table and the verb that fail it, and the event it dispatches.
  final cases = <String, ({String table, String verb, OcptResourcesEvent Function(_Seeded) event})>{
    "casting a person": (
      table: "roles",
      verb: "UPDATE",
      event: (s) => OcptResourcesRoleCastChangedEvent(roleId: s.roleId, personId: s.personId),
    ),
    "changing the kind": (
      table: "roles",
      verb: "UPDATE",
      event: (s) => OcptResourcesRoleKindChangedEvent(roleId: s.roleId, kind: OcptRoleKind.extra),
    ),
    "changing the episodes": (
      table: "role_episodes",
      verb: "UPDATE",
      event: (s) => OcptResourcesRoleEpisodesChangedEvent(roleId: s.roleId, episodeIds: const {}),
    ),
    "keeping an orphaned role": (
      table: "roles",
      verb: "UPDATE",
      event: (s) => OcptResourcesOrphanedRoleKeptEvent(roleId: s.orphanedRoleId),
    ),
    "merging a role": (
      table: "roles",
      verb: "UPDATE",
      event: (s) =>
          OcptResourcesRoleMergeRequestedEvent(sourceRoleId: s.otherRoleId, targetRoleId: s.roleId),
    ),
    "creating a role": (
      table: "roles",
      verb: "INSERT",
      event: (s) => const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.silent),
    ),
    "deleting a role": (
      table: "roles",
      verb: "UPDATE",
      event: (s) => OcptResourcesRoleDeletionRequestedEvent(roleId: s.otherRoleId),
    ),
  };

  for (final entry in cases.entries) {
    test("${entry.key} raises the write error, reads nothing again, and goes through once the "
        "refusal is lifted", () async {
      final held = modeBloc.state;
      await refuse(entry.value.verb, entry.value.table);

      rolesBloc.add(entry.value.event(seeded));
      await settle();

      expect(modeBloc.state.hasWriteError, isTrue);
      expect(modeBloc.state.reloadEpoch, held.reloadEpoch, reason: "the mode read again");

      await allow(entry.value.verb, entry.value.table);
      modeBloc.add(const OcptResourcesWriteErrorDismissedEvent());
      rolesBloc.add(entry.value.event(seeded));
      await settle();

      expect(modeBloc.state.hasWriteError, isFalse);
      expect(modeBloc.state.reloadEpoch, isNot(held.reloadEpoch));
    });
  }

  group("flushing the typed edits", () {
    /// Type a casting note into [roleId].
    Future<void> type(String roleId, String note) async {
      rolesBloc.add(
        OcptResourcesRoleFieldChangedEvent(
          roleId: roleId,
          field: OcptRoleField.castingNotes,
          rawValue: note,
        ),
      );
      await settle();
    }

    /// Refuse the update of the first role alone.
    Future<void> refuseTheFirstRole() => projectsManager.currentProject!.database.customStatement(
      "CREATE TRIGGER refuse_first BEFORE UPDATE ON roles WHEN NEW.id = '${seeded.roleId}' "
      "BEGIN SELECT RAISE(ABORT, 'refused'); END",
    );

    test("a refused write stops the edits after it", () async {
      await type(seeded.roleId, "Tall");
      await type(seeded.otherRoleId, "Short");
      await refuseTheFirstRole();

      final status = await rolesBloc.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.ok);
      expect(modeBloc.state.hasWriteError, isTrue);
      final notes = await castingNotes();
      expect(notes["PASSERBY"], isEmpty);
      expect(notes["DRIVER"], isEmpty, reason: "the edit after the refused one");
    });

    test("a refused flush on leaving stops the edits after it", () async {
      await type(seeded.roleId, "Tall");
      await type(seeded.otherRoleId, "Short");
      await refuseTheFirstRole();

      await rolesBloc.flushPendingWritesWithoutState();

      final notes = await castingNotes();
      expect(notes["DRIVER"], isEmpty, reason: "the edit after the refused one");
      expect(rolesBloc.state.pendingRoleFieldEdits, isNotEmpty);
    });

    test("a refused role edit stops the candidacy edits after it", () async {
      final candidateId = await projectsManager.roleCandidatesService
          .addCandidate(
            database: projectsManager.currentProject!.database,
            roleId: seeded.roleId,
            personId: seeded.personId,
          )
          .valueOrFail;
      await modeBloc.reload({OcptResourcesReloadScope.snapshot});
      await type(seeded.roleId, "Tall");
      rolesBloc.add(
        OcptResourcesRoleCandidateFieldChangedEvent(
          candidateId: candidateId,
          field: OcptRoleCandidateField.notes,
          rawValue: "Very good",
        ),
      );
      await settle();
      await refuse("UPDATE", "roles");

      await rolesBloc.flushPendingWritesWithoutState();

      final notes = await projectsManager.currentProject!.database
          .customSelect("SELECT notes FROM role_candidates")
          .get();
      expect(notes.single.read<String>("notes"), isEmpty);
    });
  });
}
