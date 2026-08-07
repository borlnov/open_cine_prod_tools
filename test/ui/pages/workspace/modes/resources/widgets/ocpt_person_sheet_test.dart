// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_color_swatches.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';

/// Builds a minimal [OcptPerson] for these tests, every free-text field left blank except the ones
/// a case cares about.
OcptPerson _person({
  String id = "p1",
  String firstName = "",
  String lastName = "",
  String email = "",
  int colorIndex = 0,
  DateTime? birthDate,
  String minorNotes = "",
  bool? isTransportAutonomous,
  String accommodationNotes = "",
  String travelNotes = "",
  String dietaryNotes = "",
  String allergies = "",
  String measurementHeight = "",
  String measurementChest = "",
  String measurementWaist = "",
  String measurementHips = "",
  String sizeTop = "",
  String sizeBottom = "",
  String sizeShoes = "",
  String hmcNotes = "",
  OcptImageRightsStatus imageRightsStatus = OcptImageRightsStatus.notApplicable,
  DateTime? imageRightsDate,
  OcptAssetRef? photo,
  OcptAssetRef? imageRightsDocument,
  String notes = "",
  List<OcptPersonPosition> positions = const [],
  List<OcptPersonSkill> skills = const [],
  List<OcptPersonUnavailability> unavailabilities = const [],
}) => OcptPerson(
  id: id,
  firstName: firstName,
  lastName: lastName,
  email: email,
  phone: "",
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  colorIndex: colorIndex,
  birthDate: birthDate,
  minorNotes: minorNotes,
  isTransportAutonomous: isTransportAutonomous,
  accommodationNotes: accommodationNotes,
  travelNotes: travelNotes,
  dietaryNotes: dietaryNotes,
  allergies: allergies,
  measurementHeight: measurementHeight,
  measurementChest: measurementChest,
  measurementWaist: measurementWaist,
  measurementHips: measurementHips,
  sizeTop: sizeTop,
  sizeBottom: sizeBottom,
  sizeShoes: sizeShoes,
  hmcNotes: hmcNotes,
  imageRightsStatus: imageRightsStatus,
  imageRightsDate: imageRightsDate,
  imageRightsAssetId: imageRightsDocument?.id,
  imageRightsDocument: imageRightsDocument,
  photoAssetId: photo?.id,
  photo: photo,
  notes: notes,
  positions: positions,
  skills: skills,
  unavailabilities: unavailabilities,
);

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
);

/// [person]'s current value for [field], mirroring `OcptResourcesMode._fieldValueOf` with no
/// pending edits (these tests have no bloc of their own).
String _fieldValueOf(OcptPerson person, OcptPersonField field) => switch (field) {
  OcptPersonField.firstName => person.firstName,
  OcptPersonField.lastName => person.lastName,
  OcptPersonField.email => person.email,
  OcptPersonField.phone => person.phone,
  OcptPersonField.addressLine1 => person.addressLine1,
  OcptPersonField.addressLine2 => person.addressLine2,
  OcptPersonField.postalCode => person.postalCode,
  OcptPersonField.city => person.city,
  OcptPersonField.region => person.region,
  OcptPersonField.country => person.country,
  OcptPersonField.minorNotes => person.minorNotes,
  OcptPersonField.accommodationNotes => person.accommodationNotes,
  OcptPersonField.travelNotes => person.travelNotes,
  OcptPersonField.dietaryNotes => person.dietaryNotes,
  OcptPersonField.allergies => person.allergies,
  OcptPersonField.measurementHeight => person.measurementHeight,
  OcptPersonField.measurementChest => person.measurementChest,
  OcptPersonField.measurementWaist => person.measurementWaist,
  OcptPersonField.measurementHips => person.measurementHips,
  OcptPersonField.sizeTop => person.sizeTop,
  OcptPersonField.sizeBottom => person.sizeBottom,
  OcptPersonField.sizeShoes => person.sizeShoes,
  OcptPersonField.hmcNotes => person.hmcNotes,
  OcptPersonField.notes => person.notes,
};

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 700, child: child)),
);

/// Grows the test surface tall enough that the whole (long, scrolling) sheet is built and
/// hit-testable without having to scroll it, restoring the default size once the test ends.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(700, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// The [Finder] of the text field labelled [label] (its uppercased display label, e.g. `"EMAIL"`),
/// mirroring `OcptShotInspectorPanel`'s own test helper: the label and the field are siblings
/// inside one `OcptResourcesSheetField`, so the field is found as its descendant rather than through
/// the label directly.
Finder _fieldOf(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(OcptResourcesSheetField)),
  matching: find.byType(TextField),
);

