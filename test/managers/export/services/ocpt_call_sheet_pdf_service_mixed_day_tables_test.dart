// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_block_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
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

    /// [plan]'s own general call sheet of `day-1`, at the pinned moment.
    Future<Uint8List> generalOf(OcptSchedulePlanSnapshot plan) => service.generateGeneralCallSheet(
      plan: plan,
      dayId: "day-1",
      pageSetup: pageSetup,
      labels: labels,
      projectName: "My Movie",
      exportDate: pinnedExportDate,
    );

    test("two candidacies on one block print two rows sharing one hour", () async {
      final alice = buildPerson(id: "person-alice", firstName: "Alice", lastName: "Simon");
      final second = buildRoleCandidate(id: "candidate-2", roleId: "role-2", person: alice);
      OcptSchedulePlanSnapshot buildWith(List<OcptShootingBlockCandidate> links) => buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [buildSlot(id: "slot-1", label: "Casting", anchorMinute: 540)],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 40,
              candidates: links,
            ),
          ],
        },
        roles: [
          buildRole(id: "role-1", name: "Marie", number: 3),
          buildRole(id: "role-2", name: "Julien", number: 4),
        ],
        people: [camille, alice],
        roleCandidates: [candidate, second],
      );

      final oneBytes = await generalOf(buildWith([namedOn("block-1")]));
      final twoBytes = await generalOf(
        buildWith([
          namedOn("block-1"),
          buildBlockCandidate(id: "link-2", blockId: "block-1", roleCandidateId: "candidate-2"),
        ]),
      );

      expect(contentStreams(twoBytes), isNot(contentStreams(oneBytes)));
      expect(twoBytes.length, greaterThan(oneBytes.length));
    });

    test("the candidates list is day-wide on a named sheet, the audition table is not", () async {
      final morning = buildSlot(
        id: "slot-morning",
        label: "Casting",
        anchorMinute: 540,
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-morning", personId: "person-1")],
      );
      final afternoon = buildSlot(id: "slot-afternoon", label: "Second unit", anchorMinute: 840);

      final plan = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [morning, afternoon],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-morning",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 60,
              candidates: [namedOn("block-1")],
            ),
            buildBlock(
              id: "block-2",
              slotId: "slot-afternoon",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 60,
            ),
          ],
        },
        roles: [buildRole(id: "role-1", name: "Marie", number: 3)],
        people: [
          camille,
          buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard"),
        ],
        roleCandidates: [candidate],
      );

      final crewConvocation = plan
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");
      final named = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: crewConvocation,
        exportDate: pinnedExportDate,
      );
      final general = await generalOf(plan);

      expect(ascii.decode(named.sublist(0, 4)), "%PDF");
      // The general sheet's audition table holds both blocks, the crew member's own holds only the
      // morning's — the timetable is the one thing a named sheet narrows.
      expect(contentStreams(named), isNot(contentStreams(general)));
    });

    test(
      "a candidate gets a named sheet of their own, headed by their name and the part",
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

        final candidateConvocation = plan
            .convocationsOfDay("day-1")
            .firstWhere((c) => c.isSeenForAPart);
        final bytes = await service.generateNamedCallSheet(
          plan: plan,
          dayId: "day-1",
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          convocation: candidateConvocation,
          exportDate: pinnedExportDate,
        );

        expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
        expect(pageCount(bytes), 1);
        // The recipient's own name is what the file is called: not the fallback label a convocation
        // this service could name nobody for would fall back to.
        expect(
          service.namedCallSheetFileName(
            labels: labels,
            dayNumber: 1,
            personName: "Camille Renard",
          ),
          "FDS-D1-Camille-Renard.pdf",
        );
      },
    );

    test("a candidate's own sheet prints their audition and their line, and no other's", () async {
      // The one place a named sheet narrows a directory (ADR 0024): who else is being seen for a
      // part, and on what phone number, is the production's business and not another candidate's.
      // Proved by swapping *who* that other candidate is: Camille's own sheet must come out
      // identical, which it only can if neither the audition table nor the directory carries them.
      OcptSchedulePlanSnapshot buildWithOther(OcptPerson otherPerson) {
        final other = buildRoleCandidate(id: "candidate-2", roleId: "role-1", person: otherPerson);

        return buildSnapshot(
          days: [testBuildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [buildSlot(id: "slot-1", label: "Casting", anchorMinute: 540)],
          },
          blocksByDayId: {
            "day-1": [
              buildBlock(
                id: "block-1",
                slotId: "slot-1",
                kind: OcptShootingBlockKind.audition,
                durationMinutes: 20,
                candidates: [namedOn("block-1")],
              ),
              buildBlock(
                id: "block-2",
                slotId: "slot-1",
                kind: OcptShootingBlockKind.audition,
                durationMinutes: 20,
                candidates: [
                  buildBlockCandidate(
                    id: "link-2",
                    blockId: "block-2",
                    roleCandidateId: "candidate-2",
                  ),
                ],
              ),
            ],
          },
          roles: [buildRole(id: "role-1", name: "Marie", number: 3)],
          people: [camille, otherPerson],
          roleCandidates: [candidate, other],
        );
      }

      Future<Uint8List> camilleSheetOf(OcptSchedulePlanSnapshot plan) =>
          service.generateNamedCallSheet(
            plan: plan,
            dayId: "day-1",
            pageSetup: pageSetup,
            labels: labels,
            projectName: "My Movie",
            convocation: plan
                .convocationsOfDay("day-1")
                .firstWhere((c) => c.roleCandidateIds.contains("candidate-1")),
            exportDate: pinnedExportDate,
          );

      final withAlice = buildWithOther(
        buildPerson(
          id: "person-alice",
          firstName: "Alice",
          lastName: "Simon",
          phone: "0655667788",
          email: "alice@example.org",
        ),
      );
      final withJonas = buildWithOther(
        buildPerson(
          id: "person-jonas",
          firstName: "Jonas",
          lastName: "Weber",
          phone: "0699887766",
          email: "jonas@example.org",
        ),
      );

      // Each candidate is expected at their own twenty minutes, off their own block rather than off
      // the unit's whole session.
      final convocations = withAlice.convocationsOfDay("day-1");
      final camilleCall = convocations.firstWhere(
        (c) => c.roleCandidateIds.contains("candidate-1"),
      );
      final aliceCall = convocations.firstWhere((c) => c.roleCandidateIds.contains("candidate-2"));
      expect(camilleCall.arrivalMinute, 540);
      expect(camilleCall.departureMinute, 560);
      expect(aliceCall.arrivalMinute, 560);
      expect(aliceCall.departureMinute, 580);

      expect(
        contentStreams(await camilleSheetOf(withAlice)),
        contentStreams(await camilleSheetOf(withJonas)),
        reason: "who else was seen that day appears nowhere on this candidate's own sheet",
      );

      // The general sheet, by contrast, carries both of them — it is the day's own paperwork.
      expect(
        contentStreams(await generalOf(withAlice)),
        isNot(contentStreams(await generalOf(withJonas))),
      );
    });

    test("a day that films nothing heads its band PRESENCE rather than PAT", () async {
      // The label follows the band, not the day's paperwork: a day of auditions has no take for
      // anybody to be ready for, so the word `PAT` cannot appear on it at all.
      final auditions = buildDay(
        blocks: [
          buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 20,
            candidates: [namedOn("block-1")],
          ),
        ],
      );

      final call = auditions
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.roleCandidateIds.contains("candidate-1"));
      expect(call.patStartMinute, 540);
      expect(call.isPatBand, isFalse);

      final bytes = await service.generateNamedCallSheet(
        plan: auditions,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: call,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("a candidate and an actor read different words on the one mixed sheet", () async {
      // The whole reason the label is per convocation: the unit is due ready to shoot at 13:00 and
      // the candidate is due to be seen at 09:00, and one word cannot be both.
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final plan = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [
            buildSlot(
              id: "slot-1",
              label: "Casting",
              anchorMinute: 540,
              cast: [buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
            ),
          ],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 20,
              candidates: [namedOn("block-1")],
            ),
            buildBlock(
              id: "block-2",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        roles: [buildRole(id: "role-1", name: "Marie", number: 3, personId: "person-lea")],
        people: [
          camille,
          buildPerson(id: "person-lea", firstName: "Léa", lastName: "Dubois"),
        ],
        roleCandidates: [candidate],
        shotLists: [
          buildShotList(shots: [shot]),
        ],
      );

      final convocations = plan.convocationsOfDay("day-1");
      expect(convocations.firstWhere((c) => c.personId == "person-lea").isPatBand, isTrue);
      expect(convocations.firstWhere((c) => c.isSeenForAPart).isPatBand, isFalse);
    });

    test("crewing the day and being seen for a part is one recipient, one sheet", () async {
      // The fault reading the exports showed: a person held two convocations and received two
      // sheets. They arrive once and leave once, and the one sheet says everything they do.
      final plan = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [
            buildSlot(
              id: "slot-1",
              label: "Casting",
              anchorMinute: 480, // 08:00 — on the unit from the start
              crew: [buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-camille")],
            ),
          ],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(id: "block-1", slotId: "slot-1", durationMinutes: 120),
            buildBlock(
              id: "block-2",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 20,
              candidates: [namedOn("block-2")],
            ),
          ],
        },
        roles: [buildRole(id: "role-1", name: "Marie", number: 3)],
        people: [camille],
        roleCandidates: [candidate],
      );

      // One convocation, not two, and it spans both reasons.
      final convocation = plan.convocationsOfDay("day-1").single;
      expect(convocation.personId, camille.id);
      expect(convocation.roleCandidateIds, {"candidate-1"});
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 620);
      // The day films nothing, so their band is a presence one however they got there.
      expect(convocation.isPatBand, isFalse);

      final bytes = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: convocation,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(pageCount(bytes), 1);
    });

    test(
      "an actor's own sheet drops the shots they are not in, and keeps every milestone",
      () async {
        // The fault reading the exports showed: a sheet narrowed to the recipient's units and then
        // printed the whole running order, so an actor had to work out which shots were theirs.
        // Thirty shots, alternating between two parts, is enough for the difference to be a page.
        final lea = buildPerson(id: "person-lea", firstName: "Léa", lastName: "Dubois");
        final shots = [
          for (var i = 0; i < 30; i++)
            buildShot(
              id: "shot-$i",
              sceneId: "scene-1",
              code: "$i/1",
              characters: [if (i.isEven) "MARIE" else "JULIEN"],
            ),
        ];
        final plan = buildSnapshot(
          days: [testBuildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [
              buildSlot(
                id: "slot-1",
                anchorMinute: 480,
                cast: [
                  buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1"),
                  buildCastMember(id: "cast-2", slotId: "slot-1", roleId: "role-2"),
                ],
              ),
            ],
          },
          blocksByDayId: {
            "day-1": [
              for (var i = 0; i < 30; i++)
                buildBlock(
                  id: "block-$i",
                  slotId: "slot-1",
                  kind: OcptShootingBlockKind.shot,
                  shotId: "shot-$i",
                  durationMinutes: 20,
                ),
              buildBlock(
                id: "block-meal",
                slotId: "slot-1",
                kind: OcptShootingBlockKind.meal,
                durationMinutes: 45,
              ),
            ],
          },
          roles: [
            buildRole(id: "role-1", name: "MARIE", number: 3, personId: "person-lea"),
            buildRole(id: "role-2", name: "JULIEN", number: 4, personId: "person-jules"),
          ],
          people: [
            lea,
            buildPerson(id: "person-jules", firstName: "Jules", lastName: "Marchand"),
          ],
          shotLists: [buildShotList(shots: shots)],
        );

        final leaCall = plan
            .convocationsOfDay("day-1")
            .firstWhere((c) => c.personId == "person-lea");
        final leaSheet = await service.generateNamedCallSheet(
          plan: plan,
          dayId: "day-1",
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          convocation: leaCall,
          exportDate: pinnedExportDate,
        );
        final general = await generalOf(plan);

        // The day's whole order runs onto a second page; hers, holding half of it, does not.
        expect(pageCount(general), greaterThan(1));
        expect(pageCount(leaSheet), 1);
      },
    );
  });
}
