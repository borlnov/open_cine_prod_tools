// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
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

void main() {
  /// Pumps the panel on [activeTab], with [onAddPersonRequested] as its creation callback.
  Future<void> pumpPanel(
    WidgetTester tester, {
    OcptResourcesTab activeTab = OcptResourcesTab.people,
    VoidCallback? onAddPersonRequested,
  }) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptResourcesListPanel(
          activeTab: activeTab,
          people: [_person(id: "p1", firstName: "Sofia", lastName: "Berger")],
          selectedPersonId: null,
          onTabSelected: (_) {},
          onPersonSelected: (_) {},
          onAddPersonRequested: onAddPersonRequested,
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

  testWidgets("a tab with no content yet shows a placeholder and no creation button", (
    tester,
  ) async {
    await pumpPanel(tester, activeTab: OcptResourcesTab.roles, onAddPersonRequested: () {});

    expect(find.text("Sofia Berger"), findsNothing);
    expect(find.widgetWithText(FilledButton, "+ Add a person"), findsNothing);
  });
}
