// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

void main() {
  // OcptProjectVersionSummary.parse logs through appLogger(), which requires a global manager
  // instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  /// A payload holding [screenplays] and [shots], at the standard page setup: the two tables a
  /// summary measures.
  OcptProjectVersionPayload buildPayload({
    List<OcptScreenplayRow> screenplays = const [],
    List<OcptShotRow> shots = const [],
  }) => OcptProjectVersionPayload(
    screenplays: screenplays,
    scenes: const [],
    shots: shots,
    shotCharacters: const [],
    shotCoverages: const [],
    people: const [],
    personPositions: const [],
    personSkills: const [],
    personUnavailabilities: const [],
    roles: const [],
    locations: const [],
    locationAvailabilities: const [],
    sets: const [],
    sceneSets: const [],
    elements: const [],
    sceneElements: const [],
    roleElements: const [],
    assets: const [],
    breakdownTags: const [],
    sceneBreakdowns: const [],
    shootingDays: const [],
    shootingSlots: const [],
    shootingSlotCrew: const [],
    shootingSlotCast: const [],
    shootingDayBlocks: const [],
    shootingPresences: const [],
    shootingSlotGuests: const [],
    shootingDayEvents: const [],
    rowFieldVersions: const [],
    pageSetup: const OcptPageSetup.standard(),
    settingsJson: null,
    currencyCode: null,
  );

  /// A screenplay row holding [fountainText], live unless [isDeleted].
  OcptScreenplayRow buildScreenplay({
    required String id,
    required String fountainText,
    bool isDeleted = false,
  }) => OcptScreenplayRow(
    id: id,
    title: id,
    fountainText: fountainText,
    updatedAt: DateTime.utc(2026, 5, 20),
    isDeleted: isDeleted,
  );

  /// A shot row pointing at [sceneId], live unless [isDeleted]. Only the columns this summary
  /// reads carry anything meaningful; the rest is the empty shot a fresh row would hold.
  OcptShotRow buildShot({required String id, String? sceneId, bool isDeleted = false}) =>
      OcptShotRow(
        id: id,
        screenplayId: "screenplay-1",
        sceneId: sceneId,
        position: 0,
        sortKey: "V",
        shotSize: "",
        abbreviation: "",
        framing: "",
        cameraMove: "",
        lens: "",
        recordingFormat: "",
        sound: "",
        status: OcptShotStatus.toShoot,
        difficultySet: 1,
        difficultyCamera: 1,
        difficultyActing: 1,
        difficultySound: 1,
        notes: "",
        locationNotes: "",
        needsCheck: false,
        isDeleted: isDeleted,
      );

  group('OcptProjectVersionSummary.of', () {
    test('counts the pages of every live screenplay of the payload', () {
      final summary = OcptProjectVersionSummary.of(
        buildPayload(
          screenplays: [
            buildScreenplay(id: "screenplay-1", fountainText: "INT. HOUSE - DAY\n\nCLARA enters."),
          ],
        ),
      );

      expect(summary.pageCount, 1);
    });

    test('a tombstoned screenplay adds no page, and an empty project measures zero', () {
      final summary = OcptProjectVersionSummary.of(
        buildPayload(
          screenplays: [
            buildScreenplay(
              id: "screenplay-1",
              fountainText: "INT. HOUSE - DAY\n\nCLARA enters.",
              isDeleted: true,
            ),
          ],
        ),
      );

      expect(summary.pageCount, 0);
      expect(OcptProjectVersionSummary.of(buildPayload()), OcptProjectVersionSummary.empty);
    });

    test('a sequence counts as broken down as soon as one live shot points at it', () {
      final summary = OcptProjectVersionSummary.of(
        buildPayload(
          shots: [
            buildShot(id: "shot-1", sceneId: "scene-1"),
            buildShot(id: "shot-2", sceneId: "scene-1"),
            buildShot(id: "shot-3", sceneId: "scene-2"),
          ],
        ),
      );

      expect(summary.brokenDownSequenceCount, 2);
    });

    test('tombstoned and orphaned shots break down no sequence', () {
      final summary = OcptProjectVersionSummary.of(
        buildPayload(
          shots: [
            buildShot(id: "shot-1", sceneId: "scene-1", isDeleted: true),
            buildShot(id: "shot-2"),
          ],
        ),
      );

      expect(summary.brokenDownSequenceCount, 0);
    });
  });

  group('OcptProjectVersionSummary JSON', () {
    test('parse(toJson) returns an equal summary', () {
      const summary = OcptProjectVersionSummary(pageCount: 41, brokenDownSequenceCount: 3);

      expect(OcptProjectVersionSummary.parse(jsonTextOf(summary)), summary);
    });

    test('an unreadable stored summary falls back to zeroes rather than hiding the version', () {
      expect(OcptProjectVersionSummary.parse("not json"), OcptProjectVersionSummary.empty);
      expect(OcptProjectVersionSummary.parse("[1, 2]"), OcptProjectVersionSummary.empty);
      expect(OcptProjectVersionSummary.parse('{"pageCount":41}'), OcptProjectVersionSummary.empty);
    });
  });
}

/// [summary] as the JSON text a `project_versions` row stores.
String jsonTextOf(OcptProjectVersionSummary summary) => jsonEncode(summary.toJson());
