// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_tracking_flag.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  final _popCompleter = Completer<void>();

  /// Completes the moment [pop] is called.
  Future<void> get onPop => _popCompleter.future;

  /// Records the call instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete();
    }
  }
}

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
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_bloc_test_");
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

  /// Builds a bloc wired to the test project. [fieldEditDebounce] defaults to a short duration so
  /// tests exercising the field-edit debounce don't have to wait out the real 2 s one, and
  /// [overrideProjectsManager] lets a test swap in a manager of its own (already holding an open
  /// project) when it needs to.
  OcptResourcesBloc buildBloc({
    OcptRouterManager? routerManager,
    OcptProjectsManager? overrideProjectsManager,
    OcptResourcesRevealRequest? revealRequest,
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
    String? selectedEpisodeId,
  }) => OcptResourcesBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    revealRequest: revealRequest,
    fieldEditDebounce: fieldEditDebounce,
    selectedEpisodeId: selectedEpisodeId,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptResourcesState> waitForState(
    OcptResourcesBloc bloc,
    bool Function(OcptResourcesState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Adds a person to the address book behind the mode's back, as a view's own write would, and has
  /// the mode read the catalogue again so it holds them. Selects nobody.
  Future<String> seedPerson(OcptResourcesBloc bloc) async {
    final personId = await projectsManager.peopleService.createPerson(
      database: projectsManager.currentProject!.database,
    );
    await bloc.reload({OcptResourcesReloadScope.snapshot});

    return personId!;
  }

  /// Adds a hand-added role to the cast behind the mode's back, as a view's own write would, and
  /// has the mode read the catalogue again so it holds it. Selects nothing.
  Future<String> seedRole(OcptResourcesBloc bloc) async {
    final project = projectsManager.currentProject!;
    final roleId = await projectsManager.roleIndexService.addRole(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      name: "",
      kind: OcptRoleKind.silent,
    );
    await bloc.reload({OcptResourcesReloadScope.snapshot});

    return roleId!;
  }

  /// Adds a location to the list behind the mode's back, as a view's own write would, and has the
  /// mode read the catalogue again so it holds it. Selects nothing.
  Future<String> seedLocation(OcptResourcesBloc bloc) async {
    final locationId = await projectsManager.locationsService.createLocation(
      database: projectsManager.currentProject!.database,
      name: "",
    );
    await bloc.reload({OcptResourcesReloadScope.snapshot});

    return locationId!;
  }

  group("the epochs the views react to", () {
    test("entering the mode moves both epochs and says why", () async {
      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.reloadEpoch, greaterThan(0));
      expect(state.selectionEpoch, greaterThan(0));
      expect(state.selectionCause, OcptResourcesSelectionCause.load);

      await bloc.close();
    });

    test("reading the snapshot again answers true and moves the reload epoch alone", () async {
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      // Written behind the mode's back, as a view's own write would be.
      final project = projectsManager.currentProject!;
      await project.database
          .into(project.database.ocptPeopleTable)
          .insert(OcptPeopleTableCompanion.insert(id: "person-1"));

      final hasRead = await bloc.reload({OcptResourcesReloadScope.snapshot});

      expect(hasRead, isTrue);
      expect(bloc.state.peopleCount, 1);
      expect(bloc.state.reloadEpoch, greaterThan(loaded.reloadEpoch));
      expect(bloc.state.selectionEpoch, loaded.selectionEpoch);

      await bloc.close();
    });

    test("reading again with no project open answers false and moves nothing", () async {
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      await projectsManager.closeCurrentProject();

      final hasRead = await bloc.reload({OcptResourcesReloadScope.snapshot});

      expect(hasRead, isFalse);
      expect(bloc.state.reloadEpoch, loaded.reloadEpoch);

      await bloc.close();
    });

    test("a selection moves the selection epoch with its own cause, a stale one does not", () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await seedPerson(bloc);
      final seeded = bloc.state;

      bloc.add(OcptResourcesPersonSelectedEvent(personId: personId));
      final selected = await waitForState(
        bloc,
        (state) => state.selectionEpoch > seeded.selectionEpoch,
      );
      expect(selected.selectionCause, OcptResourcesSelectionCause.person);

      // Selecting the person again is still a move: the views are told even though nothing changed.
      bloc.add(OcptResourcesPersonSelectedEvent(personId: personId));
      final reselected = await waitForState(
        bloc,
        (state) => state.selectionEpoch > selected.selectionEpoch,
      );
      expect(reselected.selectedPersonId, personId);

      bloc.add(const OcptResourcesPersonSelectedEvent(personId: "ghost"));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.selectionEpoch, reselected.selectionEpoch);

      await bloc.close();
    });

    test("a tab change moves the selection epoch, re-selecting the active tab does not", () async {
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.people));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.selectionEpoch, loaded.selectionEpoch);

      bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.locations));
      final changed = await waitForState(
        bloc,
        (state) => state.selectionEpoch > loaded.selectionEpoch,
      );
      expect(changed.selectionCause, OcptResourcesSelectionCause.tab);

      await bloc.close();
    });

    test("selecting a record a view created moves the epoch and keeps the tab", () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await seedPerson(bloc);
      final seeded = bloc.state;

      await bloc.addAndWait(
        OcptResourcesRecordCreatedEvent(tab: OcptResourcesTab.people, recordId: personId),
      );

      expect(bloc.state.selectedPersonId, personId);
      expect(bloc.state.activeTab, OcptResourcesTab.people);
      expect(bloc.state.selectionEpoch, greaterThan(seeded.selectionEpoch));
      expect(bloc.state.selectionCause, OcptResourcesSelectionCause.created);

      await bloc.close();
    });

    test("dropping the selected record clears it, dropping another one does not", () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await seedPerson(bloc);
      await bloc.addAndWait(
        OcptResourcesRecordCreatedEvent(tab: OcptResourcesTab.people, recordId: personId),
      );
      final selected = bloc.state;

      await bloc.addAndWait(
        const OcptResourcesRecordDroppedEvent(tab: OcptResourcesTab.people, recordId: "other"),
      );
      expect(bloc.state.selectedPersonId, personId);
      expect(bloc.state.selectionEpoch, selected.selectionEpoch);

      await bloc.addAndWait(
        OcptResourcesRecordDroppedEvent(tab: OcptResourcesTab.people, recordId: personId),
      );
      expect(bloc.state.selectedPersonId, isNull);
      expect(bloc.state.selectionEpoch, greaterThan(selected.selectionEpoch));
      expect(bloc.state.selectionCause, OcptResourcesSelectionCause.dropped);

      await bloc.close();
    });

    test("a write that replaces the snapshot moves the reload epoch by itself", () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      await seedPerson(bloc);
      final seeded = bloc.state;

      bloc.add(const OcptResourcesSearchToggledEvent());
      final searching = await waitForState(bloc, (state) => state.isSearchVisible);

      expect(searching.reloadEpoch, seeded.reloadEpoch);
      expect(seeded.reloadEpoch, greaterThan(0));

      await bloc.close();
    });

    test(
      "a write error reported by a view is shown, and lost edits are told to every view",
      () async {
        final bloc = buildBloc();
        final loaded = await waitForState(bloc, (state) => !state.isLoading);

        bloc.add(const OcptResourcesWriteFailedEvent());
        final failed = await waitForState(bloc, (state) => state.hasWriteError);
        expect(failed.lostEditsEpoch, loaded.lostEditsEpoch);

        bloc.add(const OcptResourcesWriteErrorDismissedEvent());
        await waitForState(bloc, (state) => !state.hasWriteError);

        await bloc.addAndWait(const OcptResourcesPendingEditsLostEvent());
        expect(bloc.state.hasWriteError, isTrue);
        expect(bloc.state.lostEditsEpoch, greaterThan(loaded.lostEditsEpoch));
        expect(bloc.state.reloadEpoch, greaterThan(loaded.reloadEpoch));

        await bloc.close();
      },
    );
  });

  test("loads an empty catalogue with every count at zero", () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.title, "My Movie");
    expect(state.peopleCount, 0);
    expect(state.roleCount, 0);
    expect(state.positionCount, 0);
    expect(state.locationCount, 0);
    expect(state.elementCount, 0);
    expect(state.selectedPersonId, isNull);

    await bloc.close();
  });

  test("the project settings changed event reloads the snapshot from the database", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    // Written directly against the database, bypassing the bloc entirely: the resources catalogue
    // isn't something the project settings page writes, so this is what a change this bloc
    // doesn't otherwise know about has to look like from its point of view.
    final project = projectsManager.currentProject!;
    await project.database
        .into(project.database.ocptPeopleTable)
        .insert(OcptPeopleTableCompanion.insert(id: "person-1"));

    bloc.add(const OcptResourcesProjectSettingsChangedEvent());
    final state = await waitForState(bloc, (state) => state.peopleCount == 1);

    expect(state.peopleCount, 1);

    await bloc.close();
  });

  test("the project settings changed event re-reads the currency", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final initialCode = bloc.state.currencyCode;
    final otherCode = initialCode == "USD" ? "GBP" : "USD";

    await projectsManager.saveCurrentProjectCurrencyCode(otherCode);

    bloc.add(const OcptResourcesProjectSettingsChangedEvent());
    final state = await waitForState(bloc, (state) => state.currencyCode == otherCode);

    expect(state.currencyCode, otherCode);

    await bloc.close();
  });

  test("the initial load reads the project's currency", () async {
    await projectsManager.saveCurrentProjectCurrencyCode("GBP");

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.currencyCode, "GBP");

    await bloc.close();
  });

  test("selecting a tab other than people clears the selected person", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    final personId = await seedPerson(bloc);
    bloc.add(OcptResourcesPersonSelectedEvent(personId: personId));
    await waitForState(bloc, (state) => state.selectedPersonId != null);

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.roles));
    final state = await waitForState(bloc, (state) => state.selectedPersonId == null);

    expect(state.activeTab, OcptResourcesTab.roles);

    await bloc.close();
  });

  test("opening search opens the left dock when it was closed", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesLeftPanelToggledEvent());
    await waitForState(bloc, (state) => !state.isListPanelVisible);

    bloc.add(const OcptResourcesSearchToggledEvent());
    final state = await waitForState(bloc, (state) => state.isSearchVisible);

    expect(state.isListPanelVisible, isTrue);

    await bloc.close();
  });

  test("opening search leaves an already-open left dock open", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesSearchToggledEvent());
    final state = await waitForState(bloc, (state) => state.isSearchVisible);

    expect(state.isListPanelVisible, isTrue);

    await bloc.close();
  });

  test("a typed query is applied to the state immediately, with no debounce", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesSearchToggledEvent());
    await waitForState(bloc, (state) => state.isSearchVisible);

    bloc.add(const OcptResourcesSearchQueryChangedEvent(query: "léa"));
    final state = await waitForState(bloc, (state) => state.searchQuery == "léa");

    expect(state.searchQuery, "léa");

    await bloc.close();
  });

  test("closing search clears whatever query was typed", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesSearchToggledEvent());
    await waitForState(bloc, (state) => state.isSearchVisible);
    bloc.add(const OcptResourcesSearchQueryChangedEvent(query: "léa"));
    await waitForState(bloc, (state) => state.searchQuery == "léa");

    bloc.add(const OcptResourcesSearchToggledEvent());
    final state = await waitForState(bloc, (state) => !state.isSearchVisible);

    expect(state.searchQuery, isEmpty);

    await bloc.close();
  });

  test("changing tab clears the query but leaves the search field open", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesSearchToggledEvent());
    await waitForState(bloc, (state) => state.isSearchVisible);
    bloc.add(const OcptResourcesSearchQueryChangedEvent(query: "léa"));
    await waitForState(bloc, (state) => state.searchQuery == "léa");

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.roles));
    final state = await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.roles);

    expect(state.searchQuery, isEmpty);
    expect(state.isSearchVisible, isTrue);

    await bloc.close();
  });

  test("re-selecting the already-active tab leaves the query untouched", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesSearchToggledEvent());
    await waitForState(bloc, (state) => state.isSearchVisible);
    bloc.add(const OcptResourcesSearchQueryChangedEvent(query: "léa"));
    await waitForState(bloc, (state) => state.searchQuery == "léa");

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.people));
    // Reselecting the tab already active is not a tab change, so it may emit no new state at all:
    // the assertion is that the bloc settles back with the query untouched.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.searchQuery, "léa");

    await bloc.close();
  });

  test("going back closes the current project and pops", () async {
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(routerManager: routerManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesBackRequestedEvent());
    await routerManager.onPop.timeout(const Duration(seconds: 5));

    expect(projectsManager.currentProject, isNull);

    await bloc.close();
  });

  test("previewing a version emits its own catalogue together with its id", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    // A person created before the version is captured, so it belongs to it.
    await seedPerson(bloc);

    bloc.add(const OcptProjectVersionCreationRequestedEvent(name: "Cast locked", note: ""));
    final withVersion = await waitForState(bloc, (state) => state.projectVersions.isNotEmpty);
    final versionId = withVersion.projectVersions.single.id;

    // A second person, created after the version, must not be part of what it holds.
    await seedPerson(bloc);

    bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    final previewing = await waitForState(bloc, (state) => state.previewedVersionId != null);

    // The version's own id and the catalogue it was captured with land in the very same state.
    expect(previewing.previewedVersionId, versionId);
    expect(previewing.peopleCount, 1);
    expect(previewing.isPreviewingVersion, isTrue);

    await bloc.close();
  });

  group("the compact role alert banner", () {
    test("selecting a role from another tab switches to the roles tab too", () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final roleId = await seedRole(bloc);

      // Away from the roles tab, exactly as tapping a compact banner line from anywhere else
      // would find the mode.
      bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.locations));
      await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.locations);

      bloc.add(OcptResourcesRoleSelectedEvent(roleId: roleId));
      final state = await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.roles);

      expect(state.selectedRoleId, roleId);

      await bloc.close();
    });

    test("orphanedRoleAlerts reports a role the screenplay no longer names", () async {
      final project = projectsManager.currentProject!;
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: "INT. HOUSE - DAY\n\nCLARA\nHello.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );

      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => state.roleCount == 1);
      expect(loaded.orphanedRoleAlerts, isEmpty);

      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: "INT. HOUSE - DAY\n\nAction, no dialogue anymore.\n",
        snapshotReason: OcptSnapshotReason.manual,
      );
      bloc.add(const OcptResourcesProjectSettingsChangedEvent());
      final orphaned = await waitForState(bloc, (state) => state.orphanedRoleAlerts.isNotEmpty);

      expect(orphaned.orphanedRoleAlerts, hasLength(1));
      expect(orphaned.orphanedRoleAlerts.single.characterName, "CLARA");
      expect(orphaned.orphanedRoleAlerts.single.roleId, orphaned.roles.single.id);

      await bloc.close();
    });
  });

  test(
    "opening a person's sheet from the roles tab selects them on the people tab at once",
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      final personId = await seedPerson(bloc);

      bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.roles));
      await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.roles);

      bloc.add(OcptResourcesPersonSheetOpenRequestedEvent(personId: personId));
      final state = await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.people);

      expect(state.selectedPersonId, personId);

      await bloc.close();
    },
  );

  test("selecting another tab clears the selected location", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.locations));
    await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.locations);
    final locationId = await seedLocation(bloc);
    bloc.add(OcptResourcesLocationSelectedEvent(locationId: locationId));
    await waitForState(bloc, (state) => state.selectedLocationId != null);

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.people));
    final state = await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.people);

    expect(state.selectedLocationId, isNull);

    await bloc.close();
  });
  test("creating an element appends it in its own category and selects it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.vehicle),
    );
    final state = await waitForState(bloc, (state) => state.elementCount == 1);

    expect(state.selectedElementId, state.elements.single.id);
    expect(state.elements.single.category, OcptElementCategory.vehicle);
    expect(state.elements.single.sceneLinks, isEmpty);

    await bloc.close();
  });

  // Nobody can type a code, so one that no longer says which department the item comes from could
  // never be repaired: it follows every category change.
  test("changing an element's category renumbers its code", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;
    expect(created.selectedElement!.code, "PRP-1");

    bloc.add(
      OcptResourcesElementCategoryChangedEvent(
        elementId: elementId,
        category: OcptElementCategory.vehicle,
      ),
    );
    await waitForState(bloc, (state) => state.selectedElement!.code == "VEH-1");

    bloc.add(
      OcptResourcesElementCategoryChangedEvent(
        elementId: elementId,
        category: OcptElementCategory.costume,
      ),
    );
    final state = await waitForState(
      bloc,
      (state) => state.selectedElement!.category == OcptElementCategory.costume,
    );
    expect(state.selectedElement!.code, "COS-1");

    await bloc.close();
  });

  test("a typed element field edit is pending until the debounce writes it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(
      OcptResourcesElementFieldChangedEvent(
        elementId: elementId,
        field: OcptElementField.name,
        rawValue: "Vélo de Léa",
      ),
    );
    var state = await waitForState(
      bloc,
      (state) =>
          state.pendingElementFieldEdits[(elementId, OcptElementField.name)] == "Vélo de Léa",
    );
    expect(state.selectedElement!.name, isEmpty);

    state = await waitForState(bloc, (state) => state.selectedElement!.name == "Vélo de Léa");
    expect(state.pendingElementFieldEdits, isEmpty);

    await bloc.close();
  });

  // The cost is typed as money and stored as cents, and what cannot be read as an amount is stored
  // as no amount at all rather than as zero — a prop whose price is unknown is not a free one.
  test("a typed cost is stored in cents, and what isn't an amount as no cost at all", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(
      OcptResourcesElementFieldChangedEvent(
        elementId: elementId,
        field: OcptElementField.cost,
        rawValue: "12,50",
      ),
    );
    await waitForState(bloc, (state) => state.selectedElement!.cost == 1250);

    bloc.add(
      OcptResourcesElementFieldChangedEvent(
        elementId: elementId,
        field: OcptElementField.cost,
        rawValue: "gratuit",
      ),
    );
    final state = await waitForState(bloc, (state) => state.selectedElement!.cost == null);
    expect(state.pendingElementFieldEdits, isEmpty);

    await bloc.close();
  });

  test("the provenance, the owner, the bringer and the flags all land in the database", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final personId = await seedPerson(bloc);

    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(
      OcptResourcesElementSourceKindChangedEvent(
        elementId: elementId,
        sourceKind: OcptElementSourceKind.borrowed,
      ),
    );
    await waitForState(
      bloc,
      (state) => state.elements.single.sourceKind == OcptElementSourceKind.borrowed,
    );

    bloc.add(OcptResourcesElementOwnerChangedEvent(elementId: elementId, personId: personId));
    await waitForState(bloc, (state) => state.elements.single.ownerPersonId == personId);

    bloc.add(OcptResourcesElementBringerChangedEvent(elementId: elementId, personId: personId));
    await waitForState(bloc, (state) => state.elements.single.broughtByPersonId == personId);

    bloc.add(
      OcptResourcesElementTrackingFlagChangedEvent(
        elementId: elementId,
        flag: OcptElementTrackingFlag.secured,
        value: true,
      ),
    );
    final state = await waitForState(bloc, (state) => state.elements.single.isSecured);
    expect(state.elements.single.isReadyForShoot, isFalse);
    expect(state.elements.single.isReturned, isFalse);

    await bloc.close();
  });

  test("a scene is linked to an element, given its own quantity, then unlinked", () async {
    final project = projectsManager.currentProject!;
    await project.database
        .into(project.database.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: "scene-1",
            screenplayId: project.primaryScreenplayId,
            position: 0,
            heading: "INT. CUISINE - NUIT",
            charStart: 0,
            charEnd: 10,
          ),
        );

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(OcptResourcesSceneAssignedToElementEvent(sceneId: "scene-1", elementId: elementId));
    var state = await waitForState(bloc, (state) => state.elements.single.sceneLinks.isNotEmpty);
    final linkId = state.elements.single.sceneLinks.single.id;
    expect(state.elements.single.sceneLinks.single.sceneId, "scene-1");

    bloc.add(
      OcptResourcesSceneElementUpdatedEvent(id: linkId, quantity: "2", notes: "Dont un cassé"),
    );
    state = await waitForState(
      bloc,
      (state) => state.elements.single.sceneLinks.single.quantity == "2",
    );
    expect(state.elements.single.sceneLinks.single.notes, "Dont un cassé");

    bloc.add(OcptResourcesSceneElementRemovedEvent(id: linkId));
    state = await waitForState(bloc, (state) => state.elements.single.sceneLinks.isEmpty);

    await bloc.close();
  });

  test("linking an element to a role, noting it, then unlinking it", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    final roleId = await seedRole(bloc);

    bloc.add(
      const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.costume),
    );
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(OcptResourcesElementLinkedToRoleEvent(roleId: roleId, elementId: elementId));
    var state = await waitForState(bloc, (state) => state.elements.single.roleLinks.isNotEmpty);
    final linkId = state.elements.single.roleLinks.single.id;
    expect(state.elements.single.roleLinks.single.roleId, roleId);

    bloc.add(OcptResourcesRoleElementUpdatedEvent(id: linkId, notes: "Taché"));
    state = await waitForState(
      bloc,
      (state) => state.elements.single.roleLinks.single.notes == "Taché",
    );

    bloc.add(OcptResourcesRoleElementRemovedEvent(id: linkId));
    state = await waitForState(bloc, (state) => state.elements.single.roleLinks.isEmpty);

    // The element itself is untouched: only the link went.
    expect(state.elementCount, 1);

    await bloc.close();
  });

  test(
    "opening a role's sheet from the elements tab selects it on the roles tab at once",
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      final roleId = await seedRole(bloc);

      bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.elements));
      await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.elements);

      bloc.add(OcptResourcesRoleSheetOpenRequestedEvent(roleId: roleId));
      final state = await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.roles);

      expect(state.selectedRoleId, roleId);
      expect(state.selectedElementId, isNull);

      await bloc.close();
    },
  );

  test("deleting the selected element clears the selection and drops its pending edit", () async {
    final bloc = buildBloc(fieldEditDebounce: const Duration(seconds: 30));
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final created = await waitForState(bloc, (state) => state.elementCount == 1);
    final elementId = created.selectedElementId!;

    bloc.add(
      OcptResourcesElementFieldChangedEvent(
        elementId: elementId,
        field: OcptElementField.name,
        rawValue: "Valise",
      ),
    );
    await waitForState(bloc, (state) => state.pendingElementFieldEdits.isNotEmpty);

    bloc.add(OcptResourcesElementDeletionRequestedEvent(elementId: elementId));
    final state = await waitForState(bloc, (state) => state.elementCount == 0);
    expect(state.selectedElementId, isNull);
    expect(state.pendingElementFieldEdits, isEmpty);

    await bloc.close();
  });

  test("selecting another tab clears the selected element", () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.elements));
    await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.elements);
    bloc.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    await waitForState(bloc, (state) => state.selectedElementId != null);

    bloc.add(const OcptResourcesTabSelectedEvent(tab: OcptResourcesTab.people));
    final state = await waitForState(bloc, (state) => state.activeTab == OcptResourcesTab.people);
    expect(state.selectedElementId, isNull);

    await bloc.close();
  });

  test('the page setup used to prefill the contact list dialog is loaded on entry', () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.pageSetup.format, OcptPageFormat.usLetter);

    await bloc.close();
  });

  test("a reveal request opens its own tab with its record already selected", () async {
    final seed = buildBloc();
    await waitForState(seed, (state) => !state.isLoading);
    seed.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final seeded = await waitForState(seed, (state) => state.elementCount == 1);
    final elementId = seeded.selectedElementId!;
    await seed.close();

    final bloc = buildBloc(
      revealRequest: OcptResourcesRevealRequest(
        tab: OcptResourcesTab.elements,
        recordId: elementId,
      ),
    );
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.activeTab, OcptResourcesTab.elements);
    expect(state.selectedElementId, elementId);
    expect(state.selectedElement, isNotNull);

    await bloc.close();
  });

  // The load clears every selection, so a reveal re-applied on each one would yank the user back to
  // the revealed record every time a version preview is entered or left.
  test("a reveal request is applied to the first load only", () async {
    final seed = buildBloc();
    await waitForState(seed, (state) => !state.isLoading);
    seed.add(const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop));
    final seeded = await waitForState(seed, (state) => state.elementCount == 1);
    final elementId = seeded.selectedElementId!;
    await seed.close();

    final bloc = buildBloc(
      revealRequest: OcptResourcesRevealRequest(
        tab: OcptResourcesTab.elements,
        recordId: elementId,
      ),
    );
    await waitForState(bloc, (state) => state.selectedElementId == elementId);

    bloc.add(const OcptResourcesLoadRequestedEvent());
    final reloaded = await waitForState(bloc, (state) => state.selectedElementId == null);

    expect(reloaded.selectedElementId, isNull);

    await bloc.close();
  });

  test("a reveal request naming an unknown record only opens its tab", () async {
    final bloc = buildBloc(
      revealRequest: const OcptResourcesRevealRequest(
        tab: OcptResourcesTab.locations,
        recordId: "no-such-location",
      ),
    );

    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.activeTab, OcptResourcesTab.locations);
    expect(state.selectedLocationId, isNull);

    await bloc.close();
  });
}
