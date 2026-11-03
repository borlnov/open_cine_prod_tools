// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_local_storage_manager/act_local_storage_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_tagging_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'breakdown_tagging_bloc_test_doubles.dart';

/// A last right dock tab item whose store takes a moment, as a slow disk does, and that counts the
/// stores it was asked for and those that finished.
// ignore: must_be_immutable
class _SlowTabItem extends SharedPrefsItemWithParser<OcptBreakdownRightDockTab, String> {
  /// How many stores were asked for.
  int started = 0;

  /// How many stores finished.
  int finished = 0;

  /// Class constructor
  _SlowTabItem()
    : super(
        "BREAKDOWN_LAST_RIGHT_DOCK_TAB",
        parser: (value) => OcptBreakdownRightDockTab.values.asNameMap()[value],
        castTo: (value) => value.name,
      );

  /// Count the start, wait 60 milliseconds, store the value as the real item does, then count the
  /// end.
  @override
  Future<bool> store(OcptBreakdownRightDockTab? value) async {
    started++;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final success = await super.store(value);
    finished++;
    return success;
  }
}

/// A properties manager whose last right dock tab is stored slowly.
class _SlowPropertiesManager extends OcptPropertiesManager {
  /// The slow item the manager hands out.
  final _SlowTabItem _slowTab = _SlowTabItem();

  /// Get the slow item.
  @override
  _SlowTabItem get breakdownLastRightDockTab => _slowTab;
}

