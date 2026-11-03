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
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';

/// A router manager whose [pop] does nothing: these bloc tests don't build a real GoRouter.
class _SilentRouterManager extends OcptRouterManager {
  /// Ignore the pop: this double navigates nowhere.
  @override
  void pop<Y extends Object?>([Y? result]) {}
}

/// The ids of what the handlers work on.
typedef _Seeded = ({String firstShot, String secondShot, String roleId});

/// Where a handler raises its write error: the mode, or the inspector.
enum _Raiser { mode, inspector }

/// What the shot list mode and its inspector do when the database refuses a write on a shot or on
/// its characters: the handler raises its write error, reads nothing again, and the same event goes
/// through once the refusal is lifted; a flush stops at the first edit that fails.
void main() {
  const text = "INT. HOUSE - DAY\n\nAction one.\n";

  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late OcptShotListBloc mode;
  late OcptShotListInspectorBloc inspector;
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
    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_shot_failure_test_");
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
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: text,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    final sceneId =
        (await project.database.select(project.database.ocptScenesTable).get()).single.id;
    Future<String> shot() => projectsManager.shotListService
        .createShot(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          sceneId: sceneId,
        )
        .valueOrFail;
    final firstShot = await shot();
    final secondShot = await shot();
    final roleId = await projectsManager.roleIndexService
        .addRole(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          name: "DRIVER",
          kind: OcptRoleKind.silent,
        )
        .valueOrFail;

    mode = OcptShotListBloc(
      projectsManager: projectsManager,
      propertiesManager: propertiesManager,
      routerManager: _SilentRouterManager(),
      exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    );
    inspector = OcptShotListInspectorBloc(
      modeBloc: mode,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(days: 1),
    );
    await mode.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    seeded = (firstShot: firstShot, secondShot: secondShot, roleId: roleId);
  });

  tearDown(() async {
    await inspector.close();
    await mode.close();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Make every [verb] on [table] fail with a database error, on the rows [when] selects when it is
  /// given.
  Future<void> refuse(String verb, String table, {String? when}) =>
      projectsManager.currentProject!.database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "${when == null ? '' : 'WHEN $when '}BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

  /// Lift what [refuse] put.
  Future<void> allow(String verb, String table) => projectsManager.currentProject!.database
      .customStatement("DROP TRIGGER refuse_${verb.toLowerCase()}_$table");

  /// Read straight from the database the `shot_size` of every live shot, by id.
  Future<Map<String, String>> shotSizes() async {
    final rows = await projectsManager.currentProject!.database
        .customSelect("SELECT id, shot_size FROM shots WHERE is_deleted = 0")
        .get();

    return {for (final row in rows) row.read<String>("id"): row.read<String>("shot_size")};
  }

  /// Tell whether the inspector or the mode shows a write error.
  bool raised(_Raiser raiser) =>
      raiser == _Raiser.mode ? mode.state.hasWriteError : inspector.state.hasWriteError;

  /// Dismiss the write error of the inspector or the mode.
  void dismiss(_Raiser raiser) => raiser == _Raiser.mode
      ? mode.add(const OcptShotListWriteErrorDismissedEvent())
      : inspector.add(const OcptShotListInspectorWriteErrorDismissedEvent());

  /// The handlers, each with the table and the verb that fail it, where it raises, and the event
  /// it dispatches.
  final cases =
      <
        String,
        ({
          String table,
          String verb,
          _Raiser raiser,
          bool isAttachedFirst,
          void Function(_Seeded) dispatch,
        })
      >{
        "creating a shot": (
          table: "shots",
          verb: "INSERT",
          raiser: _Raiser.mode,
          isAttachedFirst: false,
          dispatch: (s) => mode.add(const OcptShotListShotCreationRequestedEvent()),
        ),
        "deleting a shot": (
          table: "shots",
          verb: "UPDATE",
          raiser: _Raiser.mode,
          isAttachedFirst: false,
          dispatch: (s) => mode.add(OcptShotListShotDeletionRequestedEvent(shotId: s.secondShot)),
        ),
        "changing a difficulty": (
          table: "shots",
          verb: "UPDATE",
          raiser: _Raiser.inspector,
          isAttachedFirst: false,
          dispatch: (s) => inspector.add(
            OcptShotListShotDifficultyChangedEvent(
              shotId: s.secondShot,
              axis: OcptShotDifficultyAxis.camera,
              value: 4,
            ),
          ),
        ),
        "attaching a character": (
          table: "shot_characters",
          verb: "INSERT",
          raiser: _Raiser.inspector,
          isAttachedFirst: false,
          dispatch: (s) => inspector.add(
            OcptShotListShotCharacterToggledEvent(shotId: s.secondShot, roleId: s.roleId),
          ),
        ),
        "detaching a character": (
          table: "shot_characters",
          verb: "UPDATE",
          raiser: _Raiser.inspector,
          isAttachedFirst: true,
          dispatch: (s) => inspector.add(
            OcptShotListShotCharacterToggledEvent(shotId: s.secondShot, roleId: s.roleId),
          ),
        ),
        "adding a new character by name": (
          table: "roles",
          verb: "INSERT",
          raiser: _Raiser.inspector,
          isAttachedFirst: false,
          dispatch: (s) => inspector.add(
            OcptShotListCharacterAddRequestedEvent(shotId: s.secondShot, characterName: "CLARA"),
          ),
        ),
        "attaching a character added by the name of an existing role": (
          table: "shot_characters",
          verb: "INSERT",
          raiser: _Raiser.inspector,
          isAttachedFirst: false,
          dispatch: (s) => inspector.add(
            OcptShotListCharacterAddRequestedEvent(shotId: s.secondShot, characterName: "DRIVER"),
          ),
        ),
      };

  for (final entry in cases.entries) {
    test("${entry.key} raises the write error, reads nothing again, and goes through once the "
        "refusal is lifted", () async {
      if (entry.value.isAttachedFirst) {
        await projectsManager.shotListService
            .attachCharacter(
              database: projectsManager.currentProject!.database,
              shotId: seeded.secondShot,
              roleId: seeded.roleId,
            )
            .okOrFail;
        await mode.reload({OcptShotListReloadScope.snapshot});
      }
      final held = mode.state.reloadEpoch;
      await refuse(entry.value.verb, entry.value.table);

      entry.value.dispatch(seeded);
      await settle();

      expect(raised(entry.value.raiser), isTrue);
      expect(mode.state.reloadEpoch, held, reason: "the mode read again");

      await allow(entry.value.verb, entry.value.table);
      dismiss(entry.value.raiser);
      entry.value.dispatch(seeded);
      await settle();

      expect(raised(entry.value.raiser), isFalse);
      expect(mode.state.reloadEpoch, greaterThan(held));
    });
  }

  group("flushing the typed edits", () {
    /// Type [value] into the shot size of [shotId].
    Future<void> type(String shotId, String value) async {
      inspector.add(
        OcptShotListShotFieldChangedEvent(
          shotId: shotId,
          field: OcptShotListEditableField.shotSize,
          rawValue: value,
        ),
      );
      await settle();
    }

    /// Refuse the update of the first shot alone.
    Future<void> refuseTheFirstShot() =>
        refuse("UPDATE", "shots", when: "NEW.id = '${seeded.firstShot}'");

    /// Refuse the abbreviation of the first shot alone, which a shot size writes after itself.
    Future<void> refuseTheFirstAbbreviation() => refuse(
      "UPDATE",
      "shots",
      when: "NEW.id = '${seeded.firstShot}' AND NEW.abbreviation <> OLD.abbreviation",
    );

    test("a refused edit raises the write error and stops the edits after it", () async {
      await type(seeded.firstShot, "Wide");
      await type(seeded.secondShot, "Close");
      await refuseTheFirstShot();
      final held = mode.state.reloadEpoch;

      final status = await inspector.flushPendingWrites();

      expect(status, OcptPendingWritesStatus.ok);
      expect(inspector.state.hasWriteError, isTrue);
      expect(mode.state.reloadEpoch, held, reason: "the mode read again");
      final sizes = await shotSizes();
      expect(sizes[seeded.firstShot], isEmpty);
      expect(sizes[seeded.secondShot], isEmpty, reason: "the edit after the refused one");
    });

    test("a refused edit on leaving stops the edits after it, and keeps them pending", () async {
      await type(seeded.firstShot, "Wide");
      await type(seeded.secondShot, "Close");
      await refuseTheFirstShot();
      final held = mode.state.reloadEpoch;

      await inspector.flushPendingWritesWithoutState();

      expect(mode.state.reloadEpoch, held);
      expect((await shotSizes())[seeded.secondShot], isEmpty, reason: "the edit after the refused");
      expect(inspector.state.pendingFieldEdits, isNotEmpty);
      expect(inspector.state.hasWriteError, isFalse, reason: "a flush on leaving only logs");
    });

    test("a refused abbreviation raises the write error and stops the edits after it", () async {
      await type(seeded.firstShot, "Wide Shot");
      await type(seeded.secondShot, "Close Up");
      await refuseTheFirstAbbreviation();
      final held = mode.state.reloadEpoch;

      await inspector.flushPendingWrites();

      expect(inspector.state.hasWriteError, isTrue);
      expect(mode.state.reloadEpoch, held, reason: "the mode read again");
      final sizes = await shotSizes();
      expect(sizes[seeded.firstShot], "Wide Shot", reason: "the size written before the refusal");
      expect(sizes[seeded.secondShot], isEmpty, reason: "the edit after the refused abbreviation");
    });

    test("a refused abbreviation on leaving stops the edits after it", () async {
      await type(seeded.firstShot, "Wide Shot");
      await type(seeded.secondShot, "Close Up");
      await refuseTheFirstAbbreviation();

      await inspector.flushPendingWritesWithoutState();

      expect((await shotSizes())[seeded.secondShot], isEmpty);
      expect(inspector.state.pendingFieldEdits, isNotEmpty);
    });

    test("a refused edit on leaving is written again by the next flush", () async {
      await type(seeded.firstShot, "Wide");
      await refuse("UPDATE", "shots");
      await inspector.flushPendingWritesWithoutState();
      await allow("UPDATE", "shots");

      await inspector.flushPendingWritesWithoutState();

      expect((await shotSizes())[seeded.firstShot], "Wide");
    });
  });
}