/// Builds a sheet for [person], recording every callback into the maps/lists a test reads back.
/// Every callback but `onFieldChanged` and `onDeleteRequested` is a plain recorder: the specific
/// fields these tests care about are covered individually.
Widget _buildSheet({
  required OcptPerson person,
  bool isReadOnly = false,
  void Function(OcptPersonField field, String rawValue)? onFieldChanged,
  VoidCallback? onPositionAdded,
  void Function(String id, {required String positionId, required String customLabel})?
  onPositionUpdated,
  ValueChanged<String>? onPositionRemoved,
  ValueChanged<String>? onSkillAdded,
  ValueChanged<String>? onSkillRemoved,
  void Function({
    required DateTime startDate,
    required DateTime endDate,
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
  })?
  onUnavailabilityAdded,
  void Function(
    String id, {
    required DateTime startDate,
    required DateTime endDate,
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
    required String reason,
  })?
  onUnavailabilityUpdated,
  ValueChanged<String>? onUnavailabilityRemoved,
  ValueChanged<int>? onColorChanged,
  VoidCallback? onPhotoPickRequested,
  VoidCallback? onPhotoCleared,
  VoidCallback? onImageRightsDocumentPickRequested,
  VoidCallback? onImageRightsDocumentCleared,
  VoidCallback? onDeleteRequested,
}) => _wrapInApp(
  OcptPersonSheet(
    person: person,
    isReadOnly: isReadOnly,
    fieldValueOf: (field) => _fieldValueOf(person, field),
    onFieldChanged: onFieldChanged ?? (_, __) {},
    onColorChanged: onColorChanged ?? (_) {},
    onPhotoPickRequested: onPhotoPickRequested ?? () {},
    onPhotoCleared: onPhotoCleared ?? () {},
    onImageRightsDocumentPickRequested: onImageRightsDocumentPickRequested ?? () {},
    onImageRightsDocumentCleared: onImageRightsDocumentCleared ?? () {},
    onBirthDateChanged: (_) {},
    onTransportAutonomyChanged: (_) {},
    onImageRightsStatusChanged: (_) {},
    onImageRightsDateChanged: (_) {},
    onPositionAdded: onPositionAdded ?? () {},
    onPositionUpdated: onPositionUpdated ?? (id, {required positionId, required customLabel}) {},
    onPositionRemoved: onPositionRemoved ?? (_) {},
    onSkillAdded: onSkillAdded ?? (_) {},
    onSkillRemoved: onSkillRemoved ?? (_) {},
    onUnavailabilityAdded:
        onUnavailabilityAdded ??
        ({
          required startDate,
          required endDate,
          required slot,
          required startMinute,
          required endMinute,
        }) {},
    onUnavailabilityUpdated:
        onUnavailabilityUpdated ??
        (
          id, {
          required startDate,
          required endDate,
          required slot,
          required startMinute,
          required endMinute,
          required reason,
        }) {},
    onUnavailabilityRemoved: onUnavailabilityRemoved ?? (_) {},
    onDeleteRequested: onDeleteRequested ?? () {},
  ),
);

