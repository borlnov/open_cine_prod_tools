// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_location_sheet.dart';

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

/// Builds a minimal [OcptLocation] for these tests.
OcptLocation _location({
  String id = "l1",
  String name = "La maison des Pains",
  String? contactPersonId,
  OcptPermitStatus permitStatus = OcptPermitStatus.toRequest,
  DateTime? permitDate,
  List<OcptSet> sets = const [],
}) => OcptLocation(
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
  contactPersonId: contactPersonId,
  contactNotes: "",
  permitStatus: permitStatus,
  permitLabel: "",
  permitDate: permitDate,
  permitAssetId: null,
  parkingNotes: "",
  powerNotes: "",
  facilitiesNotes: "",
  constraintsNotes: "",
  notes: "",
  sets: sets,
  photos: const [],
  permitDocument: null,
);

/// Builds a minimal [OcptSet] for these tests.
OcptSet _set({
  String id = "s1",
  String name = "Cuisine",
  List<String> sceneIds = const [],
}) => OcptSet(id: id, locationId: "l1", code: "", name: name, notes: "", sceneIds: sceneIds);

/// Builds a minimal [OcptSceneRef] for these tests.
OcptSceneRef _scene({
  String id = "sc1",
  int position = 0,
  String heading = "INT. CUISINE - JOUR",
}) => OcptSceneRef(id: id, position: position, heading: heading, sceneNumber: null);

