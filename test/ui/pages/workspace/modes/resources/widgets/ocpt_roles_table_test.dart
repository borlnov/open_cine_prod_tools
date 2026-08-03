// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_roles_table.dart';

/// Builds a minimal [OcptPerson] for these tests.
OcptPerson _person({required String id, String firstName = "", String lastName = ""}) => OcptPerson(
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
  notes: "",
  positions: const [],
  skills: const [],
  unavailabilities: const [],
);

/// Builds a minimal [OcptRole] for these tests.
OcptRole _role({
  required String id,
  String name = "Le Client",
  String? personId,
  OcptRoleKind kind = OcptRoleKind.speaking,
  bool? isFromScreenplay,
  String castingNotes = "",
  int number = 1,
}) => OcptRole(
  id: id,
  screenplayId: "screenplay",
  name: name,
  personId: personId,
  kind: kind,
  isFromScreenplay: isFromScreenplay ?? (kind == OcptRoleKind.speaking),
  orphanedName: null,
  castingNotes: castingNotes,
  number: number,
);

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 700, height: 600, child: child)),
);

/// Builds an [OcptRolesTable] over a single [role], every callback a no-op unless overridden.
Widget _buildTable({
  required OcptRole role,
  List<OcptPerson> people = const [],
  String? selectedRoleId,
  bool isReadOnly = false,
  ValueChanged<String>? onRoleSelected,
  void Function(String roleId, OcptRoleField field, String rawValue)? onFieldChanged,
  void Function(String roleId, String? personId)? onCastChanged,
  ValueChanged<String>? onDeleteRequested,
  ValueChanged<String>? onPersonSheetOpenRequested,
}) => _wrapInApp(
  OcptRolesTable(
    roles: [role],
    people: people,
    selectedRoleId: selectedRoleId,
    isReadOnly: isReadOnly,
    fieldValueOf: (role, field) => switch (field) {
      OcptRoleField.name => role.name,
      OcptRoleField.castingNotes => role.castingNotes,
    },
    onRoleSelected: onRoleSelected ?? (roleId) {},
    onFieldChanged: onFieldChanged ?? (roleId, field, rawValue) {},
    onCastChanged: onCastChanged ?? (roleId, personId) {},
    onKindChanged: (roleId, kind) {},
    onDeleteRequested: onDeleteRequested ?? (roleId) {},
    onPersonSheetOpenRequested: onPersonSheetOpenRequested ?? (personId) {},
  ),
);

void main() {
  testWidgets("tapping a row reports its id and no editor shows while unselected", (tester) async {
    String? selected;

    await tester.pumpWidget(
      _buildTable(role: _role(id: "r1"), onRoleSelected: (roleId) => selected = roleId),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesTable)));
    expect(find.text(tr.resourcesRoleCastingNotesLabel), findsNothing);

    await tester.tap(find.text("Le Client"));
    await tester.pumpAndSettle();

    expect(selected, "r1");
  });

  testWidgets("selecting a role expands its editor in place", (tester) async {
    await tester.pumpWidget(_buildTable(role: _role(id: "r1"), selectedRoleId: "r1"));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesTable)));
    expect(find.text(tr.resourcesRoleCastingNotesLabel.toUpperCase()), findsOneWidget);
  });

  testWidgets("the name field is withheld for a screenplay role", (tester) async {
    await tester.pumpWidget(
      _buildTable(
        role: _role(id: "r1"),
        selectedRoleId: "r1",
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesTable)));
    expect(find.text(tr.resourcesRoleNameFromScreenplayNote), findsOneWidget);
    // Its name is read as plain text, not through an editable field.
    expect(find.widgetWithText(TextField, "Le Client"), findsNothing);
  });

  testWidgets("the name field is present and editable for a hand-added role", (tester) async {
    await tester.pumpWidget(
      _buildTable(
        role: _role(id: "r1", kind: OcptRoleKind.silent, isFromScreenplay: false),
        selectedRoleId: "r1",
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesTable)));
    expect(find.text(tr.resourcesRoleNameFromScreenplayNote), findsNothing);
    expect(find.widgetWithText(TextField, "Le Client"), findsOneWidget);
  });

  testWidgets("the ↗ affordance dispatches the cast member's id", (tester) async {
    String? openedPersonId;

    await tester.pumpWidget(
      _buildTable(
        role: _role(id: "r1", personId: "p1"),
        people: [_person(id: "p1", firstName: "Léa", lastName: "Martin")],
        onPersonSheetOpenRequested: (personId) => openedPersonId = personId,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.north_east));
    await tester.pumpAndSettle();

    expect(openedPersonId, "p1");
  });

  testWidgets("the ↗ affordance is absent while the role is uncast", (tester) async {
    await tester.pumpWidget(_buildTable(role: _role(id: "r1")));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.north_east), findsNothing);
  });

  testWidgets("every write affordance disappears when read-only", (tester) async {
    await tester.pumpWidget(
      _buildTable(
        role: _role(
          id: "r1",
          kind: OcptRoleKind.silent,
          isFromScreenplay: false,
          personId: "p1",
        ),
        people: [_person(id: "p1", firstName: "Léa", lastName: "Martin")],
        selectedRoleId: "r1",
        isReadOnly: true,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesTable)));

    // No dropdown arrow on either picker: withheld, not disabled.
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    // No delete action.
    expect(find.text(tr.resourcesRoleDeleteAction), findsNothing);
    // The name field still reads out its value, but not through a writable control.
    final nameField = tester.widget<TextField>(find.widgetWithText(TextField, "Le Client"));
    expect(nameField.readOnly, isTrue);
    // What only reads stays: the ↗ affordance still opens the cast member's sheet.
    expect(find.byIcon(Icons.north_east), findsOneWidget);
  });
}
