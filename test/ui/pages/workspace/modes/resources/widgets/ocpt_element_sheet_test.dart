// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_tracking_flag.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_element_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_element_sheet_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a centre-sized
/// box.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 900, height: 900, child: child)),
);

/// A person carrying only what the sheet's two pickers read.
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
      sizeTop: "",
      sizeBottom: "",
      sizeShoes: "",
      measurementHeight: "",
      measurementChest: "",
      measurementWaist: "",
      measurementHips: "",
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

/// The element the sheet is pumped over.
OcptElement _element({
  String name = "Vélo de Léa",
  String code = "ACC-3",
  int? cost,
  String? ownerPersonId,
  String? broughtByPersonId,
  bool isSecured = false,
  List<OcptSceneElementLink> sceneLinks = const [],
}) => OcptElement(
  id: "e1",
  category: OcptElementCategory.prop,
  subCategory: "",
  name: name,
  code: code,
  quantity: "",
  sourceKind: OcptElementSourceKind.owned,
  ownerPersonId: ownerPersonId,
  ownerNotes: "",
  broughtByPersonId: broughtByPersonId,
  storageNotes: "",
  isSecured: isSecured,
  isReadyForShoot: false,
  isReturned: false,
  cost: cost,
  purposeNotes: "",
  notes: "",
  photoAssetId: null,
  sceneLinks: sceneLinks,
);

/// A scene the links and the picker name.
OcptSceneRef _scene({required String id, required int position, required String heading}) =>
    OcptSceneRef(id: id, position: position, heading: heading, sceneNumber: null);

