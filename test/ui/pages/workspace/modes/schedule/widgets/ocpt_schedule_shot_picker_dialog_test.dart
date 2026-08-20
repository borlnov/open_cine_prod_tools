// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_episode_band.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_shot_picker_dialog.dart';

/// A router manager whose [pop] only records the last call and its value: this dialog is pumped
/// directly, without a real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  /// The value [pop] was last called with.
  Object? poppedValue;

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
    poppedValue = result;
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

/// Builds a shot with the few fields these tests read, everything else neutral.
OcptShot _buildShot({required String id, required String code, String shotSize = "GP"}) => OcptShot(
  id: id,
  screenplayId: "screenplay-1",
  sceneId: "scene-1",
  orphanedHeading: null,
  position: 0,
  shotSize: shotSize,
  abbreviation: "",
  framing: "",
  cameraMove: "",
  lens: "",
  recordingFormat: "",
  estimatedDurationMs: 150000,
  shootingDay: null,
  plannedTakes: null,
  sound: "",
  status: OcptShotStatus.toShoot,
  difficultySet: 0,
  difficultyCamera: 0,
  difficultyActing: 0,
  difficultySound: 0,
  notes: "",
  locationNotes: "",
  needsCheck: false,
  checkReason: null,
  characters: const [],
  coverageRanges: const [],
  code: code,
  averageDifficulty: 0,
);

/// Builds a scene sequence with the few fields these tests read, everything else neutral.
OcptSceneShotSequence _buildSequence({
  required String sceneId,
  required String displaySceneNumber,
  required List<OcptShot> shots,
  String heading = "INT. KITCHEN - DAY",
}) => OcptSceneShotSequence(
  sceneId: sceneId,
  heading: heading,
  sceneNumber: null,
  displaySceneNumber: displaySceneNumber,
  charStart: 0,
  charEnd: 0,
  shots: shots,
);

