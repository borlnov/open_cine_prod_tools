// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/types/ocpt_half_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_field.dart';

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
  String sizeTop = "",
  String sizeBottom = "",
  String sizeShoes = "",
  String hmcNotes = "",
  OcptImageRightsStatus imageRightsStatus = OcptImageRightsStatus.notApplicable,
  DateTime? imageRightsDate,
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
  address: "",
  city: "",
  colorIndex: colorIndex,
  birthDate: birthDate,
  minorNotes: minorNotes,
  isTransportAutonomous: isTransportAutonomous,
  accommodationNotes: accommodationNotes,
  travelNotes: travelNotes,
  dietaryNotes: dietaryNotes,
  allergies: allergies,
  sizeTop: sizeTop,
  sizeBottom: sizeBottom,
  sizeShoes: sizeShoes,
  hmcNotes: hmcNotes,
  imageRightsStatus: imageRightsStatus,
  imageRightsDate: imageRightsDate,
  imageRightsAssetId: null,
  photoAssetId: null,
  notes: notes,
  positions: positions,
  skills: skills,
  unavailabilities: unavailabilities,
);

/// [person]'s current value for [field], mirroring `OcptResourcesMode._fieldValueOf` with no
/// pending edits (these tests have no bloc of their own).
String _fieldValueOf(OcptPerson person, OcptPersonField field) => switch (field) {
  OcptPersonField.firstName => person.firstName,
  OcptPersonField.lastName => person.lastName,
  OcptPersonField.email => person.email,
  OcptPersonField.phone => person.phone,
  OcptPersonField.address => person.address,
  OcptPersonField.city => person.city,
  OcptPersonField.minorNotes => person.minorNotes,
  OcptPersonField.accommodationNotes => person.accommodationNotes,
  OcptPersonField.travelNotes => person.travelNotes,
  OcptPersonField.dietaryNotes => person.dietaryNotes,
  OcptPersonField.allergies => person.allergies,
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
/// inside one `OcptPersonSheetField`, so the field is found as its descendant rather than through
/// the label directly.
Finder _fieldOf(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(OcptPersonSheetField)),
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
  void Function(String id, {required String positionId, required String customLabel, required String scopeNotes})?
  onPositionUpdated,
  ValueChanged<String>? onPositionRemoved,
  ValueChanged<String>? onSkillAdded,
  ValueChanged<String>? onSkillRemoved,
  ValueChanged<DateTime>? onUnavailabilityAdded,
  ValueChanged<String>? onUnavailabilityRemoved,
  VoidCallback? onDeleteRequested,
}) => _wrapInApp(
  OcptPersonSheet(
    person: person,
    isReadOnly: isReadOnly,
    fieldValueOf: (field) => _fieldValueOf(person, field),
    onFieldChanged: onFieldChanged ?? (_, __) {},
    onColorChanged: (_) {},
    onBirthDateChanged: (_) {},
    onTransportAutonomyChanged: (_) {},
    onImageRightsStatusChanged: (_) {},
    onImageRightsDateChanged: (_) {},
    onPositionAdded: onPositionAdded ?? () {},
    onPositionUpdated: onPositionUpdated ?? (id, {required positionId, required customLabel, required scopeNotes}) {},
    onPositionRemoved: onPositionRemoved ?? (_) {},
    onSkillAdded: onSkillAdded ?? (_) {},
    onSkillRemoved: onSkillRemoved ?? (_) {},
    onUnavailabilityAdded: onUnavailabilityAdded ?? (_) {},
    onUnavailabilityUpdated: (id, {required date, required halfDay, required reason}) {},
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
              scopeNotes: "Whole shoot",
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
    expect(find.text("Whole shoot"), findsOneWidget);
    expect(find.text("Végétarienne"), findsOneWidget);
    expect(find.text("Ponctuelle"), findsOneWidget);
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

  testWidgets("clicking + Add a position (with its scope) reports it", (tester) async {
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
              scopeNotes: "",
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
                scopeNotes: "",
              ),
            ],
            unavailabilities: [
              OcptPersonUnavailability(
                id: "u1",
                personId: "p1",
                date: DateTime(2026, 8, 15),
                halfDay: OcptHalfDay.full,
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
}