void main() {
  testWidgets("renders the selected person's fields", (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      _buildSheet(
        person: _person(
          firstName: "Léa",
          lastName: "Martin",
          email: "lea@example.com",
          dietaryNotes: "Végétarienne",
          notes: "Ponctuelle",
          positions: const [
            OcptPersonPosition(
              id: "pos1",
              personId: "p1",
              positionId: "director",
              customLabel: "",
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Léa"), findsOneWidget);
    expect(find.text("Martin"), findsOneWidget);
    expect(find.text("lea@example.com"), findsOneWidget);
    expect(find.text("Director"), findsOneWidget);
    expect(find.text("defined in the schedule"), findsOneWidget);
    expect(find.text("Végétarienne"), findsOneWidget);
    expect(find.text("Ponctuelle"), findsOneWidget);
  });

  testWidgets("a malformed email is flagged once the field loses the focus, never before", (
    tester,
  ) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_buildSheet(person: _person(email: "clara@example.com")));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    expect(find.text(tr.resourcesEmailMalformedError), findsNothing);

    // Typing an incomplete address says nothing while the field still has the focus: the sheet
    // writes as it is typed, and every value passes through half-typed states.
    await tester.tap(_fieldOf(tr.resourcesEmailLabel.toUpperCase()));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldOf(tr.resourcesEmailLabel.toUpperCase()), "clara@");
    await tester.pumpAndSettle();
    expect(find.text(tr.resourcesEmailMalformedError), findsNothing);

    // It is flagged the moment the focus moves elsewhere.
    await tester.tap(_fieldOf(tr.resourcesPhoneLabel.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr.resourcesEmailMalformedError), findsOneWidget);
  });

  testWidgets("the HMC card holds the measurements and sizes, not the meals card", (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(
      _buildSheet(
        person: _person(
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
    await _useTallSurface(tester);
    final now = DateTime.now();

    await tester.pumpWidget(
      _buildSheet(
        person: _person(
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

  testWidgets("no minor badge or callout for an adult", (tester) async {
    await _useTallSurface(tester);
    final now = DateTime.now();

    await tester.pumpWidget(
      _buildSheet(person: _person(birthDate: DateTime(now.year - 30, now.month, now.day))),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    expect(find.text(tr.resourcesMinorCalloutTitle), findsNothing);
  });

  testWidgets("typing into the email field dispatches the change", (tester) async {
    await _useTallSurface(tester);
    final changes = <(OcptPersonField, String)>[];

    await tester.pumpWidget(
      _buildSheet(
        person: _person(),
        onFieldChanged: (field, rawValue) => changes.add((field, rawValue)),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.enterText(_fieldOf(tr.resourcesEmailLabel.toUpperCase()), "x");
    await tester.pump();

    expect(changes, contains((OcptPersonField.email, "x")));
  });

  testWidgets("the photo slot offers to reference a photo, and reports the pick", (tester) async {
    await _useTallSurface(tester);
    var pickRequested = false;

    await tester.pumpWidget(
      _buildSheet(person: _person(), onPhotoPickRequested: () => pickRequested = true),
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
    await _useTallSurface(tester);
    var cleared = false;

    await tester.pumpWidget(
      _buildSheet(person: _person(photo: _asset()), onPhotoCleared: () => cleared = true),
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
    await _useTallSurface(tester);

    await tester.pumpWidget(
      _buildSheet(person: _person(firstName: "Léa", lastName: "Roy", photo: _asset())),
    );
    await tester.pumpAndSettle();

    // `_asset` names a path these tests never create. A person has one photo and their initials
    // are a perfectly good thing to see in its place, so nothing is reported — unlike a scouting
    // photo, which is one item of a list and says so.
    expect(tester.takeException(), isNull);
    expect(find.text("LR"), findsWidgets);
    expect(find.text(Tr.of(tester.element(find.byType(OcptPersonSheet))).resourcesAssetFileMissing),
        findsNothing);
  });

  testWidgets("the image rights card references a document and drops it", (tester) async {
    await _useTallSurface(tester);
    var pickRequested = false;

    await tester.pumpWidget(
      _buildSheet(
        person: _person(),
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
    await _useTallSurface(tester);
    var cleared = false;

    await tester.pumpWidget(
      _buildSheet(
        person: _person(
          imageRightsDocument: _asset(
            kind: OcptAssetKind.document,
            path: "/nowhere/cession.pdf",
          ),
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
    await _useTallSurface(tester);
    final colorPicks = <int>[];

    await tester.pumpWidget(_buildSheet(person: _person(), onColorChanged: colorPicks.add));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.tap(find.byTooltip(tr.resourcesPhotoSlotTooltip));
    await tester.pumpAndSettle();

    // The popover used to throw on layout before showing a single swatch.
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(OcptResourcesColorSwatches),
        matching: find.byType(InkWell),
      ).at(4),
    );
    await tester.pumpAndSettle();

    expect(colorPicks, [4]);
  });

  testWidgets("clicking Delete this person reports it", (tester) async {
    await _useTallSurface(tester);
    var deleteRequested = false;

    await tester.pumpWidget(
      _buildSheet(person: _person(), onDeleteRequested: () => deleteRequested = true),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.tap(find.text(tr.resourcesDeletePersonAction));
    await tester.pump();

    expect(deleteRequested, isTrue);
  });

  testWidgets("clicking + Add a function reports it", (tester) async {
    await _useTallSurface(tester);
    var added = false;

    await tester.pumpWidget(_buildSheet(person: _person(), onPositionAdded: () => added = true));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPersonSheet)));
    await tester.tap(find.text(tr.resourcesAddPositionAction));
    await tester.pump();

    expect(added, isTrue);
  });

  testWidgets("removing a position reports its id", (tester) async {
    await _useTallSurface(tester);
    String? removedId;

    await tester.pumpWidget(
      _buildSheet(
        person: _person(
          positions: const [
            OcptPersonPosition(
              id: "pos1",
              personId: "p1",
              positionId: "director",
              customLabel: "",
            ),
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

  testWidgets("adding a skill through the inline field reports its label", (tester) async {
    await _useTallSurface(tester);
    String? addedLabel;

    await tester.pumpWidget(_buildSheet(person: _person(), onSkillAdded: (label) => addedLabel = label));
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
    await _useTallSurface(tester);
    String? removedId;

    await tester.pumpWidget(
      _buildSheet(
        person: _person(skills: const [OcptPersonSkill(id: "skill1", personId: "p1", label: "Piano")]),
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
      await _useTallSurface(tester);
      await tester.pumpWidget(
        _buildSheet(
          person: _person(
            firstName: "Léa",
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
      final firstNameField = tester.widget<TextField>(
        find.widgetWithText(TextField, "Léa"),
      );
      expect(firstNameField.readOnly, isTrue);
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
      await _useTallSurface(tester);
      OcptDayPartSlot? reportedSlot;
      int? reportedStartMinute;
      int? reportedEndMinute;

      await tester.pumpWidget(
        _buildSheet(
          person: _person(unavailabilities: [fullDay()]),
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
      await _useTallSurface(tester);
      DateTime? reportedStart;
      DateTime? reportedEnd;
      OcptDayPartSlot? reportedSlot;
      int? reportedStartMinute;

      await tester.pumpWidget(
        _buildSheet(
          person: _person(
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
      await _useTallSurface(tester);

      await tester.pumpWidget(_buildSheet(person: _person(unavailabilities: [fullDay()])));
      await tester.pumpAndSettle();
      expect(find.text("→"), findsNothing);

      await tester.pumpWidget(
        _buildSheet(
          person: _person(
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