void main() {
  late _RecordingRouterManager routerManager;

  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }

    routerManager = _RecordingRouterManager();
    managers.registerSingleton<OcptRouterManager>(routerManager);
  });

  /// Pumps [OcptScheduleShotPickerDialog] directly (no `showDialog`/`.show`), for
  /// [shotListSnapshots], [episodes] (defaulting to empty, i.e. a single-episode project drawing
  /// no band) and [placedDayNumbersByShotId] (defaulting to empty, i.e. nothing placed yet).
  Future<void> pumpDialog(
    WidgetTester tester, {
    required List<OcptShotListSnapshot> shotListSnapshots,
    List<OcptEpisode> episodes = const [],
    Map<String, List<int>> placedDayNumbersByShotId = const {},
  }) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptScheduleShotPickerDialog(
          shotListSnapshots: shotListSnapshots,
          episodes: episodes,
          placedDayNumbersByShotId: placedDayNumbersByShotId,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    "shots are grouped by sequence, headed like the left dock's own, and an already-placed shot "
    "carries its day tags",
    (tester) async {
      final shotOne = _buildShot(id: "shot-1", code: "4A/1");
      final shotTwo = _buildShot(id: "shot-2", code: "4A/2");
      final orphanShot = _buildShot(id: "shot-3", code: "?/1");

      await pumpDialog(
        tester,
        shotListSnapshots: [
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-1",
            sequences: [
              _buildSequence(sceneId: "scene-1", displaySceneNumber: "4A", shots: [shotOne, shotTwo]),
              OcptOrphanShotSequence(shots: [orphanShot]),
            ],
          ),
        ],
        placedDayNumbersByShotId: const {
          "shot-2": [3, 5],
        },
      );

      final context = tester.element(find.byType(OcptScheduleShotPickerDialog));
      final tr = Tr.of(context);

      expect(find.text(tr.scheduleUnplacedSequenceLabel("4A")), findsOneWidget);
      expect(find.text("INT. KITCHEN - DAY"), findsOneWidget);
      expect(find.text(tr.scheduleUnplacedOrphanGroupLabel), findsOneWidget);
      expect(find.text("4A/1"), findsOneWidget);
      expect(find.text("4A/2"), findsOneWidget);
      expect(find.text("?/1"), findsOneWidget);

      // The already-placed shot carries its day tags, joined, with a tooltip saying so; the
      // untouched shot carries neither.
      expect(find.text("D3, D5"), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: find.text("D3, D5"), matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, tr.scheduleShotPickerAlreadyPlacedTooltip);
    },
  );

  testWidgets("the search filters rows and drops a sequence left with nothing matching", (
    tester,
  ) async {
    final kitchenShot = _buildShot(id: "shot-1", code: "4A/1", shotSize: "Wide shot");
    final streetShot = _buildShot(id: "shot-2", code: "5/1", shotSize: "Tracking shot");

    await pumpDialog(
      tester,
      shotListSnapshots: [
        OcptShotListSnapshot.build(
          screenplayId: "screenplay-1",
          sequences: [
            _buildSequence(sceneId: "scene-1", displaySceneNumber: "4A", shots: [kitchenShot]),
            _buildSequence(
              sceneId: "scene-2",
              displaySceneNumber: "5",
              heading: "EXT. STREET - NIGHT",
              shots: [streetShot],
            ),
          ],
        ),
      ],
    );

    // Matches the sequence's own heading rather than the shot itself.
    await tester.enterText(find.byType(TextField), "kitchen");
    await tester.pumpAndSettle();

    expect(find.text("4A/1"), findsOneWidget);
    expect(find.text("5/1"), findsNothing);
    expect(find.text("EXT. STREET - NIGHT"), findsNothing);
  });

  testWidgets("tapping a shot row pops the router manager with its id", (tester) async {
    final shot = _buildShot(id: "shot-1", code: "4A/1");

    await pumpDialog(
      tester,
      shotListSnapshots: [
        OcptShotListSnapshot.build(
          screenplayId: "screenplay-1",
          sequences: [_buildSequence(sceneId: "scene-1", displaySceneNumber: "4A", shots: [shot])],
        ),
      ],
    );

    await tester.tap(find.text("4A/1"));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, "shot-1");
  });

  testWidgets("Cancel pops with no value", (tester) async {
    await pumpDialog(tester, shotListSnapshots: const []);
    final context = tester.element(find.byType(OcptScheduleShotPickerDialog));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.scheduleShotPickerCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });

  testWidgets("a shot list with no shot at all shows its own hint", (tester) async {
    await pumpDialog(
      tester,
      shotListSnapshots: [
        OcptShotListSnapshot.build(
          screenplayId: "screenplay-1",
          sequences: const [OcptOrphanShotSequence(shots: [])],
        ),
      ],
    );
    final context = tester.element(find.byType(OcptScheduleShotPickerDialog));
    final tr = Tr.of(context);

    expect(find.text(tr.scheduleShotPickerEmptyHint), findsOneWidget);
  });

  testWidgets("a search matching nothing shows its own hint, not the empty-shot-list one", (
    tester,
  ) async {
    final shot = _buildShot(id: "shot-1", code: "4A/1");

    await pumpDialog(
      tester,
      shotListSnapshots: [
        OcptShotListSnapshot.build(
          screenplayId: "screenplay-1",
          sequences: [_buildSequence(sceneId: "scene-1", displaySceneNumber: "4A", shots: [shot])],
        ),
      ],
    );

    await tester.enterText(find.byType(TextField), "nothing matches this");
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptScheduleShotPickerDialog));
    final tr = Tr.of(context);
    expect(find.text(tr.scheduleShotPickerNoResultsHint), findsOneWidget);
    expect(find.text(tr.scheduleShotPickerEmptyHint), findsNothing);
  });

  testWidgets("a single-episode project draws no episode band at all", (tester) async {
    final shot = _buildShot(id: "shot-1", code: "4A/1");

    await pumpDialog(
      tester,
      shotListSnapshots: [
        OcptShotListSnapshot.build(
          screenplayId: "screenplay-1",
          sequences: [_buildSequence(sceneId: "scene-1", displaySceneNumber: "4A", shots: [shot])],
        ),
      ],
      episodes: const [OcptEpisode(id: "screenplay-1", number: 1, title: "")],
    );

    expect(find.byType(OcptScheduleEpisodeBand), findsNothing);
    expect(find.text("Episode 1"), findsNothing);
  });

  testWidgets(
    "a two-episode project bands its sections by episode, then sequence, in episode order",
    (tester) async {
      final kitchenShot = _buildShot(id: "shot-1", code: "4A/1");
      final streetShot = _buildShot(id: "shot-2", code: "5/1");

      await pumpDialog(
        tester,
        shotListSnapshots: [
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-1",
            sequences: [
              _buildSequence(sceneId: "scene-1", displaySceneNumber: "4A", shots: [kitchenShot]),
            ],
          ),
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-2",
            sequences: [
              _buildSequence(
                sceneId: "scene-2",
                displaySceneNumber: "5",
                heading: "EXT. STREET - NIGHT",
                shots: [streetShot],
              ),
            ],
          ),
        ],
        episodes: const [
          OcptEpisode(id: "screenplay-1", number: 1, title: ""),
          OcptEpisode(id: "screenplay-2", number: 2, title: ""),
        ],
      );

      expect(find.byType(OcptScheduleEpisodeBand), findsNWidgets(2));
      expect(find.text("Episode 1"), findsOneWidget);
      expect(find.text("Episode 2"), findsOneWidget);

      final episodeOneBandY = tester.getTopLeft(find.text("Episode 1")).dy;
      final episodeOneSectionY = tester.getTopLeft(find.text("INT. KITCHEN - DAY")).dy;
      final episodeTwoBandY = tester.getTopLeft(find.text("Episode 2")).dy;
      final episodeTwoSectionY = tester.getTopLeft(find.text("EXT. STREET - NIGHT")).dy;

      expect(episodeOneBandY, lessThan(episodeOneSectionY));
      expect(episodeOneSectionY, lessThan(episodeTwoBandY));
      expect(episodeTwoBandY, lessThan(episodeTwoSectionY));
    },
  );

  testWidgets(
    "the search narrows across every episode, dropping a band left with nothing matching",
    (tester) async {
      final kitchenShot = _buildShot(id: "shot-1", code: "4A/1");
      final streetShot = _buildShot(id: "shot-2", code: "5/1");

      await pumpDialog(
        tester,
        shotListSnapshots: [
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-1",
            sequences: [
              _buildSequence(sceneId: "scene-1", displaySceneNumber: "4A", shots: [kitchenShot]),
            ],
          ),
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-2",
            sequences: [
              _buildSequence(
                sceneId: "scene-2",
                displaySceneNumber: "5",
                heading: "EXT. STREET - NIGHT",
                shots: [streetShot],
              ),
            ],
          ),
        ],
        episodes: const [
          OcptEpisode(id: "screenplay-1", number: 1, title: ""),
          OcptEpisode(id: "screenplay-2", number: 2, title: ""),
        ],
      );

      // Matches only episode 1's own sequence heading.
      await tester.enterText(find.byType(TextField), "kitchen");
      await tester.pumpAndSettle();

      expect(find.text("4A/1"), findsOneWidget);
      expect(find.text("5/1"), findsNothing);
      expect(find.text("EXT. STREET - NIGHT"), findsNothing);

      // Episode 1's own band survives; episode 2's disappears along with its own (now empty)
      // section, exactly as a sequence left with no matching shot already does.
      expect(find.byType(OcptScheduleEpisodeBand), findsOneWidget);
      expect(find.text("Episode 1"), findsOneWidget);
      expect(find.text("Episode 2"), findsNothing);
    },
  );
}
