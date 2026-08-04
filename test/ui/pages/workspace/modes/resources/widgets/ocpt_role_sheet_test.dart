// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_sheet_header.dart';

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
  String id = "r1",
  String name = "Le Client",
  String? personId,
  OcptRoleKind kind = OcptRoleKind.speaking,
  bool? isFromScreenplay,
  String? orphanedName,
  String castingNotes = "",
  int number = 3,
}) => OcptRole(
  id: id,
  screenplayId: "screenplay",
  name: name,
  personId: personId,
  kind: kind,
  isFromScreenplay: isFromScreenplay ?? (kind == OcptRoleKind.speaking),
  orphanedName: orphanedName,
  castingNotes: castingNotes,
  number: number,
);

/// Finds [text] inside the header alone: the cast member's name and the not-cast placeholder both
/// appear a second time in the casting card's own picker.
Finder _inHeader(String text) =>
    find.descendant(of: find.byType(OcptRoleSheetHeader), matching: find.text(text));

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 700, height: 700, child: child)),
);

/// Builds an [OcptRoleSheet] over [role], every callback a no-op unless overridden.
Widget _buildSheet({
  required OcptRole role,
  OcptPerson? castMember,
  List<OcptRole> otherRoles = const [],
  List<OcptPerson> people = const [],
  bool isReadOnly = false,
  void Function(OcptRoleField field, String rawValue)? onFieldChanged,
  ValueChanged<String?>? onCastChanged,
  ValueChanged<OcptRoleKind>? onKindChanged,
  VoidCallback? onDeleteRequested,
  VoidCallback? onOrphanedRoleKept,
  ValueChanged<String>? onPersonSheetOpenRequested,
}) => _wrapInApp(
  OcptRoleSheet(
    role: role,
    castMember: castMember,
    otherRoles: otherRoles,
    people: people,
    removedRoleAlert: OcptRemovedRoleAlert.of(role),
    isReadOnly: isReadOnly,
    fieldValueOf: (field) => switch (field) {
      OcptRoleField.name => role.name,
      OcptRoleField.castingNotes => role.castingNotes,
    },
    onFieldChanged: onFieldChanged ?? (field, rawValue) {},
    onCastChanged: onCastChanged ?? (personId) {},
    onKindChanged: onKindChanged ?? (kind) {},
    onDeleteRequested: onDeleteRequested ?? () {},
    onOrphanedRoleKept: onOrphanedRoleKept ?? () {},
    onPersonSheetOpenRequested: onPersonSheetOpenRequested ?? (personId) {},
  ),
);

