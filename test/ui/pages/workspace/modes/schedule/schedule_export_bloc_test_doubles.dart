// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:ui';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_sides_presentation.dart';

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
class RecordingRouterManager extends OcptRouterManager {
  final _popCompleter = Completer<void>();

  /// Completes the moment [pop] is called.
  Future<void> get onPop => _popCompleter.future;

  /// Records the call instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete();
    }
  }
}

/// A minimal, arbitrary set of localized strings for the call sheets export — what is held is never
/// read by [FakeScheduleExportManager], only that it reaches it unchanged.
const callSheetLabels = OcptCallSheetLabels(
  fileNamePrefix: "FDS",
  documentTitle: "Call sheet",
  dayTitles: {},
  directorLine: "",
  versionLabel: "Version",
  dayTagPrefix: "D",
  dayNumberLabel: "Day",
  recipientsSectionTitle: "Recipients",
  namedRecipientLabel: "For",
  crewNoteSectionTitle: "Note to the crew",
  locationSectionTitle: "Locations",
  mapsLinkLabel: "Map",
  sunSectionTitle: "Sun",
  civilDawnLabel: "Civil dawn",
  sunriseLabel: "Sunrise",
  sunsetLabel: "Sunset",
  civilDuskLabel: "Civil dusk",
  contactsSectionTitle: "Contacts",
  crewDepartmentLabels: {},
  crewPositionLabels: {},
  hoursLinePrefix: "Hours",
  patLabel: "PAT",
  presenceLabel: "PRESENCE",
  arrivalHeader: "Arrival",
  departureLabel: "Departure",
  toBringSectionTitle: "To bring",
  blockKindLabels: {},
  seqHeader: "Seq",
  plansHeader: "Shots",
  effetHeader: "Effect",
  decorsHeader: "Set",
  rolesHeader: "Cast",
  castSectionTitle: "Cast",
  roleHeader: "Role",
  actorHeader: "Actor",
  nameHeader: "Name",
  positionsHeader: "Position(s)",
  phoneHeader: "Phone",
  emailHeader: "Email",
  crewListSectionTitle: "Crew",
  castAndExtrasListSectionTitle: "Cast and extras",
  emptyDayNote: "Nothing planned.",
  unnamedPersonLabel: "Unnamed",
  eventsSectionTitle: "Events",
  auditionsSectionTitle: "Auditions",
  candidateHeader: "CANDIDAT",
  candidatesSectionTitle: "Candidates",
  guestsSectionTitle: "Guests",
  guestReasonHeader: "Reason",
);

/// A minimal, arbitrary set of localized strings for the shooting plan export — mirrors
/// [callSheetLabels]' own doc comment.
const shootingPlanLabels = OcptShootingPlanLabels(
  fileNameSuffix: "shooting plan",
  documentTitle: "Shooting plan",
  dayTitles: {},
  tenMinuteGridSectionTitle: "Ten-minute grid",
  directorLine: "",
  versionLabel: "Version",
  dayTagPrefix: "D",
  locationsGridTitle: "Locations",
  sequencesGridTitle: "Sequences",
  peopleGridTitle: "Crew and cast",
  elementsGridTitle: "Elements",
  locationsGridRowHeader: "Location",
  sequencesGridRowHeader: "Sequence",
  peopleGridRowHeader: "Crew / cast",
  elementsGridRowHeader: "Element",
  elementCategoryLabels: {},
  persoLabel: "People",
  sequenceRowPrefix: "Seq.",
  presenceMark: "x",
  crewPositionLabels: {},
  dayLocationLabel: "Location:",
  dayHoursLabel: "Hours:",
  daySetsLabel: "Location details:",
  dayTimetableLabel: "Detailed schedule:",
  callTimeLabel: "call time",
  estimatedEndLabel: "estimated end",
  milestoneFromLabel: "From",
  milestoneToLabel: "to",
  blockKindLabels: {},
  rolesLabel: "Cast",
  hoursHeader: "Hours",
  planHeader: "Shot",
  shotSizeHeader: "Shot size",
  moveHeader: "Move.",
  framingHeader: "Framing",
  commentHeader: "Comment",
  emptyPlanNote: "Nothing to print.",
  emptyDayScheduleNote: "Nothing planned.",
  eventsSectionTitle: "Events",
  guestsSectionTitle: "Guests",
  guestReasonHeader: "Reason",
  nameHeader: "Name",
  hoursLinePrefix: "Hours",
  unnamedPersonLabel: "Unnamed",
);

/// A minimal, arbitrary set of localized strings for the shooting plan workbook export — mirrors
/// [callSheetLabels]' own doc comment.
const shootingPlanXlsxLabels = OcptShootingPlanXlsxLabels(
  fileNameSuffix: "shooting plan",
  locationsSheetName: "Locations",
  sequencesSheetName: "Sequences",
  peopleSheetName: "Crew and cast",
  elementsSheetName: "Elements",
  chronologySheetName: "Chronology",
  locationsRowHeader: "Location",
  sequencesRowHeader: "Sequence",
  peopleRowHeader: "Crew / cast",
  elementsRowHeader: "Element",
  chronologyColumnHeaders: {},
  dayTagPrefix: "D",
  presenceMark: "x",
  persoLabel: "People",
  sequenceRowPrefix: "Seq.",
  crewPositionLabels: {},
  elementCategoryLabels: {},
  blockKindLabels: {},
);

