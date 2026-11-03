// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_people_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_roles_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter for it
/// to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// How long a view bloc waits before it writes what was typed, for the tests that wait for it.
const _shortDebounce = Duration(milliseconds: 30);

/// A debounce no test waits out, for the tests that must find an edit still pending.
const _neverDebounce = Duration(days: 1);

/// Run the tests of [OcptResourcesRolesBloc].
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's write error path)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_roles_bloc_test_");
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
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds the mode bloc wired to the test project, on [selectedEpisodeId] when given.
  OcptResourcesBloc buildBloc({String? selectedEpisodeId}) => OcptResourcesBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    selectedEpisodeId: selectedEpisodeId,
  );

  /// Builds the roles bloc of [modeBloc], writing what is typed after [fieldEditDebounce].
  OcptResourcesRolesBloc buildRoles(
    OcptResourcesBloc modeBloc, {
    Duration fieldEditDebounce = _shortDebounce,
  }) => OcptResourcesRolesBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    fieldEditDebounce: fieldEditDebounce,
  );

  /// The value the roles table holds in the column the test types into, whichever row.
  Future<String> readStoredValue(OcptProjectDatabase database) async {
    final row = await database.customSelect("SELECT casting_notes AS value FROM roles").getSingle();
    return row.read<String>("value");
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Creates a role of [kind] through [rolesBloc] and waits for the mode to select it.
  Future<String> createRole(
    OcptResourcesBloc modeBloc,
    OcptResourcesRolesBloc rolesBloc, {
    OcptRoleKind kind = OcptRoleKind.extra,
  }) async {
    final before = modeBloc.state.roleCount;
    final previouslySelected = modeBloc.state.selectedRoleId;
    rolesBloc.add(OcptResourcesRoleCreationRequestedEvent(kind: kind));
    final state = await waitForState(
      modeBloc,
      (state) =>
          state.roleCount == before + 1 &&
          state.selectedRoleId != null &&
          state.selectedRoleId != previouslySelected,
    );

    return state.selectedRoleId!;
  }

  /// Adds a person to the address book behind the mode's back, as a view's own write would, and
  /// has the mode read the catalogue again so it holds them.
  Future<String> seedPerson(OcptResourcesBloc modeBloc) async {
    final personId = await projectsManager.peopleService.createPerson(
      database: projectsManager.currentProject!.database,
    );
    await modeBloc.reload({OcptResourcesReloadScope.snapshot});

    return personId!;
  }

  /// Closes the blocs of a test, the view before its mode.
  Future<void> closeAll(OcptResourcesRolesBloc rolesBloc, OcptResourcesBloc modeBloc) async {
    await rolesBloc.close();
    await modeBloc.close();
  }

  group("creating and deleting a role", () {
    test("creating a silent role appends it to the cast and selects it", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      await createRole(bloc, rolesBloc, kind: OcptRoleKind.silent);
      final state = bloc.state;

      expect(state.selectedRole, isNotNull);
      expect(state.roles.single.id, state.selectedRoleId);
      expect(state.roles.single.kind, OcptRoleKind.silent);
      expect(state.roles.single.isFromScreenplay, isFalse);

      await closeAll(rolesBloc, bloc);
    });

    test("constructed with a second episode selected, reads and writes that episode rather than "
        "the primary screenplay", () async {
      final project = projectsManager.currentProject!;
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: "INT. PRIMARY - DAY\n\nAction one.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );
      final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
        database: project.database,
      );
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: secondEpisodeId!,
        fountainText: "INT. SECOND EPISODE - NIGHT\n\nAction two.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );

      final bloc = buildBloc(selectedEpisodeId: secondEpisodeId);
      final rolesBloc = buildRoles(bloc);
      final state = await waitForState(bloc, (state) => !state.isLoading);

      // The scenes offered to a set or an element are the selected episode's own, not the
      // primary screenplay's.
      expect(state.scenes, hasLength(1));
      expect(state.scenes.single.heading, "INT. SECOND EPISODE - NIGHT");

      // A hand-added role is linked to the selected episode (ADR 0019's "created on the selected
      // episode"), not to the primary screenplay.
      await createRole(bloc, rolesBloc, kind: OcptRoleKind.silent);
      expect(bloc.state.roles.single.episodeIds, [secondEpisodeId]);

      await closeAll(rolesBloc, bloc);
    });

    test("deleting the selected role clears the selection", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final roleId = await createRole(bloc, rolesBloc);

      rolesBloc.add(OcptResourcesRoleDeletionRequestedEvent(roleId: roleId));
      final state = await waitForState(
        bloc,
        (state) => state.roleCount == 0 && state.selectedRoleId == null,
      );

      expect(state.roles, isEmpty);

      await closeAll(rolesBloc, bloc);
    });

    test("deleting a role drops the field typed on its sheet, not a candidate's note", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      final roleId = await createRole(bloc, rolesBloc);
      final personId = await seedPerson(bloc);
      rolesBloc.add(OcptResourcesRoleCandidateAddedEvent(roleId: roleId, personId: personId));
      final withCandidate = await waitForState(
        bloc,
        (state) => state.candidatesOfRole(roleId).length == 1,
      );
      final candidateId = withCandidate.candidatesOfRole(roleId).single.id;

      rolesBloc.add(
        OcptResourcesRoleFieldChangedEvent(
          roleId: roleId,
          field: OcptRoleField.castingNotes,
          rawValue: "Zoe",
        ),
      );
      rolesBloc.add(
        OcptResourcesRoleCandidateFieldChangedEvent(
          candidateId: candidateId,
          field: OcptRoleCandidateField.notes,
          rawValue: "Voice",
        ),
      );
      await waitForState(
        rolesBloc,
        (state) =>
            state.pendingRoleFieldEdits.isNotEmpty && state.pendingCandidateFieldEdits.isNotEmpty,
      );

      rolesBloc.add(OcptResourcesRoleDeletionRequestedEvent(roleId: roleId));
      final state = await waitForState(rolesBloc, (state) => state.pendingRoleFieldEdits.isEmpty);

      // The role's own cascade tombstones its candidacies, but the note typed on one of them was
      // never dropped with the role: it is still waiting for its flush.
      expect(state.pendingCandidateFieldEdits, isNotEmpty);

      await closeAll(rolesBloc, bloc);
    });
  });

  group("the writes of a role's sheet", () {
    test("casting a person to a role and changing its kind both land in the database", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await seedPerson(bloc);
      final roleId = await createRole(bloc, rolesBloc);

      rolesBloc.add(OcptResourcesRoleCastChangedEvent(roleId: roleId, personId: personId));
      var state = await waitForState(bloc, (state) => state.roles.single.personId == personId);
      expect(state.roles.single.kind, OcptRoleKind.extra);

      rolesBloc.add(OcptResourcesRoleKindChangedEvent(roleId: roleId, kind: OcptRoleKind.silent));
      state = await waitForState(bloc, (state) => state.roles.single.kind == OcptRoleKind.silent);
      expect(state.roles.single.personId, personId);

      await closeAll(rolesBloc, bloc);
    });

    test(
      "changing a role's episodes writes through setRoleEpisodes and the reload shows it",
      () async {
        final project = projectsManager.currentProject!;
        final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
          database: project.database,
        );

        final bloc = buildBloc();
        final rolesBloc = buildRoles(bloc);
        await waitForState(bloc, (state) => !state.isLoading);

        // Created on the primary episode, ADR 0019's "created on the selected episode".
        final roleId = await createRole(bloc, rolesBloc);
        expect(bloc.state.roles.single.episodeIds, [project.primaryScreenplayId]);

        rolesBloc.add(
          OcptResourcesRoleEpisodesChangedEvent(
            roleId: roleId,
            episodeIds: {project.primaryScreenplayId, secondEpisodeId!},
          ),
        );
        final state = await waitForState(
          bloc,
          (state) => state.roles.single.episodeIds.length == 2,
        );
        expect(state.roles.single.episodeIds.toSet(), {
          project.primaryScreenplayId,
          secondEpisodeId,
        });

        await closeAll(rolesBloc, bloc);
      },
    );

    test("a role's episodes cannot be changed while a version is being previewed", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final roleId = await createRole(bloc, rolesBloc);
      final originalEpisodeIds = bloc.state.roles.single.episodeIds;

      bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "Cast locked", note: ""));
      final withVersion = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
      final versionId = withVersion.projectVersions.single.id;

      bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
      await waitForState(bloc, (state) => state.previewedVersionId != null);

      rolesBloc.add(OcptResourcesRoleEpisodesChangedEvent(roleId: roleId, episodeIds: const {}));
      // The write is refused by the database's own preview guard; wait long enough that a bug
      // silently applying it anyway would have shown up.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.roles.single.episodeIds, originalEpisodeIds);
      expect(bloc.state.hasWriteError, isFalse);

      await closeAll(rolesBloc, bloc);
    });

    test("keeping an orphaned role turns it into a hand-added silent role", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final roleId = await createRole(bloc, rolesBloc, kind: OcptRoleKind.silent);

      // A hand-added role is never orphaned by construction; the bloc only cares that the write
      // reaches `OcptRoleIndexService.keepOrphanedRoleAsSilent`, so calling it here (through the
      // event, not the service) is enough to exercise the wiring end to end.
      rolesBloc.add(OcptResourcesOrphanedRoleKeptEvent(roleId: roleId));
      final state = await waitForState(bloc, (state) => !state.roles.single.isFromScreenplay);

      expect(state.roles.single.kind, OcptRoleKind.silent);
      expect(state.roles.single.orphanedName, isNull);

      await closeAll(rolesBloc, bloc);
    });

    test(
      "merging two roles carries the source's casting onto the target and drops the source",
      () async {
        final bloc = buildBloc();
        final rolesBloc = buildRoles(bloc);
        await waitForState(bloc, (state) => !state.isLoading);
        final personId = await seedPerson(bloc);
        final targetId = await createRole(bloc, rolesBloc);
        final sourceId = await createRole(bloc, rolesBloc);

        // Cast a person to the source role, written immediately (a discrete pick, not typing): what
        // the merge is expected to carry onto the target, which starts out uncast.
        rolesBloc.add(OcptResourcesRoleCastChangedEvent(roleId: sourceId, personId: personId));
        await waitForState(bloc, (state) => state.selectedRole!.personId == personId);

        rolesBloc.add(
          OcptResourcesRoleMergeRequestedEvent(sourceRoleId: sourceId, targetRoleId: targetId),
        );
        final state = await waitForState(bloc, (state) => state.roleCount == 1);

        expect(state.roles.single.id, targetId);
        expect(state.roles.single.personId, personId);

        await closeAll(rolesBloc, bloc);
      },
    );
  });

  group("the fields typed on a role's sheet", () {
    test("are written by the debounce, and flushed by a selection change", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final roleId = await createRole(bloc, rolesBloc, kind: OcptRoleKind.silent);

      rolesBloc.add(
        OcptResourcesRoleFieldChangedEvent(
          roleId: roleId,
          field: OcptRoleField.name,
          rawValue: "Passerby",
        ),
      );
      final pending = await waitForState(
        rolesBloc,
        (state) => state.pendingRoleFieldEdits[(roleId, OcptRoleField.name)] == "Passerby",
      );
      expect(pending.pendingRoleFieldEdits, isNotEmpty);
      // Not written yet: still the field's default empty value.
      expect(bloc.state.selectedRole!.name, isEmpty);

      // Selecting another role flushes the pending edit rather than losing it.
      await createRole(bloc, rolesBloc, kind: OcptRoleKind.silent);
      await waitForState(rolesBloc, (state) => state.pendingRoleFieldEdits.isEmpty);

      final roles = await waitForState(
        bloc,
        (state) => state.roles.any((role) => role.name == "Passerby"),
      );
      expect(roles.roles.firstWhere((role) => role.id == roleId).name, "Passerby");

      await closeAll(rolesBloc, bloc);
    });

    test(
      "make a hand-added role sharing a screenplay role's name raise a collision alert",
      () async {
        final project = projectsManager.currentProject!;
        await projectsManager.screenplayService.saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: "INT. HOUSE - DAY\n\nCLARA\nHello.\n",
          snapshotReason: OcptSnapshotReason.manual,
        );

        final bloc = buildBloc();
        final rolesBloc = buildRoles(bloc, fieldEditDebounce: _neverDebounce);
        final loaded = await waitForState(bloc, (state) => state.roleCount == 1);
        expect(loaded.roleCollisionAlerts, isEmpty);
        final screenplayRoleId = loaded.roles.single.id;

        final handAddedRoleId = await createRole(bloc, rolesBloc);
        rolesBloc.add(
          OcptResourcesRoleFieldChangedEvent(
            roleId: handAddedRoleId,
            field: OcptRoleField.name,
            rawValue: "Clara",
          ),
        );
        await waitForState(rolesBloc, (state) => state.pendingRoleFieldEdits.isNotEmpty);

        // Flushed by leaving the roles tab, which asks every view bloc to write what it holds.
        bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.people));
        final state = await waitForState(bloc, (state) => state.roleCollisionAlerts.isNotEmpty);

        expect(state.roleCollisionAlerts, hasLength(1));
        expect(state.roleCollisionAlerts.single.screenplayRoleId, screenplayRoleId);
        expect(state.roleCollisionAlerts.single.handAddedRoleId, handAddedRoleId);

        await closeAll(rolesBloc, bloc);
      },
    );

    test("are written once when the widget leaves the tree and the bloc then closes", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      final roleId = await createRole(bloc, rolesBloc);
      rolesBloc.add(
        OcptResourcesRoleFieldChangedEvent(
          roleId: roleId,
          field: OcptRoleField.castingNotes,
          rawValue: "Zoe",
        ),
      );
      await waitForState(rolesBloc, (state) => state.pendingRoleFieldEdits.isNotEmpty);

      // Every update of the table is logged, so a second write of the same edit shows.
      final database = projectsManager.currentProject!.database;
      await database.customStatement("CREATE TABLE write_log (written INTEGER)");
      await database.customStatement(
        "CREATE TRIGGER log_write AFTER UPDATE ON roles "
        "BEGIN INSERT INTO write_log VALUES (1); END",
      );

      // What the widget leaving the tree does: the flush starts, and the bloc closes in the same
      // frame, before the write is done.
      final flushing = bloc.flushPendingFieldEdits();
      await closeAll(rolesBloc, bloc);
      await flushing;

      expect(await readStoredValue(database), "Zoe");
      final writes = await database.customSelect("SELECT COUNT(*) AS n FROM write_log").getSingle();
      expect(writes.read<int>("n"), 1);
    });

    test(
      "are written and forgotten, with the one write error, when the read after the write fails",
      () async {
        final bloc = buildBloc();
        final rolesBloc = buildRoles(bloc, fieldEditDebounce: _neverDebounce);
        await waitForState(bloc, (state) => !state.isLoading);
        final roleId = await createRole(bloc, rolesBloc);
        rolesBloc.add(
          OcptResourcesRoleFieldChangedEvent(
            roleId: roleId,
            field: OcptRoleField.castingNotes,
            rawValue: "Zoe",
          ),
        );
        await waitForState(rolesBloc, (state) => state.pendingRoleFieldEdits.isNotEmpty);

        final database = projectsManager.currentProject!.database;
        // The write of an edit never touches the episodes, whereas the read of the catalogue after
        // it does: the write lands and the read fails.
        await database.customStatement("ALTER TABLE screenplays RENAME TO screenplays_gone");
        try {
          final mayProceed = await bloc.flushAllPendingWrites();

          expect(mayProceed, isTrue);
          expect(bloc.state.hasWriteError, isTrue);
          expect(rolesBloc.state.pendingRoleFieldEdits, isEmpty);
        } finally {
          await database.customStatement("ALTER TABLE screenplays_gone RENAME TO screenplays");
        }

        expect(await readStoredValue(database), "Zoe");

        await closeAll(rolesBloc, bloc);
      },
    );

    test(
      "are dropped, the role and the candidate notes alike, when the mode says writing failed",
      () async {
        final bloc = buildBloc();
        final rolesBloc = buildRoles(bloc, fieldEditDebounce: _neverDebounce);
        await waitForState(bloc, (state) => !state.isLoading);
        final roleId = await createRole(bloc, rolesBloc);
        rolesBloc.add(
          OcptResourcesRoleFieldChangedEvent(
            roleId: roleId,
            field: OcptRoleField.castingNotes,
            rawValue: "Zoe",
          ),
        );
        await waitForState(rolesBloc, (state) => state.pendingRoleFieldEdits.isNotEmpty);

        bloc.add(const OcptResourcesPendingEditsLostEvent());
        await waitForState(rolesBloc, (state) => state.pendingRoleFieldEdits.isEmpty);

        expect(bloc.state.hasWriteError, isTrue);

        await closeAll(rolesBloc, bloc);
      },
    );
  });

  group("a flush that fails", () {
    test(
      "drops the edits of every sheet, shows the one write error and writes nothing after",
      () async {
        final bloc = buildBloc();
        final peopleBloc = OcptResourcesPeopleBloc(
          modeBloc: bloc,
          projectsManager: projectsManager,
          fieldEditDebounce: _neverDebounce,
        );
        final rolesBloc = buildRoles(bloc, fieldEditDebounce: _neverDebounce);
        await waitForState(bloc, (state) => !state.isLoading);
        final personId = await seedPerson(bloc);
        final roleId = await createRole(bloc, rolesBloc);

        peopleBloc.add(
          OcptResourcesPersonFieldChangedEvent(
            personId: personId,
            field: OcptPersonField.firstName,
            rawValue: "Alicia",
          ),
        );
        rolesBloc.add(
          OcptResourcesRoleFieldChangedEvent(
            roleId: roleId,
            field: OcptRoleField.castingNotes,
            rawValue: "Zoe",
          ),
        );
        await waitForState(peopleBloc, (state) => state.pendingFieldEdits.isNotEmpty);
        await waitForState(rolesBloc, (state) => state.pendingRoleFieldEdits.isNotEmpty);
        final database = projectsManager.currentProject!.database;

        // The people write fails; the role's note was not written yet and must not be afterwards.
        await database.customStatement("ALTER TABLE people RENAME TO people_gone");
        try {
          final mayProceed = await bloc.flushAllPendingWrites();

          expect(mayProceed, isTrue);
          expect(bloc.state.hasWriteError, isTrue);
          expect(peopleBloc.state.pendingFieldEdits, isEmpty);
          expect(rolesBloc.state.pendingRoleFieldEdits, isEmpty);
        } finally {
          await database.customStatement("ALTER TABLE people_gone RENAME TO people");
        }

        final roles = await projectsManager.roleIndexService
            .loadRoles(database: database)
            .valueOrFail;
        expect(roles.single.castingNotes, isEmpty);

        await peopleBloc.close();
        await closeAll(rolesBloc, bloc);
      },
    );
  });

  group("role candidates", () {
    /// Creates a hand-added role, a person, and a live candidacy pairing the two. Returns the
    /// role's id, the person's id and the candidacy's own id.
    Future<(String roleId, String personId, String candidateId)> addCandidate(
      OcptResourcesBloc bloc,
      OcptResourcesRolesBloc rolesBloc,
    ) async {
      final roleId = await createRole(bloc, rolesBloc);
      final personId = await seedPerson(bloc);

      rolesBloc.add(OcptResourcesRoleCandidateAddedEvent(roleId: roleId, personId: personId));
      final withCandidate = await waitForState(
        bloc,
        (state) => state.candidatesOfRole(roleId).length == 1,
      );

      return (roleId, personId, withCandidate.candidatesOfRole(roleId).single.id);
    }

    test("adding a candidate reloads the snapshot with the new candidacy", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      final (roleId, personId, _) = await addCandidate(bloc, rolesBloc);

      expect(bloc.state.candidatesOfRole(roleId).single.person.id, personId);
      expect(bloc.state.candidatesOfRole(roleId).single.status, OcptRoleCandidateStatus.spotted);

      await closeAll(rolesBloc, bloc);
    });

    test("a status change goes through the service, keeping roles.personId in step", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      final (roleId, personId, candidateId) = await addCandidate(bloc, rolesBloc);

      rolesBloc.add(
        OcptResourcesRoleCandidateStatusChangedEvent(
          candidateId: candidateId,
          status: OcptRoleCandidateStatus.retained,
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.candidatesOfRole(roleId).single.status == OcptRoleCandidateStatus.retained,
      );

      // The retained rule lives in OcptRoleCandidatesService alone: this event only asked for the
      // status change, and the role's own casting followed it.
      expect(state.roles.firstWhere((role) => role.id == roleId).personId, personId);

      await closeAll(rolesBloc, bloc);
    });

    test(
      "a debounced note edit lands in the pending candidate edits and is written once flushed",
      () async {
        final bloc = buildBloc();
        final rolesBloc = buildRoles(bloc);
        await waitForState(bloc, (state) => !state.isLoading);

        final (roleId, _, candidateId) = await addCandidate(bloc, rolesBloc);

        rolesBloc.add(
          OcptResourcesRoleCandidateFieldChangedEvent(
            candidateId: candidateId,
            field: OcptRoleCandidateField.notes,
            rawValue: "Great look for the part",
          ),
        );
        await waitForState(
          rolesBloc,
          (state) =>
              state.pendingCandidateFieldEdits[(candidateId, OcptRoleCandidateField.notes)] ==
              "Great look for the part",
        );
        // Not written yet: still the field's default empty value.
        expect(bloc.state.candidatesOfRole(roleId).single.notes, isEmpty);

        await waitForState(
          bloc,
          (state) => state.candidatesOfRole(roleId).single.notes == "Great look for the part",
        );
        await waitForState(rolesBloc, (state) => state.pendingCandidateFieldEdits.isEmpty);

        await closeAll(rolesBloc, bloc);
      },
    );

    test("removing a candidate drops its pending edit and its row", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);

      final (roleId, _, candidateId) = await addCandidate(bloc, rolesBloc);

      rolesBloc.add(
        OcptResourcesRoleCandidateFieldChangedEvent(
          candidateId: candidateId,
          field: OcptRoleCandidateField.notes,
          rawValue: "typing…",
        ),
      );
      await waitForState(rolesBloc, (state) => state.pendingCandidateFieldEdits.isNotEmpty);

      rolesBloc.add(OcptResourcesRoleCandidateRemovedEvent(candidateId: candidateId));
      await waitForState(bloc, (state) => state.candidatesOfRole(roleId).isEmpty);
      final state = await waitForState(
        rolesBloc,
        (state) => state.pendingCandidateFieldEdits.isEmpty,
      );

      expect(state.pendingCandidateFieldEdits, isEmpty);

      await closeAll(rolesBloc, bloc);
    });

    test("a candidate's audition date is written immediately", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      final (roleId, _, candidateId) = await addCandidate(bloc, rolesBloc);
      final auditionedOn = DateTime(2026, 3, 12);

      rolesBloc.add(
        OcptResourcesRoleCandidateAuditionDateChangedEvent(
          candidateId: candidateId,
          auditionedOn: auditionedOn,
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.candidatesOfRole(roleId).single.auditionedOn == auditionedOn,
      );

      expect(state.candidatesOfRole(roleId).single.auditionedOn, auditionedOn);

      await closeAll(rolesBloc, bloc);
    });
  });

  group("the events of the roles bloc", () {
    String nameOf(OcptResourcesRolesEvent event) => switch (event) {
      OcptResourcesRoleCreationRequestedEvent() => "creation",
      OcptResourcesRoleFieldChangedEvent() => "field",
      OcptResourcesRoleCastChangedEvent() => "cast",
      OcptResourcesRoleKindChangedEvent() => "kind",
      OcptResourcesRoleEpisodesChangedEvent() => "episodes",
      OcptResourcesRoleDeletionRequestedEvent() => "deletion",
      OcptResourcesOrphanedRoleKeptEvent() => "orphan kept",
      OcptResourcesRoleMergeRequestedEvent() => "merge",
      OcptResourcesRoleCandidateAddedEvent() => "candidate added",
      OcptResourcesRoleCandidateStatusChangedEvent() => "candidate status",
      OcptResourcesRoleCandidateAuditionDateChangedEvent() => "candidate audition date",
      OcptResourcesRoleCandidateFieldChangedEvent() => "candidate field",
      OcptResourcesRoleCandidateRemovedEvent() => "candidate removed",
      OcptResourcesRolesFieldEditFlushRequestedEvent() => "field flush",
    };

    test("every event of its hierarchy has a handler", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      final events = <OcptResourcesRolesEvent>[
        const OcptResourcesRoleCreationRequestedEvent(kind: OcptRoleKind.extra),
        const OcptResourcesRoleFieldChangedEvent(
          roleId: "r",
          field: OcptRoleField.name,
          rawValue: "",
        ),
        const OcptResourcesRoleCastChangedEvent(roleId: "r", personId: null),
        const OcptResourcesRoleKindChangedEvent(roleId: "r", kind: OcptRoleKind.extra),
        const OcptResourcesRoleEpisodesChangedEvent(roleId: "r", episodeIds: {}),
        const OcptResourcesRoleDeletionRequestedEvent(roleId: "r"),
        const OcptResourcesOrphanedRoleKeptEvent(roleId: "r"),
        const OcptResourcesRoleMergeRequestedEvent(sourceRoleId: "a", targetRoleId: "b"),
        const OcptResourcesRoleCandidateAddedEvent(roleId: "r", personId: "p"),
        const OcptResourcesRoleCandidateStatusChangedEvent(
          candidateId: "c",
          status: OcptRoleCandidateStatus.seen,
        ),
        const OcptResourcesRoleCandidateAuditionDateChangedEvent(
          candidateId: "c",
          auditionedOn: null,
        ),
        const OcptResourcesRoleCandidateFieldChangedEvent(
          candidateId: "c",
          field: OcptRoleCandidateField.notes,
          rawValue: "",
        ),
        const OcptResourcesRoleCandidateRemovedEvent(candidateId: "c"),
        const OcptResourcesRolesFieldEditFlushRequestedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(14));

      // With no project open every write handler returns at its first line: the handlers are
      // reached without any of the rows the events name having to exist.
      await projectsManager.closeCurrentProject();

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => rolesBloc.add(event), returnsNormally, reason: nameOf(event));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await closeAll(rolesBloc, bloc);
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      final rolesBloc = buildRoles(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);

      await closeAll(rolesBloc, bloc);
    });
  });
}
