// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_block_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'ocpt_call_sheet_pdf_service_test_doubles.dart';

/// Builds an element with the few fields these tests read, everything else neutral.
OcptElement _buildElement({
  required String id,
  String name = "",
  OcptElementCategory category = OcptElementCategory.prop,
  String? broughtByPersonId,
  List<OcptSceneElementLink> sceneLinks = const [],
}) => OcptElement(
  id: id,
  category: category,
  subCategory: "",
  name: name,
  code: "",
  quantity: "1",
  sourceKind: OcptElementSourceKind.owned,
  status: OcptElementStatus.toFind,
  ownerPersonId: null,
  ownerNotes: "",
  broughtByPersonId: broughtByPersonId,
  storageNotes: "",
  isSecured: false,
  isReadyForShoot: false,
  isReturned: false,
  cost: null,
  purposeNotes: "",
  notes: "",
  photoAssetId: null,
  photo: null,
  sceneLinks: sceneLinks,
  roleLinks: const [],
);

/// Builds a *dépouillement* link with the few fields these tests read, everything else neutral.
OcptSceneElementLink _buildSceneElementLink({required String id, required String sceneId}) =>
    OcptSceneElementLink(id: id, sceneId: sceneId, quantity: "1", notes: "");

/// Run the tests of the call sheet pdf service named sheet sections.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate…` calls must not re-read the asset bundle).
  final service = OcptCallSheetPdfService(logger: const SilentLogger());

  const pageSetup = OcptPageSetup.standard();

  group("the named sheet's own 'to bring' section", () {
    /// A day with one crew member (`person-1`) and one uncast role (`role-1`) convoked on the same
    /// slot, shooting `scene-1` — enough to test the section's own presence, absence and the
    /// general sheet's own indifference to it.
    OcptSchedulePlanSnapshot buildPlan({required List<OcptElement> elements}) {
      final slot = buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        crew: [buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
        cast: [buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
      );
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");

      return buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
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
        roles: [buildRole(id: "role-1", name: "Alice")], // personId null: an uncast role.
        people: [buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        shotLists: [
          buildShotList(shots: [shot]),
        ],
        elements: elements,
      );
    }

    test(
      "a named sheet differs once its recipient's own element is linked to a scene the day plays",
      () async {
        final linkedPlan = buildPlan(
          elements: [
            _buildElement(
              id: "element-1",
              name: "Umbrella",
              broughtByPersonId: "person-1",
              sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
            ),
          ],
        );
        final unlinkedPlan = buildPlan(
          elements: [
            _buildElement(id: "element-1", name: "Umbrella", broughtByPersonId: "person-1"),
          ],
        );

        final linkedConvocation = linkedPlan
            .convocationsOfDay("day-1")
            .firstWhere((c) => c.personId == "person-1");
        final unlinkedConvocation = unlinkedPlan
            .convocationsOfDay("day-1")
            .firstWhere((c) => c.personId == "person-1");

        final linkedBytes = await service.generateNamedCallSheet(
          plan: linkedPlan,
          dayId: "day-1",
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          convocation: linkedConvocation,
          exportDate: pinnedExportDate,
        );
        final unlinkedBytes = await service.generateNamedCallSheet(
          plan: unlinkedPlan,
          dayId: "day-1",
          pageSetup: pageSetup,
          labels: labels,
          projectName: "My Movie",
          convocation: unlinkedConvocation,
          exportDate: pinnedExportDate,
        );

        expect(contentStreams(linkedBytes), isNot(contentStreams(unlinkedBytes)));
      },
    );

    test("a named sheet for an uncast role is unchanged by any element at all", () async {
      final withElement = buildPlan(
        elements: [
          _buildElement(
            id: "element-1",
            name: "Umbrella",
            broughtByPersonId: "person-1",
            sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
          ),
        ],
      );
      final withoutElement = buildPlan(elements: const []);

      final withElementConvocation = withElement
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.roleId == "role-1");
      final withoutElementConvocation = withoutElement
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.roleId == "role-1");

      final withElementBytes = await service.generateNamedCallSheet(
        plan: withElement,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: withElementConvocation,
        exportDate: pinnedExportDate,
      );
      final withoutElementBytes = await service.generateNamedCallSheet(
        plan: withoutElement,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        convocation: withoutElementConvocation,
        exportDate: pinnedExportDate,
      );

      expect(
        contentStreams(withElementBytes),
        contentStreams(withoutElementBytes),
        reason: "an uncast role has nobody to bring anything, so the section never opens for it",
      );
    });

    test("the general sheet is unchanged by the same element", () async {
      final withElement = buildPlan(
        elements: [
          _buildElement(
            id: "element-1",
            name: "Umbrella",
            broughtByPersonId: "person-1",
            sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
          ),
        ],
      );
      final withoutElement = buildPlan(elements: const []);

      final withElementBytes = await service.generateGeneralCallSheet(
        plan: withElement,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );
      final withoutElementBytes = await service.generateGeneralCallSheet(
        plan: withoutElement,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: labels,
        projectName: "My Movie",
        exportDate: pinnedExportDate,
      );

      expect(
        contentStreams(withElementBytes),
        contentStreams(withoutElementBytes),
        reason:
            "what to bring is a fact about one recipient; the general sheet never reads it at all",
      );
    });
  });

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

    test(
      "a day of auditions prints a table a day of the same blocks without them does not",
      () async {
        final auditions = buildDay(
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
        final holds = buildDay(
          blocks: [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.hold,
              durationMinutes: 120,
            ),
          ],
        );

        final auditionBytes = await generalOf(auditions);
        final holdBytes = await generalOf(holds);

        expect(ascii.decode(auditionBytes.sublist(0, 4)), "%PDF");
        expect(contentStreams(auditionBytes), isNot(contentStreams(holdBytes)));
        // The audition table is a whole section the hold day has no heading for at all.
        expect(auditionBytes.length, greaterThan(holdBytes.length));
      },
    );

    test("a second audition adds a row rather than a second table", () async {
      final one = buildDay(
        blocks: [
          buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 60,
            candidates: [namedOn("block-1")],
          ),
        ],
      );
      final two = buildDay(
        blocks: [
          buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 60,
            candidates: [namedOn("block-1")],
          ),
          buildBlock(
            id: "block-2",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 60,
            candidates: [namedOn("block-2")],
          ),
        ],
      );

      final oneBytes = await generalOf(one);
      final twoBytes = await generalOf(two);

      expect(contentStreams(twoBytes), isNot(contentStreams(oneBytes)));
      expect(twoBytes.length, greaterThan(oneBytes.length));
    });

    test("a day that auditions nobody prints no audition table at all", () async {
      // The whole point of the section being skipped rather than drawn over an em dash: a day of
      // shots must be byte for byte the sheet it was before auditions existed.
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final shooting = buildDay(
        blocks: [
          buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-1",
            durationMinutes: 60,
          ),
        ],
        shots: [shot],
      );

      final bytes = await generalOf(shooting);

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(pageCount(bytes), 1);
    });

    test("a day mixing auditions and shots prints both tables, on one sheet", () async {
      final shot = buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final shotsOnly = buildDay(
        blocks: [
          buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-1",
            durationMinutes: 60,
          ),
        ],
        shots: [shot],
      );
      final both = buildDay(
        blocks: [
          buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-1",
            durationMinutes: 60,
          ),
          buildBlock(
            id: "block-2",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 60,
          ),
        ],
        shots: [shot],
      );

      final shotsOnlyBytes = await generalOf(shotsOnly);
      final bothBytes = await generalOf(both);

      expect(contentStreams(bothBytes), isNot(contentStreams(shotsOnlyBytes)));
      expect(bothBytes.length, greaterThan(shotsOnlyBytes.length));
      // One day, one piece of paper: the second table joins the first rather than starting a
      // second document.
      expect(pageCount(bothBytes), 1);
    });

    test("a day of rehearsals prints the sequence each band works, not the bare kind", () async {
      final withSequence = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [buildSlot(id: "slot-1", anchorMinute: 540)],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.rehearsal,
              sceneId: "scene-1",
              durationMinutes: 120,
            ),
          ],
        },
        shotLists: [buildShotList(shots: const [], heading: "INT. KITCHEN - NIGHT")],
      );
      final withoutSequence = buildSnapshot(
        days: [testBuildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [buildSlot(id: "slot-1", anchorMinute: 540)],
        },
        blocksByDayId: {
          "day-1": [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.rehearsal,
              durationMinutes: 120,
            ),
          ],
        },
        shotLists: [buildShotList(shots: const [], heading: "INT. KITCHEN - NIGHT")],
      );

      final withBytes = await generalOf(withSequence);
      final withoutBytes = await generalOf(withoutSequence);

      // The band reads the sequence's own heading exactly as a hold's does — the two sheets would
      // be identical if a rehearsal still printed nothing but its kind label.
      expect(contentStreams(withBytes), isNot(contentStreams(withoutBytes)));
    });

    test(
      "a candidate named on an audition is listed under the cast table, with their contact",
      () async {
        final without = buildDay(
          blocks: [
            buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 120,
            ),
          ],
        );
        final with_ = buildDay(
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

        // The candidate's own hours come off the audition that sees them, not off the unit's day
        // (ADR 0024) — here they happen to be the same, the slot holding that one block.
        final convocation = with_.convocationsOfDay("day-1").firstWhere((c) => c.isSeenForAPart);
        expect(convocation.roleCandidateIds, {"candidate-1"});
        expect(convocation.patStartMinute, 540);
        expect(convocation.patEndMinute, 660);

        final withoutBytes = await generalOf(without);
        final withBytes = await generalOf(with_);

        expect(contentStreams(withBytes), isNot(contentStreams(withoutBytes)));
        expect(withBytes.length, greaterThan(withoutBytes.length));
      },
    );

    test("the audition table names who is seen at which hour", () async {
      // The `CANDIDAT` column: a block naming somebody prints their name beside the hour, where a
      // block naming nobody prints the hour alone.
      final named = buildDay(
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
      final nameless = buildDay(
        blocks: [
          buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 20,
          ),
        ],
      );

      final namedBytes = await generalOf(named);
      final namelessBytes = await generalOf(nameless);

      expect(contentStreams(namedBytes), isNot(contentStreams(namelessBytes)));
      expect(namedBytes.length, greaterThan(namelessBytes.length));
    });
  });
}
