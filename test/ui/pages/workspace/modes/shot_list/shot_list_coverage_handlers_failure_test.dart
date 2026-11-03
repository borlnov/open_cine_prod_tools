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
import 'package:open_cine_prod_tools/models/ocpt_script_word.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
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

/// What the inspector does when the database refuses a scenario coverage write: each of the four
/// handlers that write one raises the transient write error, clears the pending anchor, reads
/// nothing again, and goes on once the refusal is lifted.
void main() {
  const text = "INT. HOUSE - DAY\n\nJOHN\nHello there.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptShotListBloc mode;
  late OcptShotListInspectorBloc inspector;
  late String shotId;
  late OcptScriptWordLayout layout;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  /// Wait until [isDone] holds, looking again every few milliseconds.
  Future<void> waitUntil(bool Function() isDone) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!isDone()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException("The awaited condition never held");
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_coverage_failure_test_");
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
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );

    mode = OcptShotListBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _RecordingRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    inspector = OcptShotListInspectorBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    await waitUntil(() => !mode.state.isLoading);

    mode.add(const OcptShotListShotCreationRequestedEvent());
    await waitUntil(() => mode.state.selectedShotId != null);
    shotId = mode.state.selectedShotId!;
    layout = mode.state.buildSelectedCoverageLayout()!;
  });

  tearDown(() async {
    await inspector.close();
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// The words of the dialogue line, which the fixture's ranges are drawn on.
  List<OcptScriptWord> dialogueWords() =>
      layout.blocks.firstWhere((block) => block.text == "Hello there.").words;

  /// Record a range over the whole dialogue line, straight through the service.
  Future<void> seedRange() async {
    final words = dialogueWords();
    await projectsManager.shotCoverageService
        .addRange(
          database: projectsManager.currentProject!.database,
          shotId: shotId,
          sceneId: layout.sceneId,
          startOffset: words.first.startOffset,
          endOffset: words.last.endOffset,
          sceneText: layout.sceneText,
        )
        .maybeValueOrFail;
    await mode.reload({OcptShotListReloadScope.snapshot});
  }

  /// Make every [verb] on [table] fail with a database error.
  Future<void> refuse(String verb, String table) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  /// Lift what [refuse] put.
  Future<void> allow(String verb, String table) => projectsManager.currentProject!.database
      .customStatement("DROP TRIGGER refuse_${verb.toLowerCase()}_$table");

  /// The ranges of the database, read straight from it.
  Future<int> liveRangeCount() async {
    final rows = await projectsManager.currentProject!.database
        .customSelect("SELECT id FROM shot_coverages WHERE is_deleted = 0")
        .get();

    return rows.length;
  }

  /// The links between a shot and a character, read straight from the database.
  Future<int> liveCharacterLinkCount() async {
    final rows = await projectsManager.currentProject!.database
        .customSelect("SELECT shot_id FROM shot_characters WHERE is_deleted = 0")
        .get();

    return rows.length;
  }

  /// Tell whether the fixture's shot is flagged as needing a check, read straight from the
  /// database.
  Future<bool> shotNeedsCheck() async {
    final rows = await projectsManager.currentProject!.database
        .customSelect("SELECT needs_check FROM shots WHERE id = '$shotId'")
        .get();

    return rows.single.read<bool>("needs_check");
  }

  /// Add a second shot straight through the service, which the mode does not know until it reads
  /// again: a handler that stopped on the failure leaves the mode ignorant of it.
  Future<void> addShotBehindTheModesBack() async {
    await projectsManager.shotListService
        .createShot(
          database: projectsManager.currentProject!.database,
          screenplayId: projectsManager.currentProject!.primaryScreenplayId,
          sceneId: layout.sceneId,
        )
        .maybeValueOrFail;
  }

  /// Tell whether the mode read the shot list again within a moment.
  Future<bool> modeReadsAgain() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    return mode.state.totalShotCount > 1;
  }

  /// Click the word at [start]..[end] of the dialogue line.
  void click(int start, int end) => inspector.add(
    OcptShotListCoverageWordClickedEvent(
      shotId: shotId,
      wordStartOffset: start,
      wordEndOffset: end,
    ),
  );

  test(
    "a refused range closing raises the write error, attaches nobody and writes nothing",
    () async {
      final cue = layout.blocks.firstWhere((block) => block.text == "JOHN").words.first;
      final last = dialogueWords().last;
      click(cue.startOffset, cue.endOffset);
      await waitUntil(() => inspector.state.pendingCoverageAnchor != null);
      await refuse("INSERT", "shot_coverages");
      await addShotBehindTheModesBack();

      click(last.startOffset, last.endOffset);
      await waitUntil(() => inspector.state.hasWriteError);

      expect(inspector.state.pendingCoverageAnchor, isNull);
      expect(await liveRangeCount(), 0);
      expect(await modeReadsAgain(), isFalse, reason: "nothing is read after a failure");
      expect(await liveCharacterLinkCount(), 0);

      await allow("INSERT", "shot_coverages");
      inspector.add(const OcptShotListInspectorWriteErrorDismissedEvent());
      await waitUntil(() => !inspector.state.hasWriteError);
      click(cue.startOffset, cue.endOffset);
      await waitUntil(() => inspector.state.pendingCoverageAnchor != null);
      click(last.startOffset, last.endOffset);
      await waitUntil(() => mode.state.selectedShot?.coverageRanges.isNotEmpty ?? false);
      expect(await liveRangeCount(), 1);
      await waitUntil(() => mode.state.snapshot!.shotsById[shotId]!.characterRoleIds.isNotEmpty);
    },
  );

  test(
    "a refused attachment of the covered character raises the write error and reads nothing",
    () async {
      final cue = layout.blocks.firstWhere((block) => block.text == "JOHN").words.first;
      final last = dialogueWords().last;
      click(cue.startOffset, cue.endOffset);
      await waitUntil(() => inspector.state.pendingCoverageAnchor != null);
      await refuse("INSERT", "shot_characters");
      await addShotBehindTheModesBack();

      click(last.startOffset, last.endOffset);
      await waitUntil(() => inspector.state.hasWriteError);

      expect(inspector.state.pendingCoverageAnchor, isNull);
      expect(await liveCharacterLinkCount(), 0);
      expect(await modeReadsAgain(), isFalse, reason: "nothing is read after a failure");
    },
  );

  test("a refused range removal raises the write error and keeps the range", () async {
    await seedRange();
    await refuse("UPDATE", "shot_coverages");
    await addShotBehindTheModesBack();

    click(dialogueWords().first.startOffset, dialogueWords().first.endOffset);
    await waitUntil(() => inspector.state.hasWriteError);

    expect(await liveRangeCount(), 1);
    expect(await modeReadsAgain(), isFalse, reason: "nothing is read after a failure");

    await allow("UPDATE", "shot_coverages");
    inspector.add(const OcptShotListInspectorWriteErrorDismissedEvent());
    await waitUntil(() => !inspector.state.hasWriteError);
    click(dialogueWords().first.startOffset, dialogueWords().first.endOffset);
    await waitUntil(() => mode.state.selectedShot?.coverageRanges.isEmpty ?? false);
    expect(await liveRangeCount(), 0);
  });

  test("a refused clear raises the write error and keeps the ranges", () async {
    await seedRange();
    await refuse("UPDATE", "shot_coverages");
    await addShotBehindTheModesBack();

    inspector.add(OcptShotListCoverageClearRequestedEvent(shotId: shotId));
    await waitUntil(() => inspector.state.hasWriteError);

    expect(await liveRangeCount(), 1);
    expect(await modeReadsAgain(), isFalse, reason: "nothing is read after a failure");

    await allow("UPDATE", "shot_coverages");
    inspector.add(const OcptShotListInspectorWriteErrorDismissedEvent());
    await waitUntil(() => !inspector.state.hasWriteError);
    inspector.add(OcptShotListCoverageClearRequestedEvent(shotId: shotId));
    await waitUntil(() => mode.state.selectedShot?.coverageRanges.isEmpty ?? false);
    expect(await liveRangeCount(), 0);
  });

  test("a refused check raises the write error and keeps the flag", () async {
    await seedRange();
    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: "INT. HOUSE - DAY\n\nJOHN\nHello you.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );
    await mode.reload({OcptShotListReloadScope.snapshot});
    await refuse("UPDATE", "shots");
    await addShotBehindTheModesBack();

    inspector.add(OcptShotListShotMarkedAsCheckedEvent(shotId: shotId));
    await waitUntil(() => inspector.state.hasWriteError);

    expect(await shotNeedsCheck(), isTrue);
    expect(await modeReadsAgain(), isFalse, reason: "nothing is read after a failure");

    await allow("UPDATE", "shots");
    inspector.add(const OcptShotListInspectorWriteErrorDismissedEvent());
    await waitUntil(() => !inspector.state.hasWriteError);
    inspector.add(OcptShotListShotMarkedAsCheckedEvent(shotId: shotId));
    await waitUntil(() => mode.state.totalShotCount > 1);
    expect(await shotNeedsCheck(), isFalse);
  });
}
