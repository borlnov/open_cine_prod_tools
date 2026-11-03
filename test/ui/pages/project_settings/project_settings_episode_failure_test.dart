// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_project_episode_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_event.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../ocpt_result_expectations.dart';

/// How long a handler that failed is given to emit anything: it must emit nothing at all.
const _quietPeriod = Duration(milliseconds: 300);

/// What the project settings bloc does when the database refuses a call on the episodes, or cannot
/// read them: the handler stops where the call failed and emits nothing, then goes through once
/// the refusal is lifted.
void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;
  late String firstId;
  late String secondId;

  setUpAll(() async {
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_project_settings_episode_failure_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: () => "en",
    );
    await projectsManager.initLifeCycle();
    await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    firstId = projectsManager.currentProject!.primaryScreenplayId;
    secondId = await projectsManager.screenplayService
        .createEpisode(database: projectsManager.currentProject!.database, title: "Two")
        .valueOrFail;
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Run [statement] on the open project's database.
  Future<void> run(String statement) =>
      projectsManager.currentProject!.database.customStatement(statement);

  /// Make [verb] on the episodes fail with a database error.
  Future<void> refuse(String verb) => run(
    "CREATE TRIGGER refuse_${verb.toLowerCase()} BEFORE $verb ON screenplays "
    "BEGIN SELECT RAISE(ABORT, 'refused'); END",
  );

  /// Lift the refusal [refuse] put on [verb].
  Future<void> lift(String verb) => run("DROP TRIGGER refuse_${verb.toLowerCase()}");

  /// Make the rows the [verb] writes unreadable afterwards: the write lands, the re-read fails.
  Future<void> poison(String verb) => run(
    "CREATE TRIGGER poison_${verb.toLowerCase()} AFTER $verb ON screenplays "
    "BEGIN UPDATE screenplays SET number = 'unreadable'; END",
  );

  /// Mend what [poison] spoilt and lift its trigger.
  Future<void> mend(String verb) async {
    await run("DROP TRIGGER poison_${verb.toLowerCase()}");
    await run("UPDATE screenplays SET number = 1");
  }

  /// Build a bloc and wait for its first load to end, then record every state it emits from there.
  Future<(OcptProjectSettingsBloc, List<OcptProjectSettingsState>)> loadedBloc() async {
    final bloc = OcptProjectSettingsBloc(projectsManager: projectsManager);
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((state) => !state.isLoading).timeout(const Duration(seconds: 5));
    final emitted = <OcptProjectSettingsState>[];
    final subscription = bloc.stream.listen(emitted.add);
    addTearDown(subscription.cancel);

    return (bloc, emitted);
  }

  /// The handlers, each with the event, the verb that fails the write and what proves it landed.
  final cases =
      <
        String,
        ({
          String verb,
          OcptProjectSettingsEvent Function() event,
          bool Function(OcptProjectSettingsState state) done,
        })
      >{
        "adding an episode": (
          verb: "INSERT",
          event: () => const OcptProjectSettingsEpisodeAddedEvent(),
          done: (state) => state.episodes.length == 3,
        ),
        "renaming an episode": (
          verb: "UPDATE",
          event: () =>
              OcptProjectSettingsEpisodeTitleChangedEvent(screenplayId: secondId, title: "Changed"),
          done: (state) => state.episodes.any((episode) => episode.title == "Changed"),
        ),
        "renumbering an episode": (
          verb: "UPDATE",
          event: () =>
              OcptProjectSettingsEpisodeNumberChangedEvent(screenplayId: secondId, number: 7),
          done: (state) => state.episodes.any((episode) => episode.number == 7),
        ),
        "moving an episode": (
          verb: "UPDATE",
          event: () => OcptProjectSettingsEpisodeMovedEvent(screenplayId: secondId, newPosition: 0),
          done: (state) => state.episodes.first.id == secondId,
        ),
        "deleting an episode": (
          verb: "UPDATE",
          event: () => OcptProjectSettingsEpisodeDeletionConfirmedEvent(screenplayId: secondId),
          done: (state) => state.episodes.length == 1,
        ),
      };

  for (final entry in cases.entries) {
    final case_ = entry.value;
    test("${entry.key} stops where the write failed, and goes through once lifted", () async {
      final (bloc, emitted) = await loadedBloc();
      await refuse(case_.verb);

      bloc.add(case_.event());
      await Future<void>.delayed(_quietPeriod);

      expect(emitted, isEmpty);
      expect(case_.done(bloc.state), isFalse);

      await lift(case_.verb);
      bloc.add(case_.event());
      await Future<void>.delayed(_quietPeriod);

      expect(emitted, isNotEmpty);
      expect(case_.done(bloc.state), isTrue);
    });

    test("${entry.key} emits nothing when the episodes cannot be read back", () async {
      final (bloc, emitted) = await loadedBloc();
      await poison(case_.verb);

      bloc.add(case_.event());
      await Future<void>.delayed(_quietPeriod);

      expect(emitted, isEmpty);

      await mend(case_.verb);
    });
  }

  for (final entry in {
    "adding an episode": (
      verb: "INSERT",
      event: () => const OcptProjectSettingsEpisodeAddedEvent() as OcptProjectSettingsEvent,
    ),
    "deleting an episode": (
      verb: "UPDATE",
      event: () =>
          OcptProjectSettingsEpisodeDeletionConfirmedEvent(screenplayId: secondId)
              as OcptProjectSettingsEvent,
    ),
  }.entries) {
    test("${entry.key} leaves the episode count of the home card alone when it failed", () async {
      final (bloc, _) = await loadedBloc();
      final path = projectsManager.currentProject!.path;
      await OcptProjectEpisodeOps.recordEpisodeCount(
        path: path,
        episodeCount: 99,
        propertiesManager: propertiesManager,
      );
      Future<int?> recordedCount() async => (await propertiesManager.recentProjects.load())
          ?.firstWhere((project) => project.path == path)
          .episodeCount;
      await refuse(entry.value.verb);

      bloc.add(entry.value.event());
      await Future<void>.delayed(_quietPeriod);

      expect(await recordedCount(), 99);

      await lift(entry.value.verb);
      bloc.add(entry.value.event());
      await Future<void>.delayed(_quietPeriod);

      expect(await recordedCount(), isNot(99));
    });
  }

  test("a deleted episode keeps its cascade when it cannot be written", () async {
    final (bloc, emitted) = await loadedBloc();
    final database = projectsManager.currentProject!.database;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: database,
          screenplayId: secondId,
          fountainText: "INT. HOUSE - DAY\n\nAction.\n\nINT. CABIN - NIGHT\n\nAction two.\n",
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: database,
          screenplayId: secondId,
          fountainText: "INT. HOUSE - DAY\n\nAction.\n\nINT. CABIN - NIGHT\n\nAction three.\n",
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
    final sceneId =
        (await database
                .customSelect("SELECT id FROM scenes WHERE screenplay_id = '$secondId'")
                .get())
            .first
            .read<String>("id");
    await projectsManager.shotListService
        .createShot(database: database, screenplayId: secondId, sceneId: sceneId)
        .maybeValueOrFail;
    Future<List<int>> liveCounts() async {
      final counts = <int>[];
      for (final table in ["scenes", "shots", "screenplay_snapshots", "screenplays"]) {
        final rows = await database
            .customSelect(
              "SELECT COUNT(*) AS n FROM $table WHERE is_deleted = 0 "
              "AND ${table == "screenplays" ? "id" : "screenplay_id"} = '$secondId'",
            )
            .get();
        counts.add(rows.single.read<int>("n"));
      }

      return counts;
    }

    final before = await liveCounts();
    expect(before.every((count) => count > 0), isTrue, reason: "every table holds live rows");
    await run(
      "CREATE TRIGGER refuse_snapshots BEFORE UPDATE ON screenplay_snapshots "
      "BEGIN SELECT RAISE(ABORT, 'refused'); END",
    );

    bloc.add(OcptProjectSettingsEpisodeDeletionConfirmedEvent(screenplayId: secondId));
    await Future<void>.delayed(_quietPeriod);

    expect(emitted, isEmpty);
    expect(await liveCounts(), before, reason: "the scenes and shots tombstoned first rolled back");
  });

  test("episodes that cannot be read leave the page loading", () async {
    await run("ALTER TABLE screenplays RENAME TO screenplays_gone");
    final bloc = OcptProjectSettingsBloc(projectsManager: projectsManager);
    addTearDown(bloc.close);

    await Future<void>.delayed(_quietPeriod);

    expect(bloc.state.isLoading, isTrue);

    await run("ALTER TABLE screenplays_gone RENAME TO screenplays");
  });
}
