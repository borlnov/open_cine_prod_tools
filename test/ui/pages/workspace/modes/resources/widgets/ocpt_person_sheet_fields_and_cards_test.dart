// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_color_swatches.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_crew_position_picker_dialog.dart';
import 'ocpt_person_sheet_test_doubles.dart';

/// Builds an [OcptAssetRef] pointing at [path] — a path these tests deliberately never create, so
/// every widget under test falls back to what it shows without a file.
OcptAssetRef _asset({
  String id = "a1",
  OcptAssetKind kind = OcptAssetKind.personPhoto,
  String path = "/nowhere/portrait.jpg",
}) => OcptAssetRef(
  id: id,
  kind: kind,
  path: path,
  label: "",
  addedAt: DateTime(2026, 8, 7),
  personId: "p1",
  locationId: null,
  elementId: null,
  validFrom: null,
  validUntil: null,
);

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

  testWidgets("renders the selected person's fields", (tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(
      buildSheet(
        person: testPerson(
          firstName: "Léa",
          lastName: "Martin",
          email: "lea@example.com",
          dietaryNotes: "Végétarienne",
          notes: "Ponctuelle",
          positions: const [
            OcptPersonPosition(id: "pos1", personId: "p1", positionId: "director", customLabel: ""),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Léa"), findsOneWidget);
    expect(find.text("Martin"), findsOneWidget);
    expect(find.text("lea@example.com"), findsOneWidget);
    expect(find.text("Director"), findsOneWidget);
    expect(find.text("Végétarienne"), findsOneWidget);
    expect(find.text("Ponctuelle"), findsOneWidget);
  });

  testWidgets("a malformed email is flagged once the field loses the focus, never before", (
    tester,
  ) async {
    await useTallSurface(tester);
    await tester.pumpWidget(buildSheet(person: testPerson(email: "clara@example.com")));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    expect(find.text(tr.resourcesEmailMalformedError), findsNothing);

    // Typing an incomplete address says nothing while the field still has the focus: the sheet
    // writes as it is typed, and every value passes through half-typed states.
    await tester.tap(fieldOf(tr.resourcesEmailLabel.toUpperCase()));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(tr.resourcesEmailLabel.toUpperCase()), "clara@");
    await tester.pumpAndSettle();
    expect(find.text(tr.resourcesEmailMalformedError), findsNothing);

    // It is flagged the moment the focus moves elsewhere.
    await tester.tap(fieldOf(tr.resourcesPhoneLabel.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr.resourcesEmailMalformedError), findsOneWidget);
  });

  testWidgets("the HMC card holds the measurements and sizes, not the meals card", (tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(
      buildSheet(
        person: testPerson(
          dietaryNotes: "Végétarienne",
          measurementHeight: "168",
          measurementChest: "88",
          sizeShoes: "39",
          hmcNotes: "Cicatrice au menton",
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    final hmcCard = find.ancestor(
      of: find.text(tr.resourcesHmcTitle),
      matching: find.byType(OcptResourcesSheetCard),
    );

    for (final value in ["168", "88", "39", "Cicatrice au menton"]) {
      expect(find.descendant(of: hmcCard, matching: find.text(value)), findsOneWidget);
    }

    // The meals card keeps what is read at catering time, and nothing a fitting needs.
    final mealsCard = find.ancestor(
      of: find.text(tr.resourcesMealsHealthTitle),
      matching: find.byType(OcptResourcesSheetCard),
    );
    expect(find.descendant(of: mealsCard, matching: find.text("Végétarienne")), findsOneWidget);
    expect(find.descendant(of: mealsCard, matching: find.text("39")), findsNothing);
  });

  testWidgets("shows the minor badge and legal-hours callout for a minor", (tester) async {
    await useTallSurface(tester);
    final now = DateTime.now();

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(
          birthDate: DateTime(now.year - 15, now.month, now.day),
          minorNotes: "Guardian on set at all times",
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    expect(find.text(tr.resourcesMinorBadge(15)), findsOneWidget);
    expect(find.text(tr.resourcesMinorCalloutTitle), findsOneWidget);
    expect(find.text("Guardian on set at all times"), findsOneWidget);
  });

  testWidgets("no minor badge or callout for an adult, but the presence card stays", (
    tester,
  ) async {
    await useTallSurface(tester);
    final now = DateTime.now();

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(
          birthDate: DateTime(now.year - 30, now.month, now.day),
          maxDailyPresenceMinutes: 480,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    expect(find.text(tr.resourcesMinorCalloutTitle), findsNothing);
    // The maximum daily presence card isn't restricted to minors: an adult under a medical
    // restriction is the same fact, so it stays even while the callout is gone.
    expect(find.text(tr.resourcesMaxDailyPresenceTitle), findsOneWidget);
    expect(find.text("480"), findsOneWidget);
  });

  testWidgets("the maximum daily presence card sits beside the legal-hours callout for a minor", (
    tester,
  ) async {
    await useTallSurface(tester);
    final now = DateTime.now();

    await tester.pumpWidget(
      buildSheet(person: testPerson(birthDate: DateTime(now.year - 15, now.month, now.day))),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    expect(find.text(tr.resourcesMinorCalloutTitle), findsOneWidget);
    expect(find.text(tr.resourcesMaxDailyPresenceTitle), findsOneWidget);
  });

  testWidgets("typing into the maximum daily presence field dispatches the change", (tester) async {
    await useTallSurface(tester);
    final changes = <(OcptPersonField, String)>[];

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(),
        onFieldChanged: (field, rawValue) => changes.add((field, rawValue)),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    final field = find.descendant(
      of: find.ancestor(
        of: find.text(tr.resourcesMaxDailyPresenceTitle),
        matching: find.byType(OcptResourcesSheetCard),
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, "480");
    await tester.pump();

    expect(changes, contains((OcptPersonField.maxDailyPresenceMinutes, "480")));
  });

  testWidgets("the commute distance field round-trips through thousandths", (tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(buildSheet(person: testPerson(commuteKmMilli: 12400)));
    await tester.pumpAndSettle();

    expect(find.text("12.4"), findsOneWidget);
  });

  testWidgets("typing into the commute distance field dispatches the change", (tester) async {
    await useTallSurface(tester);
    final changes = <(OcptPersonField, String)>[];

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(),
        onFieldChanged: (field, rawValue) => changes.add((field, rawValue)),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.enterText(fieldOf(tr.resourcesCommuteDistanceLabel.toUpperCase()), "12.4");
    await tester.pump();

    expect(changes, contains((OcptPersonField.commuteKmMilli, "12.4")));
  });

  testWidgets(
    "the mileage rate picker offers No rate and the project's own rates, reporting the id picked",
    (tester) async {
      await useTallSurface(tester);
      String? reportedId = "not called";
      const rates = [
        OcptBudgetMileageRate(id: "r1", label: "Car", ratePerKmMilliCents: 52900, sortKey: "a"),
        OcptBudgetMileageRate(id: "r2", label: "Van", ratePerKmMilliCents: 60100, sortKey: "b"),
      ];

      await tester.pumpWidget(
        buildSheet(
          person: testPerson(),
          mileageRates: rates,
          onMileageRateChanged: (id) => reportedId = id,
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
      expect(find.text(tr.resourcesMileageRateLabel.toUpperCase()), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      expect(find.text(tr.resourcesMileageRateNoRateOption), findsWidgets);
      expect(find.text("Car"), findsWidgets);
      expect(find.text("Van"), findsWidgets);

      await tester.tap(find.text("Van").last);
      await tester.pumpAndSettle();

      expect(reportedId, "r2");
    },
  );

  testWidgets("a person naming a rate the project no longer lists reads as no rate", (
    tester,
  ) async {
    await useTallSurface(tester);
    await tester.pumpWidget(
      buildSheet(
        person: testPerson(mileageRateId: "gone"),
        mileageRates: const [
          OcptBudgetMileageRate(id: "r1", label: "Car", ratePerKmMilliCents: 52900, sortKey: "a"),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    expect(find.text(tr.resourcesMileageRateNoRateOption), findsOneWidget);
  });

  testWidgets("typing into the email field dispatches the change", (tester) async {
    await useTallSurface(tester);
    final changes = <(OcptPersonField, String)>[];

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(),
        onFieldChanged: (field, rawValue) => changes.add((field, rawValue)),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.enterText(fieldOf(tr.resourcesEmailLabel.toUpperCase()), "x");
    await tester.pump();

    expect(changes, contains((OcptPersonField.email, "x")));
  });

  testWidgets("the photo slot offers to reference a photo, and reports the pick", (tester) async {
    await useTallSurface(tester);
    var pickRequested = false;

    await tester.pumpWidget(
      buildSheet(person: testPerson(), onPhotoPickRequested: () => pickRequested = true),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.tap(find.byTooltip(tr.resourcesPhotoSlotTooltip));
    await tester.pumpAndSettle();

    // Nothing is referenced yet, so the menu invites rather than offering to replace, and there is
    // nothing to remove.
    expect(find.text(tr.resourcesReferencePhotoAction), findsOneWidget);
    expect(find.text(tr.resourcesReplacePhotoAction), findsNothing);
    expect(find.text(tr.resourcesRemovePhotoAction), findsNothing);

    await tester.tap(find.text(tr.resourcesReferencePhotoAction));
    await tester.pumpAndSettle();

    // The sheet only asks: the native dialog is the mode's to open.
    expect(pickRequested, isTrue);
  });

  testWidgets("a referenced photo turns the slot's menu into replace and remove", (tester) async {
    await useTallSurface(tester);
    var cleared = false;

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(photo: _asset()),
        onPhotoCleared: () => cleared = true,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.tap(find.byTooltip(tr.resourcesPhotoSlotTooltip));
    await tester.pumpAndSettle();

    expect(find.text(tr.resourcesReplacePhotoAction), findsOneWidget);
    expect(find.text(tr.resourcesReferencePhotoAction), findsNothing);

    await tester.tap(find.text(tr.resourcesRemovePhotoAction));
    await tester.pumpAndSettle();

    expect(cleared, isTrue);
  });

  testWidgets("a photo whose file is gone falls back to the initials, silently", (tester) async {
    await useTallSurface(tester);

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(firstName: "Léa", lastName: "Roy", photo: _asset()),
      ),
    );
    await tester.pumpAndSettle();

    // `_asset` names a path these tests never create. A person has one photo and their initials
    // are a perfectly good thing to see in its place, so nothing is reported — unlike a scouting
    // photo, which is one item of a list and says so.
    expect(tester.takeException(), isNull);
    expect(find.text("LR"), findsWidgets);
    expect(
      find.text(Tr.of(tester.element(find.byType(OcptPersonSheet))).resourcesAssetFileMissing),
      findsNothing,
    );
  });

  testWidgets("the image rights card references a document and drops it", (tester) async {
    await useTallSurface(tester);
    var pickRequested = false;

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(),
        onImageRightsDocumentPickRequested: () => pickRequested = true,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.tap(find.text(tr.resourcesReferenceDocumentAction));
    await tester.pump();

    expect(pickRequested, isTrue);
  });

  testWidgets("a referenced release reads by its file name and says it is missing", (tester) async {
    await useTallSurface(tester);
    var cleared = false;

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(
          imageRightsDocument: _asset(kind: OcptAssetKind.document, path: "/nowhere/cession.pdf"),
        ),
        onImageRightsDocumentCleared: () => cleared = true,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    // A document is read by its name rather than drawn, so unlike a photo it *does* report a path
    // that resolves to nothing: the reference is kept and the user can re-point it.
    expect(find.text("cession.pdf"), findsOneWidget);
    expect(find.text(tr.resourcesAssetFileMissing), findsOneWidget);
    expect(find.text(tr.resourcesReferenceDocumentAction), findsNothing);

    await tester.tap(find.byTooltip(tr.resourcesRemoveDocumentTooltip));
    await tester.pump();

    expect(cleared, isTrue);
  });

  testWidgets("the photo slot opens the palette and reports the swatch picked", (tester) async {
    await useTallSurface(tester);
    final colorPicks = <int>[];

    await tester.pumpWidget(buildSheet(person: testPerson(), onColorChanged: colorPicks.add));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.tap(find.byTooltip(tr.resourcesPhotoSlotTooltip));
    await tester.pumpAndSettle();

    // The popover used to throw on layout before showing a single swatch.
    expect(tester.takeException(), isNull);

    await tester.tap(
      find
          .descendant(of: find.byType(OcptResourcesColorSwatches), matching: find.byType(InkWell))
          .at(4),
    );
    await tester.pumpAndSettle();

    expect(colorPicks, [4]);
  });

  testWidgets("clicking Delete this person reports it", (tester) async {
    await useTallSurface(tester);
    var deleteRequested = false;

    await tester.pumpWidget(
      buildSheet(person: testPerson(), onDeleteRequested: () => deleteRequested = true),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.tap(find.text(tr.resourcesDeletePersonAction));
    await tester.pump();

    expect(deleteRequested, isTrue);
  });

  testWidgets("clicking + Add a function reports it", (tester) async {
    await useTallSurface(tester);
    var added = false;

    await tester.pumpWidget(buildSheet(person: testPerson(), onPositionAdded: () => added = true));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.tap(find.text(tr.resourcesAddPositionAction));
    await tester.pump();

    expect(added, isTrue);
  });

  testWidgets("removing a position reports its id", (tester) async {
    await useTallSurface(tester);
    String? removedId;

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(
          positions: const [
            OcptPersonPosition(id: "pos1", personId: "p1", positionId: "director", customLabel: ""),
          ],
        ),
        onPositionRemoved: (id) => removedId = id,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.tap(find.byTooltip(tr.resourcesRemovePositionTooltip));
    await tester.pump();

    expect(removedId, "pos1");
  });

  testWidgets("a position row's picker button opens OcptCrewPositionPickerDialog, and picking a "
      "catalogue entry reports it", (tester) async {
    await useTallSurface(tester);
    String? updatedId;
    String? updatedPositionId;
    String? updatedCustomLabel;

    await tester.pumpWidget(
      buildSheet(
        person: testPerson(
          positions: const [
            OcptPersonPosition(id: "pos1", personId: "p1", positionId: "director", customLabel: ""),
          ],
        ),
        onPositionUpdated: (id, {required positionId, required customLabel}) {
          updatedId = id;
          updatedPositionId = positionId;
          updatedCustomLabel = customLabel;
        },
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
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

    expect(find.byType(OcptCrewPositionPickerDialog), findsOneWidget);
    await tester.ensureVisible(find.text(ocptCrewPositionLabel(tr, "gaffer")));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ocptCrewPositionLabel(tr, "gaffer")));
    await tester.pumpAndSettle();

    expect(updatedId, "pos1");
    expect(updatedPositionId, "gaffer");
    expect(updatedCustomLabel, "");
  });
}
