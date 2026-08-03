// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_panel.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a panel-sized
/// box.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 280, child: child)),
);

/// A person carrying nothing but a name, enough for a row of the list.
OcptPerson _person({required String id, required String firstName, required String lastName}) =>
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

/// A role carrying nothing but a name, enough for a row of the list.
OcptRole _role({required String id, required String name}) => OcptRole(
  id: id,
  screenplayId: "screenplay",
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
);

/// A location carrying nothing but a name, enough for a row of the list.
OcptLocation _location({required String id, required String name}) => OcptLocation(
  id: id,
  name: name,
  colorIndex: 0,
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  latitude: null,
  longitude: null,
  contactPersonId: null,
  contactNotes: "",
  permitStatus: OcptPermitStatus.notNeeded,
  permitLabel: "",
  permitDate: null,
  permitAssetId: null,
  parkingNotes: "",
  powerNotes: "",
  facilitiesNotes: "",
  constraintsNotes: "",
  notes: "",
  sets: const [],
  photos: const [],
  permitDocument: null,
  availabilities: const [],
);

void main() {
  /// Pumps the panel on [activeTab], with the three contextual creation callbacks a tab may carry.
  Future<void> pumpPanel(
    WidgetTester tester, {
    OcptResourcesTab activeTab = OcptResourcesTab.people,
    VoidCallback? onAddPersonRequested,
    ValueChanged<OcptRoleKind>? onAddRoleRequested,
    VoidCallback? onAddLocationRequested,
    ValueChanged<String>? onLocationSelected,
  }) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptResourcesListPanel(
          activeTab: activeTab,
          people: [_person(id: "p1", firstName: "Sofia", lastName: "Berger")],
          selectedPersonId: null,
          roles: [_role(id: "r1", name: "Le Client")],
          selectedRoleId: null,
          locations: [_location(id: "l1", name: "La maison des Pains")],
          selectedLocationId: null,
          onTabSelected: (tab) {},
          onPersonSelected: (personId) {},
          onRoleSelected: (roleId) {},
          onLocationSelected: onLocationSelected ?? (locationId) {},
          onAddPersonRequested: onAddPersonRequested,
          onAddRoleRequested: onAddRoleRequested,
          onAddLocationRequested: onAddLocationRequested,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("the people tab lists its people and offers the creation button", (tester) async {
    await pumpPanel(tester, onAddPersonRequested: () {});

    expect(find.text("Sofia Berger"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, "+ Add a person"), findsOneWidget);
  });

  testWidgets("a null creation callback draws no button at all, not a disabled one", (
    tester,
  ) async {
    await pumpPanel(tester);

    // Withheld, not disabled: a preview must not show an affordance the user cannot use.
    expect(find.widgetWithText(FilledButton, "+ Add a person"), findsNothing);
    // What only reads stays.
    expect(find.text("Sofia Berger"), findsOneWidget);
  });

  testWidgets("the roles tab lists its cast and offers the add-role menu", (tester) async {
    OcptRoleKind? pickedKind;

    await pumpPanel(
      tester,
      activeTab: OcptResourcesTab.roles,
      onAddRoleRequested: (kind) => pickedKind = kind,
    );

    expect(find.text("Le Client"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, "+ Add a role"), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, "+ Add a role"));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptResourcesListPanel)));
    // `speaking` is never offered: only `OcptRoleIndexService.reconcile` ever creates one.
    expect(find.text(tr.resourcesAddRoleSilentOption), findsOneWidget);
    expect(find.text(tr.resourcesAddRoleExtraOption), findsOneWidget);

    await tester.tap(find.text(tr.resourcesAddRoleExtraOption));
    await tester.pumpAndSettle();

    expect(pickedKind, OcptRoleKind.extra);
  });

  testWidgets("a null add-role callback draws no button at all, not a disabled one", (
    tester,
  ) async {
    await pumpPanel(tester, activeTab: OcptResourcesTab.roles);

    expect(find.widgetWithText(FilledButton, "+ Add a role"), findsNothing);
    expect(find.text("Le Client"), findsOneWidget);
  });

  testWidgets("the locations tab lists its locations and offers the creation button", (
    tester,
  ) async {
    String? selectedLocationId;

    await pumpPanel(
      tester,
      activeTab: OcptResourcesTab.locations,
      onAddLocationRequested: () {},
      onLocationSelected: (locationId) => selectedLocationId = locationId,
    );

    expect(find.text("La maison des Pains"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, "+ Add a location"), findsOneWidget);

    await tester.tap(find.text("La maison des Pains"));
    await tester.pumpAndSettle();

    expect(selectedLocationId, "l1");
  });

  testWidgets("a null add-location callback draws no button at all, not a disabled one", (
    tester,
  ) async {
    await pumpPanel(tester, activeTab: OcptResourcesTab.locations);

    expect(find.widgetWithText(FilledButton, "+ Add a location"), findsNothing);
    expect(find.text("La maison des Pains"), findsOneWidget);
  });

  testWidgets("a tab with no content yet shows a placeholder and no creation button", (
    tester,
  ) async {
    await pumpPanel(
      tester,
      activeTab: OcptResourcesTab.elements,
      onAddPersonRequested: () {},
      onAddRoleRequested: (kind) {},
      onAddLocationRequested: () {},
    );

    expect(find.text("Sofia Berger"), findsNothing);
    expect(find.text("Le Client"), findsNothing);
    expect(find.text("La maison des Pains"), findsNothing);
    expect(find.widgetWithText(FilledButton, "+ Add a person"), findsNothing);
    expect(find.widgetWithText(FilledButton, "+ Add a role"), findsNothing);
    expect(find.widgetWithText(FilledButton, "+ Add a location"), findsNothing);
  });
}
