// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_dated_window_controls.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_location_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_color_swatches.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

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
  maxDailyPresenceMinutes: null,
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
  imageRightsDocument: null,
  photoAssetId: null,
  photo: null,
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
  List<OcptAssetRef> photos = const [],
  OcptAssetRef? permitDocument,
  List<OcptLocationAvailability> availabilities = const [],
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
  photos: photos,
  permitDocument: permitDocument,
  availabilities: availabilities,
);

/// Builds an [OcptAssetRef] pointing at [path] — a path these tests deliberately never create, so
/// the widgets under test show their own "file not found" state.
OcptAssetRef _asset({
  String id = "a1",
  OcptAssetKind kind = OcptAssetKind.locationPhoto,
  String path = "/nowhere/repérage.jpg",
  DateTime? validFrom,
  DateTime? validUntil,
}) => OcptAssetRef(
  id: id,
  kind: kind,
  path: path,
  label: "",
  addedAt: DateTime(2026, 8, 3),
  personId: null,
  locationId: "l1",
  elementId: null,
  validFrom: validFrom,
  validUntil: validUntil,
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

/// An availability window of location `l1`, whole days, free of any condition.
OcptLocationAvailability _availability({
  String id = "a1",
  int weekdays = ocptEveryWeekdayMask,
  OcptDayPartSlot slot = OcptDayPartSlot.fullDay,
  OcptLocationAvailabilityKind kind = OcptLocationAvailabilityKind.available,
  String note = "",
}) => OcptLocationAvailability(
  id: id,
  locationId: "l1",
  startDate: DateTime(2026, 3, 2),
  endDate: DateTime(2026, 3, 20),
  weekdays: weekdays,
  slot: slot,
  startMinute: null,
  endMinute: null,
  kind: kind,
  note: note,
);

void main() {
  /// The values the pumped sheet answers `fieldValueOf` with, and the edits it records.
  late Map<OcptLocationField, String> fieldValues;
  late List<(OcptLocationField, String)> fieldEdits;

  /// The availability updates the pumped sheet reports: the window's id, its weekday mask and its
  /// kind — the three the tests below actually assert on.
  late List<(String, int, OcptLocationAvailabilityKind)> availabilityEdits;

  setUp(() {
    fieldValues = {};
    fieldEdits = [];
    availabilityEdits = [];
  });

  /// Pumps [location]'s sheet, wide enough for its two- and three-card rows to lay out.
  Future<void> pumpSheet(
    WidgetTester tester, {
    OcptLocation? location,
    OcptPerson? contact,
    List<OcptPerson> people = const [],
    List<OcptSceneRef> scenes = const [],
    List<(String, String)> otherLocations = const [],
    Set<String> assignedSceneIds = const {},
    Map<String, String> suggestedSetIdBySceneId = const {},
    bool isReadOnly = false,
    void Function(String setId, String locationId)? onSetLocationChanged,
    void Function(String sceneId, String setId)? onSceneAssigned,
    void Function(String sceneId, String setId)? onSceneRemoved,
    VoidCallback? onSetAdded,
    VoidCallback? onPhotoAddRequested,
    ValueChanged<String>? onPhotoRemoved,
    VoidCallback? onPermitDocumentPickRequested,
    ValueChanged<DateTime?>? onPermitDocumentValidFromChanged,
    ValueChanged<DateTime?>? onPermitDocumentValidUntilChanged,
    ValueChanged<int>? onColorChanged,
    ValueChanged<OcptPermitStatus>? onPermitStatusChanged,
    ValueChanged<String?>? onContactChanged,
    ValueChanged<String>? onPersonSheetOpenRequested,
    ValueChanged<String>? onAvailabilityRemoved,
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
              otherLocations: otherLocations,
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
                OcptSetField.name => "Cuisine",
                OcptSetField.notes => "",
              },
              onSetFieldChanged: (setId, field, rawValue) {},
              onSetAdded: onSetAdded ?? () {},
              onSetRemoved: (setId) {},
              onSetLocationChanged: onSetLocationChanged ?? (setId, locationId) {},
              onSceneAssigned: onSceneAssigned ?? (sceneId, setId) {},
              onSceneRemoved: onSceneRemoved ?? (sceneId, setId) {},
              onPhotoAddRequested: onPhotoAddRequested ?? () {},
              onPhotoRemoved: onPhotoRemoved ?? (assetId) {},
              onPermitDocumentPickRequested: onPermitDocumentPickRequested ?? () {},
              onPermitDocumentCleared: () {},
              onPermitDocumentValidFromChanged: onPermitDocumentValidFromChanged ?? (date) {},
              onPermitDocumentValidUntilChanged: onPermitDocumentValidUntilChanged ?? (date) {},
              onAvailabilityUpdated:
                  (
                    id, {
                    required startDate,
                    required endDate,
                    required weekdays,
                    required slot,
                    required startMinute,
                    required endMinute,
                    required kind,
                    required note,
                  }) => availabilityEdits.add((id, weekdays, kind)),
              onAvailabilityAdded:
                  ({
                    required startDate,
                    required endDate,
                    required weekdays,
                    required slot,
                    required startMinute,
                    required endMinute,
                  }) {},
              onAvailabilityRemoved: onAvailabilityRemoved ?? (id) {},
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

  testWidgets("the colour bar opens the palette and reports the swatch picked", (tester) async {
    final colorPicks = <int>[];

    await pumpSheet(tester, onColorChanged: colorPicks.add);
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    await tester.tap(find.byTooltip(tr.resourcesChangeColorTooltip));
    await tester.pumpAndSettle();

    // The popover used to throw on layout before showing a single swatch.
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(OcptResourcesColorSwatches),
        matching: find.byType(InkWell),
      ).at(2),
    );
    await tester.pumpAndSettle();

    expect(colorPicks, [2]);
  });

  testWidgets("clicking Delete this location reports it", (tester) async {
    var deleteCount = 0;

    await pumpSheet(tester, onDeleteRequested: () => deleteCount++);
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    // The sheet is taller than any test viewport: the action has to be scrolled to before it can
    // be aimed at.
    await tester.ensureVisible(find.text(tr.resourcesLocationDeleteAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesLocationDeleteAction));
    await tester.pumpAndSettle();

    // The sheet only asks: the question itself is the mode's confirmation dialog.
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

  testWidgets("a scene already shot in another set is still offered", (tester) async {
    String? assignedSceneId;

    await pumpSheet(
      tester,
      location: _location(sets: [_set()]),
      scenes: [_scene()],
      assignedSceneIds: const {"sc1"},
      onSceneAssigned: (sceneId, setId) => assignedSceneId = sceneId,
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    await tester.ensureVisible(find.text(tr.resourcesAddSceneToSetAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesAddSceneToSetAction));
    await tester.pumpAndSettle();

    // A scene is regularly covered in two sets, so the picker says where it already is rather than
    // hiding it — and picking it adds this set beside the one it has.
    expect(find.text(tr.resourcesScenesInAnotherSetLabel), findsOneWidget);

    await tester.tap(find.text("1 · CUISINE"));
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

  testWidgets("a location with no availability window says so", (tester) async {
    await pumpSheet(tester);
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    // "Nothing is known yet" rather than "never free": an empty card is an unanswered question.
    expect(find.text(tr.resourcesLocationAvailabilitiesEmptyHint), findsOneWidget);
    expect(find.text(tr.resourcesAddLocationAvailabilityAction), findsOneWidget);
  });

  testWidgets("a window's weekday, once unticked, is reported", (tester) async {
    await pumpSheet(tester, location: _location(availabilities: [_availability()]));
    final context = tester.element(find.byType(OcptLocationSheet));
    // Wednesday, whose narrow name no other day shares in this locale — two days sharing a letter
    // (Saturday and Sunday in English) would be two matches for one finder.
    final wednesday = MaterialLocalizations.of(context).narrowWeekdays[DateTime.wednesday % 7];

    await tester.ensureVisible(find.text(wednesday));
    await tester.pumpAndSettle();
    await tester.tap(find.text(wednesday));
    await tester.pumpAndSettle();

    expect(availabilityEdits, hasLength(1));
    final (id, weekdays, _) = availabilityEdits.single;
    expect(id, "a1");
    expect(ocptWeekdayMaskContains(weekdays, DateTime.wednesday), isFalse);
    expect(ocptWeekdayMaskContains(weekdays, DateTime.monday), isTrue);
  });

  testWidgets("unticking the last weekday of a window changes nothing", (tester) async {
    await pumpSheet(
      tester,
      location: _location(
        availabilities: [
          _availability(weekdays: 1 << (DateTime.wednesday - 1)),
        ],
      ),
    );
    final context = tester.element(find.byType(OcptLocationSheet));
    final wednesday = MaterialLocalizations.of(context).narrowWeekdays[DateTime.wednesday % 7];

    await tester.ensureVisible(find.text(wednesday));
    await tester.pumpAndSettle();
    await tester.tap(find.text(wednesday));
    await tester.pumpAndSettle();

    // A window covering no day at all would say nothing: the way to drop it is the remove control.
    expect(availabilityEdits, isEmpty);
  });

  testWidgets("a window is made conditional from its own pills", (tester) async {
    await pumpSheet(tester, location: _location(availabilities: [_availability()]));
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    await tester.ensureVisible(find.text(tr.resourcesAvailabilityKindConditional));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesAvailabilityKindConditional));
    await tester.pumpAndSettle();

    expect(availabilityEdits.single.$3, OcptLocationAvailabilityKind.conditional);
  });

  testWidgets("a custom slot shows its time window, a whole day doesn't", (tester) async {
    await pumpSheet(
      tester,
      location: _location(
        availabilities: [_availability(), _availability(id: "a2", slot: OcptDayPartSlot.custom)],
      ),
    );

    expect(find.byType(OcptTimeWindowControl), findsOneWidget);
  });

  testWidgets("a window is removed from its own control", (tester) async {
    String? removedId;
    await pumpSheet(
      tester,
      location: _location(availabilities: [_availability()]),
      onAvailabilityRemoved: (id) => removedId = id,
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    final removeButton = find.byTooltip(tr.resourcesRemoveLocationAvailabilityTooltip);
    await tester.ensureVisible(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(removedId, "a1");
  });

  testWidgets("the availability card withholds every control when read-only", (tester) async {
    await pumpSheet(
      tester,
      location: _location(
        availabilities: [_availability(note: "No noise after 22:00")],
      ),
      isReadOnly: true,
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    expect(find.text(tr.resourcesAddLocationAvailabilityAction), findsNothing);
    expect(find.byTooltip(tr.resourcesRemoveLocationAvailabilityTooltip), findsNothing);
    // What only reads stays: the window is still there to be read.
    expect(find.text(tr.resourcesAvailabilityKindAvailable), findsOneWidget);
  });

  testWidgets("a photo whose file is gone keeps its reference and says so", (tester) async {
    String? removedAssetId;

    await pumpSheet(
      tester,
      location: _location(photos: [_asset()]),
      onPhotoRemoved: (assetId) => removedAssetId = assetId,
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));
    await tester.pumpAndSettle();

    expect(find.text(tr.resourcesAssetFileMissing), findsOneWidget);
    expect(find.text(tr.resourcesLocationPhotosCount(1)), findsOneWidget);

    await tester.ensureVisible(find.byTooltip(tr.resourcesRemovePhotoTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(tr.resourcesRemovePhotoTooltip));
    await tester.pumpAndSettle();

    expect(removedAssetId, "a1");
  });

  testWidgets("referencing a photo is asked for through the picker", (tester) async {
    var addCount = 0;

    await pumpSheet(tester, onPhotoAddRequested: () => addCount++);
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    await tester.ensureVisible(find.text(tr.resourcesAddPhotoAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesAddPhotoAction));
    await tester.pumpAndSettle();

    expect(addCount, 1);
  });

  testWidgets("a referenced permit document reads by its file name", (tester) async {
    await pumpSheet(
      tester,
      location: _location(
        permitDocument: _asset(
          id: "d1",
          kind: OcptAssetKind.document,
          path: "/nowhere/autorisation.pdf",
        ),
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    expect(find.text("autorisation.pdf"), findsOneWidget);
    // The file is not there: the reference is kept and the line says so.
    expect(find.text(tr.resourcesAssetFileMissing), findsOneWidget);
    expect(find.text(tr.resourcesReplaceDocumentAction), findsOneWidget);
  });

  testWidgets("a location with no document offers to reference one", (tester) async {
    var pickCount = 0;

    await pumpSheet(tester, onPermitDocumentPickRequested: () => pickCount++);
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    await tester.tap(find.text(tr.resourcesReferenceDocumentAction));
    await tester.pumpAndSettle();

    expect(pickCount, 1);
  });

  testWidgets("the document's validity dates are absent with no document referenced", (
    tester,
  ) async {
    await pumpSheet(tester);
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    expect(find.text(tr.resourcesLocationPermitValidFromLabel.toUpperCase()), findsNothing);
    expect(find.text(tr.resourcesLocationPermitValidUntilLabel.toUpperCase()), findsNothing);
    expect(find.text(tr.resourcesLocationPermitValidityHint), findsNothing);
  });

  testWidgets("the document's validity dates show once one is referenced", (tester) async {
    await pumpSheet(
      tester,
      location: _location(
        permitDocument: _asset(
          id: "d1",
          kind: OcptAssetKind.document,
          path: "/nowhere/autorisation.pdf",
          validFrom: DateTime(2026, 3, 5),
          validUntil: DateTime(2026, 9, 30),
        ),
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    expect(find.text(tr.resourcesLocationPermitValidFromLabel.toUpperCase()), findsOneWidget);
    expect(find.text(tr.resourcesLocationPermitValidUntilLabel.toUpperCase()), findsOneWidget);
    expect(find.text(tr.resourcesLocationPermitValidityHint), findsOneWidget);
  });

  testWidgets("picking the document's valid-from date reports it", (tester) async {
    DateTime? picked;

    await pumpSheet(
      tester,
      location: _location(
        permitDocument: _asset(id: "d1", kind: OcptAssetKind.document, path: "/nowhere/a.pdf"),
      ),
      onPermitDocumentValidFromChanged: (date) => picked = date,
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    final validFromField = find.ancestor(
      of: find.text(tr.resourcesLocationPermitValidFromLabel.toUpperCase()),
      matching: find.byType(OcptPersonSheetDateField),
    );
    await tester.tap(
      find.descendant(of: validFromField, matching: find.byIcon(Icons.calendar_today_outlined)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("OK"));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
  });

  testWidgets("clearing the document's valid-until date reports null", (tester) async {
    DateTime? picked = DateTime(2099);

    await pumpSheet(
      tester,
      location: _location(
        permitDocument: _asset(
          id: "d1",
          kind: OcptAssetKind.document,
          path: "/nowhere/a.pdf",
          validUntil: DateTime(2026, 9, 30),
        ),
      ),
      onPermitDocumentValidUntilChanged: (date) => picked = date,
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));

    final validUntilField = find.ancestor(
      of: find.text(tr.resourcesLocationPermitValidUntilLabel.toUpperCase()),
      matching: find.byType(OcptPersonSheetDateField),
    );
    await tester.tap(find.descendant(of: validUntilField, matching: find.byIcon(Icons.clear)));
    await tester.pump();

    expect(picked, isNull);
  });

  testWidgets("the referenced files offer nothing to change when read-only", (tester) async {
    await pumpSheet(
      tester,
      location: _location(
        photos: [_asset()],
        permitDocument: _asset(
          id: "d1",
          kind: OcptAssetKind.document,
          path: "/nowhere/a.pdf",
          validFrom: DateTime(2026, 3, 5),
        ),
      ),
      isReadOnly: true,
    );
    final tr = Tr.of(tester.element(find.byType(OcptLocationSheet)));
    await tester.pumpAndSettle();

    expect(find.text(tr.resourcesAddPhotoAction), findsNothing);
    expect(find.text(tr.resourcesReferenceDocumentAction), findsNothing);
    expect(find.text(tr.resourcesReplaceDocumentAction), findsNothing);
    expect(find.byTooltip(tr.resourcesRemovePhotoTooltip), findsNothing);
    expect(find.byTooltip(tr.resourcesRemoveDocumentTooltip), findsNothing);
    // The permit's own validity dates read out with no picker at all.
    expect(find.text(tr.resourcesLocationPermitValidFromLabel.toUpperCase()), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
    expect(find.byIcon(Icons.clear), findsNothing);
    // What only reads stays: the reference itself is still named.
    expect(find.text("a.pdf"), findsOneWidget);
  });

  testWidgets("a set is handed to another location through its own move control", (tester) async {
    (String, String)? moved;

    await pumpSheet(
      tester,
      location: _location(sets: [_set()]),
      otherLocations: const [("l2", "Le hangar")],
      onSetLocationChanged: (setId, locationId) => moved = (setId, locationId),
    );

    final tr = await Tr.delegate.load(const Locale("en", "GB"));
    await tester.tap(find.byTooltip(tr.resourcesMoveSetTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Le hangar"));
    await tester.pumpAndSettle();

    expect(moved, ("s1", "l2"));
  });

  testWidgets("the move control is dropped while the project has nowhere to move to",
      (tester) async {
    await pumpSheet(tester, location: _location(sets: [_set()]));

    final tr = await Tr.delegate.load(const Locale("en", "GB"));
    expect(find.byTooltip(tr.resourcesMoveSetTooltip), findsNothing);
  });
}
