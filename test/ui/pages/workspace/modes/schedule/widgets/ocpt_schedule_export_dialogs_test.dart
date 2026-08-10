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
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_call_sheets_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_out_of_days_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_named_call_sheets_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_shooting_plan_export_dialog.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';

/// A router manager whose [pop] only records the last call and its value: these dialogs are pumped
/// directly, without a real GoRouter for them to operate on — the idiom
/// `ocpt_schedule_shot_picker_dialog_test.dart` already uses.
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

/// Builds a shooting day with the few fields these dialogs read, everything else neutral.
OcptShootingDay _buildDay({required String id, required int dayNumber, required DateTime date}) =>
    OcptShootingDay(
      id: id,
      date: date,
      dayNumber: dayNumber,
      status: OcptShootingDayStatus.planned,
      crewNote: "",
      weatherNote: "",
      notes: "",
    );

/// Builds a person with the few fields these dialogs read, everything else neutral.
OcptPerson _buildPerson({required String id, required String firstName, required String lastName}) =>
    OcptPerson(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: "",
      phone: "",
      addressLine1: "",
      addressLine2: "",
      postalCode: "",
      city: "",
      region: "",
      country: "",
      colorIndex: 0,
      birthDate: null,
      minorNotes: "",
      maxDailyPresenceMinutes: null,
      isTransportAutonomous: null,
      accommodationNotes: "",
      travelNotes: "",
      dietaryNotes: "",
      allergies: "",
      measurementHeight: "",
      measurementChest: "",
      measurementWaist: "",
      measurementHips: "",
      sizeTop: "",
      sizeBottom: "",
      sizeShoes: "",
      hmcNotes: "",
      imageRightsStatus: OcptImageRightsStatus.notApplicable,
      imageRightsDate: null,
      imageRightsAssetId: null,
      photoAssetId: null,
      photo: null,
      imageRightsDocument: null,
      notes: "",
      positions: const [],
      skills: const [],
      unavailabilities: const [],
    );

/// Builds a role with the few fields these dialogs read, everything else neutral.
OcptRole _buildRole({required String id, required String name, String? personId}) => OcptRole(
  id: id,
  name: name,
  personId: personId,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
  episodeIds: const [],
);

/// A convocation of [personId] (or of the uncast [roleId]), with clocks these dialogs never read.
OcptDayConvocation _buildConvocation({String? personId, String? roleId}) => OcptDayConvocation(
  personId: personId,
  roleId: roleId,
  guestPersonId: null,
  guestFreeName: null,
  arrivalMinute: 480,
  patStartMinute: 540,
  patEndMinute: 1020,
  departureMinute: 1080,
  slotIds: const ["slot-1"],
);

