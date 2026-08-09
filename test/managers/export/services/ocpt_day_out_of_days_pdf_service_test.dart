// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_day_out_of_days_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_out_of_days.dart';

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the schedule does — the same convention `ocpt_shooting_plan_pdf_service_test.dart` follows.
const _labels = OcptDayOutOfDaysLabels(
  fileNameSuffix: "day out of days",
  documentTitle: "Day Out of Days",
  directorLine: '"My Movie" by Jane Doe',
  versionLabel: "Version",
  dayTagPrefix: "D",
  dayDateLabels: {"day-1": "1/1", "day-2": "1/2", "day-3": "1/3"},
  roleHeader: "Role",
  workedDaysHeader: "Worked",
  heldDaysHeader: "Held",
  codeLabels: {
    OcptDayOutOfDaysCode.startWork: "SW",
    OcptDayOutOfDaysCode.work: "W",
    OcptDayOutOfDaysCode.workFinish: "WF",
    OcptDayOutOfDaysCode.startWorkFinish: "SWF",
    OcptDayOutOfDaysCode.hold: "H",
  },
  codeDescriptions: {
    OcptDayOutOfDaysCode.startWork: "Start work",
    OcptDayOutOfDaysCode.work: "Work",
    OcptDayOutOfDaysCode.workFinish: "Work finish",
    OcptDayOutOfDaysCode.startWorkFinish: "Start work and finish",
    OcptDayOutOfDaysCode.hold: "Hold",
  },
  legendSectionTitle: "Legend",
  unnamedRoleLabel: "Unnamed role",
  emptyTableNote: "No role is called on the printed days yet.",
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({required String id, required int dayNumber}) => OcptShootingDay(
  id: id,
  screenplayId: "screenplay-1",
  date: DateTime(2026, 1, dayNumber),
  dayNumber: dayNumber,
  status: OcptShootingDayStatus.planned,
  crewNote: "",
  weatherNote: "",
  notes: "",
);

/// Builds a slot convoking [roleIds], everything else neutral.
OcptShootingSlot _buildSlot({
  required String id,
  required String shootingDayId,
  List<String> roleIds = const [],
}) => OcptShootingSlot(
  id: id,
  shootingDayId: shootingDayId,
  label: "",
  locationId: null,
  setId: null,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: 480,
  anchorSlotId: null,
  notes: "",
  crew: const [],
  cast: [
    for (final roleId in roleIds)
      OcptShootingSlotCastMember(id: "cast-$id-$roleId", slotId: id, roleId: roleId, notes: ""),
  ],
  guests: const [],
);

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole _buildRole({required String id, required String name, required int number}) => OcptRole(
  id: id,
  screenplayId: "screenplay-1",
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: number,
);

/// Builds an [OcptSchedulePlanSnapshot] over one screenplay's worth of days and slots, plus its
/// cast.
OcptSchedulePlanSnapshot _buildSnapshot({
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  List<OcptRole> roles = const [],
}) => OcptSchedulePlanSnapshot.build(
  schedule: OcptScheduleSnapshot.build(
    screenplayId: "screenplay-1",
    days: days,
    slotsByDayId: slotsByDayId,
    blocksByDayId: const {},
    eventsByDayId: const {},
  ),
  shotList: null,
  locations: const [],
  roles: roles,
  people: const [],
  elements: const [],
  minimumRestMinutes: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate` calls must not re-read the asset bundle).
  final service = OcptDayOutOfDaysPdfService();
  const pageSetup = OcptPageSetup.standard();
  final pinnedExportDate = DateTime(2026, 1, 15);

  /// A three-day shoot whose only role works on the first and the last day.
  OcptSchedulePlanSnapshot buildThreeDayPlan() => _buildSnapshot(
    days: [
      _buildDay(id: "day-1", dayNumber: 1),
      _buildDay(id: "day-2", dayNumber: 2),
      _buildDay(id: "day-3", dayNumber: 3),
    ],
    slotsByDayId: {
      "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1", roleIds: const ["role-1"])],
      "day-2": [_buildSlot(id: "slot-2", shootingDayId: "day-2")],
      "day-3": [_buildSlot(id: "slot-3", shootingDayId: "day-3", roleIds: const ["role-1"])],
    },
    roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
  );

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await service.generate(
        plan: buildThreeDayPlan(),
        dayIds: const ["day-1", "day-2", "day-3"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: true,
        exportDate: pinnedExportDate,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("the title page is one page of its own, and toggling it off drops it", () async {
      final plan = buildThreeDayPlan();

      Future<Uint8List> generateFor({required bool includeTitlePage}) => service.generate(
        plan: plan,
        dayIds: const ["day-1", "day-2", "day-3"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: includeTitlePage,
        exportDate: pinnedExportDate,
      );

      expect(_pageCount(await generateFor(includeTitlePage: true)), 2);
      expect(_pageCount(await generateFor(includeTitlePage: false)), 1);
    });

    test("a role held on a middle day prints differently from one released before it", () async {
      final withHold = buildThreeDayPlan();
      final withoutHold = _buildSnapshot(
        days: [
          _buildDay(id: "day-1", dayNumber: 1),
          _buildDay(id: "day-2", dayNumber: 2),
          _buildDay(id: "day-3", dayNumber: 3),
        ],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1", roleIds: const ["role-1"])],
          "day-2": [_buildSlot(id: "slot-2", shootingDayId: "day-2")],
          "day-3": [_buildSlot(id: "slot-3", shootingDayId: "day-3")],
        },
        roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1", "day-2", "day-3"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );

      // The held day prints an `H` the released one leaves blank, and the trailing counts differ.
      expect(_contentStreams(await generateFor(withHold)), isNot(_contentStreams(await generateFor(withoutHold))));
    });

    test("a range naming no live day prints the empty note rather than a table", () async {
      final bytes = await service.generate(
        plan: buildThreeDayPlan(),
        dayIds: const ["nope"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("a shoot convoking nobody still produces a readable one-page document", () async {
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
        },
        roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
      );

      final bytes = await service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );

      expect(_pageCount(bytes), 1);
    });

    test("a range wider than one page chunks the columns over several pages", () async {
      final days = [for (var i = 1; i <= 30; i++) _buildDay(id: "day-$i", dayNumber: i)];
      final plan = _buildSnapshot(
        days: days,
        slotsByDayId: {
          for (var i = 1; i <= 30; i++)
            "day-$i": [_buildSlot(id: "slot-$i", shootingDayId: "day-$i", roleIds: const ["role-1"])],
        },
        roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
      );

      final bytes = await service.generate(
        plan: plan,
        dayIds: [for (var i = 1; i <= 30; i++) "day-$i"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );

      // 30 day columns against a 12-column page: three chunks, one page each.
      expect(_pageCount(bytes), 3);
    });

    test("the export moment is what the version line prints, not the wall clock", () async {
      final plan = buildThreeDayPlan();

      Future<Uint8List> generateFor(DateTime exportDate) => service.generate(
        plan: plan,
        dayIds: const ["day-1", "day-2", "day-3"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: true,
        exportDate: exportDate,
      );

      final morning = await generateFor(DateTime(2026, 1, 15, 9, 30));
      final afternoon = await generateFor(DateTime(2026, 1, 15, 16, 45));
      final sameMorningAgain = await generateFor(DateTime(2026, 1, 15, 9, 30));

      expect(_contentStreams(morning), isNot(_contentStreams(afternoon)));
      expect(_contentStreams(morning), _contentStreams(sameMorningAgain));
    });
  });

  group("dayOutOfDaysFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.dayOutOfDaysFileName(projectName: "My Movie", suffix: "day out of days"),
        "My Movie - day out of days.pdf",
      );
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.dayOutOfDaysFileName(projectName: "My Movie", suffix: "   "), "My Movie.pdf");
    });
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node) — the same cheap approach `ocpt_shooting_plan_pdf_service_test.dart` uses.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order —
/// see `ocpt_call_sheet_pdf_service_test.dart`'s own doc comment for why this, rather than the
/// printed text, is what every "prints something different" assertion above compares.
List<String> _contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
