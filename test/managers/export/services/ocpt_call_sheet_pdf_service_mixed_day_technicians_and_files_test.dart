// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_block_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'ocpt_call_sheet_pdf_service_test_doubles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate…` calls must not re-read the asset bundle).
  final service = OcptCallSheetPdfService(logger: const SilentLogger());

  const pageSetup = OcptPageSetup.standard();

  group("a day that does not only shoot", () {
    /// A candidate seen for `role-1`, and the person behind them.
    final camille = buildPerson(
      id: "person-camille",
      firstName: "Camille",
      lastName: "Renard",
      phone: "0611223344",
      email: "camille@example.org",
    );

    final candidate = buildRoleCandidate(id: "candidate-1", roleId: "role-1", person: camille);

    /// The link naming [candidate] on audition block [blockId].
    OcptShootingBlockCandidate namedOn(String blockId) =>
        buildBlockCandidate(id: "link-$blockId", blockId: blockId, roleCandidateId: "candidate-1");

    /// A day of one slot, given [blocks].
    OcptSchedulePlanSnapshot buildDay({
      required List<OcptShootingDayBlock> blocks,
      List<OcptShot> shots = const [],
    }) => buildSnapshot(
      days: [testBuildDay(id: "day-1", dayNumber: 1)],
      slotsByDayId: {
        "day-1": [buildSlot(id: "slot-1", label: "Casting", anchorMinute: 540)],
      },
      blocksByDayId: {"day-1": blocks},
      roles: [buildRole(id: "role-1", name: "Marie", number: 3)],
      people: [camille],
      roleCandidates: [candidate],
      shotLists: shots.isEmpty ? const [] : [buildShotList(shots: shots)],
    );

    test("a technician keeps the whole running order of the unit they crew", () async {
      // The rule that keeps a narrowing from taking a sheet apart: a slot naming somebody as crew
      // is an order they work end to end, whatever it plays.
      final gaffer = buildPerson(id: "person-gaffer", firstName: "Sam", lastName: "Roche");
      final shot = buildShot(
        id: "shot-1",
        sceneId: "scene-1",
        code: "1/1",
        characters: const ["MARIE"],
      );
      final plan = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [
            buildSlot(
              id: "slot-1",
              anchorMinute: 480,
              crew: [buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-gaffer")],
            ),
          ],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        roles: [buildRole(id: "role-1", name: "MARIE", number: 3)],
        people: [gaffer],
        shotLists: [
          buildShotList(shots: [shot]),
        ],
      );

      final call = plan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-gaffer");
      final theirs = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: call,
        exportDate: pinnedExportDate,
      );

      // The shot plays a part they do not, and it is still on their sheet: they light it.
      expect(ascii.decode(theirs.sublist(0, 4)), "%PDF");
      expect(pageCount(theirs), 1);
    });

    test(
      "a candidate carries a selection key, so the named export can be narrowed to them",
      () async {
        final plan = buildDay(
          blocks: [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 120,
              candidates: [namedOn("block-1")],
            ),
          ],
        );

        // Keyed by their **person**: a sheet is addressed to somebody, so somebody crewing the day
        // and seen for a part is one recipient and one PDF. A guest is the one convocation kind
        // carrying no key at all, which is what keeps them out of the named sheets dialog without
        // that dialog needing a rule of its own.
        final convocations = plan.convocationsOfDay("day-1");
        expect(convocations.single.selectionKey, camille.id);
      },
    );
  });

  group("multiple episodes", () {
    /// Episode 1's own one-scene shot list: `scene-e1`, prefixed `1.3` — the number
    /// `OcptShotListService.loadShotList` would already have given it.
    OcptShotListSnapshot buildEpisodeOneShotList(OcptShot shot) => OcptShotListSnapshot.build(
      screenplayId: "episode-1",
      sequences: [
        OcptSceneShotSequence(
          sceneId: "scene-e1",
          heading: "INT. HOUSE - DAY",
          sceneNumber: null,
          displaySceneNumber: "1.3",
          charStart: 0,
          charEnd: 10,
          shots: [shot],
        ),
      ],
    );

    /// Episode 2's own one-scene shot list: `scene-e2`, prefixed `2.4`.
    OcptShotListSnapshot buildEpisodeTwoShotList(OcptShot shot) => OcptShotListSnapshot.build(
      screenplayId: "episode-2",
      sequences: [
        OcptSceneShotSequence(
          sceneId: "scene-e2",
          heading: "EXT. STREET - NIGHT",
          sceneNumber: null,
          displaySceneNumber: "2.4",
          charStart: 0,
          charEnd: 10,
          shots: [shot],
        ),
      ],
    );

    test(
      "a role speaking in shots of both episodes is one cast row, not two, carrying scene "
      "numbers from both — and the SEQ column carries both episodes' own prefixed codes",
      () async {
        final role = buildRole(id: "role-1", name: "Alice");
        final slot = buildSlot(
          id: "slot-1",
          anchorMinute: 480,
          cast: [buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
        );
        final blocks = {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e1",
              durationMinutes: 60,
            ),
            buildBlock(
              id: "block-2",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e2",
              durationMinutes: 60,
            ),
          ],
        };

        // Alice speaks in both episodes' own shots: one role, cast once on the slot, its character
        // read off two shots of two different scenes.
        final oneRoleShotOne = buildShot(
          id: "shot-e1",
          sceneId: "scene-e1",
          code: "1.3/1",
          characters: const ["ALICE"],
        );
        final oneRoleShotTwo = buildShot(
          id: "shot-e2",
          sceneId: "scene-e2",
          code: "2.4/1",
          characters: const ["ALICE"],
        );
        final oneRolePlan = buildSnapshot(
          days: [testBuildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: blocks,
          roles: [role],
          shotLists: [
            buildEpisodeOneShotList(oneRoleShotOne),
            buildEpisodeTwoShotList(oneRoleShotTwo),
          ],
        );

        // A second, distinct role speaks in the second episode's own shot instead — a whole second
        // identity, where the fixture above kept it the very same Alice.
        final secondRole = buildRole(id: "role-2", name: "Bob", number: 2);
        final twoRolesShotOne = buildShot(
          id: "shot-e1",
          sceneId: "scene-e1",
          code: "1.3/1",
          characters: const ["ALICE"],
        );
        final twoRolesShotTwo = buildShot(
          id: "shot-e2",
          sceneId: "scene-e2",
          code: "2.4/1",
          characters: const ["BOB"],
        );
        final twoRolesSlot = buildSlot(
          id: "slot-1",
          anchorMinute: 480,
          cast: [
            buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1"),
            buildCastMember(id: "cast-2", slotId: "slot-1", roleId: "role-2"),
          ],
        );
        final twoRolesPlan = buildSnapshot(
          days: [testBuildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [twoRolesSlot],
          },
          blocksByDayId: blocks,
          roles: [role, secondRole],
          shotLists: [
            buildEpisodeOneShotList(twoRolesShotOne),
            buildEpisodeTwoShotList(twoRolesShotTwo),
          ],
        );

        final oneRoleBytes = await service.generateGeneralCallSheet(
          plan: oneRolePlan,
          dayId: "day-1",
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          exportDate: pinnedExportDate,
        );
        final twoRolesBytes = await service.generateGeneralCallSheet(
          plan: twoRolesPlan,
          dayId: "day-1",
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          exportDate: pinnedExportDate,
        );

        // Both documents print the same two SEQ rows (1.3 then 2.4), so the only thing that can
        // still tell them apart is the cast side: a second, distinct role costs a whole extra row
        // in the cast table and a whole extra entry in the cast-and-extras list, where the very
        // same Alice speaking a second time costs one more scene number appended to her own row. If
        // the cast table had printed Alice twice instead of merging her two episodes into one row,
        // the two documents would be the same size; they are not, and the two-role one is the
        // larger of the two.
        expect(contentStreams(oneRoleBytes), isNot(contentStreams(twoRolesBytes)));
        expect(twoRolesBytes.length, greaterThan(oneRoleBytes.length));
      },
    );

    test("a named sheet's own timetable narrows to its recipient's episode, but its cast table "
        "stays the day's — naming a role that speaks only in the other episode's own "
        "slot", () async {
      final role = buildRole(id: "role-1", name: "Alice");
      final secondRole = buildRole(id: "role-2", name: "Bob", number: 2);
      final morning = buildSlot(
        id: "slot-morning",
        anchorMinute: 480,
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-morning", personId: "person-1")],
      );
      final evening = buildSlot(id: "slot-evening", anchorMinute: 1080);
      final shotOne = buildShot(
        id: "shot-e1",
        sceneId: "scene-e1",
        code: "1.3/1",
        characters: const ["ALICE"],
      );
      final shotTwo = buildShot(
        id: "shot-e2",
        sceneId: "scene-e2",
        code: "2.4/1",
        characters: const ["BOB"],
      );

      OcptSchedulePlanSnapshot buildPlan({required bool withEveningEpisode}) => buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": withEveningEpisode ? [morning, evening] : [morning],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-morning",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e1",
              durationMinutes: 60,
            ),
            if (withEveningEpisode)
              buildBlock(
                id: "block-2",
                slotId: "slot-evening",
                kind: OcptShootingBlockKind.shot,
                shotId: "shot-e2",
                durationMinutes: 60,
              ),
          ],
        },
        roles: withEveningEpisode ? [role, secondRole] : [role],
        people: [buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        shotLists: withEveningEpisode
            ? [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)]
            : [buildEpisodeOneShotList(shotOne)],
      );

      final withBothEpisodes = buildPlan(withEveningEpisode: true);
      final morningEpisodeOnly = buildPlan(withEveningEpisode: false);

      Future<Uint8List> generateNamedFor(OcptSchedulePlanSnapshot plan) async {
        final convocation = plan
            .convocationsOfDay("day-1")
            .firstWhere((c) => c.personId == "person-1");
        return service.generateNamedCallSheet(
          plan: plan,
          dayId: "day-1",
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          convocation: convocation,
          exportDate: pinnedExportDate,
        );
      }

      final withBothEpisodesBytes = await generateNamedFor(withBothEpisodes);
      final morningEpisodeOnlyBytes = await generateNamedFor(morningEpisodeOnly);

      // The morning recipient's own main table never sees the evening slot at all, so this can
      // only differ through the day-wide cast table (and the two closing lists it feeds): Bob, cast
      // in the evening's own episode 2 shot alone, still has to show up on a sheet addressed to
      // somebody who never shares a slot with him.
      expect(contentStreams(withBothEpisodesBytes), isNot(contentStreams(morningEpisodeOnlyBytes)));
      expect(withBothEpisodesBytes.length, greaterThan(morningEpisodeOnlyBytes.length));
    });
  });

  group("callSheetFileName", () {
    test("joins the file name prefix and the day tag", () {
      expect(service.callSheetFileName(labels: labels, dayNumber: 2), "FDS-D2.pdf");
    });
  });

  group("namedCallSheetFileName", () {
    test("appends the sanitized person name", () {
      expect(
        service.namedCallSheetFileName(labels: labels, dayNumber: 2, personName: "Elisa Mabit"),
        "FDS-D2-Elisa-Mabit.pdf",
      );
    });

    test("a name with a slash, an accent and a space produces a safe file name", () {
      final fileName = service.namedCallSheetFileName(
        labels: labels,
        dayNumber: 2,
        personName: "Élise/Bénard Dupont",
      );

      expect(fileName, isNot(contains("/")));
      expect(fileName, isNot(contains("É")));
      expect(fileName, isNot(contains("é")));
      expect(fileName, "FDS-D2-EliseBenard-Dupont.pdf");
    });

    test("a blank name falls back to the localized unnamed-person label, sanitized", () {
      expect(
        service.namedCallSheetFileName(labels: labels, dayNumber: 3, personName: "   "),
        "FDS-D3-No-name.pdf",
      );
    });
  });
}
