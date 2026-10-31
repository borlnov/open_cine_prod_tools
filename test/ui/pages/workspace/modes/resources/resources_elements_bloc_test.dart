// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_tracking_flag.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_elements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter for it
/// to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// A file selector manager answering the picker with a file of its own, so a test never opens a
/// native dialog: [pickedPath] is what the user is pretending to pick, and null is a cancellation.
class _StubFileSelectorManager extends FileSelectorManager {
  /// The path the next pick answers with, or null to answer as a cancelled dialog does.
  final String? pickedPath;

  /// Class constructor
  const _StubFileSelectorManager({required this.pickedPath});

  /// Answers with [pickedPath] instead of opening the platform's own dialog.
  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async {
    final pickedPath = this.pickedPath;
    if (pickedPath == null) {
      return const ResultWithBoolStatus(status: BoolResultStatus.error);
    }

    return ResultWithBoolStatus(status: BoolResultStatus.success, value: XFile(pickedPath));
  }
}

/// How long a view bloc waits before it writes what was typed, for the tests that wait for it.
const _shortDebounce = Duration(milliseconds: 30);

/// A debounce no test waits out, for the tests that must find an edit still pending.
const _neverDebounce = Duration(days: 1);

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
    tempDir = await Directory.systemTemp.createTemp("ocpt_resources_elements_bloc_test_");
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

  /// Builds the mode bloc wired to the test project.
  OcptResourcesBloc buildBloc() => OcptResourcesBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the elements bloc of [modeBloc], writing what is typed after [fieldEditDebounce].
  OcptResourcesElementsBloc buildElements(
    OcptResourcesBloc modeBloc, {
    Duration fieldEditDebounce = _shortDebounce,
    FileSelectorManager? fileSelectorManager,
  }) => OcptResourcesElementsBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    fileSelectorManager: fileSelectorManager,
    fieldEditDebounce: fieldEditDebounce,
  );

  /// The value the elements table holds in the column the test types into, whichever row.
  Future<String> readStoredValue(OcptProjectDatabase database) async {
    final row = await database.customSelect("SELECT notes AS value FROM elements").getSingle();
    return row.read<String>("value");
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Creates an element of [category] through [elementsBloc] and waits for the mode to select it.
  Future<String> createElement(
    OcptResourcesBloc modeBloc,
    OcptResourcesElementsBloc elementsBloc, {
    OcptElementCategory category = OcptElementCategory.prop,
  }) async {
    final before = modeBloc.state.elementCount;
    final previouslySelected = modeBloc.state.selectedElementId;
    elementsBloc.add(OcptResourcesElementCreationRequestedEvent(category: category));
    final state = await waitForState(
      modeBloc,
      (state) =>
          state.elementCount == before + 1 &&
          state.selectedElementId != null &&
          state.selectedElementId != previouslySelected,
    );

    return state.selectedElementId!;
  }

  /// Reads the elements catalogue straight from the database.
  Future<List<OcptElement>> readElements() => projectsManager.elementsService.loadElements(
    database: projectsManager.currentProject!.database,
  );

  /// Closes the blocs of a test, the view before its mode.
  Future<void> closeAll(OcptResourcesElementsBloc elementsBloc, OcptResourcesBloc modeBloc) async {
    await elementsBloc.close();
    await modeBloc.close();
  }

  group("creating and deleting an element", () {
    test("creating an element appends it in its own category and selects it", () async {
      final bloc = buildBloc();
      final elementsBloc = buildElements(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      await createElement(bloc, elementsBloc, category: OcptElementCategory.vehicle);
      final state = bloc.state;

      expect(state.selectedElementId, state.elements.single.id);
      expect(state.elements.single.category, OcptElementCategory.vehicle);
      expect(state.elements.single.sceneLinks, isEmpty);

      await closeAll(elementsBloc, bloc);
    });

    test("deleting the selected element clears the selection and drops its pending edit", () async {
      final bloc = buildBloc();
      final elementsBloc = buildElements(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      final elementId = await createElement(bloc, elementsBloc);

      elementsBloc.add(
        OcptResourcesElementFieldChangedEvent(
          elementId: elementId,
          field: OcptElementField.name,
          rawValue: "Valise",
        ),
      );
      await waitForState(elementsBloc, (state) => state.pendingElementFieldEdits.isNotEmpty);

      elementsBloc.add(OcptResourcesElementDeletionRequestedEvent(elementId: elementId));
      final state = await waitForState(
        bloc,
        (state) => state.elementCount == 0 && state.selectedElementId == null,
      );
      await waitForState(elementsBloc, (state) => state.pendingElementFieldEdits.isEmpty);

      expect(state.elements, isEmpty);
      expect(await readElements(), isEmpty);

      await closeAll(elementsBloc, bloc);
    });
  });

  group("the fields typed on an element's sheet", () {
    test("a typed element field edit is pending until the debounce writes it", () async {
      final bloc = buildBloc();
      final elementsBloc = buildElements(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final elementId = await createElement(bloc, elementsBloc);

      elementsBloc.add(
        OcptResourcesElementFieldChangedEvent(
          elementId: elementId,
          field: OcptElementField.name,
          rawValue: "Vélo de Léa",
        ),
      );
      await waitForState(
        elementsBloc,
        (state) =>
            state.pendingElementFieldEdits[(elementId, OcptElementField.name)] == "Vélo de Léa",
      );
      expect(bloc.state.selectedElement!.name, isEmpty);

      await waitForState(bloc, (state) => state.selectedElement!.name == "Vélo de Léa");
      await waitForState(elementsBloc, (state) => state.pendingElementFieldEdits.isEmpty);

      await closeAll(elementsBloc, bloc);
    });

    // The cost is typed as money and stored as cents, and what cannot be read as an amount is stored
    // as no amount at all rather than as zero — a prop whose price is unknown is not a free one.
    test("a typed cost is stored in cents, and what isn't an amount as no cost at all", () async {
      final bloc = buildBloc();
      final elementsBloc = buildElements(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final elementId = await createElement(bloc, elementsBloc);

      elementsBloc.add(
        OcptResourcesElementFieldChangedEvent(
          elementId: elementId,
          field: OcptElementField.cost,
          rawValue: "12,50",
        ),
      );
      await waitForState(bloc, (state) => state.selectedElement!.cost == 1250);

      elementsBloc.add(
        OcptResourcesElementFieldChangedEvent(
          elementId: elementId,
          field: OcptElementField.cost,
          rawValue: "gratuit",
        ),
      );
      await waitForState(bloc, (state) => state.selectedElement!.cost == null);
      await waitForState(elementsBloc, (state) => state.pendingElementFieldEdits.isEmpty);

      await closeAll(elementsBloc, bloc);
    });

    test("are written once when the widget leaves the tree and the bloc then closes", () async {
      final bloc = buildBloc();
      final elementsBloc = buildElements(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      final elementId = await createElement(bloc, elementsBloc);
      elementsBloc.add(
        OcptResourcesElementFieldChangedEvent(
          elementId: elementId,
          field: OcptElementField.notes,
          rawValue: "Fragile",
        ),
      );
      await waitForState(elementsBloc, (state) => state.pendingElementFieldEdits.isNotEmpty);

      await bloc.flushPendingFieldEdits();

      // The value is put back to blank behind the bloc's back: a second write of the same edit, which
      // the bloc closing would make without the memory of the first, would bring it back.
      final database = projectsManager.currentProject!.database;
      expect(await readStoredValue(database), "Fragile");
      await database.customStatement("UPDATE elements SET notes = ''");
      await closeAll(elementsBloc, bloc);

      expect(await readStoredValue(database), isEmpty);
    });

    test(
      "are written and forgotten, with the one write error, when the read after the write fails",
      () async {
        final bloc = buildBloc();
        final elementsBloc = buildElements(bloc, fieldEditDebounce: _neverDebounce);
        await waitForState(bloc, (state) => !state.isLoading);
        final elementId = await createElement(bloc, elementsBloc);
        elementsBloc.add(
          OcptResourcesElementFieldChangedEvent(
            elementId: elementId,
            field: OcptElementField.notes,
            rawValue: "Fragile",
          ),
        );
        await waitForState(elementsBloc, (state) => state.pendingElementFieldEdits.isNotEmpty);

        final database = projectsManager.currentProject!.database;
        // The write of an edit never touches the episodes, whereas the read of the catalogue after it
        // does: the write lands and the read fails.
        await database.customStatement("ALTER TABLE screenplays RENAME TO screenplays_gone");
        try {
          final mayProceed = await bloc.flushAllPendingWrites();

          expect(mayProceed, isTrue);
          expect(bloc.state.hasWriteError, isTrue);
          expect(elementsBloc.state.pendingElementFieldEdits, isEmpty);
        } finally {
          await database.customStatement("ALTER TABLE screenplays_gone RENAME TO screenplays");
        }

        expect(await readStoredValue(database), "Fragile");

        await closeAll(elementsBloc, bloc);
      },
    );

    test(
      "are written at once, and show on the mode, when the mode asks every view to write",
      () async {
        final bloc = buildBloc();
        final elementsBloc = buildElements(bloc, fieldEditDebounce: _neverDebounce);
        await waitForState(bloc, (state) => !state.isLoading);
        final elementId = await createElement(bloc, elementsBloc);
        elementsBloc.add(
          OcptResourcesElementFieldChangedEvent(
            elementId: elementId,
            field: OcptElementField.storageNotes,
            rawValue: "Cave",
          ),
        );
        await waitForState(elementsBloc, (state) => state.pendingElementFieldEdits.isNotEmpty);

        final mayProceed = await bloc.flushAllPendingWrites();

        expect(mayProceed, isTrue);
        expect(elementsBloc.state.pendingElementFieldEdits, isEmpty);
        expect(bloc.state.selectedElement!.storageNotes, "Cave");

        await closeAll(elementsBloc, bloc);
      },
    );

    test("are dropped when the mode says writing the typed edits failed", () async {
      final bloc = buildBloc();
      final elementsBloc = buildElements(bloc, fieldEditDebounce: _neverDebounce);
      await waitForState(bloc, (state) => !state.isLoading);
      final elementId = await createElement(bloc, elementsBloc);
      elementsBloc.add(
        OcptResourcesElementFieldChangedEvent(
          elementId: elementId,
          field: OcptElementField.name,
          rawValue: "Valise",
        ),
      );
      await waitForState(elementsBloc, (state) => state.pendingElementFieldEdits.isNotEmpty);

      bloc.add(const OcptResourcesPendingEditsLostEvent());
      await waitForState(elementsBloc, (state) => state.pendingElementFieldEdits.isEmpty);

      expect(bloc.state.hasWriteError, isTrue);
      expect(bloc.state.selectedElement!.name, isEmpty);

      await closeAll(elementsBloc, bloc);
    });
  });

  group("the other writes of an element's sheet", () {
    // Nobody can type a code, so one that no longer says which department the item comes from could
    // never be repaired: it follows every category change.
    test("changing an element's category renumbers its code", () async {
      final bloc = buildBloc();
      final elementsBloc = buildElements(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final elementId = await createElement(bloc, elementsBloc);
      expect(bloc.state.selectedElement!.code, "PRP-1");

      elementsBloc.add(
        OcptResourcesElementCategoryChangedEvent(
          elementId: elementId,
          category: OcptElementCategory.vehicle,
        ),
      );
      await waitForState(bloc, (state) => state.selectedElement!.code == "VEH-1");

      elementsBloc.add(
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

      await closeAll(elementsBloc, bloc);
    });

    test("the provenance, the owner, the bringer and the flags all land in the database", () async {
      final bloc = buildBloc();
      final elementsBloc = buildElements(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final personId = await projectsManager.peopleService.createPerson(
        database: projectsManager.currentProject!.database,
      );
      await bloc.reload({OcptResourcesReloadScope.snapshot});
      final elementId = await createElement(bloc, elementsBloc);

      elementsBloc.add(
        OcptResourcesElementSourceKindChangedEvent(
          elementId: elementId,
          sourceKind: OcptElementSourceKind.borrowed,
        ),
      );
      await waitForState(
        bloc,
        (state) => state.elements.single.sourceKind == OcptElementSourceKind.borrowed,
      );

      elementsBloc.add(
        OcptResourcesElementOwnerChangedEvent(elementId: elementId, personId: personId),
      );
      await waitForState(bloc, (state) => state.elements.single.ownerPersonId == personId);

      elementsBloc.add(
        OcptResourcesElementBringerChangedEvent(elementId: elementId, personId: personId),
      );
      await waitForState(bloc, (state) => state.elements.single.broughtByPersonId == personId);

      elementsBloc.add(
        OcptResourcesElementTrackingFlagChangedEvent(
          elementId: elementId,
          flag: OcptElementTrackingFlag.secured,
          value: true,
        ),
      );
      final state = await waitForState(bloc, (state) => state.elements.single.isSecured);
      expect(state.elements.single.isReadyForShoot, isFalse);
      expect(state.elements.single.isReturned, isFalse);

      await closeAll(elementsBloc, bloc);
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
      final elementsBloc = buildElements(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final elementId = await createElement(bloc, elementsBloc);

      elementsBloc.add(
        OcptResourcesSceneAssignedToElementEvent(sceneId: "scene-1", elementId: elementId),
      );
      var state = await waitForState(bloc, (state) => state.elements.single.sceneLinks.isNotEmpty);
      final linkId = state.elements.single.sceneLinks.single.id;
      expect(state.elements.single.sceneLinks.single.sceneId, "scene-1");

      elementsBloc.add(
        OcptResourcesSceneElementUpdatedEvent(id: linkId, quantity: "2", notes: "Dont un cassé"),
      );
      state = await waitForState(
        bloc,
        (state) => state.elements.single.sceneLinks.single.quantity == "2",
      );
      expect(state.elements.single.sceneLinks.single.notes, "Dont un cassé");

      elementsBloc.add(OcptResourcesSceneElementRemovedEvent(id: linkId));
      await waitForState(bloc, (state) => state.elements.single.sceneLinks.isEmpty);

      await closeAll(elementsBloc, bloc);
    });

    test("linking an element to a role, noting it, then unlinking it", () async {
      final bloc = buildBloc();
      final elementsBloc = buildElements(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      final roleId = await projectsManager.roleIndexService.addRole(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        name: "",
        kind: OcptRoleKind.silent,
      );
      await bloc.reload({OcptResourcesReloadScope.snapshot});
      final elementId = await createElement(
        bloc,
        elementsBloc,
        category: OcptElementCategory.costume,
      );

      elementsBloc.add(
        OcptResourcesElementLinkedToRoleEvent(roleId: roleId!, elementId: elementId),
      );
      var state = await waitForState(bloc, (state) => state.elements.single.roleLinks.isNotEmpty);
      final linkId = state.elements.single.roleLinks.single.id;
      expect(state.elements.single.roleLinks.single.roleId, roleId);

      elementsBloc.add(OcptResourcesRoleElementUpdatedEvent(id: linkId, notes: "Taché"));
      state = await waitForState(
        bloc,
        (state) => state.elements.single.roleLinks.single.notes == "Taché",
      );

      elementsBloc.add(OcptResourcesRoleElementRemovedEvent(id: linkId));
      state = await waitForState(bloc, (state) => state.elements.single.roleLinks.isEmpty);

      // The element itself is untouched: only the link went.
      expect(state.elementCount, 1);

      await closeAll(elementsBloc, bloc);
    });

    test("reference a photo the picker answered with, and nothing when it is cancelled", () async {
      final bloc = buildBloc();
      final cancelledBloc = buildElements(
        bloc,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: null),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final elementId = await createElement(bloc, cancelledBloc);

      cancelledBloc.add(
        OcptResourcesElementPhotoPickRequestedEvent(elementId: elementId, fileTypeLabel: "Images"),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.selectedElement!.photo, isNull);
      await cancelledBloc.close();

      final photoBloc = buildElements(
        bloc,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/tmp/valise.jpg"),
      );
      photoBloc.add(
        OcptResourcesElementPhotoPickRequestedEvent(elementId: elementId, fileTypeLabel: "Images"),
      );
      final state = await waitForState(bloc, (state) => state.selectedElement!.photo != null);

      expect(state.selectedElement!.photo!.path, "/tmp/valise.jpg");

      photoBloc.add(OcptResourcesElementPhotoClearedEvent(elementId: elementId));
      await waitForState(bloc, (state) => state.selectedElement!.photo == null);

      await closeAll(photoBloc, bloc);
    });
  });

  group("the events of the elements bloc", () {
    String nameOf(OcptResourcesElementsEvent event) => switch (event) {
      OcptResourcesElementCreationRequestedEvent() => "creation",
      OcptResourcesElementDeletionRequestedEvent() => "deletion",
      OcptResourcesElementFieldChangedEvent() => "field",
      OcptResourcesElementCategoryChangedEvent() => "category",
      OcptResourcesElementSourceKindChangedEvent() => "source kind",
      OcptResourcesElementOwnerChangedEvent() => "owner",
      OcptResourcesElementBringerChangedEvent() => "bringer",
      OcptResourcesElementTrackingFlagChangedEvent() => "tracking flag",
      OcptResourcesSceneAssignedToElementEvent() => "scene assigned",
      OcptResourcesSceneElementUpdatedEvent() => "scene link updated",
      OcptResourcesSceneElementRemovedEvent() => "scene link removed",
      OcptResourcesElementLinkedToRoleEvent() => "role link added",
      OcptResourcesRoleElementUpdatedEvent() => "role link updated",
      OcptResourcesRoleElementRemovedEvent() => "role link removed",
      OcptResourcesElementPhotoPickRequestedEvent() => "photo pick",
      OcptResourcesElementPhotoClearedEvent() => "photo cleared",
      OcptResourcesElementsFieldEditFlushRequestedEvent() => "field flush",
    };

    test("every event of its hierarchy has a handler", () async {
      final bloc = buildBloc();
      final elementsBloc = buildElements(
        bloc,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: null),
      );
      await waitForState(bloc, (state) => !state.isLoading);

      final events = <OcptResourcesElementsEvent>[
        const OcptResourcesElementCreationRequestedEvent(category: OcptElementCategory.prop),
        const OcptResourcesElementDeletionRequestedEvent(elementId: "e"),
        const OcptResourcesElementFieldChangedEvent(
          elementId: "e",
          field: OcptElementField.name,
          rawValue: "",
        ),
        const OcptResourcesElementCategoryChangedEvent(
          elementId: "e",
          category: OcptElementCategory.prop,
        ),
        const OcptResourcesElementSourceKindChangedEvent(
          elementId: "e",
          sourceKind: OcptElementSourceKind.owned,
        ),
        const OcptResourcesElementOwnerChangedEvent(elementId: "e", personId: null),
        const OcptResourcesElementBringerChangedEvent(elementId: "e", personId: null),
        const OcptResourcesElementTrackingFlagChangedEvent(
          elementId: "e",
          flag: OcptElementTrackingFlag.secured,
          value: true,
        ),
        const OcptResourcesSceneAssignedToElementEvent(sceneId: "c", elementId: "e"),
        const OcptResourcesSceneElementUpdatedEvent(id: "i", quantity: "", notes: ""),
        const OcptResourcesSceneElementRemovedEvent(id: "i"),
        const OcptResourcesElementLinkedToRoleEvent(roleId: "r", elementId: "e"),
        const OcptResourcesRoleElementUpdatedEvent(id: "i", notes: ""),
        const OcptResourcesRoleElementRemovedEvent(id: "i"),
        const OcptResourcesElementPhotoPickRequestedEvent(elementId: "e", fileTypeLabel: ""),
        const OcptResourcesElementPhotoClearedEvent(elementId: "e"),
        const OcptResourcesElementsFieldEditFlushRequestedEvent(),
      ];
      expect(
        events.map(nameOf).toSet(),
        hasLength(17),
        reason: 'one event per name of the hierarchy',
      );

      // With no project open every write handler returns at its first line: the handlers are
      // reached without any of the rows the events name having to exist.
      await projectsManager.closeCurrentProject();

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => elementsBloc.add(event), returnsNormally, reason: nameOf(event));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await closeAll(elementsBloc, bloc);
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      final elementsBloc = buildElements(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);

      await closeAll(elementsBloc, bloc);
    });
  });
}