/// Run the tests of the breakdown tagging bloc tagging range.
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_breakdown_tagging_bloc_test_");
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

    await projectsManager.breakdownService.createTag(
      database: project.database,
      sceneId: sceneId,
      startOffset: 2,
      endOffset: 6,
      taggedText: "lamp",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: elementId!,
    );

    return (sceneId: sceneId, elementId: elementId);
  }

  /// Builds the mode bloc wired to the test project.
  OcptBreakdownBloc buildBloc() => OcptBreakdownBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the tagging bloc of [modeBloc].
  OcptBreakdownTaggingBloc buildTagging(OcptBreakdownBloc modeBloc) =>
      OcptBreakdownTaggingBloc(modeBloc: modeBloc, projectsManager: projectsManager);

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<S> waitForState<S>(BlocBase<S> bloc, bool Function(S state) predicate) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Opens an anchor on "lamp" and closes the range on "desk" in [sceneId] through [taggingBloc],
  /// then waits for the range.
  Future<void> closeRange(OcptBreakdownTaggingBloc taggingBloc, String sceneId) async {
    taggingBloc.add(
      OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 20, wordEndOffset: 24),
    );
    await waitForState(taggingBloc, (state) => state.pendingTagAnchor != null);
    taggingBloc.add(
      OcptBreakdownWordClickedEvent(sceneId: sceneId, wordStartOffset: 37, wordEndOffset: 42),
    );
    await waitForState(taggingBloc, (state) => state.pendingTagRange != null);
  }

  group("the range the script view is tagging", () {
    test(
      "survives a scene or a target being selected, and an ordinary read of the snapshot",
      () async {
        await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
        final bloc = buildBloc();
        final taggingBloc = buildTagging(bloc);
        final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
        final sceneId = loaded.scenes.single.id;
        await closeRange(taggingBloc, sceneId);
        final range = taggingBloc.state.pendingTagRange;

        bloc.add(OcptBreakdownSceneSelectedEvent(sceneId: sceneId));
        bloc.add(OcptBreakdownSceneHeadingSelectedEvent(sceneId: sceneId));
        bloc.add(const OcptBreakdownTargetSelectionClearedEvent());
        bloc.add(
          OcptBreakdownTargetSelectedEvent(
            targetKind: OcptBreakdownTargetKind.element,
            targetId: "el-1",
            sceneId: sceneId,
          ),
        );
        await waitForState(bloc, (state) => state.selectedTargetRef != null);
        expect(await bloc.reload({OcptBreakdownReloadScope.snapshot}), isTrue);
        bloc.add(const OcptBreakdownProjectSettingsChangedEvent());
        await pumpEventQueue();

        expect(taggingBloc.state.pendingTagRange, range);

        await taggingBloc.close();
        await bloc.close();
      },
    );

    test("is dropped, the notice with it, when the mode reads everything again", () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
      final bloc = buildBloc();
      final taggingBloc = buildTagging(bloc);
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;
      await closeRange(taggingBloc, sceneId);

      bloc.add(const AsyncInitEvent());
      final dropped = await waitForState(
        taggingBloc,
        (state) => state.pendingTagAnchor == null && state.pendingTagRange == null,
      );

      expect(dropped.hasTagWriteError, isFalse);

      await taggingBloc.close();
      await bloc.close();
    });

    test("is dropped when the same centre view is asked for again", () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
      final bloc = buildBloc();
      final taggingBloc = buildTagging(bloc);
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;
      await closeRange(taggingBloc, sceneId);

      bloc.add(const OcptBreakdownCentreViewSelectedEvent(view: OcptBreakdownCentreView.script));
      await waitForState(
        taggingBloc,
        (state) => state.pendingTagAnchor == null && state.pendingTagRange == null,
      );

      await taggingBloc.close();
      await bloc.close();
    });

    test("is kept when a search is typed while the recap is already showing", () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
      final bloc = buildBloc();
      final taggingBloc = buildTagging(bloc);
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;
      await closeRange(taggingBloc, sceneId);
      // The recap was reached without the range being open, then the range was opened behind it.
      bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "lamp"));
      await waitForState(
        taggingBloc,
        (state) => state.pendingTagAnchor == null && state.pendingTagRange == null,
      );
      await closeRange(taggingBloc, sceneId);

      bloc.add(const OcptBreakdownSearchQueryChangedEvent(query: "lamps"));
      await waitForState(bloc, (state) => state.searchQuery == "lamps");
      await pumpEventQueue();

      expect(taggingBloc.state.pendingTagRange, isNotNull);

      await taggingBloc.close();
      await bloc.close();
    });

    test("a link refused behind the popover's back raises the notice, keeps the range", () async {
      final tagged = await writeTaggedElement();
      final bloc = buildBloc();
      final taggingBloc = buildTagging(bloc);
      await waitForState(bloc, (state) => state.taggedTargetCount == 1);
      // "A" (18, 19) then "sits" (25, 29): a range that crosses the tag over "lamp" (20, 24), which
      // the click handler itself refuses, so it is closed on "sits on" instead and the tag is
      // written behind the popover's back.
      taggingBloc.add(
        OcptBreakdownWordClickedEvent(
          sceneId: tagged.sceneId,
          wordStartOffset: 25,
          wordEndOffset: 29,
        ),
      );
      await waitForState(taggingBloc, (state) => state.pendingTagAnchor != null);
      taggingBloc.add(
        OcptBreakdownWordClickedEvent(
          sceneId: tagged.sceneId,
          wordStartOffset: 33,
          wordEndOffset: 36,
        ),
      );
      final opened = await waitForState(taggingBloc, (state) => state.pendingTagRange != null);
      await projectsManager.breakdownService.createTag(
        database: projectsManager.currentProject!.database,
        sceneId: tagged.sceneId,
        startOffset: opened.pendingTagRange!.startOffset,
        endOffset: opened.pendingTagRange!.endOffset,
        taggedText: opened.pendingTagRange!.taggedText,
        targetKind: OcptBreakdownTargetKind.element,
        targetId: tagged.elementId,
      );

      taggingBloc.add(
        OcptBreakdownPopoverTargetLinkedEvent(
          targetKind: OcptBreakdownTargetKind.element,
          targetId: tagged.elementId,
        ),
      );
      final refused = await waitForState(taggingBloc, (state) => state.hasTagWriteError);

      expect(refused.pendingTagRange, opened.pendingTagRange);

      taggingBloc.add(const OcptBreakdownTagWriteErrorDismissedEvent());
      final dismissed = await waitForState(taggingBloc, (state) => !state.hasTagWriteError);
      expect(dismissed.pendingTagRange, opened.pendingTagRange);

      await taggingBloc.close();
      await bloc.close();
    });

    test("picking `Create a set` creates the set, tags the range and selects the set", () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
      final bloc = buildBloc();
      final taggingBloc = buildTagging(bloc);
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;
      await closeRange(taggingBloc, sceneId);

      taggingBloc.add(
        const OcptBreakdownPopoverSetCreationRequestedEvent(locationId: null, name: "Maison"),
      );
      await waitForState(taggingBloc, (state) => state.pendingTagRange == null);

      expect(bloc.state.sets.single.name, "Maison");
      expect(bloc.state.selectedTargetRef, (
        OcptBreakdownTargetKind.set,
        bloc.state.sets.single.id,
      ));
      expect(bloc.state.selectedSceneId, sceneId);
      expect(bloc.state.rightDockTab, OcptBreakdownRightDockTab.inspector);
      expect(bloc.state.taggedTargetCount, 1);

      await taggingBloc.close();
      await bloc.close();
    });

    test(
      "has stored the Inspector tab before the mode paints the tag, whatever the disk's speed",
      () async {
        await propertiesManager.breakdownLastRightDockTab.store(OcptBreakdownRightDockTab.versions);
        await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
        final slowProperties = _SlowPropertiesManager();
        final bloc = OcptBreakdownBloc(
          projectsManager: projectsManager,
          propertiesManager: slowProperties,
          routerManager: RecordingRouterManager(),
          exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
        );
        final taggingBloc = buildTagging(bloc);
        final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
        final sceneId = loaded.scenes.single.id;
        await closeRange(taggingBloc, sceneId);

        try {
          taggingBloc.add(
            const OcptBreakdownPopoverSetCreationRequestedEvent(locationId: null, name: "Maison"),
          );
          await waitForState(bloc, (state) => state.taggedTargetCount == 1);

          // The popover is still open when the tag shows, but nothing slow is left to wait for.
          expect(slowProperties.breakdownLastRightDockTab.finished, 1);

          await waitForState(taggingBloc, (state) => state.pendingTagRange == null);
          expect(slowProperties.breakdownLastRightDockTab.started, 1);
          expect(bloc.state.lastRightDockTab, OcptBreakdownRightDockTab.inspector);
        } finally {
          await propertiesManager.breakdownLastRightDockTab.store(
            OcptBreakdownRightDockTab.inspector,
          );
          await taggingBloc.close();
          await bloc.close();
        }
      },
    );

    test("stays open when the mode cannot read the snapshot after the tag was written", () async {
      await writeScreenplay("INT. HOUSE - DAY\n\nA lamp sits on the desk.\n");
      final bloc = buildBloc();
      final taggingBloc = buildTagging(bloc);
      final loaded = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
      final sceneId = loaded.scenes.single.id;
      await closeRange(taggingBloc, sceneId);
      final database = projectsManager.currentProject!.database;

      // Writing a tag never touches the episodes, whereas every read of the snapshot does.
      await database.customStatement("ALTER TABLE screenplays RENAME TO screenplays_gone");
      try {
        taggingBloc.add(
          const OcptBreakdownPopoverElementCreationRequestedEvent(
            category: OcptElementCategory.prop,
            name: "Desk lamp",
          ),
        );
        await pumpEventQueue(times: 400);
      } finally {
        await database.customStatement("ALTER TABLE screenplays_gone RENAME TO screenplays");
      }

      expect(taggingBloc.state.pendingTagRange, isNotNull);
      expect(bloc.state.selectedTargetRef, isNull);

      await taggingBloc.close();
      await bloc.close();
    });
  });

  group("the events of the tagging bloc", () {
    /// The name of each event of the tagging hierarchy: the switch names every one, so an event
    /// added to the hierarchy does not compile until this list, and the test below, know it.
    String nameOf(OcptBreakdownTaggingEvent event) => switch (event) {
      OcptBreakdownWordClickedEvent() => "word",
      OcptBreakdownTagRangeCancelledEvent() => "cancel",
      OcptBreakdownPopoverTargetLinkedEvent() => "link",
      OcptBreakdownPopoverElementCreationRequestedEvent() => "element",
      OcptBreakdownPopoverSetCreationRequestedEvent() => "set",
      OcptBreakdownTagWriteErrorDismissedEvent() => "dismiss",
      OcptBreakdownSuggestionAcceptedEvent() => "suggestion",
    };

    test("every event of its hierarchy has a handler", () async {
      final bloc = buildBloc();
      final taggingBloc = buildTagging(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      const events = <OcptBreakdownTaggingEvent>[
        OcptBreakdownWordClickedEvent(sceneId: "s", wordStartOffset: 0, wordEndOffset: 1),
        OcptBreakdownTagRangeCancelledEvent(),
        OcptBreakdownPopoverTargetLinkedEvent(
          targetKind: OcptBreakdownTargetKind.element,
          targetId: "e",
        ),
        OcptBreakdownPopoverElementCreationRequestedEvent(
          category: OcptElementCategory.prop,
          name: "",
        ),
        OcptBreakdownPopoverSetCreationRequestedEvent(locationId: null, name: ""),
        OcptBreakdownTagWriteErrorDismissedEvent(),
        OcptBreakdownSuggestionAcceptedEvent(
          targetKind: OcptBreakdownTargetKind.element,
          targetId: "e",
          sceneId: "s",
          startOffset: 0,
          endOffset: 1,
          taggedText: "x",
        ),
      ];
      expect(events.map(nameOf).toSet(), hasLength(7), reason: "one event per name");

      // With no project open every write handler returns at its first line: the handlers are
      // reached without any of the rows the events name having to exist.
      await projectsManager.closeCurrentProject();

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => taggingBloc.add(event), returnsNormally, reason: nameOf(event));
      }
      await pumpEventQueue();

      await taggingBloc.close();
      await bloc.close();
    });

    test("is registered with the mode as a flusher, without any widget having read it", () async {
      final bloc = buildBloc();
      final taggingBloc = buildTagging(bloc);
      await waitForState(bloc, (state) => !state.isLoading);

      expect(bloc.pendingWritesFlusherCount, 1);

      await taggingBloc.close();
      await bloc.close();
    });
  });
}