void main() {
  /// The values the pumped sheet answers `fieldValueOf` with, and the edits it records.
  late Map<OcptLocationField, String> fieldValues;
  late List<(OcptLocationField, String)> fieldEdits;

  setUp(() {
    fieldValues = {};
    fieldEdits = [];
  });

  /// Pumps [location]'s sheet, wide enough for its two- and three-card rows to lay out.
  Future<void> pumpSheet(
    WidgetTester tester, {
    OcptLocation? location,
    OcptPerson? contact,
    List<OcptPerson> people = const [],
    List<OcptSceneRef> scenes = const [],
    Set<String> assignedSceneIds = const {},
    Map<String, String> suggestedSetIdBySceneId = const {},
    bool isReadOnly = false,
    void Function(String sceneId, String setId)? onSceneAssigned,
    void Function(String sceneId, String setId)? onSceneRemoved,
    VoidCallback? onSetAdded,
    ValueChanged<int>? onColorChanged,
    ValueChanged<OcptPermitStatus>? onPermitStatusChanged,
    ValueChanged<String?>? onContactChanged,
    ValueChanged<String>? onPersonSheetOpenRequested,
    VoidCallback? onDeleteRequested,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          Tr.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: Tr.delegate.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 2400,
            child: OcptLocationSheet(
              location: location ?? _location(),
              contact: contact,
              people: people,
              scenes: scenes,
              assignedSceneIds: assignedSceneIds,
              suggestedSetIdBySceneId: suggestedSetIdBySceneId,
              isReadOnly: isReadOnly,
              fieldValueOf: (field) => fieldValues[field] ?? "",
              onFieldChanged: (field, rawValue) => fieldEdits.add((field, rawValue)),
              onColorChanged: onColorChanged ?? (colorIndex) {},
              onPermitStatusChanged: onPermitStatusChanged ?? (status) {},
              onPermitDateChanged: (date) {},
              onContactChanged: onContactChanged ?? (personId) {},
              onPersonSheetOpenRequested: onPersonSheetOpenRequested ?? (personId) {},
              setFieldValueOf: (setId, field) => switch (field) {
                OcptSetField.code => "",
                OcptSetField.name => "Cuisine",
                OcptSetField.notes => "",
              },
              onSetFieldChanged: (setId, field, rawValue) {},
              onSetAdded: onSetAdded ?? () {},
              onSetRemoved: (setId) {},
              onSceneAssigned: onSceneAssigned ?? (sceneId, setId) {},
              onSceneRemoved: onSceneRemoved ?? (sceneId, setId) {},
              onDeleteRequested: onDeleteRequested ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("the header reads the location's name and its permit status", (tester) async {
    fieldValues[OcptLocationField.name] = "La maison des Pains";

    await pumpSheet(tester, location: _location(permitStatus: OcptPermitStatus.granted));

    expect(find.text("La maison des Pains"), findsOneWidget);
    expect(find.text("Permit granted"), findsOneWidget);
  });

  testWidgets("typing into the name field reports the raw text it now holds", (tester) async {
    await pumpSheet(tester);

    // The header's own field is the sheet's first: it is the title, so it comes before every card.
    await tester.enterText(find.byType(TextField).first, "Le hangar");
    await tester.pump();

    expect(fieldEdits, [(OcptLocationField.name, "Le hangar")]);
  });

  testWidgets("a coordinate that isn't a number is flagged once the field loses the focus", (
    tester,
  ) async {
    fieldValues[OcptLocationField.latitude] = "45,76";

    await pumpSheet(tester);
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    // Nothing is refused: the remark only appears once the field is left, so it never fights a
    // value being typed.
    expect(find.text(tr.resourcesCoordinateFormatError), findsOneWidget);
  });

  testWidgets("picking a status reports it", (tester) async {
    OcptPermitStatus? picked;

    await pumpSheet(tester, onPermitStatusChanged: (status) => picked = status);
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    await tester.tap(find.text(tr.resourcesPermitToRequest));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesPermitGranted).last);
    await tester.pumpAndSettle();

    expect(picked, OcptPermitStatus.granted);
  });

  testWidgets("the contact is picked from the address book and opened from its arrow", (
    tester,
  ) async {
    String? openedPersonId;

    await pumpSheet(
      tester,
      location: _location(contactPersonId: "p1"),
      contact: _person(id: "p1", firstName: "Camille", lastName: "Roy"),
      people: [_person(id: "p1", firstName: "Camille", lastName: "Roy")],
      onPersonSheetOpenRequested: (personId) => openedPersonId = personId,
    );

    expect(find.text("Camille Roy"), findsOneWidget);

    await tester.tap(find.byIcon(Icons.north_east));
    await tester.pumpAndSettle();

    expect(openedPersonId, "p1");
  });

  testWidgets("deleting asks first and reports only once confirmed", (tester) async {
    var deleteCount = 0;

    await pumpSheet(tester, onDeleteRequested: () => deleteCount++);
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    // The sheet is taller than any test viewport: the action has to be scrolled to before it can
    // be aimed at.
    await tester.ensureVisible(find.text(tr.resourcesLocationDeleteAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesLocationDeleteAction));
    await tester.pumpAndSettle();
    expect(deleteCount, 0);
    expect(find.text(tr.resourcesLocationDeleteConfirmMessage), findsOneWidget);

    await tester.ensureVisible(find.text(tr.resourcesDeleteConfirmAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesDeleteConfirmAction));
    await tester.pumpAndSettle();

    expect(deleteCount, 1);
  });

  testWidgets("every write affordance disappears when read-only", (tester) async {
    await pumpSheet(
      tester,
      location: _location(contactPersonId: "p1"),
      contact: _person(id: "p1", firstName: "Camille", lastName: "Roy"),
      people: [_person(id: "p1", firstName: "Camille", lastName: "Roy")],
      isReadOnly: true,
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    // Withheld, not disabled.
    expect(find.text(tr.resourcesLocationDeleteAction), findsNothing);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    // What only reads stays, the jump to the contact's own sheet included.
    expect(find.text("Camille Roy"), findsOneWidget);
    expect(find.byIcon(Icons.north_east), findsOneWidget);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.readOnly, isTrue);
    }
  });

  testWidgets("a set lists the scenes shot in it, and drops one", (tester) async {
    String? removedSceneId;

    await pumpSheet(
      tester,
      location: _location(sets: [_set(sceneIds: const ["sc1"])]),
      scenes: [_scene(), _scene(id: "sc2", position: 1, heading: "EXT. JARDIN - NUIT")],
      assignedSceneIds: const {"sc1"},
      onSceneRemoved: (sceneId, setId) => removedSceneId = sceneId,
    );

    expect(find.text("1 · CUISINE"), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pumpAndSettle();

    expect(removedSceneId, "sc1");
  });

  testWidgets("the scene picker marks the suggested scene and reports the pick", (tester) async {
    String? assignedSceneId;

    await pumpSheet(
      tester,
      location: _location(sets: [_set()]),
      scenes: [_scene(), _scene(id: "sc2", position: 1, heading: "EXT. JARDIN - NUIT")],
      suggestedSetIdBySceneId: const {"sc1": "s1"},
      onSceneAssigned: (sceneId, setId) => assignedSceneId = sceneId,
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    await tester.ensureVisible(find.text(tr.resourcesAddSceneToSetAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesAddSceneToSetAction));
    await tester.pumpAndSettle();

    // The suggestion is offered, and offered first: it is never applied on its own.
    expect(find.text(tr.resourcesSceneSuggestedOption("1 · CUISINE")), findsOneWidget);

    await tester.tap(find.text(tr.resourcesSceneSuggestedOption("1 · CUISINE")));
    await tester.pumpAndSettle();

    expect(assignedSceneId, "sc1");
  });

  testWidgets("the sets card withholds every control when read-only", (tester) async {
    await pumpSheet(
      tester,
      location: _location(sets: [_set(sceneIds: const ["sc1"])]),
      scenes: [_scene()],
      assignedSceneIds: const {"sc1"},
      isReadOnly: true,
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    expect(find.text(tr.resourcesAddSetAction), findsNothing);
    expect(find.text(tr.resourcesAddSceneToSetAction), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    // What only reads stays.
    expect(find.text("1 · CUISINE"), findsOneWidget);
  });
}