void main() {
  /// Pumps the sheet over [element], returning the [Tr] its own context resolves.
  Future<Tr> pumpSheet(
    WidgetTester tester, {
    OcptElement? element,
    List<OcptPerson> people = const [],
    List<OcptSceneRef> scenes = const [],
    String currencyCode = "EUR",
    bool isReadOnly = false,
    String Function(OcptElementField field)? fieldValueOf,
    void Function(OcptElementField field, String rawValue)? onFieldChanged,
    void Function(OcptElementTrackingFlag flag, {required bool value})? onTrackingFlagChanged,
    ValueChanged<String?>? onOwnerChanged,
    ValueChanged<String>? onSceneAssigned,
    void Function(String id, {required String quantity, required String notes})? onLinkUpdated,
    ValueChanged<String>? onLinkRemoved,
    VoidCallback? onDeleteRequested,
  }) async {
    final shown = element ?? _element();

    await tester.pumpWidget(
      _wrapInApp(
        OcptElementSheet(
          element: shown,
          owner: _personOf(people, shown.ownerPersonId),
          bringer: _personOf(people, shown.broughtByPersonId),
          people: people,
          scenes: scenes,
          currencyCode: currencyCode,
          isReadOnly: isReadOnly,
          fieldValueOf: fieldValueOf ?? (field) => "",
          onFieldChanged: onFieldChanged ?? (field, rawValue) {},
          onCategoryChanged: (category) {},
          onSourceKindChanged: (sourceKind) {},
          onOwnerChanged: onOwnerChanged ?? (personId) {},
          onBringerChanged: (personId) {},
          onTrackingFlagChanged: onTrackingFlagChanged ?? (flag, {required value}) {},
          onSceneAssigned: onSceneAssigned ?? (sceneId) {},
          onLinkUpdated: onLinkUpdated ?? (id, {required quantity, required notes}) {},
          onLinkRemoved: onLinkRemoved ?? (id) {},
          onDeleteRequested: onDeleteRequested ?? () {},
          onPersonSheetOpenRequested: (personId) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptElementSheet)));
  }

  testWidgets("the header reads how far along the element is", (tester) async {
    final tr = await pumpSheet(tester, element: _element(isSecured: true));

    // Scoped to the header: the tracking card's own checkbox happens to carry the same word, which
    // is exactly what makes the badge readable without looking at the boxes.
    expect(
      find.descendant(
        of: find.byType(OcptElementSheetHeader),
        matching: find.text(tr.resourcesElementTrackingSecured),
      ),
      findsOneWidget,
    );
  });

  testWidgets("ticking a tracking box reports the flag and its new value", (tester) async {
    OcptElementTrackingFlag? tickedFlag;
    bool? tickedValue;

    final tr = await pumpSheet(
      tester,
      onTrackingFlagChanged: (flag, {required value}) {
        tickedFlag = flag;
        tickedValue = value;
      },
    );

    await tester.tap(find.text(tr.resourcesElementReadyLabel));
    await tester.pumpAndSettle();

    expect(tickedFlag, OcptElementTrackingFlag.readyForShoot);
    expect(tickedValue, isTrue);
  });

  testWidgets("the owner is picked out of the address book", (tester) async {
    String? pickedOwnerId;

    final tr = await pumpSheet(
      tester,
      people: [_person(id: "p1", firstName: "Sofia", lastName: "Berger")],
      onOwnerChanged: (personId) => pickedOwnerId = personId,
    );

    await tester.tap(find.text(tr.resourcesElementNoOwner).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text("Sofia Berger").last);
    await tester.pumpAndSettle();

    expect(pickedOwnerId, "p1");
  });

  testWidgets("a cost that isn't an amount is flagged once the field loses the focus", (
    tester,
  ) async {
    final tr = await pumpSheet(
      tester,
      fieldValueOf: (field) => field == OcptElementField.cost ? "gratuit" : "",
    );

    // Flagged, never refused: the sheet writes as it is typed, so the remark only appears once the
    // field is left alone.
    expect(find.text(tr.resourcesElementCostFormatError), findsOneWidget);
  });

  testWidgets(
    "the cost field shows the project's currency symbol as a suffix, never as part of the text "
    "being edited",
    (tester) async {
      final tr = await pumpSheet(
        tester,
        currencyCode: "USD",
        fieldValueOf: (field) => field == OcptElementField.cost ? "42.00" : "",
      );

      final costField = find.byWidgetPredicate(
        (widget) => widget is OcptResourcesSheetField && widget.label == tr.resourcesElementCostLabel,
      );
      final textField = tester.widget<TextField>(
        find.descendant(of: costField, matching: find.byType(TextField)),
      );

      expect(textField.decoration?.suffixText, r"$");
      expect(textField.controller?.text, "42.00");
    },
  );

  testWidgets("a scene link shows its own quantity and note, and can be unlinked", (tester) async {
    String? removedLinkId;

    final tr = await pumpSheet(
      tester,
      element: _element(
        sceneLinks: const [
          OcptSceneElementLink(id: "link-1", sceneId: "s1", quantity: "×2", notes: "Dont un cassé"),
        ],
      ),
      scenes: [_scene(id: "s1", position: 0, heading: "INT. CUISINE - NUIT")],
      onLinkRemoved: (id) => removedLinkId = id,
    );

    expect(find.text("1 · CUISINE"), findsOneWidget);
    expect(find.text("×2"), findsOneWidget);
    expect(find.text("Dont un cassé"), findsOneWidget);

    await tester.ensureVisible(find.byTooltip(tr.resourcesRemoveSceneFromElementTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(tr.resourcesRemoveSceneFromElementTooltip));
    await tester.pumpAndSettle();

    expect(removedLinkId, "link-1");
  });

  testWidgets("the picker only offers the scenes the element isn't needed in yet", (tester) async {
    String? assignedSceneId;

    final tr = await pumpSheet(
      tester,
      element: _element(
        sceneLinks: const [
          OcptSceneElementLink(id: "link-1", sceneId: "s1", quantity: "", notes: ""),
        ],
      ),
      scenes: [
        _scene(id: "s1", position: 0, heading: "INT. CUISINE - NUIT"),
        _scene(id: "s2", position: 1, heading: "EXT. RUE DE LA GARE - JOUR"),
      ],
      onSceneAssigned: (sceneId) => assignedSceneId = sceneId,
    );

    // The sheet is taller than any test viewport: the picker has to be scrolled to before it can be
    // aimed at.
    await tester.ensureVisible(find.text(tr.resourcesAddSceneToElementAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesAddSceneToElementAction));
    await tester.pumpAndSettle();

    // The scene already linked is not offered a second time; the link's own row is what shows it.
    expect(find.text("1 · CUISINE"), findsOneWidget);
    expect(find.text("2 · RUE DE LA GARE"), findsOneWidget);

    await tester.tap(find.text("2 · RUE DE LA GARE"));
    await tester.pumpAndSettle();

    expect(assignedSceneId, "s2");
  });

  testWidgets("a read-only sheet withholds every control and keeps the reading", (tester) async {
    final tr = await pumpSheet(
      tester,
      element: _element(
        sceneLinks: const [
          OcptSceneElementLink(id: "link-1", sceneId: "s1", quantity: "×2", notes: ""),
        ],
      ),
      people: [_person(id: "p1", firstName: "Sofia", lastName: "Berger")],
      scenes: [_scene(id: "s1", position: 0, heading: "INT. CUISINE - NUIT")],
      isReadOnly: true,
      fieldValueOf: (field) => field == OcptElementField.name ? "Vélo de Léa" : "",
    );

    // Withheld, not disabled.
    expect(find.text(tr.resourcesAddSceneToElementAction), findsNothing);
    expect(find.byTooltip(tr.resourcesRemoveSceneFromElementTooltip), findsNothing);
    expect(find.text(tr.resourcesDeleteElementAction), findsNothing);

    // What only reads stays.
    expect(find.text("Vélo de Léa"), findsOneWidget);
    expect(find.text("1 · CUISINE"), findsOneWidget);
    expect(find.text("×2"), findsOneWidget);
  });

  testWidgets("deleting asks inline before it reports anything", (tester) async {
    var deleteCount = 0;

    final tr = await pumpSheet(tester, onDeleteRequested: () => deleteCount++);

    await tester.ensureVisible(find.text(tr.resourcesDeleteElementAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesDeleteElementAction));
    await tester.pumpAndSettle();

    expect(deleteCount, 0);
    expect(find.text(tr.resourcesDeleteElementConfirm), findsOneWidget);
  });
}

/// The person [personId] names among [people], or null when it names nobody.
OcptPerson? _personOf(List<OcptPerson> people, String? personId) {
  if (personId == null) {
    return null;
  }

  for (final person in people) {
    if (person.id == personId) {
      return person;
    }
  }

  return null;
}
