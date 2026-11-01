// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_skill.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_unavailability.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet.dart';
import 'ocpt_person_sheet_test_doubles.dart';

void main() {
  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }
    managers.registerSingleton<OcptRouterManager>(RecordingRouterManager());
  });

  testWidgets(
    "picking the picker's custom label entry keeps the row's own typed text, whatever it is",
    (tester) async {
      await useTallSurface(tester);
      String? updatedPositionId;
      String? updatedCustomLabel;

      await tester.pumpWidget(
        buildSheet(
          person: testPerson(
            positions: const [
              OcptPersonPosition(
                id: "pos1",
                personId: "p1",
                positionId: "director",
                customLabel: "",
              ),
            ],
          ),
          onPositionUpdated: (id, {required positionId, required customLabel}) {
            updatedPositionId = positionId;
            updatedCustomLabel = customLabel;
          },
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
      final positionLabelField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == tr.resourcesPositionLabelHint,
      );
      await tester.enterText(positionLabelField, "Runner");
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.icon is Icon &&
              (widget.icon as Icon).icon == Icons.arrow_drop_down &&
              (widget.icon as Icon).size == 18,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(tr.resourcesPositionCustomOptionLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.resourcesPositionCustomOptionLabel));
      await tester.pumpAndSettle();

      expect(updatedPositionId, "");
      expect(updatedCustomLabel, "Runner");
    },
  );

  testWidgets("adding a skill through the inline field reports its label", (tester) async {
    await useTallSurface(tester);
    String? addedLabel;

    await tester.pumpWidget(
      buildSheet(person: testPerson(), onSkillAdded: (label) => addedLabel = label),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("+"));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    final addField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == tr.resourcesAddSkillHint,
    );
    await tester.enterText(addField, "Permis B");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(addedLabel, "Permis B");
  });

  testWidgets("removing a skill chip reports its id", (tester) async {
    await useTallSurface(tester);
    String? removedId;

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(
          skills: const [OcptPersonSkill(id: "skill1", personId: "p1", label: "Piano")],
        ),
        onSkillRemoved: (id) => removedId = id,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.tap(find.byTooltip(tr.resourcesRemoveSkillTooltip));
    await tester.pump();

    expect(removedId, "skill1");
  });

  group("read-only preview", () {
    testWidgets("withholds every writing affordance", (tester) async {
      await useTallSurface(tester);
      await tester.pumpWidget(
        buildSheet(
          person: testPerson(
            firstName: "Léa",
            commuteKmMilli: 12400,
            mileageRateId: "r1",
            positions: const [
              OcptPersonPosition(
                id: "pos1",
                personId: "p1",
                positionId: "director",
                customLabel: "",
              ),
            ],
            unavailabilities: [
              OcptPersonUnavailability(
                id: "u1",
                personId: "p1",
                startDate: DateTime(2026, 8, 15),
                endDate: DateTime(2026, 8, 15),
                slot: OcptDayPartSlot.fullDay,
                startMinute: null,
                endMinute: null,
                reason: "",
              ),
            ],
            skills: const [OcptPersonSkill(id: "skill1", personId: "p1", label: "Piano")],
          ),
          mileageRates: const [
            OcptBudgetMileageRate(id: "r1", label: "Car", ratePerKmMilliCents: 52900, sortKey: "a"),
          ],
          isReadOnly: true,
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));

      // The value is still shown as static text.
      expect(find.text("Léa"), findsOneWidget);
      expect(find.text("Director"), findsOneWidget);
      expect(find.text("Piano"), findsOneWidget);

      // Every affordance that would write is gone.
      expect(find.text(tr.resourcesDeletePersonAction), findsNothing);
      expect(find.text(tr.resourcesAddPositionAction), findsNothing);
      expect(find.text(tr.resourcesAddUnavailabilityAction), findsNothing);
      expect(find.text("+"), findsNothing);
      expect(find.byTooltip(tr.resourcesRemovePositionTooltip), findsNothing);
      expect(find.byTooltip(tr.resourcesRemoveUnavailabilityTooltip), findsNothing);
      expect(find.byType(InputChip), findsNothing);
      expect(find.byType(Chip), findsOneWidget);

      // Every text field reads out its value rather than accepting a new one.
      final firstNameField = tester.widget<TextField>(find.widgetWithText(TextField, "Léa"));
      expect(firstNameField.readOnly, isTrue);

      // The commute distance field reads out its value rather than accepting a new one.
      final commuteField = tester.widget<TextField>(
        fieldOf(tr.resourcesCommuteDistanceLabel.toUpperCase()),
      );
      expect(commuteField.readOnly, isTrue);

      // The mileage rate picker is withheld rather than merely disabled: no `DropdownButton` at
      // all, just its current pick read out as plain text.
      expect(find.byType(DropdownButton<String?>), findsNothing);
      expect(find.text("Car"), findsOneWidget);
    });
  });

  group("unavailabilities", () {
    /// One unavailability of person `p1`, a single full day with no window.
    OcptPersonUnavailability fullDay() => OcptPersonUnavailability(
      id: "u1",
      personId: "p1",
      startDate: DateTime(2026, 8, 15),
      endDate: DateTime(2026, 8, 15),
      slot: OcptDayPartSlot.fullDay,
      startMinute: null,
      endMinute: null,
      reason: "",
    );

    testWidgets("picking the custom slot reports it with a working-day window", (tester) async {
      await useTallSurface(tester);
      OcptDayPartSlot? reportedSlot;
      int? reportedStartMinute;
      int? reportedEndMinute;

      await tester.pumpWidget(
        buildSheet(
          person: testPerson(unavailabilities: [fullDay()]),
          onUnavailabilityUpdated:
              (
                id, {
                required startDate,
                required endDate,
                required slot,
                required startMinute,
                required endMinute,
                required reason,
              }) {
                reportedSlot = slot;
                reportedStartMinute = startMinute;
                reportedEndMinute = endMinute;
              },
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
      await tester.tap(find.text(tr.resourcesSlotCustom));
      await tester.pumpAndSettle();

      expect(reportedSlot, OcptDayPartSlot.custom);
      expect(reportedStartMinute, 9 * 60);
      expect(reportedEndMinute, 18 * 60);
    });

    testWidgets("a row's + adds a second slot over the same dates", (tester) async {
      await useTallSurface(tester);
      DateTime? reportedStart;
      DateTime? reportedEnd;
      OcptDayPartSlot? reportedSlot;
      int? reportedStartMinute;

      await tester.pumpWidget(
        buildSheet(
          person: testPerson(
            unavailabilities: [
              OcptPersonUnavailability(
                id: "u1",
                personId: "p1",
                startDate: DateTime(2026, 8, 15),
                endDate: DateTime(2026, 8, 15),
                slot: OcptDayPartSlot.morning,
                startMinute: null,
                endMinute: null,
                reason: "",
              ),
            ],
          ),
          onUnavailabilityAdded:
              ({
                required startDate,
                required endDate,
                required slot,
                required startMinute,
                required endMinute,
              }) {
                reportedStart = startDate;
                reportedEnd = endDate;
                reportedSlot = slot;
                reportedStartMinute = startMinute;
              },
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
      await tester.tap(find.byTooltip(tr.resourcesAddUnavailabilitySlotTooltip));
      await tester.pumpAndSettle();

      // The same dates, as a window the user then narrows: an afternoon conflict on a day that
      // already carries a morning one is a second row, never an edit of the first.
      expect(reportedStart, DateTime(2026, 8, 15));
      expect(reportedEnd, DateTime(2026, 8, 15));
      expect(reportedSlot, OcptDayPartSlot.custom);
      expect(reportedStartMinute, 9 * 60);
    });

    testWidgets("the window is shown for a custom slot and hidden for the others", (tester) async {
      await useTallSurface(tester);

      await tester.pumpWidget(buildSheet(person: testPerson(unavailabilities: [fullDay()])));
      await tester.pumpAndSettle();
      expect(find.text("→"), findsNothing);

      await tester.pumpWidget(
        buildSheet(
          person: testPerson(
            unavailabilities: [
              OcptPersonUnavailability(
                id: "u2",
                personId: "p1",
                startDate: DateTime(2026, 8, 15),
                endDate: DateTime(2026, 8, 17),
                slot: OcptDayPartSlot.custom,
                startMinute: 14 * 60,
                endMinute: 17 * 60 + 30,
                reason: "Examen",
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("→"), findsOneWidget);
      expect(find.text("Examen"), findsOneWidget);
      // Both ends of the range are shown, even when they differ by two days.
      final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
      expect(find.text(tr.resourcesUnavailabilityFromLabel), findsOneWidget);
      expect(find.text(tr.resourcesUnavailabilityToLabel), findsOneWidget);
    });
  });
}
