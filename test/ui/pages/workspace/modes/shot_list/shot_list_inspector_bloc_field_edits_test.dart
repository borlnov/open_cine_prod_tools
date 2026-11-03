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
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../../../ocpt_result_expectations.dart';
import 'shot_list_inspector_bloc_test_doubles.dart';

/// Run the tests of the shot list inspector bloc field edits.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  const dialogueText =
      "INT. HOUSE - DAY\n\nAction one.\n\nLÉA\nHello there.\n\n"
      "EXT. GARDEN - NIGHT\n\nAction two.\n";

  const twoCharactersText =
      "INT. HOUSE - DAY\n\nAction one.\n\nLÉA\nHello there.\n\n"
      "MARC\nHello back.\n";

  const oneCharacterLeftText = "INT. HOUSE - DAY\n\nAction one.\n\nMARC\nHello back.\n";

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
    // The in-memory preference store outlives a single test, so every test that reads a
    // preference back seeds the ones it cares about rather than assuming a pristine store.
    await propertiesManager.shotListVisibleColumns.store(OcptShotListColumn.defaultVisibleColumns);
    await propertiesManager.shotListLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await propertiesManager.shotListRightDockFraction.store(OcptWorkspaceDock.rightDefaultFraction);
    await propertiesManager.shotListLastRightDockTab.store(OcptShotListRightDockTab.inspector);

    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_inspector_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: testAppLanguageCode,
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
  /// gives the shot list its sequences.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: text,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
  }

  /// Builds the mode bloc wired to the test project. Its export manager is a plain one nothing ever
  /// exports through: the exports are the export bloc's own, tested apart.
  OcptShotListBloc buildBloc({OcptShotListService? shotListService}) => OcptShotListBloc(
    projectsManager: projectsManager,
    shotListService: shotListService,
    propertiesManager: propertiesManager,
    routerManager: RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the inspector bloc of [modeBloc]. [fieldEditDebounce] defaults to a short duration so
  /// tests exercising the field-edit debounce don't have to wait out the real 2 s one.
  OcptShotListInspectorBloc buildInspector(
    OcptShotListBloc modeBloc, {
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
    OcptShotCoverageService? shotCoverageService,
  }) => OcptShotListInspectorBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    shotCoverageService: shotCoverageService,
    fieldEditDebounce: fieldEditDebounce,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptShotListState> waitForState(
    OcptShotListBloc bloc,
    bool Function(OcptShotListState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Waits for the first state of [inspector] matching [predicate] (the current one included): for
  /// a state that is only there for a moment, like a pending edit while its short debounce runs,
  /// which polling could step over.
  Future<OcptShotListInspectorState> waitForInspector(
    OcptShotListInspectorBloc inspector,
    bool Function(OcptShotListInspectorState state) predicate,
  ) async {
    if (predicate(inspector.state)) {
      return inspector.state;
    }

    return inspector.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Waits until [isDone] holds, looking again every few milliseconds: for a condition that spans
  /// the mode bloc and the inspector bloc, whose states change in an order a test must not depend
  /// on.
  Future<void> waitUntil(bool Function() isDone) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!isDone()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException("The awaited condition never held");
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// Closes the inspector and the mode, in the order the widget tree does.
  Future<void> closeAll(OcptShotListInspectorBloc inspector, OcptShotListBloc mode) async {
    await inspector.close();
    await mode.close();
  }

  /// Dispatches the two word clicks that draw a scenario coverage range across every word of
  /// [block] on shot [shotId] (first word opens the anchor, last word closes it), waiting for the
  /// anchor to land after the first click and for the range to land, and the anchor to be gone,
  /// after the second.
  Future<void> drawCoverageRange(
    OcptShotListBloc mode,
    OcptShotListInspectorBloc inspector, {
    required String shotId,
    required OcptScriptWordBlock block,
  }) async {
    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: block.words.first.startOffset,
        wordEndOffset: block.words.first.endOffset,
      ),
    );
    await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: block.words.last.startOffset,
        wordEndOffset: block.words.last.endOffset,
      ),
    );
    await waitUntil(
      () =>
          mode.state.snapshot!.shotsById[shotId]!.coverageRanges.isNotEmpty &&
          inspector.state.pendingCoverageAnchor == null,
    );
  }

  /// Attaches [characterNames] to a freshly created shot of the first sequence, then closes the
  /// blocs that did it, and returns the new shot's derived code.
  ///
  /// The deleted-character tests all need the same starting point: a shot carrying characters the
  /// screenplay is then edited to no longer speak. The mode bloc reads the screenplay's speaking
  /// characters once, on entry, so a fresh bloc is what sees the edited screenplay — which is also
  /// what happens in the app, where the shot list mode is mounted anew every time it is switched
  /// to.
  Future<String> createShotWithCharacters(List<String> characterNames) async {
    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    for (final characterName in characterNames) {
      final roleId = state.roles.firstWhere((role) => role.name == characterName).id;
      inspector.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, roleId: roleId));
      state = await waitForState(
        mode,
        (state) => state.selectedShot!.characters.contains(characterName),
      );
    }

    final code = state.selectedShot!.code;
    await closeAll(inspector, mode);

    return code;
  }

  test(
    'a typed field edit is visible as a pending value and writes once after the debounce',
    () async {
      await writeScreenplay(twoSceneText);

      final mode = buildBloc();
      final inspector = buildInspector(mode);
      await waitForState(mode, (state) => !state.isLoading);
      mode.add(const OcptShotListShotCreationRequestedEvent());
      final created = await waitForState(mode, (state) => state.totalShotCount == 1);
      final shotId = created.selectedShotId!;

      inspector.add(
        OcptShotListShotFieldChangedEvent(
          shotId: shotId,
          field: OcptShotListEditableField.shotSize,
          rawValue: "W",
        ),
      );
      await waitForInspector(
        inspector,
        (state) =>
            state.pendingFieldEdits[OcptShotListShotFieldEditKey(
              shotId: shotId,
              field: OcptShotListEditableField.shotSize,
            )] ==
            "W",
      );
      // Not written yet: still the field's default empty value.
      expect(mode.state.selectedShot!.shotSize, isEmpty);

      // A second keystroke before the debounce elapses restarts it rather than firing twice: only
      // the last value typed is ever written.
      inspector.add(
        OcptShotListShotFieldChangedEvent(
          shotId: shotId,
          field: OcptShotListEditableField.shotSize,
          rawValue: "Wide",
        ),
      );
      await waitForInspector(
        inspector,
        (state) =>
            state.pendingFieldEdits[OcptShotListShotFieldEditKey(
              shotId: shotId,
              field: OcptShotListEditableField.shotSize,
            )] ==
            "Wide",
      );
      expect(mode.state.selectedShot!.shotSize, isEmpty);

      await waitForState(mode, (state) => state.selectedShot!.shotSize == "Wide");
      // The inspector forgets what it wrote once the mode holds it, one turn later.
      await pumpEventQueue();
      expect(inspector.state.pendingFieldEdits, isEmpty);

      await closeAll(inspector, mode);
    },
  );

  test('committing a shot size deduces the abbreviation once, then never again', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Plan moyen",
      ),
    );
    var state = await waitForState(mode, (state) => state.selectedShot!.shotSize == "Plan moyen");
    expect(state.selectedShot!.abbreviation, "PM");

    // A later shot size never overwrites the abbreviation the shot already carries.
    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Gros plan",
      ),
    );
    state = await waitForState(mode, (state) => state.selectedShot!.shotSize == "Gros plan");
    expect(state.selectedShot!.abbreviation, "PM");

    await closeAll(inspector, mode);
  });

  test('an abbreviation typed in the same flush wins over the deduced one', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Plan moyen",
      ),
    );
    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.abbreviation,
        rawValue: "PMS",
      ),
    );

    final state = await waitForState(mode, (state) => state.selectedShot!.shotSize == "Plan moyen");
    expect(state.selectedShot!.abbreviation, "PMS");

    await closeAll(inspector, mode);
  });

  test('selecting another shot flushes a pending field edit immediately', () async {
    await writeScreenplay(twoSceneText);

    // A debounce long enough that the assertions below could only pass through the flush the
    // selection change performs, never through the debounce elapsing on its own.
    final mode = buildBloc();
    final inspector = buildInspector(mode, fieldEditDebounce: const Duration(seconds: 5));
    await waitForState(mode, (state) => !state.isLoading);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final firstShotId = state.selectedShotId!;

    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: firstShotId,
        field: OcptShotListEditableField.notes,
        rawValue: "Handheld",
      ),
    );
    await waitUntil(
      () =>
          inspector.state.pendingFieldEdits[OcptShotListShotFieldEditKey(
            shotId: firstShotId,
            field: OcptShotListEditableField.notes,
          )] ==
          "Handheld",
    );

    mode.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(mode, (state) => state.totalShotCount == 2);

    expect(inspector.state.pendingFieldEdits, isEmpty);
    expect(state.snapshot!.shotsById[firstShotId]!.notes, "Handheld");

    await closeAll(inspector, mode);
  });

  test('flushPendingFieldEdits writes a pending edit directly, without touching state', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode, fieldEditDebounce: const Duration(seconds: 5));
    await waitForState(mode, (state) => !state.isLoading);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.sound,
        rawValue: "Wind noise",
      ),
    );
    await waitUntil(
      () =>
          inspector.state.pendingFieldEdits[OcptShotListShotFieldEditKey(
            shotId: shotId,
            field: OcptShotListEditableField.sound,
          )] ==
          "Wind noise",
    );

    await mode.flushPendingFieldEdits();

    // This flush never touches the inspector's own state...
    expect(inspector.state.pendingFieldEdits, isNotEmpty);
    // ...but the database already has the write.
    final reloaded = await projectsManager.shotListService
        .loadShotList(
          database: projectsManager.currentProject!.database,
          screenplayId: projectsManager.currentProject!.primaryScreenplayId,
          episodeNumber: null,
        )
        .valueOrFail;
    expect(reloaded.shotsById[shotId]!.sound, "Wind noise");

    await closeAll(inspector, mode);
  });

  test('a difficulty axis and a character toggle each write immediately', () async {
    await writeScreenplay(dialogueText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    inspector.add(
      OcptShotListShotDifficultyChangedEvent(
        shotId: shotId,
        axis: OcptShotDifficultyAxis.sound,
        value: 4,
      ),
    );
    state = await waitForState(mode, (state) => state.selectedShot!.difficultySound == 4);

    final leaRoleId = state.roles.firstWhere((role) => role.name == "LÉA").id;
    inspector.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, roleId: leaRoleId));
    state = await waitForState(mode, (state) => state.selectedShot!.characters.contains("LÉA"));

    inspector.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, roleId: leaRoleId));
    state = await waitForState(mode, (state) => state.selectedShot!.characters.isEmpty);

    await closeAll(inspector, mode);
  });

  test('an orphaned role is reported, then deletable everywhere', () async {
    await writeScreenplay(twoCharactersText);
    await createShotWithCharacters(["LÉA", "MARC"]);

    await writeScreenplay(oneCharacterLeftText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    var state = await waitForState(mode, (state) => !state.isLoading);

    expect(state.orphanedRoleAlerts, hasLength(1));
    expect(state.orphanedRoleAlerts.single.characterName, "LÉA");
    final leaRoleId = state.orphanedRoleAlerts.single.roleId;

    inspector.add(OcptShotListOrphanedRoleDeleteRequestedEvent(roleId: leaRoleId));
    state = await waitForState(mode, (state) => state.orphanedRoleAlerts.isEmpty);

    // The character still spoken is left untouched by the deletion, and the role's own cascade
    // drops it from the shot rather than leaving a dangling attachment.
    expect(state.snapshot!.shotsById.values.single.characters, ["MARC"]);

    await closeAll(inspector, mode);
  });

  test(
    'an orphaned role can be merged into a still-speaking one, carrying its shots along',
    () async {
      await writeScreenplay(twoCharactersText);
      await createShotWithCharacters(["LÉA"]);

      await writeScreenplay(oneCharacterLeftText);

      final mode = buildBloc();
      final inspector = buildInspector(mode);
      var state = await waitForState(mode, (state) => !state.isLoading);
      expect(state.orphanedRoleAlerts, hasLength(1));
      final leaRoleId = state.orphanedRoleAlerts.single.roleId;
      final marcRoleId = state.roles.firstWhere((role) => role.name == "MARC").id;

      inspector.add(
        OcptShotListRoleMergeRequestedEvent(sourceRoleId: leaRoleId, targetRoleId: marcRoleId),
      );
      state = await waitForState(mode, (state) => state.orphanedRoleAlerts.isEmpty);

      expect(state.snapshot!.shotsById.values.single.characters, ["MARC"]);

      await closeAll(inspector, mode);
    },
  );

  test('an orphaned role can be kept as silent, its casting untouched and its shot kept', () async {
    await writeScreenplay(twoCharactersText);
    await createShotWithCharacters(["LÉA", "MARC"]);

    await writeScreenplay(oneCharacterLeftText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    var state = await waitForState(mode, (state) => !state.isLoading);
    expect(state.orphanedRoleAlerts, hasLength(1));
    final leaRoleId = state.orphanedRoleAlerts.single.roleId;

    inspector.add(OcptShotListOrphanedRoleKeptEvent(roleId: leaRoleId));
    state = await waitForState(mode, (state) => state.orphanedRoleAlerts.isEmpty);

    final leaRole = state.roles.firstWhere((role) => role.id == leaRoleId);
    expect(leaRole.isFromScreenplay, isFalse);
    expect(leaRole.kind, OcptRoleKind.silent);
    // Kept, not dropped: the shot still carries both characters.
    expect(state.snapshot!.shotsById.values.single.characters, ["LÉA", "MARC"]);

    await closeAll(inspector, mode);
  });

  test('a first coverage click sets the pending anchor and writes nothing', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    final firstWord = actionBlock.words.first;

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: firstWord.startOffset,
        wordEndOffset: firstWord.endOffset,
      ),
    );
    await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

    expect(inspector.state.pendingCoverageAnchor!.wordStartOffset, actionBlock.startOffset);
    expect(inspector.state.pendingCoverageAnchor!.wordStartOffset, firstWord.startOffset);
    expect(mode.state.selectedShot!.coverageRanges, isEmpty);

    await closeAll(inspector, mode);
  });

  test('cancelling the pending anchor clears it without recording a range', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    final firstWord = actionBlock.words.first;

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: firstWord.startOffset,
        wordEndOffset: firstWord.endOffset,
      ),
    );
    await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

    inspector.add(const OcptShotListCoverageAnchorCancelledEvent());
    await waitUntil(() => inspector.state.pendingCoverageAnchor == null);

    expect(inspector.state.pendingCoverageAnchor, isNull);
    expect(mode.state.selectedShot!.coverageRanges, isEmpty);

    await closeAll(inspector, mode);
  });

  test('a second click in the same block writes a range covering both words', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(mode, inspector, shotId: shotId, block: actionBlock);
    state = mode.state;

    expect(inspector.state.pendingCoverageAnchor, isNull);
    final range = state.selectedShot!.coverageRanges.single;
    expect(range.sceneId, layout.sceneId);
    expect(range.startOffset, actionBlock.words.first.startOffset);
    expect(range.endOffset, actionBlock.words.last.endOffset);

    await closeAll(inspector, mode);
  });

  test('closing a range over dialogue attaches the characters it covers', () async {
    await writeScreenplay(dialogueText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;
    expect(state.selectedShot!.characters, isEmpty);

    final layout = state.buildSelectedCoverageLayout()!;
    final dialogueBlock = layout.blocks.firstWhere((block) => block.text == "Hello there.");

    await drawCoverageRange(mode, inspector, shotId: shotId, block: dialogueBlock);
    state = await waitForState(mode, (state) => state.selectedShot!.characters.isNotEmpty);

    // The cue itself is outside the range: the speaker is named by their dialogue alone.
    expect(state.selectedShot!.characters, ["LÉA"]);

    await closeAll(inspector, mode);
  });

  test('a range covering no dialogue attaches nobody', () async {
    await writeScreenplay(dialogueText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(mode, inspector, shotId: shotId, block: actionBlock);
    state = mode.state;

    expect(state.selectedShot!.coverageRanges, hasLength(1));
    expect(state.selectedShot!.characters, isEmpty);

    await closeAll(inspector, mode);
  });

  test('removing a range keeps the characters it had attached', () async {
    await writeScreenplay(dialogueText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final dialogueBlock = layout.blocks.firstWhere((block) => block.text == "Hello there.");

    await drawCoverageRange(mode, inspector, shotId: shotId, block: dialogueBlock);
    await waitForState(mode, (state) => state.selectedShot!.characters.isNotEmpty);

    inspector.add(OcptShotListCoverageClearRequestedEvent(shotId: shotId));
    state = await waitForState(mode, (state) => state.selectedShot!.coverageRanges.isEmpty);

    // Attaching is one-way: only the user takes a character off a shot.
    expect(state.selectedShot!.characters, ["LÉA"]);

    await closeAll(inspector, mode);
  });

  test('a click on a covered word with no anchor removes that range', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(mode, inspector, shotId: shotId, block: actionBlock);

    final firstWord = actionBlock.words.first;
    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: firstWord.startOffset,
        wordEndOffset: firstWord.endOffset,
      ),
    );
    state = await waitForState(mode, (state) => state.selectedShot!.coverageRanges.isEmpty);
    // The inspector forgets the anchor once the mode holds the change, one turn later.
    await pumpEventQueue();
    expect(inspector.state.pendingCoverageAnchor, isNull);

    await closeAll(inspector, mode);
  });

  test("a second click in another block closes a range spanning both", () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final headingBlock = layout.blocks.firstWhere((block) => block.text == "INT. HOUSE - DAY");
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: headingBlock.words.first.startOffset,
        wordEndOffset: headingBlock.words.first.endOffset,
      ),
    );
    await waitUntil(() => inspector.state.pendingCoverageAnchor != null);

    inspector.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: actionBlock.words.last.startOffset,
        wordEndOffset: actionBlock.words.last.endOffset,
      ),
    );
    state = await waitForState(mode, (state) => state.selectedShot!.coverageRanges.isNotEmpty);
    // The inspector forgets the anchor once the mode holds the range, one turn later.
    await pumpEventQueue();

    final range = state.selectedShot!.coverageRanges.single;
    expect(range.startOffset, headingBlock.words.first.startOffset);
    expect(range.endOffset, actionBlock.words.last.endOffset);
    // The range genuinely runs through both blocks, blank line included.
    expect(layout.blocksSpannedBy(range), [headingBlock, actionBlock]);
    expect(inspector.state.pendingCoverageAnchor, isNull);

    await closeAll(inspector, mode);
  });

  test("a range drawn next to an existing one merges with it", () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final heading = layout.blocks.firstWhere((block) => block.text == "INT. HOUSE - DAY");

    Future<void> drawWord(OcptScriptWord word) async {
      for (var click = 0; click < 2; click++) {
        inspector.add(
          OcptShotListCoverageWordClickedEvent(
            shotId: shotId,
            wordStartOffset: word.startOffset,
            wordEndOffset: word.endOffset,
          ),
        );
      }
      await waitUntil(
        () =>
            inspector.state.pendingCoverageAnchor == null &&
            mode.state.selectedShot!.coverageRanges.any(
              (range) => range.endOffset == word.endOffset,
            ),
      );
      state = mode.state;
    }

    // Two one-word ranges, drawn separately on two words a single space apart.
    await drawWord(heading.words[0]);
    await drawWord(heading.words[1]);

    final range = state.selectedShot!.coverageRanges.single;
    expect(layout.sceneText.substring(range.startOffset, range.endOffset), "INT. HOUSE");

    await closeAll(inspector, mode);
  });

  test("clearing coverage drops only the cleared shot's ranges", () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotAId = state.selectedShotId!;
    var layout = state.buildSelectedCoverageLayout()!;
    var actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(mode, inspector, shotId: shotAId, block: actionBlock);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(mode, (state) => state.totalShotCount == 2);
    final shotBId = state.selectedShotId!;
    layout = state.buildSelectedCoverageLayout()!;
    actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(mode, inspector, shotId: shotBId, block: actionBlock);

    inspector.add(OcptShotListCoverageClearRequestedEvent(shotId: shotAId));
    state = await waitForState(
      mode,
      (state) => state.snapshot!.shotsById[shotAId]!.coverageRanges.isEmpty,
    );

    expect(state.snapshot!.shotsById[shotBId]!.coverageRanges, isNotEmpty);

    await closeAll(inspector, mode);
  });

  test('marking a shot as checked clears needsCheck and re-stamps digests so a following '
      'staleness pass stays quiet', () async {
    await writeScreenplay(twoSceneText);

    final mode = buildBloc();
    final inspector = buildInspector(mode);
    await waitForState(mode, (state) => !state.isLoading);
    mode.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(mode, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    final layout = created.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(mode, inspector, shotId: shotId, block: actionBlock);
    await closeAll(inspector, mode);

    // Changing the scene's body (its heading is untouched, so the scene keeps its own id) makes
    // the recorded range's digest disagree with the text under it, raising needsCheck on save.
    const modifiedText =
        "INT. HOUSE - DAY\n\nAction one revised.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";
    await writeScreenplay(modifiedText);

    final reopenedMode = buildBloc();
    final reopenedInspector = buildInspector(reopenedMode);
    var state = await waitForState(reopenedMode, (state) => !state.isLoading);
    var shot = state.snapshot!.shotsById[shotId]!;
    expect(shot.needsCheck, isTrue);
    expect(shot.checkReason, OcptShotCheckReason.coveredTextChanged);

    reopenedInspector.add(OcptShotListShotMarkedAsCheckedEvent(shotId: shotId));
    state = await waitForState(
      reopenedMode,
      (state) => !state.snapshot!.shotsById[shotId]!.needsCheck,
    );
    expect(reopenedInspector.state.pendingCoverageAnchor, isNull);

    await closeAll(reopenedInspector, reopenedMode);

    // Saving the very same (already stale-inducing) text again re-runs the staleness pass; the
    // digests were just re-stamped to it, so it stays quiet this time.
    await writeScreenplay(modifiedText);
    final finalMode = buildBloc();
    final finalInspector = buildInspector(finalMode);
    final finalState = await waitForState(finalMode, (state) => !state.isLoading);
    shot = finalState.snapshot!.shotsById[shotId]!;
    expect(shot.needsCheck, isFalse);
    expect(shot.checkReason, isNull);

    await closeAll(finalInspector, finalMode);
  });
}
