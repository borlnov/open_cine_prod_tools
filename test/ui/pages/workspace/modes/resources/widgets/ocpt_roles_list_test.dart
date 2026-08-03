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
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_roles_list.dart';

/// Builds a minimal [OcptPerson] for these tests, every free-text field left blank except the ones
/// a case cares about.
OcptPerson _person({required String id, String firstName = "", String lastName = "", int colorIndex = 0}) =>
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
      colorIndex: colorIndex,
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
  String name = "",
  String? personId,
  OcptRoleKind kind = OcptRoleKind.speaking,
  String? orphanedName,
  int number = 1,
}) => OcptRole(
  id: id,
  screenplayId: "screenplay",
  name: name,
  personId: personId,
  kind: kind,
  isFromScreenplay: kind == OcptRoleKind.speaking,
  orphanedName: orphanedName,
  castingNotes: "",
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
  home: Scaffold(body: SizedBox(width: 260, height: 400, child: child)),
);

void main() {
  testWidgets("a cast role shows its name and its cast member", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [_role(id: "r1", name: "Le Client", personId: "p1")],
          people: [_person(id: "p1", firstName: "Léa", lastName: "Martin")],
          selectedRoleId: null,
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Le Client"), findsOneWidget);
    expect(find.text("Léa Martin"), findsOneWidget);
  });

  testWidgets("an uncast role shows the not-cast placeholder", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [_role(id: "r1", name: "Le Client")],
          people: const [],
          selectedRoleId: null,
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
    expect(find.text(tr.resourcesRoleNotCast), findsOneWidget);
  });

  testWidgets("a cast member holding another role shows it on a muted line", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [
            _role(id: "r1", name: "Le Client", personId: "p1"),
            _role(id: "r2", name: "Le Voisin", personId: "p1", number: 2),
          ],
          people: [_person(id: "p1", firstName: "Léa", lastName: "Martin")],
          selectedRoleId: null,
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
    expect(find.text(tr.resourcesRolesListOtherRolesLabel("Le Voisin")), findsOneWidget);
    expect(find.text(tr.resourcesRolesListOtherRolesLabel("Le Client")), findsOneWidget);
  });

  testWidgets("an empty cast shows the empty hint instead of a list", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(roles: const [], people: const [], selectedRoleId: null, onRoleSelected: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
    expect(find.text(tr.resourcesRolesEmptyHint), findsOneWidget);
  });

  testWidgets("an orphaned role is flagged, an ordinary one is not", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [
            _role(id: "r1", name: "Le Client", orphanedName: "LE CLIENT"),
            _role(id: "r2", name: "Le Voisin", number: 2),
          ],
          people: const [],
          selectedRoleId: null,
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The alert itself lives in the role's own sheet: this list only says which one to go and read.
    expect(find.byIcon(Icons.person_off_outlined), findsOneWidget);
  });

  testWidgets("tapping a row reports that role's id", (tester) async {
    String? selected;

    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [_role(id: "r1", name: "Le Client")],
          people: const [],
          selectedRoleId: null,
          onRoleSelected: (roleId) => selected = roleId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Le Client"));
    await tester.pumpAndSettle();

    expect(selected, "r1");
  });
}
