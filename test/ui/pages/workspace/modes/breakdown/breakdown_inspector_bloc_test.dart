// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_inspector_bloc.dart';
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

/// Run the tests of [OcptBreakdownInspectorBloc].
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() resolvable; the bloc's dependencies
    // themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_breakdown_inspector_bloc_test_");
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

  /// Writes [text] as the project's screenplay, which reconciles its scene index and therefore
  /// gives the breakdown mode its scenes.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  /// Writes a one-scene screenplay, an element tagged in it, and returns the scene and element
  /// ids the rest of a test writes against.
  Future<({String sceneId, String elementId})> writeTaggedElement() async {
    await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(
      project.database.ocptScenesTable,
    )).get()).single.id;

    final elementId = await projectsManager.elementsService
        .createElement(
          database: project.database,
          name: "Desk lamp",
          category: OcptElementCategory.prop,
          sourceKind: OcptElementSourceKind.owned,
        )
        .maybeValueOrFail;

    await projectsManager.breakdownService
        .createTag(
          database: project.database,
          sceneId: sceneId,
          startOffset: 2,
          endOffset: 6,
          taggedText: "lamp",
          targetKind: OcptBreakdownTargetKind.element,
          targetId: elementId!,
        )
        .maybeValueOrFail;

    return (sceneId: sceneId, elementId: elementId);
  }

  /// Reads the live scenes of the open project, with their breakdown rows.
  Future<List<OcptBreakdownScene>> readScenes() => projectsManager.breakdownService
      .loadScenes(
        database: projectsManager.currentProject!.database,
        screenplayId: projectsManager.currentProject!.primaryScreenplayId,
        episodeNumber: null,
      )
      .valueOrFail;

  /// Builds the mode bloc wired to the test project.
  OcptBreakdownBloc buildBloc() => OcptBreakdownBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the inspector bloc of [modeBloc], writing what is typed after [fieldEditDebounce]
  /// (short by default, so a test exercising the debounce does not wait out the real 2 s one).
  OcptBreakdownInspectorBloc buildInspector(
    OcptBreakdownBloc modeBloc, {
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
  }) => OcptBreakdownInspectorBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    fieldEditDebounce: fieldEditDebounce,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test("changing an element's status writes it immediately and reloads the snapshot", () async {
    final tagged = await writeTaggedElement();
    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc);
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    inspectorBloc.add(
      OcptBreakdownElementStatusChangedEvent(
        elementId: tagged.elementId,
        status: OcptElementStatus.confirmed,
      ),
    );
    final state = await waitForState(
      bloc,
      (state) => state.targets.single.status == OcptElementStatus.confirmed,
    );

    expect(state.toFindCount, 0);

    await inspectorBloc.close();
    await bloc.close();
  });

  test("changing an element's category writes it immediately and reloads the snapshot", () async {
    final tagged = await writeTaggedElement();
    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc);
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    inspectorBloc.add(
      OcptBreakdownElementCategoryChangedEvent(
        elementId: tagged.elementId,
        category: OcptElementCategory.vehicle,
      ),
    );
    final state = await waitForState(
      bloc,
      (state) => state.targets.single.category == OcptElementCategory.vehicle,
    );

    expect(state.targets.single.color, isNot(0));

    await inspectorBloc.close();
    await bloc.close();
  });

  test(
    "typing into an element field debounces then writes it, clearing the pending edit",
    () async {
      final tagged = await writeTaggedElement();
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc);
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);

      inspectorBloc.add(
        OcptBreakdownElementFieldChangedEvent(
          elementId: tagged.elementId,
          field: OcptElementField.subCategory,
          rawValue: "1960s",
        ),
      );
      final pending = await waitForState(
        inspectorBloc,
        (state) => state.pendingElementFieldEdits.isNotEmpty,
      );
      expect(
        pending.elementFieldValueOf(tagged.elementId, OcptElementField.subCategory, ""),
        "1960s",
      );

      final flushed = await waitForState(
        inspectorBloc,
        (state) => state.pendingElementFieldEdits.isEmpty,
      );
      expect(flushed.pendingElementFieldEdits, isEmpty);
      expect(bloc.state.selectedElement, isNull); // nothing selected here, just checking it flushed

      final elements = await projectsManager.elementsService
          .loadElements(database: projectsManager.currentProject!.database)
          .valueOrFail;
      expect(elements.single.subCategory, "1960s");

      await inspectorBloc.close();
      await bloc.close();
    },
  );

  test("renaming an element through the name field writes it and renames its target", () async {
    final tagged = await writeTaggedElement();
    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc);
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    inspectorBloc.add(
      OcptBreakdownElementFieldChangedEvent(
        elementId: tagged.elementId,
        field: OcptElementField.name,
        rawValue: "Queen's crown",
      ),
    );

    // The snapshot is read again once the debounce lands, so every surface naming the target — the
    // script's tooltips, the legend, the recap table — follows the new name.
    final renamed = await waitForState(
      bloc,
      (state) => state.targets.single.name == "Queen's crown",
    );
    expect(renamed.targets.single.name, "Queen's crown");
    // The edit is forgotten once the mode holds the row it was written into.
    await waitForState(inspectorBloc, (state) => state.pendingElementFieldEdits.isEmpty);

    final elements = await projectsManager.elementsService
        .loadElements(database: projectsManager.currentProject!.database)
        .valueOrFail;
    expect(elements.single.name, "Queen's crown");

    await inspectorBloc.close();
    await bloc.close();
  });

  test("changing an element's owner writes it immediately", () async {
    final tagged = await writeTaggedElement();
    final project = projectsManager.currentProject!;
    final personId = await projectsManager.peopleService.createPerson(database: project.database);
    expect(personId, isNotNull);

    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc);
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    inspectorBloc.add(
      OcptBreakdownElementOwnerChangedEvent(elementId: tagged.elementId, personId: personId),
    );
    final state = await waitForState(
      bloc,
      (state) => state.elements.isNotEmpty && state.elements.single.ownerPersonId == personId,
    );

    expect(state.elements.single.ownerPersonId, personId);

    await inspectorBloc.close();
    await bloc.close();
  });

  test("changing an element's who-brings-it writes it immediately", () async {
    final tagged = await writeTaggedElement();
    final project = projectsManager.currentProject!;
    final personId = await projectsManager.peopleService.createPerson(database: project.database);
    expect(personId, isNotNull);

    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc);
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    inspectorBloc.add(
      OcptBreakdownElementBringerChangedEvent(elementId: tagged.elementId, personId: personId),
    );
    final state = await waitForState(
      bloc,
      (state) => state.elements.isNotEmpty && state.elements.single.broughtByPersonId == personId,
    );

    expect(state.elements.single.broughtByPersonId, personId);

    await inspectorBloc.close();
    await bloc.close();
  });

  test("linking a scene to a set writes the link alone, and unlinking drops it", () async {
    await writeScreenplay("INT. CUISINE - DAY\n\nA lamp sits on the desk.\n");
    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(
      project.database.ocptScenesTable,
    )).get()).single.id;
    final locationId = (await projectsManager.locationsService.createLocation(
      database: project.database,
      name: "Maison des Martin",
    ))!;
    final setId = (await projectsManager.locationsService.createSet(
      database: project.database,
      locationId: locationId,
      name: "Cuisine",
    ))!;

    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc);
    await waitForState(bloc, (state) => state.scenes.length == 1);

    inspectorBloc.add(OcptBreakdownSceneSetLinkedEvent(sceneId: sceneId, setId: setId));
    var state = await waitForState(
      bloc,
      (state) => state.sets.any((set) => set.sceneIds.contains(sceneId)),
    );
    // Linking a scene to a set is a fact about the scene, not a passage of the script.
    expect(state.taggedTargetCount, 0);

    inspectorBloc.add(OcptBreakdownSceneSetUnlinkedEvent(sceneId: sceneId, setId: setId));
    state = await waitForState(
      bloc,
      (state) => state.sets.every((set) => !set.sceneIds.contains(sceneId)),
    );
    expect(state.sets, hasLength(1));

    await inspectorBloc.close();
    await bloc.close();
  });

  test("creating a set from the scene sheet mints its location too, and no tag", () async {
    await writeScreenplay("INT. CUISINE - DAY\n\nA lamp sits on the desk.\n");
    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(
      project.database.ocptScenesTable,
    )).get()).single.id;

    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc);
    await waitForState(bloc, (state) => state.scenes.length == 1);

    // The project has never heard of this place: no location to file the set under, so one is
    // minted along with it.
    inspectorBloc.add(
      OcptBreakdownSceneSetCreationRequestedEvent(
        sceneId: sceneId,
        locationId: null,
        name: "CUISINE",
      ),
    );
    var state = await waitForState(bloc, (state) => state.sets.length == 1);

    expect(state.sets.single.name, "CUISINE");
    expect(state.sets.single.sceneIds, [sceneId]);
    expect(state.locations.single.name, "CUISINE");
    // Naming a scene's décor is not tagging a passage of the script.
    expect(state.taggedTargetCount, 0);

    // A second one goes into the location the first minted, rather than into another of its own.
    inspectorBloc.add(
      OcptBreakdownSceneSetCreationRequestedEvent(
        sceneId: sceneId,
        locationId: state.locations.single.id,
        name: "SALON",
      ),
    );
    state = await waitForState(bloc, (state) => state.sets.length == 2);

    expect(state.locations, hasLength(1));
    expect(state.sets.map((set) => set.name), ["CUISINE", "SALON"]);
    expect(state.sets.map((set) => set.code), ["A", "B"]);

    await inspectorBloc.close();
    await bloc.close();
  });

  test("renaming a set rides the field-edit debounce and lands on the catalogue row", () async {
    await writeScreenplay("INT. CUISINE - DAY\n\nA lamp sits on the desk.\n");
    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(
      project.database.ocptScenesTable,
    )).get()).single.id;

    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc);
    await waitForState(bloc, (state) => state.scenes.length == 1);

    inspectorBloc.add(
      OcptBreakdownSceneSetCreationRequestedEvent(
        sceneId: sceneId,
        locationId: null,
        name: "CUISINE",
      ),
    );
    final created = await waitForState(bloc, (state) => state.sets.length == 1);
    final setId = created.sets.single.id;

    inspectorBloc.add(
      OcptBreakdownSetNameChangedEvent(setId: setId, rawValue: "Cuisine des Martin"),
    );
    // Pending first: the rename reads back immediately, before the debounce has written anything.
    final pending = await waitForState(
      inspectorBloc,
      (state) => state.pendingSetNameEdits.isNotEmpty,
    );
    expect(pending.setNameValueOf(setId, "CUISINE"), "Cuisine des Martin");
    expect(bloc.state.sets.single.name, "CUISINE");

    inspectorBloc.add(const OcptBreakdownFieldEditFlushRequestedEvent());
    await waitForState(inspectorBloc, (state) => state.pendingSetNameEdits.isEmpty);

    expect(bloc.state.sets.single.name, "Cuisine des Martin");
    // The location minted to hold it keeps the name it was given: the two are renamed apart.
    expect(bloc.state.locations.single.name, "CUISINE");

    await inspectorBloc.close();
    await bloc.close();
  });

  test("tag removal with no target selected leaves the tag untouched", () async {
    final tagged = await writeTaggedElement();
    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc);
    await waitForState(bloc, (state) => state.taggedTargetCount == 1);

    // The scene alone is selected, never the target: the confirmation the mode shows is about the
    // selected target, so answering it with none is the stale click the handler guards against.
    bloc.add(OcptBreakdownSceneSelectedEvent(sceneId: tagged.sceneId));
    await waitForState(bloc, (state) => state.selectedSceneId == tagged.sceneId);

    inspectorBloc.add(const OcptBreakdownTagRemovalConfirmedEvent());
    await pumpEventQueue();

    expect(bloc.state.taggedTargetCount, 1);

    await inspectorBloc.close();
    await bloc.close();
  });

  test(
    "tag removal confirmed removes the tag but keeps the scene_elements link it once ensured",
    () async {
      final tagged = await writeTaggedElement();
      final project = projectsManager.currentProject!;
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc);
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);

      bloc.add(
        OcptBreakdownTargetSelectedEvent(
          targetKind: OcptBreakdownTargetKind.element,
          targetId: tagged.elementId,
          sceneId: tagged.sceneId,
        ),
      );
      await waitForState(bloc, (state) => state.selectedTarget != null);

      inspectorBloc.add(const OcptBreakdownTagRemovalConfirmedEvent());
      await waitForState(bloc, (state) => state.taggedTargetCount == 0);

      final elements = await projectsManager.elementsService
          .loadElements(database: project.database)
          .valueOrFail;
      expect(elements.single.sceneLinks, isNotEmpty);

      await inspectorBloc.close();
      await bloc.close();
    },
  );

  test("marking a flagged tag as checked clears needsCheck without moving its offsets", () async {
    await writeTaggedElement();
    // The tagged word is gone from the scene: the next save flags the tag rather than
    // re-anchoring it, mirroring `OcptBreakdownService.reconcileTags`'s own "text is gone" test.
    await writeScreenplay("INT. HOUSE - DAY\n\nA torch sits on the desk.\n");

    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc);
    final loaded = await waitForState(bloc, (state) => state.needsCheckTagCount == 1);
    final flaggedTag = loaded.scenes.single.tags.single;
    expect(flaggedTag.needsCheck, isTrue);

    inspectorBloc.add(OcptBreakdownTagNeedsCheckClearedEvent(tagId: flaggedTag.id));
    final state = await waitForState(bloc, (state) => state.needsCheckTagCount == 0);

    final clearedTag = state.scenes.single.tags.single;
    expect(clearedTag.needsCheck, isFalse);
    expect(clearedTag.startOffset, flaggedTag.startOffset);
    expect(clearedTag.endOffset, flaggedTag.endOffset);

    await inspectorBloc.close();
    await bloc.close();
  });

  test("removing a flagged tag tombstones it and drops its target from the snapshot", () async {
    await writeTaggedElement();
    await writeScreenplay("INT. HOUSE - DAY\n\nA torch sits on the desk.\n");

    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc);
    final loaded = await waitForState(bloc, (state) => state.needsCheckTagCount == 1);
    final flaggedTagId = loaded.scenes.single.tags.single.id;

    inspectorBloc.add(OcptBreakdownFlaggedTagRemovedEvent(tagId: flaggedTagId));
    final state = await waitForState(bloc, (state) => state.needsCheckTagCount == 0);

    expect(state.taggedTargetCount, 0);
    expect(state.scenes.single.tags, isEmpty);

    await inspectorBloc.close();
    await bloc.close();
  });

  test(
    "flushPendingFieldEdits writes a pending element field edit directly, bypassing the debounce",
    () async {
      final tagged = await writeTaggedElement();
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);

      inspectorBloc.add(
        OcptBreakdownElementFieldChangedEvent(
          elementId: tagged.elementId,
          field: OcptElementField.notes,
          rawValue: "handle with care",
        ),
      );
      await waitForState(inspectorBloc, (state) => state.pendingElementFieldEdits.isNotEmpty);

      await bloc.flushPendingFieldEdits();

      final elements = await projectsManager.elementsService
          .loadElements(database: projectsManager.currentProject!.database)
          .valueOrFail;
      expect(elements.single.notes, "handle with care");

      await inspectorBloc.close();
      await bloc.close();
    },
  );

  test(
    "changing a scene's breakdown status writes it immediately and reloads the snapshot",
    () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc);
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;

      inspectorBloc.add(
        OcptBreakdownSceneStatusChangedEvent(
          sceneId: sceneId,
          status: OcptBreakdownSceneStatus.done,
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.scenes.single.status == OcptBreakdownSceneStatus.done,
      );

      expect(state.scenes.single.status, OcptBreakdownSceneStatus.done);

      final scenes = await readScenes();
      expect(scenes.single.status, OcptBreakdownSceneStatus.done);

      await inspectorBloc.close();
      await bloc.close();
    },
  );

  test(
    "typing into a scene's breakdown notes debounces then writes it, clearing the pending edit",
    () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc);
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;

      inspectorBloc.add(
        OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "Bring the lamp"),
      );
      final pending = await waitForState(
        inspectorBloc,
        (state) => state.pendingSceneNotesEdits.isNotEmpty,
      );
      expect(pending.sceneNotesValueOf(sceneId, ""), "Bring the lamp");

      await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isEmpty);
      expect(bloc.state.scenes.single.notes, "Bring the lamp");

      final scenes = await readScenes();
      expect(scenes.single.notes, "Bring the lamp");

      await inspectorBloc.close();
      await bloc.close();
    },
  );

  test("selecting a different scene flushes a pending scene notes edit", () async {
    await writeScreenplay(
      "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n",
    );
    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
    final loaded = await waitForState(bloc, (state) => state.scenes.length == 2);
    final firstSceneId = loaded.scenes[0].id;
    final secondSceneId = loaded.scenes[1].id;

    inspectorBloc.add(
      OcptBreakdownSceneNotesChangedEvent(sceneId: firstSceneId, rawValue: "note one"),
    );
    await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);

    bloc.add(OcptBreakdownSceneSelectedEvent(sceneId: secondSceneId));
    await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isEmpty);

    final scenes = await readScenes();
    expect(scenes.firstWhere((scene) => scene.id == firstSceneId).notes, "note one");

    await inspectorBloc.close();
    await bloc.close();
  });

  test("switching the right dock tab flushes a pending scene notes edit", () async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final bloc = buildBloc();
    final inspectorBloc = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
    final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    final sceneId = loaded.scenes.single.id;

    inspectorBloc.add(OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "note"));
    await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);

    bloc.add(const OcptBreakdownRightDockTabSelectedEvent(tab: OcptBreakdownRightDockTab.versions));
    await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isEmpty);

    final scenes = await readScenes();
    expect(scenes.single.notes, "note");

    await inspectorBloc.close();
    await bloc.close();
  });

  test(
    "flushPendingFieldEdits writes a pending scene notes edit directly, bypassing the debounce",
    () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;

      inspectorBloc.add(
        OcptBreakdownSceneNotesChangedEvent(sceneId: sceneId, rawValue: "handle with care"),
      );
      await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);

      await bloc.flushPendingFieldEdits();

      final scenes = await readScenes();
      expect(scenes.single.notes, "handle with care");

      await inspectorBloc.close();
      await bloc.close();
    },
  );

  group("the pending edits the inspector holds", () {
    test("survive an ordinary read of the snapshot", () async {
      final tagged = await writeTaggedElement();
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);
      inspectorBloc.add(
        OcptBreakdownSceneNotesChangedEvent(sceneId: tagged.sceneId, rawValue: "Bring the lamp"),
      );
      await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);

      final reloaded = bloc.state.reloadEpoch;
      expect(await bloc.reload({OcptBreakdownReloadScope.snapshot}), isTrue);
      await pumpEventQueue();

      expect(bloc.state.reloadEpoch, greaterThan(reloaded));
      expect(inspectorBloc.state.pendingSceneNotesEdits, {tagged.sceneId: "Bring the lamp"});

      await inspectorBloc.close();
      await bloc.close();
    });

    test("are all dropped when the mode reads everything again", () async {
      final tagged = await writeTaggedElement();
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);
      inspectorBloc.add(
        OcptBreakdownSceneNotesChangedEvent(sceneId: tagged.sceneId, rawValue: "Bring the lamp"),
      );
      inspectorBloc.add(
        OcptBreakdownElementFieldChangedEvent(
          elementId: tagged.elementId,
          field: OcptElementField.notes,
          rawValue: "Fragile",
        ),
      );
      inspectorBloc.add(
        const OcptBreakdownSetNameChangedEvent(setId: "set-1", rawValue: "Cuisine"),
      );
      await waitForState(
        inspectorBloc,
        (state) =>
            state.pendingSceneNotesEdits.isNotEmpty &&
            state.pendingElementFieldEdits.isNotEmpty &&
            state.pendingSetNameEdits.isNotEmpty,
      );

      bloc.add(const AsyncInitEvent());
      await waitForState(
        inspectorBloc,
        (state) =>
            state.pendingSceneNotesEdits.isEmpty &&
            state.pendingElementFieldEdits.isEmpty &&
            state.pendingSetNameEdits.isEmpty,
      );

      await inspectorBloc.close();
      await bloc.close();
    });

    test("are written by a flush of the mode, which answers true", () async {
      final tagged = await writeTaggedElement();
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);
      inspectorBloc.add(
        OcptBreakdownSceneNotesChangedEvent(sceneId: tagged.sceneId, rawValue: "Bring the lamp"),
      );
      await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);

      final mayProceed = await bloc.flushAllPendingWrites();

      expect(mayProceed, isTrue);
      expect(inspectorBloc.state.pendingSceneNotesEdits, isEmpty);
      expect(bloc.state.scenes.single.notes, "Bring the lamp");

      await inspectorBloc.close();
      await bloc.close();
    });

    test("are all dropped, the flush still answering true, when a write fails", () async {
      final tagged = await writeTaggedElement();
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);
      inspectorBloc.add(
        OcptBreakdownElementFieldChangedEvent(
          elementId: tagged.elementId,
          field: OcptElementField.notes,
          rawValue: "Fragile",
        ),
      );
      inspectorBloc.add(
        OcptBreakdownSceneNotesChangedEvent(sceneId: tagged.sceneId, rawValue: "Bring the lamp"),
      );
      await waitForState(
        inspectorBloc,
        (state) =>
            state.pendingElementFieldEdits.isNotEmpty && state.pendingSceneNotesEdits.isNotEmpty,
      );
      final database = projectsManager.currentProject!.database;

      await database.customStatement("ALTER TABLE elements RENAME TO elements_gone");
      try {
        final mayProceed = await bloc.flushAllPendingWrites();

        expect(mayProceed, isTrue);
        expect(inspectorBloc.state.pendingElementFieldEdits, isEmpty);
        expect(inspectorBloc.state.pendingSceneNotesEdits, isEmpty);
      } finally {
        await database.customStatement("ALTER TABLE elements_gone RENAME TO elements");
      }

      // The scene notes came after the element field in the write, which failed: they were never
      // written either.
      final scenes = await readScenes();
      expect(scenes.single.notes, isEmpty);

      await inspectorBloc.close();
      await bloc.close();
    });

    test("are forgotten, written, when the read of the snapshot after them fails", () async {
      final tagged = await writeTaggedElement();
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);
      inspectorBloc.add(
        OcptBreakdownSceneNotesChangedEvent(sceneId: tagged.sceneId, rawValue: "Bring the lamp"),
      );
      await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);
      final database = projectsManager.currentProject!.database;

      // The write of a scene's notes never touches the episodes, whereas every read of the
      // snapshot does: the write lands and the read after it fails.
      await database.customStatement("ALTER TABLE screenplays RENAME TO screenplays_gone");
      try {
        final mayProceed = await bloc.flushAllPendingWrites();

        expect(mayProceed, isTrue);
        expect(inspectorBloc.state.pendingSceneNotesEdits, isEmpty);
      } finally {
        await database.customStatement("ALTER TABLE screenplays_gone RENAME TO screenplays");
      }

      final scenes = await readScenes();
      expect(scenes.single.notes, "Bring the lamp");

      await inspectorBloc.close();
      await bloc.close();
    });

    test("are written once when the widget leaves the tree and the bloc then closes", () async {
      final tagged = await writeTaggedElement();
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);
      inspectorBloc.add(
        OcptBreakdownSceneNotesChangedEvent(sceneId: tagged.sceneId, rawValue: "Bring the lamp"),
      );
      await waitForState(inspectorBloc, (state) => state.pendingSceneNotesEdits.isNotEmpty);
      final database = projectsManager.currentProject!.database;

      // Every insert and update of the table is logged, so a second write of the same edit shows.
      await database.customStatement("CREATE TABLE write_log (written INTEGER)");
      for (final operation in ["INSERT", "UPDATE"]) {
        await database.customStatement(
          "CREATE TRIGGER log_$operation AFTER $operation ON scene_breakdowns "
          "BEGIN INSERT INTO write_log VALUES (1); END",
        );
      }

      // What the widget leaving the tree does: the flush starts, and the bloc closes in the same
      // frame, before the write is done.
      final flushing = bloc.flushPendingFieldEdits();
      await inspectorBloc.close();
      await bloc.close();
      await flushing;

      final scenes = await readScenes();
      expect(scenes.single.notes, "Bring the lamp");
      final writes = await database.customSelect("SELECT COUNT(*) AS n FROM write_log").getSingle();
      expect(writes.read<int>("n"), 1);
    });
  });

  group("the events of the inspector bloc", () {
    /// The name of each event of the inspector hierarchy: the switch names every one, so an event
    /// added to the hierarchy does not compile until this list, and the test below, know it.
    String nameOf(OcptBreakdownInspectorEvent event) => switch (event) {
      OcptBreakdownSceneStatusChangedEvent() => "scene status",
      OcptBreakdownSceneNotesChangedEvent() => "scene notes",
      OcptBreakdownElementStatusChangedEvent() => "element status",
      OcptBreakdownElementCategoryChangedEvent() => "element category",
      OcptBreakdownElementFieldChangedEvent() => "element field",
      OcptBreakdownFieldEditFlushRequestedEvent() => "flush",
      OcptBreakdownElementOwnerChangedEvent() => "owner",
      OcptBreakdownElementBringerChangedEvent() => "bringer",
      OcptBreakdownSceneSetLinkedEvent() => "set linked",
      OcptBreakdownSetNameChangedEvent() => "set name",
      OcptBreakdownSceneSetCreationRequestedEvent() => "set created",
      OcptBreakdownSceneSetUnlinkedEvent() => "set unlinked",
      OcptBreakdownTagRemovalConfirmedEvent() => "tag removal",
      OcptBreakdownTagNeedsCheckClearedEvent() => "needs check",
      OcptBreakdownFlaggedTagRemovedEvent() => "flagged tag",
    };

    test("every event of its hierarchy has a handler", () async {
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      const events = <OcptBreakdownInspectorEvent>[
        OcptBreakdownSceneStatusChangedEvent(sceneId: "s", status: OcptBreakdownSceneStatus.done),
        OcptBreakdownSceneNotesChangedEvent(sceneId: "s", rawValue: ""),
        OcptBreakdownElementStatusChangedEvent(elementId: "e", status: OcptElementStatus.reserved),
        OcptBreakdownElementCategoryChangedEvent(
          elementId: "e",
          category: OcptElementCategory.prop,
        ),
        OcptBreakdownElementFieldChangedEvent(
          elementId: "e",
          field: OcptElementField.notes,
          rawValue: "",
        ),
        OcptBreakdownFieldEditFlushRequestedEvent(),
        OcptBreakdownElementOwnerChangedEvent(elementId: "e", personId: null),
        OcptBreakdownElementBringerChangedEvent(elementId: "e", personId: null),
        OcptBreakdownSceneSetLinkedEvent(sceneId: "s", setId: "t"),
        OcptBreakdownSetNameChangedEvent(setId: "t", rawValue: ""),
        OcptBreakdownSceneSetCreationRequestedEvent(sceneId: "s", locationId: null, name: ""),
        OcptBreakdownSceneSetUnlinkedEvent(sceneId: "s", setId: "t"),
        OcptBreakdownTagRemovalConfirmedEvent(),
        OcptBreakdownTagNeedsCheckClearedEvent(tagId: "g"),
        OcptBreakdownFlaggedTagRemovedEvent(tagId: "g"),
      ];
      expect(events.map(nameOf).toSet(), hasLength(15), reason: "one event per name");

      // With no project open every write handler returns at its first line: the handlers are
      // reached without any of the rows the events name having to exist.
      await projectsManager.closeCurrentProject();

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => inspectorBloc.add(event), returnsNormally, reason: nameOf(event));
      }
      await pumpEventQueue();

      await inspectorBloc.close();
      await bloc.close();
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      final inspectorBloc = buildInspector(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);

      await inspectorBloc.close();
      await bloc.close();
    });
  });
}
