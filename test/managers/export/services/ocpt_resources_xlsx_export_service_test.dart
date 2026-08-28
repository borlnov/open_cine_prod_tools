// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_resources_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_elements_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_availability_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_locations_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_people_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_roles_xlsx_column.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

/// The seven weekday names an availability window's summary cell is built from, keyed by their
/// `DateTime.monday`…`DateTime.sunday` numbers — the locale's own names in the app, plain English
/// ones here.
const Map<int, String> _weekdayLabels = {
  DateTime.monday: "Mon",
  DateTime.tuesday: "Tue",
  DateTime.wednesday: "Wed",
  DateTime.thursday: "Thu",
  DateTime.friday: "Fri",
  DateTime.saturday: "Sat",
  DateTime.sunday: "Sun",
};

/// The four sheet names every test here exports under, distinct so a mixed-up sheet is caught.
const _peopleSheetName = "People";
const _rolesSheetName = "Roles";
const _locationsSheetName = "Locations";
const _elementsSheetName = "Elements";

/// Builds the labels the tests export with: every header named after the enum value itself and
/// every enum label named after the enum value too, so an assertion can tell any two columns or
/// statuses apart without depending on the app's own translations. Mirrors
/// `ocpt_shot_list_xlsx_export_service_test.dart`'s own `_buildLabels`.
OcptResourcesXlsxLabels _buildLabels({
  Map<String, String> sceneLabels = const {},
}) => OcptResourcesXlsxLabels(
  fileNameSuffix: "resources",
  peopleSheetName: _peopleSheetName,
  rolesSheetName: _rolesSheetName,
  locationsSheetName: _locationsSheetName,
  elementsSheetName: _elementsSheetName,
  peopleColumnHeaders: {for (final column in OcptPeopleXlsxColumn.values) column: column.name},
  rolesColumnHeaders: {for (final column in OcptRolesXlsxColumn.values) column: column.name},
  locationsColumnHeaders: {
    for (final column in OcptLocationsXlsxColumn.values) column: column.name,
  },
  elementsColumnHeaders: {for (final column in OcptElementsXlsxColumn.values) column: column.name},
  crewPositionLabels: const {"director": "Director"},
  roleKindLabels: {for (final kind in OcptRoleKind.values) kind: kind.name},
  imageRightsStatusLabels: {for (final status in OcptImageRightsStatus.values) status: status.name},
  permitStatusLabels: {for (final status in OcptPermitStatus.values) status: status.name},
  elementCategoryLabels: {
    for (final category in OcptElementCategory.values) category: category.name,
  },
  elementSourceKindLabels: {
    for (final sourceKind in OcptElementSourceKind.values) sourceKind: sourceKind.name,
  },
  dayPartSlotLabels: {for (final slot in OcptDayPartSlot.values) slot: slot.name},
  availabilityKindLabels: {for (final kind in OcptLocationAvailabilityKind.values) kind: kind.name},
  elementTrackingToSecureLabel: "To secure",
  elementTrackingSecuredLabel: "Secured",
  elementTrackingReadyLabel: "Ready",
  elementTrackingReturnedLabel: "Returned",
  everyDayLabel: "Every day",
  weekdayLabels: _weekdayLabels,
  sceneLabels: sceneLabels,
);

/// Builds a person, every field left at a neutral/empty value unless the test overrides it.
OcptPerson _buildPerson({
  required String id,
  String firstName = "",
  String lastName = "",
  String email = "",
  String phone = "",
  DateTime? birthDate,
  bool? isTransportAutonomous,
  OcptImageRightsStatus imageRightsStatus = OcptImageRightsStatus.notApplicable,
  DateTime? imageRightsDate,
  List<OcptPersonPosition> positions = const [],
  List<OcptPersonSkill> skills = const [],
  List<OcptPersonUnavailability> unavailabilities = const [],
}) => OcptPerson(
  id: id,
  firstName: firstName,
  lastName: lastName,
  email: email,
  phone: phone,
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  colorIndex: 0,
  birthDate: birthDate,
  minorNotes: "",
  maxDailyPresenceMinutes: null,
  isTransportAutonomous: isTransportAutonomous,
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
  imageRightsStatus: imageRightsStatus,
  imageRightsDate: imageRightsDate,
  imageRightsAssetId: null,
  imageRightsDocument: null,
  photoAssetId: null,
  photo: null,
  notes: "",
  commuteKmMilli: null,
  mileageRateId: null,
  positions: positions,
  skills: skills,
  unavailabilities: unavailabilities,
);