void main() {
  late _RecordingRouterManager routerManager;

  const pageSetup = OcptPageSetup.standard();
  final dayOne = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 10));
  final dayTwo = _buildDay(id: "day-2", dayNumber: 2, date: DateTime(2026, 8, 11));
  final dayThree = _buildDay(id: "day-3", dayNumber: 3, date: DateTime(2026, 8, 12));

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

  group("OcptScheduleCallSheetsExportDialog", () {
    /// Pumps the dialog directly (no `showDialog`/`.show`) over [days], with [selectedDayId] the
    /// mode's own current selection.
    Future<void> pumpDialog(
      WidgetTester tester, {
      required List<OcptShootingDay> days,
      required String? selectedDayId,
    }) async {
      await tester.pumpWidget(
        _wrapWithLocalization(
          OcptScheduleCallSheetsExportDialog(
            current: pageSetup,
            days: days,
            selectedDayId: selectedDayId,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("ticks the mode's own selected day alone by default", (tester) async {
      await pumpDialog(tester, days: [dayOne, dayTwo, dayThree], selectedDayId: "day-2");

      final ticked = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .where((tile) => tile.value ?? false);

      expect(ticked, hasLength(1));
    });

    testWidgets("applying returns only the ticked days, in the days' own order", (tester) async {
      await pumpDialog(tester, days: [dayOne, dayTwo, dayThree], selectedDayId: "day-3");

      // Tick the first day too: the result must still read D1 then D3, the order the days are
      // printed in, rather than the order they happened to be ticked in.
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      final options = routerManager.poppedValue as OcptCallSheetExportOptions?;
      expect(options?.dayIds, ["day-1", "day-3"]);
      expect(options?.margins, pageSetup.margins);
    });

    testWidgets("the two bulk controls tick every day and none", (tester) async {
      await pumpDialog(tester, days: [dayOne, dayTwo, dayThree], selectedDayId: "day-1");

      await tester.tap(find.text(Tr.current.scheduleExportSelectAllAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      expect(
        (routerManager.poppedValue as OcptCallSheetExportOptions?)?.dayIds,
        ["day-1", "day-2", "day-3"],
      );

      await tester.tap(find.text(Tr.current.scheduleExportSelectNoneAction));
      await tester.pumpAndSettle();

      // Nothing left to print: the export button is withheld rather than producing an empty run.
      final exportButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(exportButton.onPressed, isNull);
    });

    testWidgets("cancelling pops without any options", (tester) async {
      await pumpDialog(tester, days: [dayOne], selectedDayId: "day-1");

      await tester.tap(find.text(Tr.current.editorPageSetupCancelAction));
      await tester.pumpAndSettle();

      expect(routerManager.popped, isTrue);
      expect(routerManager.poppedValue, isNull);
    });
  });

  group("OcptScheduleNamedCallSheetsExportDialog", () {
    /// Pumps the dialog directly over [days], [selectedDayId] ticked by default, reading each day's
    /// own convocations out of [convocationsByDayId] (empty for a day not present in the map).
    Future<void> pumpDialog(
      WidgetTester tester, {
      required List<OcptShootingDay> days,
      required String? selectedDayId,
      required Map<String, List<OcptDayConvocation>> convocationsByDayId,
      Map<String, OcptPerson> personById = const {},
      Map<String, OcptRole> roleById = const {},
    }) async {
      await tester.pumpWidget(
        _wrapWithLocalization(
          OcptScheduleNamedCallSheetsExportDialog(
            current: pageSetup,
            days: days,
            selectedDayId: selectedDayId,
            recipientsOfDay: (dayId) => convocationsByDayId[dayId] ?? const [],
            personById: personById,
            roleById: roleById,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("ticks every convoked person of the selected day by default and returns them all", (
      tester,
    ) async {
      await pumpDialog(
        tester,
        days: [dayOne, dayTwo],
        selectedDayId: "day-1",
        convocationsByDayId: {
          "day-1": [
            _buildConvocation(personId: "person-1"),
            _buildConvocation(personId: "person-2"),
          ],
        },
        personById: {
          "person-1": _buildPerson(id: "person-1", firstName: "Elisa", lastName: "Mabit"),
          "person-2": _buildPerson(id: "person-2", firstName: "Pascal", lastName: "Bonnelle"),
        },
      );

      expect(find.text("Elisa Mabit"), findsOneWidget);
      expect(find.text("Pascal Bonnelle"), findsOneWidget);

      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      final options = routerManager.poppedValue as OcptCallSheetExportOptions?;
      expect(options?.dayIds, ["day-1"]);
      expect(options?.selectedConvocationKeys, {"person-1", "person-2"});
    });

    testWidgets("an uncast role is listed by its role and says it has no recipient", (tester) async {
      await pumpDialog(
        tester,
        days: [dayOne],
        selectedDayId: "day-1",
        convocationsByDayId: {
          "day-1": [_buildConvocation(roleId: "role-1")],
        },
        roleById: {"role-1": _buildRole(id: "role-1", name: "ARTHUR")},
      );

      expect(find.text(Tr.current.scheduleConvocationsUncastRoleLabel("ARTHUR")), findsOneWidget);
      expect(find.text(Tr.current.scheduleExportNamedCallSheetsUncastRoleHint), findsOneWidget);

      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      expect(
        (routerManager.poppedValue as OcptCallSheetExportOptions?)?.selectedConvocationKeys,
        {"role-1"},
      );
    });

    testWidgets("unticking everybody withholds the export button", (tester) async {
      await pumpDialog(
        tester,
        days: [dayOne],
        selectedDayId: "day-1",
        convocationsByDayId: {
          "day-1": [_buildConvocation(personId: "person-1")],
        },
        personById: {
          "person-1": _buildPerson(id: "person-1", firstName: "Elisa", lastName: "Mabit"),
        },
      );

      // Two "Select none" buttons are on screen — the day list's own, then the recipients
      // section's; the latter is the one this test means.
      await tester.tap(find.text(Tr.current.scheduleExportSelectNoneAction).last);
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets("somebody can be ticked back on after the whole list was cleared", (tester) async {
      await pumpDialog(
        tester,
        days: [dayOne],
        selectedDayId: "day-1",
        convocationsByDayId: {
          "day-1": [_buildConvocation(personId: "person-1")],
        },
        personById: {
          "person-1": _buildPerson(id: "person-1", firstName: "Elisa", lastName: "Mabit"),
        },
      );

      // "Select none" used to leave a const set behind, which the very next tick threw on.
      await tester.tap(find.text(Tr.current.scheduleExportSelectNoneAction).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Elisa Mabit"));
      await tester.pumpAndSettle();

      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      expect(
        (routerManager.poppedValue as OcptCallSheetExportOptions?)?.selectedConvocationKeys,
        {"person-1"},
      );
    });

    testWidgets("unticking every day also withholds the export button", (tester) async {
      await pumpDialog(
        tester,
        days: [dayOne],
        selectedDayId: "day-1",
        convocationsByDayId: {
          "day-1": [_buildConvocation(personId: "person-1")],
        },
        personById: {
          "person-1": _buildPerson(id: "person-1", firstName: "Elisa", lastName: "Mabit"),
        },
      );

      // The day checkbox is the first one in the dialog, the recipient's own being the second.
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets("cancelling pops without any options", (tester) async {
      await pumpDialog(
        tester,
        days: [dayOne],
        selectedDayId: "day-1",
        convocationsByDayId: {
          "day-1": [_buildConvocation(personId: "person-1")],
        },
      );

      await tester.tap(find.text(Tr.current.editorPageSetupCancelAction));
      await tester.pumpAndSettle();

      expect(routerManager.popped, isTrue);
      expect(routerManager.poppedValue, isNull);
    });

    testWidgets(
      "ticking a second day extends the recipient list with the union, carrying tick state over",
      (tester) async {
        await pumpDialog(
          tester,
          days: [dayOne, dayTwo],
          selectedDayId: "day-1",
          convocationsByDayId: {
            "day-1": [
              _buildConvocation(personId: "person-1"),
              _buildConvocation(personId: "person-2"),
            ],
            "day-2": [
              _buildConvocation(personId: "person-1"),
              _buildConvocation(personId: "person-3"),
            ],
          },
          personById: {
            "person-1": _buildPerson(id: "person-1", firstName: "Elisa", lastName: "Mabit"),
            "person-2": _buildPerson(id: "person-2", firstName: "Pascal", lastName: "Bonnelle"),
            "person-3": _buildPerson(id: "person-3", firstName: "Zoe", lastName: "Carret"),
          },
        );

        // Untick person-2 (day-1 only) before day-2 is ticked, so the carry-over rule has something
        // to preserve: person-2 stays unticked once it is still in the union, and the newly
        // appearing person-3 is ticked by the dialog's own standing default.
        await tester.tap(find.text("Pascal Bonnelle"));
        await tester.pumpAndSettle();

        // Tick day-2 (the second day checkbox).
        await tester.tap(find.byType(CheckboxListTile).at(1));
        await tester.pumpAndSettle();

        expect(find.text("Elisa Mabit"), findsOneWidget);
        expect(find.text("Pascal Bonnelle"), findsOneWidget);
        expect(find.text("Zoe Carret"), findsOneWidget);

        await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
        await tester.pumpAndSettle();

        final options = routerManager.poppedValue as OcptCallSheetExportOptions?;
        expect(options?.dayIds, ["day-1", "day-2"]);
        // person-1 carries over ticked (present on both days), person-2 carries over unticked (still
        // in the union, but the user had unticked it), person-3 is ticked as a newly appearing entry.
        expect(options?.selectedConvocationKeys, {"person-1", "person-3"});
      },
    );

    testWidgets("unticking the only day the union came from drops that day's own recipients", (
      tester,
    ) async {
      await pumpDialog(
        tester,
        days: [dayOne, dayTwo],
        selectedDayId: "day-1",
        convocationsByDayId: {
          "day-1": [_buildConvocation(personId: "person-1")],
          "day-2": [_buildConvocation(personId: "person-2")],
        },
        personById: {
          "person-1": _buildPerson(id: "person-1", firstName: "Elisa", lastName: "Mabit"),
          "person-2": _buildPerson(id: "person-2", firstName: "Pascal", lastName: "Bonnelle"),
        },
      );

      expect(find.text("Elisa Mabit"), findsOneWidget);

      // Tick day-2, then untick day-1: person-1, who only ever appeared through day-1, must leave
      // the recipient list along with it.
      await tester.tap(find.byType(CheckboxListTile).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();

      expect(find.text("Elisa Mabit"), findsNothing);
      expect(find.text("Pascal Bonnelle"), findsOneWidget);
    });
  });

  group("OcptScheduleShootingPlanExportDialog", () {
    /// Pumps the dialog directly over [days].
    Future<void> pumpDialog(WidgetTester tester, {required List<OcptShootingDay> days}) async {
      await tester.pumpWidget(
        _wrapWithLocalization(
          OcptScheduleShootingPlanExportDialog(current: pageSetup, days: days),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("ticks every day and every section by default", (tester) async {
      await pumpDialog(tester, days: [dayOne, dayTwo]);

      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      final options = routerManager.poppedValue as OcptShootingPlanExportOptions?;
      expect(options?.dayIds, ["day-1", "day-2"]);
      expect(options?.includeTitlePage, isTrue);
      expect(options?.includeLocationsGrid, isTrue);
      expect(options?.includeSequencesGrid, isTrue);
      expect(options?.includePeopleGrid, isTrue);
      expect(options?.includeTenMinuteGrid, isTrue);
      expect(options?.includeElementsGrid, isTrue);
    });

    testWidgets("unticking a grid carries that one choice out alone", (tester) async {
      await pumpDialog(tester, days: [dayOne]);

      await tester.tap(find.text(Tr.current.scheduleExportShootingPlanSequencesGridLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      final options = routerManager.poppedValue as OcptShootingPlanExportOptions?;
      expect(options?.includeSequencesGrid, isFalse);
      expect(options?.includeLocationsGrid, isTrue);
      expect(options?.includePeopleGrid, isTrue);
      expect(options?.includeTenMinuteGrid, isTrue);
      expect(options?.includeElementsGrid, isTrue);
    });

    testWidgets("unticking the ten-minute grid carries that one choice out alone", (tester) async {
      await pumpDialog(tester, days: [dayOne]);

      await tester.tap(find.text(Tr.current.scheduleExportShootingPlanTenMinuteGridLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      final options = routerManager.poppedValue as OcptShootingPlanExportOptions?;
      expect(options?.includeTenMinuteGrid, isFalse);
      expect(options?.includeLocationsGrid, isTrue);
      expect(options?.includeSequencesGrid, isTrue);
      expect(options?.includePeopleGrid, isTrue);
      expect(options?.includeElementsGrid, isTrue);
    });

    testWidgets("unticking the elements grid carries that one choice out alone", (tester) async {
      await pumpDialog(tester, days: [dayOne]);

      await tester.tap(find.text(Tr.current.scheduleExportShootingPlanElementsGridLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      final options = routerManager.poppedValue as OcptShootingPlanExportOptions?;
      expect(options?.includeElementsGrid, isFalse);
      expect(options?.includeLocationsGrid, isTrue);
      expect(options?.includeSequencesGrid, isTrue);
      expect(options?.includePeopleGrid, isTrue);
      expect(options?.includeTenMinuteGrid, isTrue);
    });

    testWidgets("cancelling pops without any options", (tester) async {
      await pumpDialog(tester, days: [dayOne]);

      await tester.tap(find.text(Tr.current.editorPageSetupCancelAction));
      await tester.pumpAndSettle();

      expect(routerManager.popped, isTrue);
      expect(routerManager.poppedValue, isNull);
    });
  });
  group("OcptScheduleDayOutOfDaysExportDialog", () {
    /// Pumps the dialog directly over [days].
    Future<void> pumpDialog(WidgetTester tester, {required List<OcptShootingDay> days}) async {
      await tester.pumpWidget(
        _wrapWithLocalization(
          OcptScheduleDayOutOfDaysExportDialog(current: pageSetup, days: days),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("ticks every day and the title page by default", (tester) async {
      await pumpDialog(tester, days: [dayOne, dayTwo]);

      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      final options = routerManager.poppedValue as OcptDayOutOfDaysExportOptions?;
      expect(options?.dayIds, ["day-1", "day-2"]);
      expect(options?.includeTitlePage, isTrue);
    });

    testWidgets("unticking a day narrows the printed range", (tester) async {
      await pumpDialog(tester, days: [dayOne, dayTwo]);

      await tester.tap(find.text(Tr.current.scheduleExportSelectNoneAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      final options = routerManager.poppedValue as OcptDayOutOfDaysExportOptions?;
      expect(options?.dayIds, isEmpty);
    });

    testWidgets("unticking the title page carries that choice out", (tester) async {
      await pumpDialog(tester, days: [dayOne]);

      await tester.tap(find.text(Tr.current.editorExportPdfTitlePageLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Tr.current.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      final options = routerManager.poppedValue as OcptDayOutOfDaysExportOptions?;
      expect(options?.includeTitlePage, isFalse);
      expect(options?.dayIds, ["day-1"]);
    });

    testWidgets("cancelling pops without any options", (tester) async {
      await pumpDialog(tester, days: [dayOne]);

      await tester.tap(find.text(Tr.current.editorPageSetupCancelAction));
      await tester.pumpAndSettle();

      expect(routerManager.popped, isTrue);
      expect(routerManager.poppedValue, isNull);
    });
  });
}
