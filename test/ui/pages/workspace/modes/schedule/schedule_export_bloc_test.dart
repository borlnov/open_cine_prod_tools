// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_sides_presentation.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_day_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
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

/// A schedule service whose slot writes always fail, as a full disk would.
class _FailingScheduleService extends OcptScheduleService {
  /// Class constructor
  _FailingScheduleService() : super(logger: const SilentLogger(), deviceId: _testDeviceId);

  @override
  Future<void> updateSlot({
    required OcptProjectDatabase database,
    required String slotId,
    Value<String> label = const Value.absent(),
    Value<String?> locationId = const Value.absent(),
    Value<String?> setId = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async => throw StateError("slot write intentionally failed for the test");
}

/// The fixed device id [_FailingScheduleService] stamps its writes with.
Future<String> _testDeviceId() async => "test-device";

/// A minimal, arbitrary set of localized strings for the call sheets export — what is held is never
/// read by [_FakeScheduleExportManager], only that it reaches it unchanged.
const _callSheetLabels = OcptCallSheetLabels(
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
/// [_callSheetLabels]' own doc comment.
const _shootingPlanLabels = OcptShootingPlanLabels(
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
/// [_callSheetLabels]' own doc comment.
const _shootingPlanXlsxLabels = OcptShootingPlanXlsxLabels(
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
/// [_callSheetLabels]' own doc comment.
const _dayOutOfDaysLabels = OcptDayOutOfDaysLabels(
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
/// [_callSheetLabels]' own doc comment.
const _oneLineScheduleLabels = OcptOneLineScheduleLabels(
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

/// A minimal, arbitrary set of localized strings for the sides export — mirrors [_callSheetLabels]'
/// own doc comment.
const _sidesLabels = OcptSidesLabels(
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
class _FakeScheduleExportManager extends OcptExportManager {
  /// Class constructor
  _FakeScheduleExportManager({
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

void main() {
  late OcptPropertiesManager propertiesManager;
  late OcptProjectsManager projectsManager;
  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() resolvable; the bloc's dependencies
    // themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_schedule_bloc_test_");
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
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Writes [text] as the project's screenplay, which reconciles its scene index and therefore
  /// gives the schedule mode's shot list a scene to hang a shot off.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  /// Writes a one-scene screenplay, creates a shot in it, a shooting day with its default slot,
  /// and places the shot on that slot — the fixture every selection test below shares.
  Future<({String shotId, String dayId, String slotId, String blockId})> writePlacedShot() async {
    await writeScreenplay("INT. HOUSE - DAY\n\nAction one.\n");
    final project = projectsManager.currentProject!;
    final sceneId = (await (project.database.select(
      project.database.ocptScenesTable,
    )).get()).single.id;

    final shotId = await projectsManager.shotListService.createShot(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      sceneId: sceneId,
    );
    expect(shotId, isNotNull);

    final dayId = await projectsManager.scheduleService.createDay(
      database: project.database,
      date: DateTime(2026, 8, 10),
    );
    expect(dayId, isNotNull);

    final snapshot = await projectsManager.scheduleService.loadSchedule(database: project.database);
    final slotId = snapshot.slotsByDayId[dayId]!.single.id;

    final blockId = await projectsManager.scheduleService.placeShot(
      database: project.database,
      slotId: slotId,
      shotId: shotId!,
    );
    expect(blockId, isNotNull);

    return (shotId: shotId, dayId: dayId!, slotId: slotId, blockId: blockId!);
  }

  /// Builds a bloc wired to the test project, defaulting [exportManager] to a
  /// [_FakeScheduleExportManager] with every one of its four methods returning null (a cancelled
  /// dialog), so a test not about exporting never has to think about it.
  OcptScheduleBloc buildBloc() => OcptScheduleBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: _FakeScheduleExportManager(),
  );

  /// Builds the export bloc of [modeBloc], wired to the test project and to [exportManager].
  OcptScheduleExportBloc buildExportBloc(
    OcptScheduleBloc modeBloc, {
    required OcptExportManager exportManager,
  }) => OcptScheduleExportBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    exportManager: exportManager,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptScheduleState> waitForState(
    OcptScheduleBloc bloc,
    bool Function(OcptScheduleState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptScheduleExportState> waitForExportState(
    OcptScheduleExportBloc bloc,
    bool Function(OcptScheduleExportState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  group("exporting the general call sheets", () {
    test("hands the plan and the options to the manager and raises the succeeded notice", () async {
      final fixture = await writePlacedShot();
      final exportManager = _FakeScheduleExportManager(
        generalCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/call-sheets",
          writtenFileNames: ["FDS-D1.pdf"],
          failedFileNames: [],
        ),
      );
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      exportBloc.add(
        OcptScheduleCallSheetsExportRequestedEvent(
          options: OcptCallSheetExportOptions(
            format: OcptPageFormat.a4,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
          ),
          labels: _callSheetLabels,
          confirmButtonText: "Choose",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastGeneralDayIds, [fixture.dayId]);
      expect(exportManager.lastGeneralConfirmButtonText, "Choose");
      expect(exportManager.lastGeneralPlan?.schedule.days, hasLength(1));
      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.folderExportSucceeded);
      expect(state.ioNotice?.folderPath, "/tmp/call-sheets");
      expect(state.ioNotice?.writtenCount, 1);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the partial notice rather than the success one when some files failed", () async {
      final fixture = await writePlacedShot();
      final exportManager = _FakeScheduleExportManager(
        generalCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/call-sheets",
          writtenFileNames: ["FDS-D1.pdf"],
          failedFileNames: ["FDS-D2.pdf"],
        ),
      );
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      exportBloc.add(
        OcptScheduleCallSheetsExportRequestedEvent(
          options: OcptCallSheetExportOptions(
            format: OcptPageFormat.a4,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
          ),
          labels: _callSheetLabels,
          confirmButtonText: "Choose",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.folderExportPartiallySucceeded);
      expect(state.ioNotice?.writtenCount, 1);
      expect(state.ioNotice?.failedCount, 1);

      await exportBloc.close();
      await bloc.close();
    });

    test("is a silent no-op when the folder dialog is cancelled", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: _FakeScheduleExportManager());

      exportBloc.add(
        OcptScheduleCallSheetsExportRequestedEvent(
          options: OcptCallSheetExportOptions(
            format: OcptPageFormat.a4,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
          ),
          labels: _callSheetLabels,
          confirmButtonText: "Choose",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeScheduleExportManager(generalCallSheetsFails: true),
      );

      exportBloc.add(
        OcptScheduleCallSheetsExportRequestedEvent(
          options: OcptCallSheetExportOptions(
            format: OcptPageFormat.a4,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
          ),
          labels: _callSheetLabels,
          confirmButtonText: "Choose",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  group("exporting the named call sheets", () {
    test("hands the day and the selected convocation keys to the manager", () async {
      final fixture = await writePlacedShot();
      final project = projectsManager.currentProject!;
      final personId = await projectsManager.peopleService.createPerson(database: project.database);
      expect(personId, isNotNull);

      final snapshot = await projectsManager.scheduleService.loadSchedule(
        database: project.database,
      );
      final slotId = snapshot.slotsByDayId[fixture.dayId]!.single.id;
      await projectsManager.scheduleService.addSlotCrewMember(
        database: project.database,
        slotId: slotId,
        personId: personId!,
      );

      final exportManager = _FakeScheduleExportManager(
        namedCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/named",
          writtenFileNames: ["FDS-D1-Someone.pdf"],
          failedFileNames: [],
        ),
      );
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      exportBloc.add(
        OcptScheduleNamedCallSheetsExportRequestedEvent(
          options: OcptCallSheetExportOptions(
            format: OcptPageFormat.a4,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
            selectedConvocationKeys: {personId},
          ),
          labels: _callSheetLabels,
          confirmButtonText: "Choose",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastNamedDayIds, [fixture.dayId]);
      expect(exportManager.lastNamedConvocationKeys, {personId});
      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.folderExportSucceeded);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeScheduleExportManager(namedCallSheetsFails: true),
      );

      exportBloc.add(
        OcptScheduleNamedCallSheetsExportRequestedEvent(
          options: OcptCallSheetExportOptions(
            format: OcptPageFormat.a4,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
            selectedConvocationKeys: const {"whoever"},
          ),
          labels: _callSheetLabels,
          confirmButtonText: "Choose",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  group("exporting the shooting plan", () {
    test(
      "hands the plan and the options to the manager and raises the file-succeeded notice",
      () async {
        final fixture = await writePlacedShot();
        final exportManager = _FakeScheduleExportManager(shootingPlanResult: "/tmp/plan.pdf");
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

        exportBloc.add(
          OcptScheduleShootingPlanExportRequestedEvent(
            options: OcptShootingPlanExportOptions(
              format: OcptPageFormat.usLetter,
              margins: const FountainPageMargins.standard(),
              dayIds: [fixture.dayId],
              includeTitlePage: true,
              includeLocationsGrid: true,
              includeSequencesGrid: true,
              includePeopleGrid: true,
              includeTenMinuteGrid: true,
              includeElementsGrid: true,
            ),
            labels: _shootingPlanLabels,
            fileTypeLabel: "PDF document",
          ),
        );
        final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

        expect(exportManager.lastShootingPlanDayIds, [fixture.dayId]);
        expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.fileExportSucceeded);
        expect(state.ioNotice?.path, "/tmp/plan.pdf");

        await exportBloc.close();
        await bloc.close();
      },
    );

    test("is a silent no-op when the save dialog is cancelled", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: _FakeScheduleExportManager());

      exportBloc.add(
        OcptScheduleShootingPlanExportRequestedEvent(
          options: OcptShootingPlanExportOptions(
            format: OcptPageFormat.usLetter,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
            includeTitlePage: true,
            includeLocationsGrid: true,
            includeSequencesGrid: true,
            includePeopleGrid: true,
            includeTenMinuteGrid: true,
            includeElementsGrid: true,
          ),
          labels: _shootingPlanLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeScheduleExportManager(shootingPlanFails: true),
      );

      exportBloc.add(
        OcptScheduleShootingPlanExportRequestedEvent(
          options: OcptShootingPlanExportOptions(
            format: OcptPageFormat.usLetter,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
            includeTitlePage: true,
            includeLocationsGrid: true,
            includeSequencesGrid: true,
            includePeopleGrid: true,
            includeTenMinuteGrid: true,
            includeElementsGrid: true,
          ),
          labels: _shootingPlanLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  group("exporting the shooting plan workbook", () {
    test(
      "hands the plan and the options to the manager and raises the file-succeeded notice",
      () async {
        final fixture = await writePlacedShot();
        final exportManager = _FakeScheduleExportManager(shootingPlanXlsxResult: "/tmp/plan.xlsx");
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

        exportBloc.add(
          OcptScheduleShootingPlanXlsxExportRequestedEvent(
            options: OcptShootingPlanXlsxExportOptions(dayIds: [fixture.dayId]),
            labels: _shootingPlanXlsxLabels,
            fileTypeLabel: "Excel workbook",
          ),
        );
        final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

        expect(exportManager.lastShootingPlanXlsxDayIds, [fixture.dayId]);
        expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.fileExportSucceeded);
        expect(state.ioNotice?.path, "/tmp/plan.xlsx");

        await exportBloc.close();
        await bloc.close();
      },
    );

    test("is a silent no-op when the save dialog is cancelled", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: _FakeScheduleExportManager());

      exportBloc.add(
        OcptScheduleShootingPlanXlsxExportRequestedEvent(
          options: OcptShootingPlanXlsxExportOptions(dayIds: [fixture.dayId]),
          labels: _shootingPlanXlsxLabels,
          fileTypeLabel: "Excel workbook",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeScheduleExportManager(shootingPlanXlsxFails: true),
      );

      exportBloc.add(
        OcptScheduleShootingPlanXlsxExportRequestedEvent(
          options: OcptShootingPlanXlsxExportOptions(dayIds: [fixture.dayId]),
          labels: _shootingPlanXlsxLabels,
          fileTypeLabel: "Excel workbook",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  group("exporting the day out of days", () {
    test(
      "hands the plan and the options to the manager and raises the file-succeeded notice",
      () async {
        final fixture = await writePlacedShot();
        final exportManager = _FakeScheduleExportManager(dayOutOfDaysResult: "/tmp/dood.pdf");
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

        exportBloc.add(
          OcptScheduleDayOutOfDaysExportRequestedEvent(
            options: OcptDayOutOfDaysExportOptions(
              format: OcptPageFormat.usLetter,
              margins: const FountainPageMargins.standard(),
              dayIds: [fixture.dayId],
              includeTitlePage: true,
            ),
            labels: _dayOutOfDaysLabels,
            fileTypeLabel: "PDF document",
          ),
        );
        final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

        expect(exportManager.lastDayOutOfDaysDayIds, [fixture.dayId]);
        expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.fileExportSucceeded);
        expect(state.ioNotice?.path, "/tmp/dood.pdf");

        await exportBloc.close();
        await bloc.close();
      },
    );

    test("is a silent no-op when the save dialog is cancelled", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: _FakeScheduleExportManager());

      exportBloc.add(
        OcptScheduleDayOutOfDaysExportRequestedEvent(
          options: OcptDayOutOfDaysExportOptions(
            format: OcptPageFormat.usLetter,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
            includeTitlePage: true,
          ),
          labels: _dayOutOfDaysLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeScheduleExportManager(dayOutOfDaysFails: true),
      );

      exportBloc.add(
        OcptScheduleDayOutOfDaysExportRequestedEvent(
          options: OcptDayOutOfDaysExportOptions(
            format: OcptPageFormat.usLetter,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
            includeTitlePage: true,
          ),
          labels: _dayOutOfDaysLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  group("exporting the one-line schedule", () {
    /// The one-line schedule export request for [dayId].
    OcptScheduleOneLineScheduleExportRequestedEvent requestFor(String dayId) =>
        OcptScheduleOneLineScheduleExportRequestedEvent(
          options: OcptOneLineScheduleExportOptions(
            format: OcptPageFormat.usLetter,
            margins: const FountainPageMargins.standard(),
            dayIds: [dayId],
            includeTitlePage: true,
          ),
          labels: _oneLineScheduleLabels,
          fileTypeLabel: "PDF document",
        );

    test("hands the plan's days to the manager and raises the succeeded notice", () async {
      final fixture = await writePlacedShot();
      final exportManager = _FakeScheduleExportManager(oneLineScheduleResult: "/tmp/one-line.pdf");
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      exportBloc.add(requestFor(fixture.dayId));
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastOneLineScheduleDayIds, [fixture.dayId]);
      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.fileExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/one-line.pdf");

      await exportBloc.close();
      await bloc.close();
    });

    test("is a silent no-op when the save dialog is cancelled", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: _FakeScheduleExportManager());

      exportBloc.add(requestFor(fixture.dayId));
      await pumpEventQueue();

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the export-failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeScheduleExportManager(oneLineScheduleFails: true),
      );

      exportBloc.add(requestFor(fixture.dayId));
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  group("exporting the sides", () {
    /// The sides export request `writePlacedShot`'s own day is printed by, [presentation] aside.
    OcptScheduleSidesExportRequestedEvent requestFor(
      String dayId, {
      OcptSidesPresentation presentation = OcptSidesPresentation.scriptPages,
    }) => OcptScheduleSidesExportRequestedEvent(
      options: OcptSidesExportOptions(
        format: OcptPageFormat.usLetter,
        margins: const FountainPageMargins.standard(),
        dayId: dayId,
        includeSceneNumbers: true,
        presentation: presentation,
      ),
      labels: _sidesLabels,
      fileTypeLabel: "PDF document",
    );

    test("hands the day, the presentation and the project's own screenplay to the "
        "manager", () async {
      final fixture = await writePlacedShot();
      final exportManager = _FakeScheduleExportManager(sidesResult: "/tmp/sides.pdf");
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      exportBloc.add(requestFor(fixture.dayId, presentation: OcptSidesPresentation.packed));
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(exportManager.lastSidesDayId, fixture.dayId);
      expect(exportManager.lastSidesPresentation, OcptSidesPresentation.packed);
      // The handler reads the Fountain text out of the open project rather than out of its own
      // state, which holds none: what reaches the manager is the very screenplay the fixture wrote,
      // as the project's own single episode.
      final project = projectsManager.currentProject!;
      expect(exportManager.lastSidesScreenplayIds, [project.primaryScreenplayId]);
      expect(
        exportManager.lastSidesSourceTextsByScreenplayId?[project.primaryScreenplayId],
        contains("INT. HOUSE - DAY"),
      );
      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.fileExportSucceeded);
      expect(state.ioNotice?.path, "/tmp/sides.pdf");

      await exportBloc.close();
      await bloc.close();
    });

    test(
      "a day playing two episodes hands the manager both episodes' documents, in episode order",
      () async {
        final fixture = await writePlacedShot();
        final project = projectsManager.currentProject!;

        final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
          database: project.database,
        );
        expect(secondEpisodeId, isNotNull);
        await projectsManager.screenplayService.saveScreenplayText(
          database: project.database,
          screenplayId: secondEpisodeId!,
          fountainText: "EXT. STREET - NIGHT\n\nAction two.\n",
          snapshotReason: OcptSnapshotReason.manual,
        );
        final secondSceneId = (await (project.database.select(
          project.database.ocptScenesTable,
        )..where((table) => table.screenplayId.equals(secondEpisodeId))).get()).single.id;

        final secondShotId = await projectsManager.shotListService.createShot(
          database: project.database,
          screenplayId: secondEpisodeId,
          sceneId: secondSceneId,
        );
        expect(secondShotId, isNotNull);

        final secondSlotId = await projectsManager.scheduleService.createSlot(
          database: project.database,
          shootingDayId: fixture.dayId,
          anchorMinute: 600,
        );
        expect(secondSlotId, isNotNull);
        final secondBlockId = await projectsManager.scheduleService.placeShot(
          database: project.database,
          slotId: secondSlotId!,
          shotId: secondShotId!,
        );
        expect(secondBlockId, isNotNull);

        final exportManager = _FakeScheduleExportManager(sidesResult: "/tmp/sides.pdf");
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

        exportBloc.add(requestFor(fixture.dayId));
        await waitForExportState(exportBloc, (state) => state.ioNotice != null);

        expect(
          exportManager.lastSidesScreenplayIds,
          [project.primaryScreenplayId, secondEpisodeId],
          reason: "episode 1's own document before episode 2's, the project's own episode order",
        );
        expect(
          exportManager.lastSidesSourceTextsByScreenplayId?[project.primaryScreenplayId],
          contains("INT. HOUSE - DAY"),
        );
        expect(
          exportManager.lastSidesSourceTextsByScreenplayId?[secondEpisodeId],
          contains("EXT. STREET - NIGHT"),
        );

        await exportBloc.close();
        await bloc.close();
      },
    );

    test("is a silent no-op when the save dialog is cancelled", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: _FakeScheduleExportManager());

      exportBloc.add(requestFor(fixture.dayId));
      await pumpEventQueue();

      expect(exportBloc.state.ioNotice, isNull);

      await exportBloc.close();
      await bloc.close();
    });

    test("raises the export-failed notice when the export throws", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeScheduleExportManager(sidesFails: true),
      );

      exportBloc.add(requestFor(fixture.dayId));
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(state.ioNotice?.kind, OcptScheduleIoNoticeKind.exportFailed);

      await exportBloc.close();
      await bloc.close();
    });
  });

  /// One request per export the bloc offers, each over [dayId], in the order of the sealed hierarchy.
  List<OcptScheduleExportEvent> everyExportRequest(String dayId) {
    final pageSetup = (format: OcptPageFormat.a4, margins: const FountainPageMargins.standard());
    return <OcptScheduleExportEvent>[
      OcptScheduleCallSheetsExportRequestedEvent(
        options: OcptCallSheetExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayIds: [dayId],
        ),
        labels: _callSheetLabels,
        confirmButtonText: "Choose",
      ),
      OcptScheduleNamedCallSheetsExportRequestedEvent(
        options: OcptCallSheetExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayIds: [dayId],
          selectedConvocationKeys: const {"whoever"},
        ),
        labels: _callSheetLabels,
        confirmButtonText: "Choose",
      ),
      OcptScheduleShootingPlanExportRequestedEvent(
        options: OcptShootingPlanExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayIds: [dayId],
          includeTitlePage: true,
          includeLocationsGrid: true,
          includeSequencesGrid: true,
          includePeopleGrid: true,
          includeTenMinuteGrid: true,
          includeElementsGrid: true,
        ),
        labels: _shootingPlanLabels,
        fileTypeLabel: "PDF document",
      ),
      OcptScheduleShootingPlanXlsxExportRequestedEvent(
        options: OcptShootingPlanXlsxExportOptions(dayIds: [dayId]),
        labels: _shootingPlanXlsxLabels,
        fileTypeLabel: "Excel workbook",
      ),
      OcptScheduleDayOutOfDaysExportRequestedEvent(
        options: OcptDayOutOfDaysExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayIds: [dayId],
          includeTitlePage: true,
        ),
        labels: _dayOutOfDaysLabels,
        fileTypeLabel: "PDF document",
      ),
      OcptScheduleOneLineScheduleExportRequestedEvent(
        options: OcptOneLineScheduleExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayIds: [dayId],
          includeTitlePage: true,
        ),
        labels: _oneLineScheduleLabels,
        fileTypeLabel: "PDF document",
      ),
      OcptScheduleSidesExportRequestedEvent(
        options: OcptSidesExportOptions(
          format: pageSetup.format,
          margins: pageSetup.margins,
          dayId: dayId,
          includeSceneNumbers: true,
          presentation: OcptSidesPresentation.scriptPages,
        ),
        labels: _sidesLabels,
        fileTypeLabel: "PDF document",
      ),
    ];
  }

  group("the bloc as a whole", () {
    /// Names [event] by the exhaustive switch over the sealed hierarchy: adding an event to it makes
    /// this fail to compile until the list below names it too.
    String nameOf(OcptScheduleExportEvent event) => switch (event) {
      OcptScheduleCallSheetsExportRequestedEvent() => "call sheets",
      OcptScheduleNamedCallSheetsExportRequestedEvent() => "named call sheets",
      OcptScheduleShootingPlanExportRequestedEvent() => "shooting plan",
      OcptScheduleShootingPlanXlsxExportRequestedEvent() => "shooting plan workbook",
      OcptScheduleDayOutOfDaysExportRequestedEvent() => "day out of days",
      OcptScheduleOneLineScheduleExportRequestedEvent() => "one-line schedule",
      OcptScheduleSidesExportRequestedEvent() => "sides",
      OcptScheduleIoNoticeDismissedEvent() => "dismiss",
    };

    test("every event of its hierarchy has a handler", () async {
      final fixture = await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeScheduleExportManager(
          generalCallSheetsResult: const OcptCallSheetExportResult(
            folderPath: "/tmp/sheets",
            writtenFileNames: ["a.pdf"],
            failedFileNames: [],
          ),
          namedCallSheetsResult: const OcptCallSheetExportResult(
            folderPath: "/tmp/sheets",
            writtenFileNames: ["a.pdf"],
            failedFileNames: [],
          ),
          shootingPlanResult: "/tmp/plan.pdf",
          shootingPlanXlsxResult: "/tmp/plan.xlsx",
          dayOutOfDaysResult: "/tmp/dood.pdf",
          oneLineScheduleResult: "/tmp/one-line.pdf",
          sidesResult: "/tmp/sides.pdf",
        ),
      );

      final exports = everyExportRequest(fixture.dayId);
      const dismissal = OcptScheduleIoNoticeDismissedEvent();
      expect(
        [...exports, dismissal].map(nameOf).toSet(),
        hasLength(8),
        reason: 'one event per name of the hierarchy',
      );

      // An event nobody handles is ignored silently, so each is proven by its effect: a notice
      // appears for every export, and the dismissal takes it away.
      for (final event in exports) {
        exportBloc.add(event);
        await waitForExportState(exportBloc, (state) => state.ioNotice != null);
        exportBloc.add(dismissal);
        await waitForExportState(exportBloc, (state) => state.ioNotice == null);
      }

      await exportBloc.close();
      await bloc.close();
    });

    test("an export writes what is pending first, so the plan it prints holds it", () async {
      final fixture = await writePlacedShot();
      final exportManager = _FakeScheduleExportManager(
        generalCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/sheets",
          writtenFileNames: ["a.pdf"],
          failedFileNames: [],
        ),
      );
      final bloc = buildBloc();
      final dayBloc = OcptScheduleDayBloc(
        modeBloc: bloc,
        projectsManager: projectsManager,
        fieldEditDebounce: const Duration(days: 1),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);
      dayBloc.add(
        OcptScheduleFieldChangedEvent(
          targetId: fixture.slotId,
          field: OcptScheduleField.slotLabel,
          rawValue: "Cave",
        ),
      );
      await dayBloc.stream.first;

      exportBloc.add(
        OcptScheduleCallSheetsExportRequestedEvent(
          options: OcptCallSheetExportOptions(
            format: OcptPageFormat.a4,
            margins: const FountainPageMargins.standard(),
            dayIds: [fixture.dayId],
          ),
          labels: _callSheetLabels,
          confirmButtonText: "Choose",
        ),
      );
      await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(
        exportManager.lastGeneralPlan?.schedule.slotsByDayId[fixture.dayId]?.single.label,
        "Cave",
      );

      await exportBloc.close();
      await dayBloc.close();
      await bloc.close();
    });

    test("an export is not made while a typed edit could not be written", () async {
      final fixture = await writePlacedShot();
      final exportManager = _FakeScheduleExportManager(
        generalCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/sheets",
          writtenFileNames: ["a.pdf"],
          failedFileNames: [],
        ),
        namedCallSheetsResult: const OcptCallSheetExportResult(
          folderPath: "/tmp/sheets",
          writtenFileNames: ["a.pdf"],
          failedFileNames: [],
        ),
        shootingPlanResult: "/tmp/plan.pdf",
        shootingPlanXlsxResult: "/tmp/plan.xlsx",
        dayOutOfDaysResult: "/tmp/dood.pdf",
        oneLineScheduleResult: "/tmp/one-line.pdf",
        sidesResult: "/tmp/sides.pdf",
      );
      final bloc = buildBloc();
      final dayBloc = OcptScheduleDayBloc(
        modeBloc: bloc,
        projectsManager: projectsManager,
        scheduleService: _FailingScheduleService(),
        fieldEditDebounce: const Duration(days: 1),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);
      dayBloc.add(
        OcptScheduleFieldChangedEvent(
          targetId: fixture.slotId,
          field: OcptScheduleField.slotLabel,
          rawValue: "Cave",
        ),
      );
      await dayBloc.stream.first;

      everyExportRequest(fixture.dayId).forEach(exportBloc.add);
      await pumpEventQueue(times: 200);

      expect(exportBloc.state.ioNotice, isNull);
      expect(exportManager.lastGeneralDayIds, isNull);
      expect(exportManager.lastNamedDayIds, isNull);
      expect(exportManager.lastShootingPlanDayIds, isNull);
      expect(exportManager.lastShootingPlanXlsxDayIds, isNull);
      expect(exportManager.lastDayOutOfDaysDayIds, isNull);
      expect(exportManager.lastOneLineScheduleDayIds, isNull);
      expect(exportManager.lastSidesDayId, isNull);
      expect(dayBloc.state.pendingFieldEdits, isNotEmpty);

      await exportBloc.close();
      await dayBloc.close();
      await bloc.close();
    });

    test("an export asked just as the mode closes neither hangs nor throws", () async {
      await writePlacedShot();
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: _FakeScheduleExportManager());

      exportBloc.add(
        const OcptScheduleShootingPlanXlsxExportRequestedEvent(
          options: OcptShootingPlanXlsxExportOptions(dayIds: []),
          labels: _shootingPlanXlsxLabels,
          fileTypeLabel: "Excel workbook",
        ),
      );
      await bloc.close().timeout(const Duration(seconds: 5));
      await exportBloc.close().timeout(const Duration(seconds: 5));
    });
  });
}