/// A minimal, arbitrary set of localized strings for the *Day Out of Days* export — mirrors
/// [callSheetLabels]' own doc comment.
const dayOutOfDaysLabels = OcptDayOutOfDaysLabels(
  fileNameSuffix: "day out of days",
  documentTitle: "Day Out of Days",
  directorLine: "",
  versionLabel: "Version",
  dayTagPrefix: "D",
  dayDateLabels: {},
  roleHeader: "Role",
  workedDaysHeader: "Worked",
  heldDaysHeader: "Held",
  codeLabels: {},
  codeDescriptions: {},
  legendSectionTitle: "Legend",
  unnamedRoleLabel: "Unnamed role",
  emptyTableNote: "Nothing to print.",
);

/// A minimal, arbitrary set of localized strings for the one-line schedule export — mirrors
/// [callSheetLabels]' own doc comment.
const oneLineScheduleLabels = OcptOneLineScheduleLabels(
  fileNameSuffix: "one line schedule",
  documentTitle: "One-line schedule",
  directorLine: "",
  versionLabel: "Version",
  dayTagPrefix: "D",
  dayTitles: {},
  seqHeader: "Seq",
  effectHeader: "Effect",
  decorHeader: "Set",
  rolesHeader: "Cast",
  durationHeader: "Duration",
  noLocationLabel: "No location",
  emptyDayNote: "Nothing planned.",
  emptyDocumentNote: "Nothing to print.",
);

/// A minimal, arbitrary set of localized strings for the sides export — mirrors [callSheetLabels]'
/// own doc comment.
const sidesLabels = OcptSidesLabels(
  fileNameSuffix: "sides",
  documentTitle: "Sides",
  versionLabel: "Version",
  dayTagPrefix: "D",
  dayTitle: "",
  episodeLabels: {},
  scriptPagePrefix: "p.",
  emptyDayNote: "Nothing to print.",
);

/// An export manager whose schedule PDF entry points are stubbed and whose calls are recorded, so
/// the bloc's export handlers can be exercised without any real native dialog or PDF write. Mirrors
/// `breakdown_bloc_test.dart`'s own `_FakeExportManager`.
class FakeScheduleExportManager extends OcptExportManager {
  /// Class constructor
  FakeScheduleExportManager({
    this.generalCallSheetsResult,
    this.namedCallSheetsResult,
    this.shootingPlanResult,
    this.shootingPlanXlsxResult,
    this.dayOutOfDaysResult,
    this.oneLineScheduleResult,
    this.sidesResult,
    this.generalCallSheetsFails = false,
    this.namedCallSheetsFails = false,
    this.shootingPlanFails = false,
    this.shootingPlanXlsxFails = false,
    this.dayOutOfDaysFails = false,
    this.oneLineScheduleFails = false,
    this.sidesFails = false,
  }) : super(fileSelectorManager: const FileSelectorManager());

  /// The result [exportGeneralCallSheets] returns, or null to simulate a cancelled folder dialog.
  final OcptCallSheetExportResult? generalCallSheetsResult;

  /// The result [exportNamedCallSheets] returns, or null to simulate a cancelled folder dialog.
  final OcptCallSheetExportResult? namedCallSheetsResult;

  /// The path [exportShootingPlan] returns, or null to simulate a cancelled save dialog.
  final String? shootingPlanResult;

  /// The path [exportShootingPlanXlsx] returns, or null to simulate a cancelled save dialog.
  final String? shootingPlanXlsxResult;

  /// The path [exportDayOutOfDays] returns, or null to simulate a cancelled save dialog.
  final String? dayOutOfDaysResult;

  /// The path [exportOneLineSchedule] returns, or null to simulate a cancelled save dialog.
  final String? oneLineScheduleResult;

  /// Whether [exportGeneralCallSheets] throws, to exercise the bloc's export-failed path.
  final bool generalCallSheetsFails;

  /// Whether [exportNamedCallSheets] throws, to exercise the bloc's export-failed path.
  final bool namedCallSheetsFails;

  /// Whether [exportShootingPlan] throws, to exercise the bloc's export-failed path.
  final bool shootingPlanFails;

  /// Whether [exportShootingPlanXlsx] throws, to exercise the bloc's export-failed path.
  final bool shootingPlanXlsxFails;

  /// Whether [exportDayOutOfDays] throws, to exercise the bloc's export-failed path.
  final bool dayOutOfDaysFails;

  /// Whether [exportOneLineSchedule] throws, to exercise the bloc's export-failed path.
  final bool oneLineScheduleFails;

  /// The path [exportSides] returns, or null to simulate a cancelled save dialog.
  final String? sidesResult;

  /// Whether [exportSides] throws, to exercise the bloc's export-failed path.
  final bool sidesFails;

