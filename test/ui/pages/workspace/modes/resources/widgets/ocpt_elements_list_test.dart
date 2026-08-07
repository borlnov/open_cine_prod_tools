// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_elements_list.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a dock-sized
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

/// An element with only the fields a row of the list reads.
OcptElement _element({
  required String id,
  required String name,
  OcptElementCategory category = OcptElementCategory.prop,
  String subCategory = "",
  String code = "",
  String quantity = "",
  OcptElementSourceKind sourceKind = OcptElementSourceKind.owned,
  bool isSecured = false,
  bool isReadyForShoot = false,
  bool isReturned = false,
}) => OcptElement(
      status: OcptElementStatus.toFind,
  id: id,
  category: category,
  subCategory: subCategory,
  name: name,
  code: code,
  quantity: quantity,
  sourceKind: sourceKind,
  ownerPersonId: null,
  ownerNotes: "",
  broughtByPersonId: null,
  storageNotes: "",
  isSecured: isSecured,
  isReadyForShoot: isReadyForShoot,
  isReturned: isReturned,
  cost: null,
  purposeNotes: "",
  notes: "",
  photoAssetId: null,
  photo: null,
  sceneLinks: const [],
  roleLinks: const [],
);

void main() {
  /// Pumps the list over [elements].
  Future<Tr> pumpList(
    WidgetTester tester,
    List<OcptElement> elements, {
    String? selectedElementId,
    String searchQuery = "",
    ValueChanged<String>? onElementSelected,
  }) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptElementsList(
          elements: elements,
          selectedElementId: selectedElementId,
          searchQuery: searchQuery,
          onElementSelected: onElementSelected ?? (elementId) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptElementsList)));
  }

  testWidgets("an empty catalogue reads as an invitation rather than as a blank panel", (
    tester,
  ) async {
    final tr = await pumpList(tester, const []);

    expect(find.text(tr.resourcesElementsEmptyHint), findsOneWidget);
  });

  testWidgets("the rows are grouped under a heading per category, empty ones left out", (
    tester,
  ) async {
    final tr = await pumpList(tester, [
      _element(id: "e1", name: "Vélo de Léa", category: OcptElementCategory.vehicle),
      _element(id: "e2", name: "Valise"),
      _element(id: "e3", name: "Lampe torche"),
    ]);

    expect(find.text(tr.resourcesElementCategoryProp.toUpperCase()), findsOneWidget);
    expect(find.text(tr.resourcesElementCategoryVehicle.toUpperCase()), findsOneWidget);
    // A heading over nothing would claim a department the production doesn't have.
    expect(find.text(tr.resourcesElementCategoryCostume.toUpperCase()), findsNothing);

    // The enum's own order decides the headings' order, whatever order the catalogue is stored in.
    final propHeading = tester.getTopLeft(find.text(tr.resourcesElementCategoryProp.toUpperCase()));
    final vehicleHeading = tester.getTopLeft(
      find.text(tr.resourcesElementCategoryVehicle.toUpperCase()),
    );
    expect(propHeading.dy, lessThan(vehicleHeading.dy));
  });

  testWidgets("a row says how many are needed and where the element comes from", (tester) async {
    final tr = await pumpList(tester, [
      _element(
        id: "e1",
        name: "Verres",
        subCategory: "Vaisselle",
        quantity: "×6",
        sourceKind: OcptElementSourceKind.borrowed,
      ),
    ]);

    expect(
      find.text("Vaisselle · ×6 · ${tr.resourcesElementSourceBorrowed}"),
      findsOneWidget,
    );
  });

  testWidgets("the tracking column reads the last flag ticked, not the first", (tester) async {
    final tr = await pumpList(tester, [
      _element(id: "e1", name: "À trouver"),
      _element(id: "e2", name: "Trouvé", isSecured: true),
      _element(id: "e3", name: "Prêt", isSecured: true, isReadyForShoot: true),
      _element(
        id: "e4",
        name: "Rendu",
        isSecured: true,
        isReadyForShoot: true,
        isReturned: true,
      ),
    ]);

    expect(find.text(tr.resourcesElementTrackingToSecure), findsOneWidget);
    expect(find.text(tr.resourcesElementTrackingSecured), findsOneWidget);
    expect(find.text(tr.resourcesElementTrackingReady), findsOneWidget);
    expect(find.text(tr.resourcesElementTrackingReturned), findsOneWidget);
  });

  testWidgets("an element with no name yet still has a row to click", (tester) async {
    String? selectedElementId;
    final tr = await pumpList(
      tester,
      [_element(id: "e1", name: "")],
      onElementSelected: (elementId) => selectedElementId = elementId,
    );

    expect(find.text(tr.resourcesElementUnnamed), findsOneWidget);

    await tester.tap(find.text(tr.resourcesElementUnnamed));
    await tester.pumpAndSettle();

    expect(selectedElementId, "e1");
  });

  testWidgets("a query finds an element by its code", (tester) async {
    await pumpList(
      tester,
      [
        _element(id: "e1", name: "Verres", code: "PR-01"),
        _element(id: "e2", name: "Lampe torche", code: "PR-02"),
      ],
      searchQuery: "pr-01",
    );

    expect(find.text("Verres"), findsOneWidget);
    expect(find.text("Lampe torche"), findsNothing);
  });

  testWidgets("a query finds an element by its localized category, dropping the other heading", (
    tester,
  ) async {
    final tr = await pumpList(
      tester,
      [
        _element(id: "e1", name: "Vélo de Léa", category: OcptElementCategory.vehicle),
        _element(id: "e2", name: "Valise"),
      ],
      searchQuery: "vehicle",
    );

    expect(find.text("Vélo de Léa"), findsOneWidget);
    expect(find.text("Valise"), findsNothing);
    expect(find.text(tr.resourcesElementCategoryVehicle.toUpperCase()), findsOneWidget);
    // The prop category held nothing once filtered: its heading drops along with its rows.
    expect(find.text(tr.resourcesElementCategoryProp.toUpperCase()), findsNothing);
  });

  testWidgets("a query finds an element by its localized tracking status", (tester) async {
    // "Secured" (`resourcesElementTrackingSecured`) in the `en_GB` locale these tests run under.
    await pumpList(
      tester,
      [
        _element(id: "e1", name: "Verres", isSecured: true),
        _element(id: "e2", name: "Lampe torche"),
      ],
      searchQuery: "secured",
    );

    expect(find.text("Verres"), findsOneWidget);
    expect(find.text("Lampe torche"), findsNothing);
  });

  testWidgets("a query matching nothing shows the no-match line, not the empty hint", (
    tester,
  ) async {
    final tr = await pumpList(tester, [_element(id: "e1", name: "Verres")], searchQuery: "zzz");

    expect(find.text(tr.resourcesSearchNoMatchHint("zzz")), findsOneWidget);
    expect(find.text(tr.resourcesElementsEmptyHint), findsNothing);
  });
}
