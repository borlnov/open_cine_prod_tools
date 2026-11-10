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
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
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

/// What the roles bloc does when the database refuses a write on a candidacy, or the mode cannot
/// read the candidacies: the handler raises the mode's write error, reads nothing again, and goes
/// on once the refusal is lifted.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptResourcesBloc modeBloc;
  late OcptResourcesRolesBloc rolesBloc;
  late String personId;
  late String otherPersonId;
  late String roleId;
  late String candidateId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Wait for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Build a mode bloc on the test project.
  OcptResourcesBloc buildMode() => OcptResourcesBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_candidates_failure_test_");
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
    personId = (await projectsManager.peopleService
        .createPerson(database: project.database)
        .valueOrFail);
    otherPersonId = (await projectsManager.peopleService
        .createPerson(database: project.database)
        .valueOrFail);
    roleId = (await projectsManager.roleIndexService
        .addRole(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          name: "",
          kind: OcptRoleKind.silent,
        )
        .valueOrFail);
    candidateId = await projectsManager.roleCandidatesService
        .addCandidate(database: project.database, roleId: roleId, personId: personId)
        .valueOrFail;

    modeBloc = buildMode();
    rolesBloc = OcptResourcesRolesBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    await waitForState(modeBloc, (state) => !state.isLoading);
    await modeBloc.reload({OcptResourcesReloadScope.snapshot});
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

  /// Add a candidacy straight through the service, which the mode does not know until it reads
  /// again: a handler that stopped on the failure leaves the mode ignorant of it.
  Future<void> addCandidacyBehindTheModesBack() => projectsManager.roleCandidatesService
      .addCandidate(
        database: projectsManager.currentProject!.database,
        roleId: roleId,
        personId: otherPersonId,
      )
      .maybeValueOrFail;

  /// Tell whether the mode read the candidacies again within a moment.
  Future<bool> modeReadsAgain() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    return modeBloc.state.candidatesOfRole(roleId).length > 1;
  }

  /// The candidacy the fixture works on, as the mode shows it.
  OcptRoleCandidate shown() => modeBloc.state
      .candidatesOfRole(roleId)
      .firstWhere((candidate) => candidate.id == candidateId);

  test("a refused candidacy creation raises the write error and adds none", () async {
    await refuse("INSERT", "role_candidates");

    rolesBloc.add(OcptResourcesRoleCandidateAddedEvent(roleId: roleId, personId: otherPersonId));
    final state = await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(state.candidatesOfRole(roleId), hasLength(1));
    expect(await modeReadsAgain(), isFalse);

    await allow("INSERT", "role_candidates");
    rolesBloc.add(OcptResourcesRoleCandidateAddedEvent(roleId: roleId, personId: otherPersonId));
    await waitForState(modeBloc, (state) => state.candidatesOfRole(roleId).length == 2);
  });

  test("a refused status change raises the write error and keeps the status", () async {
    await refuse("UPDATE", "role_candidates");
    await addCandidacyBehindTheModesBack();

    rolesBloc.add(
      OcptResourcesRoleCandidateStatusChangedEvent(
        candidateId: candidateId,
        status: OcptRoleCandidateStatus.shortlisted,
      ),
    );
    await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(shown().status, OcptRoleCandidateStatus.spotted);
    expect(await modeReadsAgain(), isFalse);

    await allow("UPDATE", "role_candidates");
    rolesBloc.add(
      OcptResourcesRoleCandidateStatusChangedEvent(
        candidateId: candidateId,
        status: OcptRoleCandidateStatus.shortlisted,
      ),
    );
    await waitForState(modeBloc, (state) => shown().status == OcptRoleCandidateStatus.shortlisted);
  });

  test("a retaining refused on the cast column leaves the candidacies as they were", () async {
    await refuse("UPDATE", "roles");
    final other = await projectsManager.roleCandidatesService
        .addCandidate(
          database: projectsManager.currentProject!.database,
          roleId: roleId,
          personId: otherPersonId,
        )
        .valueOrFail;
    await modeBloc.reload({OcptResourcesReloadScope.snapshot});

    rolesBloc.add(
      OcptResourcesRoleCandidateStatusChangedEvent(
        candidateId: other,
        status: OcptRoleCandidateStatus.retained,
      ),
    );
    await waitForState(modeBloc, (state) => state.hasWriteError);

    final statuses = await projectsManager.currentProject!.database
        .customSelect("SELECT status FROM role_candidates ORDER BY id")
        .get();
    expect(
      {for (final row in statuses) row.data["status"]},
      {OcptRoleCandidateStatus.spotted.name},
      reason: "neither the retained status nor the turn-down of the others was kept",
    );
  });

  test("a refused audition date raises the write error and keeps the date", () async {
    await refuse("UPDATE", "role_candidates");
    await addCandidacyBehindTheModesBack();

    rolesBloc.add(
      OcptResourcesRoleCandidateAuditionDateChangedEvent(
        candidateId: candidateId,
        auditionedOn: DateTime(2026, 3, 5),
      ),
    );
    await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(shown().auditionedOn, isNull);
    expect(await modeReadsAgain(), isFalse);

    await allow("UPDATE", "role_candidates");
    rolesBloc.add(
      OcptResourcesRoleCandidateAuditionDateChangedEvent(
        candidateId: candidateId,
        auditionedOn: DateTime(2026, 3, 5),
      ),
    );
    await waitForState(modeBloc, (state) => shown().auditionedOn != null);
  });

  test("a refused removal raises the write error, keeps the candidacy and reads nothing", () async {
    await refuse("UPDATE", "role_candidates");
    await addCandidacyBehindTheModesBack();

    rolesBloc.add(OcptResourcesRoleCandidateRemovedEvent(candidateId: candidateId));
    await waitForState(modeBloc, (state) => state.hasWriteError);

    expect(modeBloc.state.candidatesOfRole(roleId).single.id, candidateId);
    expect(await modeReadsAgain(), isFalse);

    await allow("UPDATE", "role_candidates");
    rolesBloc.add(OcptResourcesRoleCandidateRemovedEvent(candidateId: candidateId));
    await waitForState(
      modeBloc,
      (state) => state.candidatesOfRole(roleId).every((candidate) => candidate.id != candidateId),
    );
  });

  test("a refused flush of a typed note keeps the edit and raises the write error", () async {
    await refuse("UPDATE", "role_candidates");
    rolesBloc.add(
      OcptResourcesRoleCandidateFieldChangedEvent(
        candidateId: candidateId,
        field: OcptRoleCandidateField.notes,
        rawValue: "Very good",
      ),
    );
    await waitForState(rolesBloc, (state) => state.pendingCandidateFieldEdits.isNotEmpty);

    final mayProceed = await modeBloc.flushAllPendingWrites();

    expect(mayProceed, isFalse);
    expect(modeBloc.state.hasWriteError, isTrue);
    expect(rolesBloc.state.pendingCandidateFieldEdits, hasLength(1));
    expect(rolesBloc.state.pendingCandidateFieldEdits.values.single, "Very good");
    expect(shown().notes, isEmpty);
  });

  test("a refused flush on leaving writes nothing and keeps nothing as written", () async {
    await refuse("UPDATE", "role_candidates");
    rolesBloc.add(
      OcptResourcesRoleCandidateFieldChangedEvent(
        candidateId: candidateId,
        field: OcptRoleCandidateField.notes,
        rawValue: "Very good",
      ),
    );
    await waitForState(rolesBloc, (state) => state.pendingCandidateFieldEdits.isNotEmpty);

    await rolesBloc.flushPendingWritesWithoutState();
    await allow("UPDATE", "role_candidates");
    await rolesBloc.flushPendingWritesWithoutState();

    await modeBloc.reload({OcptResourcesReloadScope.snapshot});
    expect(shown().notes, "Very good", reason: "the failed write was forgotten, so it is retried");
  });

  group("a read of the candidacies the database refuses", () {
    test("leaves the data the mode shows as it was, and raises the write error", () async {
      await projectsManager.currentProject!.database.customStatement(
        "ALTER TABLE role_candidates RENAME TO role_candidates_gone",
      );
      final snapshot = modeBloc.state.snapshot;

      expect(await modeBloc.reload({OcptResourcesReloadScope.snapshot}), isFalse);

      expect(modeBloc.state.snapshot, same(snapshot));
      expect(modeBloc.state.hasWriteError, isTrue);
    });

    test("leaves the mode loading when it cannot read at all", () async {
      await projectsManager.currentProject!.database.customStatement(
        "ALTER TABLE role_candidates RENAME TO role_candidates_gone",
      );

      final fresh = buildMode();
      addTearDown(fresh.close);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(fresh.state.isLoading, isTrue);
    });

    test("after a project setting change the mode keeps what it shows", () async {
      await projectsManager.currentProject!.database.customStatement(
        "ALTER TABLE role_candidates RENAME TO role_candidates_gone",
      );
      final snapshot = modeBloc.state.snapshot;

      modeBloc.add(const OcptResourcesProjectSettingsChangedEvent());
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(modeBloc.state.snapshot, same(snapshot));
    });
  });
}