/// Builds a role, every field left at a neutral value unless the test overrides it.
OcptRole _buildRole({
  required String id,
  required int number,
  String name = "",
  String? personId,
  OcptRoleKind kind = OcptRoleKind.speaking,
  bool isFromScreenplay = true,
  String? orphanedName,
  String castingNotes = "",
}) => OcptRole(
  id: id,
  name: name,
  personId: personId,
  kind: kind,
  isFromScreenplay: isFromScreenplay,
  orphanedName: orphanedName,
  castingNotes: castingNotes,
  number: number,
  episodeIds: const [],
);

/// Builds a set holding [sceneIds], every other field left at a neutral value unless overridden.
OcptSet _buildSet({
  required String id,
  required String locationId,
  String code = "",
  String name = "",
  List<String> sceneIds = const [],
}) =>
    OcptSet(id: id, locationId: locationId, code: code, name: name, notes: "", sceneIds: sceneIds);

/// Builds a location holding [sets], every other field left at a neutral value unless overridden.
OcptLocation _buildLocation({
  required String id,
  String name = "",
  String? contactPersonId,
  OcptPermitStatus permitStatus = OcptPermitStatus.notNeeded,
  List<OcptSet> sets = const [],
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
  permitDate: null,
  permitAssetId: null,
  parkingNotes: "",
  powerNotes: "",
  facilitiesNotes: "",
  constraintsNotes: "",
  notes: "",
  sets: sets,
  photos: const [],
  permitDocument: null,
  availabilities: availabilities,
);

/// The weekday mask covering exactly [weekdays].
int _maskOf(List<int> weekdays) =>
    weekdays.fold(0, (mask, weekday) => mask | (1 << (weekday - 1)));

/// Builds an availability window of [locationId], covering [weekdays] of the days from
/// [startDate] to [endDate].
OcptLocationAvailability _buildAvailability({
  required String id,
  required String locationId,
  required DateTime startDate,
  required DateTime endDate,
  required int weekdays,
  OcptDayPartSlot slot = OcptDayPartSlot.fullDay,
  OcptLocationAvailabilityKind kind = OcptLocationAvailabilityKind.available,
  String note = "",
}) => OcptLocationAvailability(
  id: id,
  locationId: locationId,
  startDate: startDate,
  endDate: endDate,
  weekdays: weekdays,
  slot: slot,
  startMinute: null,
  endMinute: null,
  kind: kind,
  note: note,
);

/// Builds an element, every field left at a neutral value unless the test overrides it.
OcptElement _buildElement({
  required String id,
  OcptElementCategory category = OcptElementCategory.prop,
  String name = "",
  bool isSecured = false,
  bool isReadyForShoot = false,
  bool isReturned = false,
  int? cost,
  String? ownerPersonId,
  String? broughtByPersonId,
  List<OcptSceneElementLink> sceneLinks = const [],
}) => OcptElement(
      status: OcptElementStatus.toFind,
  id: id,
  category: category,
  subCategory: "",
  name: name,
  code: "",
  quantity: "",
  sourceKind: OcptElementSourceKind.owned,
  ownerPersonId: ownerPersonId,
  ownerNotes: "",
  broughtByPersonId: broughtByPersonId,
  storageNotes: "",
  isSecured: isSecured,
  isReadyForShoot: isReadyForShoot,
  isReturned: isReturned,
  cost: cost,
  purposeNotes: "",
  notes: "",
  photoAssetId: null,
  photo: null,
  sceneLinks: sceneLinks,
  roleLinks: const [],
);

/// Decodes [bytes] and returns the rows of [sheetName], every cell unwrapped to a plain Dart value
/// (or a [DateCellValue]/[BoolCellValue], kept as-is so a test can compare it directly), an empty
/// cell reading as null.
List<List<Object?>> _rowsOf(List<int> bytes, String sheetName) {
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables[sheetName];
  expect(sheet, isNotNull, reason: "the workbook has no sheet named $sheetName");

  return [
    for (final row in sheet!.rows) [for (final cell in row) _valueOf(cell)],
  ];
}

/// The plain Dart value [cell] holds, or null when it is empty; a [BoolCellValue] or a
/// [DateCellValue] is kept as-is so a test can compare it directly.
Object? _valueOf(Data? cell) {
  final value = cell?.value;
  return switch (value) {
    TextCellValue(:final value) => value.toString(),
    IntCellValue(:final value) => value,
    DoubleCellValue(:final value) => value,
    BoolCellValue() => value,
    DateCellValue() => value,
    null => null,
    _ => value.toString(),
  };
}

/// The value of column [index] in [row], or null when the row is shorter than that column.
Object? _cellAt(List<Object?> row, int index) => index < row.length ? row[index] : null;

void main() {
  const service = OcptResourcesXlsxExportService();

  group('xlsxFileName', () {
    test('appends the .xlsx extension and the suffix to the project name', () {
      expect(
        service.xlsxFileName(projectName: "My Movie", suffix: "resources"),
        "My Movie - resources.xlsx",
      );
    });

    test('falls back to a bare name when the suffix is blank', () {
      expect(service.xlsxFileName(projectName: "My Movie", suffix: "   "), "My Movie.xlsx");
    });
  });

  group('generate', () {
    test('writes exactly four sheets, named after the labels, in order', () {
      final bytes = service.generate(
        snapshot: OcptResourcesSnapshot.build(
          people: const [],
          roles: const [],
          locations: const [],
          elements: const [],
          candidatesByRoleId: const {},
          scenes: const [],
        ),
        labels: _buildLabels(),
      );

      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys, [
        _peopleSheetName,
        _rolesSheetName,
        _locationsSheetName,
        _elementsSheetName,
      ]);
    });

    test("writes each sheet's header row, one cell per column", () {
      final bytes = service.generate(
        snapshot: OcptResourcesSnapshot.build(
          people: const [],
          roles: const [],
          locations: const [],
          elements: const [],
          candidatesByRoleId: const {},
          scenes: const [],
        ),
        labels: _buildLabels(),
      );

      expect(_rowsOf(bytes, _peopleSheetName).first, [
        for (final column in OcptPeopleXlsxColumn.values) column.name,
      ]);
      expect(_rowsOf(bytes, _rolesSheetName).first, [
        for (final column in OcptRolesXlsxColumn.values) column.name,
      ]);
      expect(_rowsOf(bytes, _locationsSheetName).first, [
        for (final column in OcptLocationsXlsxColumn.values) column.name,
      ]);
      expect(_rowsOf(bytes, _elementsSheetName).first, [
        for (final column in OcptElementsXlsxColumn.values) column.name,
      ]);
    });

    test("writes a person's row with their functions, roles and typed fields", () {
      final person = _buildPerson(
        id: "person-1",
        firstName: "Léa",
        lastName: "Martin",
        email: "lea@example.com",
        birthDate: DateTime(1990, 5, 20),
        isTransportAutonomous: true,
        imageRightsStatus: OcptImageRightsStatus.signed,
        positions: const [
          OcptPersonPosition(
            id: "position-1",
            personId: "person-1",
            positionId: "director",
            customLabel: "",
          ),
        ],
        skills: const [OcptPersonSkill(id: "skill-1", personId: "person-1", label: "Permis B")],
      );
      final role = _buildRole(id: "role-1", number: 1, name: "LÉA", personId: "person-1");

      final bytes = service.generate(
        snapshot: OcptResourcesSnapshot.build(
          people: [person],
          roles: [role],
          locations: const [],
          elements: const [],
          candidatesByRoleId: const {},
          scenes: const [],
        ),
        labels: _buildLabels(),
      );

      final row = _rowsOf(bytes, _peopleSheetName)[1];
      expect(_cellAt(row, OcptPeopleXlsxColumn.name.index), "Léa Martin");
      expect(_cellAt(row, OcptPeopleXlsxColumn.positions.index), "Director");
      expect(_cellAt(row, OcptPeopleXlsxColumn.roles.index), "LÉA");
      expect(_cellAt(row, OcptPeopleXlsxColumn.email.index), "lea@example.com");
      expect(
        _cellAt(row, OcptPeopleXlsxColumn.birthDate.index),
        const DateCellValue(year: 1990, month: 5, day: 20),
      );
      expect(_cellAt(row, OcptPeopleXlsxColumn.age.index), isA<int>());
      expect(_cellAt(row, OcptPeopleXlsxColumn.transportAutonomy.index), const BoolCellValue(true));
      expect(_cellAt(row, OcptPeopleXlsxColumn.skills.index), "Permis B");
      expect(_cellAt(row, OcptPeopleXlsxColumn.imageRightsStatus.index), "signed");
    });

    test('writes a location with two sets as two rows, its own columns repeated', () {
      final location = _buildLocation(
        id: "location-1",
        name: "La maison des Pains",
        permitStatus: OcptPermitStatus.granted,
        sets: [
          _buildSet(
            id: "set-a",
            locationId: "location-1",
            code: "A",
            name: "Cuisine",
            sceneIds: ["scene-1"],
          ),
          _buildSet(id: "set-b", locationId: "location-1", code: "B", name: "Jardin"),
        ],
      );

      final bytes = service.generate(
        snapshot: OcptResourcesSnapshot.build(
          people: const [],
          roles: const [],
          locations: [location],
          elements: const [],
          candidatesByRoleId: const {},
          scenes: const [],
        ),
        labels: _buildLabels(sceneLabels: const {"scene-1": "4 · Cuisine"}),
      );

      final rows = _rowsOf(bytes, _locationsSheetName);
      expect(rows, hasLength(3)); // header + 2 set rows

      final setARow = rows[1];
      expect(_cellAt(setARow, OcptLocationsXlsxColumn.locationName.index), "La maison des Pains");
      expect(_cellAt(setARow, OcptLocationsXlsxColumn.setCode.index), "A");
      expect(_cellAt(setARow, OcptLocationsXlsxColumn.setScenes.index), "4 · Cuisine");
      expect(_cellAt(setARow, OcptLocationsXlsxColumn.permitStatus.index), "granted");

      final setBRow = rows[2];
      expect(_cellAt(setBRow, OcptLocationsXlsxColumn.locationName.index), "La maison des Pains");
      expect(_cellAt(setBRow, OcptLocationsXlsxColumn.setCode.index), "B");
      expect(_cellAt(setBRow, OcptLocationsXlsxColumn.setScenes.index), isNull);
    });

    test('writes a location with no set at all as one row, its set columns left empty', () {
      final location = _buildLocation(id: "location-1", name: "Rue du marché");

      final bytes = service.generate(
        snapshot: OcptResourcesSnapshot.build(
          people: const [],
          roles: const [],
          locations: [location],
          elements: const [],
          candidatesByRoleId: const {},
          scenes: const [],
        ),
        labels: _buildLabels(),
      );

      final rows = _rowsOf(bytes, _locationsSheetName);
      expect(rows, hasLength(2)); // header + 1 row

      final row = rows[1];
      expect(_cellAt(row, OcptLocationsXlsxColumn.locationName.index), "Rue du marché");
      expect(_cellAt(row, OcptLocationsXlsxColumn.setCode.index), isNull);
      expect(_cellAt(row, OcptLocationsXlsxColumn.setName.index), isNull);
      expect(_cellAt(row, OcptLocationsXlsxColumn.setScenes.index), isNull);
    });

    test("names the weekdays an availability window is narrowed to", () {
      final location = _buildLocation(
        id: "location-1",
        name: "La maison des Pains",
        availabilities: [
          _buildAvailability(
            id: "availability-1",
            locationId: "location-1",
            startDate: DateTime(2026, 3, 2),
            endDate: DateTime(2026, 3, 20),
            weekdays: _maskOf(const [DateTime.monday, DateTime.tuesday]),
            note: "No noise after 22:00",
            kind: OcptLocationAvailabilityKind.conditional,
          ),
          _buildAvailability(
            id: "availability-2",
            locationId: "location-1",
            startDate: DateTime(2026, 4),
            endDate: DateTime(2026, 4),
            weekdays: ocptEveryWeekdayMask,
          ),
        ],
      );

      final bytes = service.generate(
        snapshot: OcptResourcesSnapshot.build(
          people: const [],
          roles: const [],
          locations: [location],
          elements: const [],
          candidatesByRoleId: const {},
          scenes: const [],
        ),
        labels: _buildLabels(),
      );

      final windows = _cellAt(
        _rowsOf(bytes, _locationsSheetName)[1],
        OcptLocationsXlsxColumn.availabilityWindows.index,
      );

      // The narrowed window names its two days, in `DateTime`'s own order, while the one covering
      // its whole range says so in one word rather than listing all seven.
      expect(windows, contains("Mon, Tue"));
      expect(windows, contains("No noise after 22:00"));
      expect(windows, contains("Every day"));
    });

    test("writes an element's tracking flags, cost and scene links", () {
      final element = _buildElement(
        id: "element-1",
        name: "Vélo rouge",
        isSecured: true,
        isReadyForShoot: true,
        cost: 1250,
        sceneLinks: const [
          OcptSceneElementLink(id: "link-1", sceneId: "scene-1", quantity: "1", notes: "Cassé"),
        ],
      );

      final bytes = service.generate(
        snapshot: OcptResourcesSnapshot.build(
          people: const [],
          roles: const [],
          locations: const [],
          elements: [element],
          candidatesByRoleId: const {},
          scenes: const [],
        ),
        labels: _buildLabels(sceneLabels: const {"scene-1": "4 · Cuisine"}),
      );

      final row = _rowsOf(bytes, _elementsSheetName)[1];
      expect(_cellAt(row, OcptElementsXlsxColumn.name.index), "Vélo rouge");
      expect(_cellAt(row, OcptElementsXlsxColumn.secured.index), const BoolCellValue(true));
      expect(_cellAt(row, OcptElementsXlsxColumn.ready.index), const BoolCellValue(true));
      expect(_cellAt(row, OcptElementsXlsxColumn.returned.index), const BoolCellValue(false));
      expect(_cellAt(row, OcptElementsXlsxColumn.trackingStatus.index), "Ready");
      expect(_cellAt(row, OcptElementsXlsxColumn.cost.index), 12.5);
      expect(_cellAt(row, OcptElementsXlsxColumn.scenes.index), "4 · Cuisine (1, Cassé)");
    });

    test('leaves every unset field as an empty cell, never as a placeholder', () {
      final person = _buildPerson(id: "person-1");
      final role = _buildRole(id: "role-1", number: 1);
      final location = _buildLocation(id: "location-1");
      final element = _buildElement(id: "element-1");

      final bytes = service.generate(
        snapshot: OcptResourcesSnapshot.build(
          people: [person],
          roles: [role],
          locations: [location],
          elements: [element],
          candidatesByRoleId: const {},
          scenes: const [],
        ),
        labels: _buildLabels(),
      );

      final personRow = _rowsOf(bytes, _peopleSheetName)[1];
      expect(_cellAt(personRow, OcptPeopleXlsxColumn.name.index), isNull);
      expect(_cellAt(personRow, OcptPeopleXlsxColumn.email.index), isNull);
      expect(_cellAt(personRow, OcptPeopleXlsxColumn.birthDate.index), isNull);
      expect(_cellAt(personRow, OcptPeopleXlsxColumn.age.index), isNull);
      expect(_cellAt(personRow, OcptPeopleXlsxColumn.transportAutonomy.index), isNull);
      expect(_cellAt(personRow, OcptPeopleXlsxColumn.unavailabilities.index), isNull);

      final roleRow = _rowsOf(bytes, _rolesSheetName)[1];
      expect(_cellAt(roleRow, OcptRolesXlsxColumn.name.index), isNull);
      expect(_cellAt(roleRow, OcptRolesXlsxColumn.castMember.index), isNull);

      final locationRow = _rowsOf(bytes, _locationsSheetName)[1];
      expect(_cellAt(locationRow, OcptLocationsXlsxColumn.locationName.index), isNull);
      expect(_cellAt(locationRow, OcptLocationsXlsxColumn.latitude.index), isNull);
      expect(_cellAt(locationRow, OcptLocationsXlsxColumn.availabilityWindows.index), isNull);

      final elementRow = _rowsOf(bytes, _elementsSheetName)[1];
      expect(_cellAt(elementRow, OcptElementsXlsxColumn.name.index), isNull);
      expect(_cellAt(elementRow, OcptElementsXlsxColumn.cost.index), isNull);
      expect(_cellAt(elementRow, OcptElementsXlsxColumn.scenes.index), isNull);
    });
  });
}