void main() {
  testWidgets("the header names the role, its rank and its cast member", (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        role: _role(personId: "p1"),
        castMember: _person(id: "p1", firstName: "Léa", lastName: "Martin"),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text("Le Client"), findsOneWidget);
    expect(find.text(tr.resourcesRoleNumberBadge(3)), findsOneWidget);
    expect(find.text("Léa Martin"), findsWidgets);
  });

  testWidgets("the name is read-only for a role the screenplay owns", (tester) async {
    await tester.pumpWidget(_buildSheet(role: _role()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text(tr.resourcesRoleNameFromScreenplayNote), findsOneWidget);
    expect(find.widgetWithText(TextField, "Le Client"), findsNothing);
  });

  testWidgets("a hand-added role types its own name", (tester) async {
    final changes = <(OcptRoleField, String)>[];

    await tester.pumpWidget(
      _buildSheet(
        role: _role(name: "Le Serveur", kind: OcptRoleKind.silent, isFromScreenplay: false),
        onFieldChanged: (field, rawValue) => changes.add((field, rawValue)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, "Le Serveur"), "Le Serveur du bar");
    await tester.pumpAndSettle();

    expect(changes, [(OcptRoleField.name, "Le Serveur du bar")]);
  });

  testWidgets("typing casting notes reports them raw", (tester) async {
    final changes = <(OcptRoleField, String)>[];

    await tester.pumpWidget(
      _buildSheet(
        role: _role(castingNotes: "Agent"),
        onFieldChanged: (field, rawValue) => changes.add((field, rawValue)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, "Agent"), "Agent : Dupont");
    await tester.pumpAndSettle();

    expect(changes, [(OcptRoleField.castingNotes, "Agent : Dupont")]);
  });

  testWidgets("the casting card picks a cast member, and uncasts through its own entry", (
    tester,
  ) async {
    final casts = <String?>[];

    await tester.pumpWidget(
      _buildSheet(
        role: _role(personId: "p1"),
        castMember: _person(id: "p1", firstName: "Léa", lastName: "Martin"),
        people: [
          _person(id: "p1", firstName: "Léa", lastName: "Martin"),
          _person(id: "p2", firstName: "Nour", lastName: "Bakri"),
        ],
        onCastChanged: casts.add,
      ),
    );
    await tester.pumpAndSettle();

    // The header's kind picker carries the first arrow, the casting card's the second.
    await tester.tap(find.byIcon(Icons.arrow_drop_down).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Nour Bakri").last);
    await tester.pumpAndSettle();

    expect(casts, ["p2"]);

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    await tester.tap(find.byIcon(Icons.arrow_drop_down).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesRoleNotCast).last);
    await tester.pumpAndSettle();

    expect(casts, ["p2", null]);
  });

  testWidgets("the header picks the role's kind", (tester) async {
    final kinds = <OcptRoleKind>[];

    await tester.pumpWidget(
      _buildSheet(role: _role(), onKindChanged: kinds.add),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    // The kind picker is the header's own, so it carries the first of the two arrows.
    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesRoleKindSilent).last);
    await tester.pumpAndSettle();

    expect(kinds, [OcptRoleKind.silent]);
  });

  testWidgets("the other roles the cast member holds are named", (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        role: _role(personId: "p1"),
        castMember: _person(id: "p1", firstName: "Léa", lastName: "Martin"),
        otherRoles: [_role(id: "r2", name: "La Voisine", personId: "p1", number: 5)],
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text(tr.resourcesRolesListOtherRolesLabel("La Voisine")), findsOneWidget);
  });

  testWidgets("the delete action is withheld while the screenplay still speaks the role", (
    tester,
  ) async {
    await tester.pumpWidget(_buildSheet(role: _role()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    // Deleting it would cost the casting and the notes without removing anything: the next save's
    // reconciliation inserts that character right back.
    expect(find.text(tr.resourcesRoleDeleteAction), findsNothing);
  });

  testWidgets("clicking Delete this role reports it for a hand-added role", (tester) async {
    var deleted = 0;

    await tester.pumpWidget(
      _buildSheet(
        role: _role(kind: OcptRoleKind.extra, isFromScreenplay: false),
        onDeleteRequested: () => deleted++,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    await tester.tap(find.text(tr.resourcesRoleDeleteAction));
    await tester.pumpAndSettle();

    // The sheet only asks: the question itself is the mode's confirmation dialog.
    expect(deleted, 1);
  });

  testWidgets("an orphaned role reports its alert in its own sheet, with both ways out", (
    tester,
  ) async {
    var deleted = 0;
    var kept = 0;

    await tester.pumpWidget(
      _buildSheet(
        role: _role(orphanedName: "LE CLIENT"),
        onDeleteRequested: () => deleted++,
        onOrphanedRoleKept: () => kept++,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text(tr.resourcesRemovedRoleBanner("LE CLIENT")), findsOneWidget);

    // The banner carries the deletion, so the bottom of the sheet does not ask for it again.
    expect(find.text(tr.resourcesRemovedRoleDeleteAction), findsOneWidget);

    await tester.tap(find.text(tr.resourcesRemovedRoleKeepAction));
    await tester.pumpAndSettle();
    expect(kept, 1);

    // The banner's own delete needs no second question: the banner is that question.
    await tester.tap(find.text(tr.resourcesRemovedRoleDeleteAction));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets("a role still spoken in the screenplay reports no alert", (tester) async {
    await tester.pumpWidget(_buildSheet(role: _role()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_off_outlined), findsNothing);
  });

  testWidgets("the whole cast member line opens their sheet, name included", (tester) async {
    final opened = <String>[];

    await tester.pumpWidget(
      _buildSheet(
        role: _role(personId: "p1"),
        castMember: _person(id: "p1", firstName: "Léa", lastName: "Martin"),
        onPersonSheetOpenRequested: opened.add,
      ),
    );
    await tester.pumpAndSettle();

    // The name is the target one actually aims at, not only the 14 px arrow beside it.
    await tester.tap(_inHeader("Léa Martin"));
    await tester.pumpAndSettle();
    expect(opened, ["p1"]);

    await tester.tap(find.byIcon(Icons.north_east));
    await tester.pumpAndSettle();
    expect(opened, ["p1", "p1"]);
  });

  testWidgets("an uncast role offers nothing to open", (tester) async {
    await tester.pumpWidget(_buildSheet(role: _role()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.byIcon(Icons.north_east), findsNothing);
    expect(_inHeader(tr.resourcesRoleNotCast), findsOneWidget);
  });

  testWidgets("every write affordance disappears when read-only", (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        role: _role(kind: OcptRoleKind.silent, isFromScreenplay: false, personId: "p1"),
        castMember: _person(id: "p1", firstName: "Léa", lastName: "Martin"),
        people: [_person(id: "p1", firstName: "Léa", lastName: "Martin")],
        isReadOnly: true,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));

    // No dropdown arrow on either picker: withheld, not disabled.
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    // No delete action, even for a role that could be deleted.
    expect(find.text(tr.resourcesRoleDeleteAction), findsNothing);
    // The name field still reads its value out, but not through a writable control.
    final nameField = tester.widget<TextField>(find.widgetWithText(TextField, "Le Client"));
    expect(nameField.readOnly, isTrue);
    // What only reads stays: the ↗ affordance still opens the cast member's sheet.
    expect(find.byIcon(Icons.north_east), findsOneWidget);
  });
}