  /// The plan of the last [exportGeneralCallSheets] call.
  OcptSchedulePlanSnapshot? lastGeneralPlan;

  /// The day ids of the last [exportGeneralCallSheets] call.
  List<String>? lastGeneralDayIds;

  /// The confirm button text of the last [exportGeneralCallSheets] call.
  String? lastGeneralConfirmButtonText;

  /// The day ids of the last [exportNamedCallSheets] call.
  List<String>? lastNamedDayIds;

  /// The convocation keys of the last [exportNamedCallSheets] call.
  Set<String>? lastNamedConvocationKeys;

  /// The day ids of the last [exportShootingPlan] call.
  List<String>? lastShootingPlanDayIds;

  /// The day ids of the last [exportShootingPlanXlsx] call.
  List<String>? lastShootingPlanXlsxDayIds;

  /// The day ids of the last [exportDayOutOfDays] call.
  List<String>? lastDayOutOfDaysDayIds;

  /// The day ids of the last [exportOneLineSchedule] call.
  List<String>? lastOneLineScheduleDayIds;

  /// The day id of the last [exportSides] call.
  String? lastSidesDayId;

  /// The presentation of the last [exportSides] call.
  OcptSidesPresentation? lastSidesPresentation;

  /// The screenplay ids of the last [exportSides] call, in the order they were handed over — what
  /// proves the handler resolved every episode the day plays, in the project's own episode order,
  /// rather than always the one primary screenplay.
  List<String>? lastSidesScreenplayIds;

  /// The Fountain source texts of the documents handed to the last [exportSides] call, keyed by
  /// screenplay id — what proves the handler read each episode's own screenplay out of the open
  /// project rather than handing over an empty one.
  Map<String, String>? lastSidesSourceTextsByScreenplayId;

  @override
  Future<OcptCallSheetExportResult?> exportGeneralCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
    Rect? shareAnchor,
  }) async {
    lastGeneralPlan = plan;
    lastGeneralDayIds = dayIds;
    lastGeneralConfirmButtonText = confirmButtonText;

    if (generalCallSheetsFails) {
      throw StateError("general call sheets export intentionally failed for the test");
    }
    return generalCallSheetsResult;
  }

  @override
  Future<OcptCallSheetExportResult?> exportNamedCallSheets({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    Set<String>? convocationKeys,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String confirmButtonText,
    Rect? shareAnchor,
  }) async {
    lastNamedDayIds = dayIds;
    lastNamedConvocationKeys = convocationKeys;

    if (namedCallSheetsFails) {
      throw StateError("named call sheets export intentionally failed for the test");
    }
    return namedCallSheetsResult;
  }

  @override
  Future<OcptExportOutcome?> exportShootingPlan({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required bool includeLocationsGrid,
    required bool includeSequencesGrid,
    required bool includePeopleGrid,
    required bool includeTenMinuteGrid,
    required bool includeElementsGrid,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    lastShootingPlanDayIds = dayIds;

    if (shootingPlanFails) {
      throw StateError("shooting plan export intentionally failed for the test");
    }
    final result = shootingPlanResult;
    return result == null ? null : OcptExportSaved(result);
  }

  @override
  Future<OcptExportOutcome?> exportShootingPlanXlsx({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptShootingPlanXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    lastShootingPlanXlsxDayIds = dayIds;

    if (shootingPlanXlsxFails) {
      throw StateError("shooting plan workbook export intentionally failed for the test");
    }
    final result = shootingPlanXlsxResult;
    return result == null ? null : OcptExportSaved(result);
  }

  @override
  Future<OcptExportOutcome?> exportDayOutOfDays({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptDayOutOfDaysLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    lastDayOutOfDaysDayIds = dayIds;

    if (dayOutOfDaysFails) {
      throw StateError("day out of days export intentionally failed for the test");
    }
    final result = dayOutOfDaysResult;
    return result == null ? null : OcptExportSaved(result);
  }

  @override
  Future<OcptExportOutcome?> exportOneLineSchedule({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptOneLineScheduleLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    lastOneLineScheduleDayIds = dayIds;

    if (oneLineScheduleFails) {
      throw StateError("one-line schedule export intentionally failed for the test");
    }
    final result = oneLineScheduleResult;
    return result == null ? null : OcptExportSaved(result);
  }

  @override
  Future<OcptExportOutcome?> exportSides({
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required List<({String screenplayId, FountainDocument document})> documents,
    required OcptPageSetup pageSetup,
    required OcptSidesLabels labels,
    required String projectName,
    required bool includeSceneNumbers,
    required OcptSidesPresentation presentation,
    required String fileTypeLabel,
    Rect? shareAnchor,
  }) async {
    lastSidesDayId = dayId;
    lastSidesPresentation = presentation;
    lastSidesScreenplayIds = [for (final pair in documents) pair.screenplayId];
    lastSidesSourceTextsByScreenplayId = {
      for (final pair in documents) pair.screenplayId: pair.document.sourceText,
    };

    if (sidesFails) {
      throw StateError("sides export intentionally failed for the test");
    }
    final result = sidesResult;
    return result == null ? null : OcptExportSaved(result);
  }
}
