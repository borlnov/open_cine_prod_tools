// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_breakdown_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_entries_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scenes_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// A two-scene screenplay, short enough that every eighths figure the export writes stays small
/// and predictable.
const _screenplay =
    "INT. KITCHEN - DAY\n"
    "\n"
    "A room lit by the desk lamp alone.\n"
    "\n"
    "EXT. STREET - NIGHT\n"
    "\n"
    "Rain falls on the empty pavement.\n";

/// Every localized string of the two sheets, named after its own key so a test can tell any two
/// columns, statuses or groups apart without depending on the app's own translations. Mirrors
/// `ocpt_resources_xlsx_export_service_test.dart`'s own `_buildLabels`.
const _scenesSheetName = "Scenes";
const _entriesSheetName = "Breakdown";

OcptBreakdownXlsxLabels _buildLabels() => OcptBreakdownXlsxLabels(
  fileNameSuffix: "breakdown",
  scenesSheetName: _scenesSheetName,
  entriesSheetName: _entriesSheetName,
  scenesColumnHeaders: {
    for (final column in OcptBreakdownScenesXlsxColumn.values) column: column.name,
  },
  entriesColumnHeaders: {
    for (final column in OcptBreakdownEntriesXlsxColumn.values) column: column.name,
  },
  sceneStatusLabels: {
    for (final status in OcptBreakdownSceneStatus.values) status: status.name,
  },
  elementStatusLabels: {
    for (final status in OcptElementStatus.values) status: status.name,
  },
  elementCategoryLabels: {
    for (final category in OcptElementCategory.values) category: category.name,
  },
  roleGroupLabel: "Roles",
  setGroupLabel: "Sets",
);

/// Builds a scene at [position], with the tags left for [OcptBreakdownSnapshot.build] to attach.
OcptBreakdownScene _buildScene({
  required String id,
  required int position,
  OcptBreakdownSceneStatus status = OcptBreakdownSceneStatus.toDo,
  String notes = "",
}) => OcptBreakdownScene(
  id: id,
  position: position,
  heading: position == 0 ? "INT. KITCHEN - DAY" : "EXT. STREET - NIGHT",
  sceneNumber: null,
  charStart: 0,
  charEnd: 40,
  status: status,
  notes: notes,
  tags: const [],
);

/// Builds a tag pointing scene [sceneId] at ([targetKind], [targetId]), carrying [taggedText].
OcptBreakdownTag _buildTag({
  required String id,
  required String sceneId,
  required String targetId,
  OcptBreakdownTargetKind targetKind = OcptBreakdownTargetKind.element,
  String taggedText = "desk lamp",
}) => OcptBreakdownTag(
  id: id,
  sceneId: sceneId,
  targetKind: targetKind,
  targetId: targetId,
  startOffset: 0,
  endOffset: taggedText.length,
  taggedText: taggedText,
  needsCheck: false,
);

/// Builds an element, every field left at a neutral value unless the test overrides it.
OcptElement _buildElement({
  required String id,
  OcptElementCategory category = OcptElementCategory.prop,
  String name = "",
  String code = "",
  OcptElementStatus status = OcptElementStatus.toFind,
  String? ownerPersonId,
  List<OcptSceneElementLink> sceneLinks = const [],
}) => OcptElement(
  id: id,
  category: category,
  subCategory: "",
  name: name,
  code: code,
  quantity: "",
  sourceKind: OcptElementSourceKind.owned,
  status: status,
  ownerPersonId: ownerPersonId,
  ownerNotes: "",
  broughtByPersonId: null,
  storageNotes: "",
  isSecured: false,
  isReadyForShoot: false,
  isReturned: false,
  cost: null,
  purposeNotes: "",
  notes: "",
  photoAssetId: null,
  photo: null,
  sceneLinks: sceneLinks,
  roleLinks: const [],
);

/// Builds a role named [name], numbered [number].
OcptRole _buildRole({required String id, required String name, int number = 1}) => OcptRole(
  id: id,
  screenplayId: "screenplay",
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: number,
);

/// Builds a set named [name], holding [sceneIds].
OcptSet _buildSet({
  required String id,
  required String locationId,
  String code = "",
  String name = "",
  List<String> sceneIds = const [],
}) =>
    OcptSet(id: id, locationId: locationId, code: code, name: name, notes: "", sceneIds: sceneIds);

/// Builds a location named [name], holding [sets].
OcptLocation _buildLocation({
  required String id,
  String name = "",
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
  sets: sets,
  photos: const [],
  permitDocument: null,
  availabilities: const [],
);

/// Builds a person named [firstName] [lastName].
OcptPerson _buildPerson({
  required String id,
  required String firstName,
  required String lastName,
}) => OcptPerson(
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

/// Decodes [bytes] and returns the rows of [sheetName], every cell unwrapped to a plain Dart value,
/// an empty cell reading as null. Mirrors `ocpt_resources_xlsx_export_service_test.dart`'s own
/// `_rowsOf`.
List<List<Object?>> _rowsOf(List<int> bytes, String sheetName) {
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables[sheetName];
  expect(sheet, isNotNull, reason: "the workbook has no sheet named $sheetName");

  return [
    for (final row in sheet!.rows) [for (final cell in row) _valueOf(cell)],
  ];
}

/// The plain Dart value [cell] holds, or null when it is empty.
Object? _valueOf(Data? cell) {
  final value = cell?.value;
  return switch (value) {
    TextCellValue(:final value) => value.toString(),
    IntCellValue(:final value) => value,
    null => null,
    _ => value.toString(),
  };
}

/// The value of column [index] in [row], or null when the row is shorter than that column.
Object? _cellAt(List<Object?> row, int index) => index < row.length ? row[index] : null;

void main() {
  const service = OcptBreakdownXlsxExportService();
  const parser = FountainParser();
  const pageSetup = OcptPageSetup.standard();
  final document = parser.parse(_screenplay);

  /// A snapshot of the two scenes above, the first one tagging [elements] and — when [taggedRole]
  /// or [taggedSet] are given — the role/set of the same name too.
  OcptBreakdownSnapshot buildSnapshot({
    List<OcptElement> elements = const [],
    OcptBreakdownSceneStatus firstSceneStatus = OcptBreakdownSceneStatus.toDo,
    String firstSceneNotes = "",
    OcptRole? taggedRole,
    OcptSet? taggedSet,
    List<OcptPerson> people = const [],
    List<OcptLocation> locations = const [],
  }) => OcptBreakdownSnapshot.build(
    screenplayId: "screenplay",
    scenes: [
      _buildScene(id: "scene-1", position: 0, status: firstSceneStatus, notes: firstSceneNotes),
      _buildScene(id: "scene-2", position: 1),
    ],
    tags: [
      for (final (index, element) in elements.indexed)
        _buildTag(id: "tag-element-$index", sceneId: "scene-1", targetId: element.id),
      if (taggedRole != null)
        _buildTag(
          id: "tag-role",
          sceneId: "scene-1",
          targetId: taggedRole.id,
          targetKind: OcptBreakdownTargetKind.role,
          taggedText: taggedRole.name,
        ),
      if (taggedSet != null)
        _buildTag(
          id: "tag-set",
          sceneId: "scene-1",
          targetId: taggedSet.id,
          targetKind: OcptBreakdownTargetKind.set,
          taggedText: taggedSet.name,
        ),
    ],
    elements: elements,
    roles: [if (taggedRole != null) taggedRole],
    sets: [if (taggedSet != null) taggedSet],
    locations: locations,
    people: people,
  );

  Uint8List generate(OcptBreakdownSnapshot snapshot) => service.generate(
    document: document,
    snapshot: snapshot,
    pageSetup: pageSetup,
    labels: _buildLabels(),
  );

  group("xlsxFileName", () {
    test("appends the .xlsx extension and the suffix to the project name", () {
      expect(
        service.xlsxFileName(projectName: "My Movie", suffix: "breakdown"),
        "My Movie - breakdown.xlsx",
      );
    });

    test("falls back to a bare name when the suffix is blank", () {
      expect(service.xlsxFileName(projectName: "My Movie", suffix: "   "), "My Movie.xlsx");
    });
  });

  group("generate", () {
    test("writes exactly two sheets, named after the labels, in order", () {
      final bytes = generate(buildSnapshot());

      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys, [_scenesSheetName, _entriesSheetName]);
    });

    test("writes each sheet's header row, one cell per column, bold", () {
      final bytes = generate(buildSnapshot());

      expect(_rowsOf(bytes, _scenesSheetName).first, [
        for (final column in OcptBreakdownScenesXlsxColumn.values) column.name,
      ]);
      expect(_rowsOf(bytes, _entriesSheetName).first, [
        for (final column in OcptBreakdownEntriesXlsxColumn.values) column.name,
      ]);

      final excel = Excel.decodeBytes(bytes);
      final headerCell = excel
          .tables[_scenesSheetName]!
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      expect(headerCell.cellStyle?.isBold, isTrue);
    });

    test("an empty snapshot still produces a decodable workbook with just the header rows", () {
      final bytes = generate(
        OcptBreakdownSnapshot.build(
          screenplayId: "screenplay",
          scenes: const [],
          tags: const [],
          elements: const [],
          roles: const [],
          sets: const [],
          locations: const [],
          people: const [],
        ),
      );

      expect(_rowsOf(bytes, _scenesSheetName), hasLength(1));
      expect(_rowsOf(bytes, _entriesSheetName), hasLength(1));
    });

    group("the Scenes sheet", () {
      test("writes one row per scene, whether tagged or not", () {
        final bytes = generate(
          buildSnapshot(elements: [_buildElement(id: "element-1", name: "Desk lamp")]),
        );

        // Header + 2 scenes.
        expect(_rowsOf(bytes, _scenesSheetName), hasLength(3));
      });

      test("writes the scene's number, heading and status", () {
        final bytes = generate(
          buildSnapshot(firstSceneStatus: OcptBreakdownSceneStatus.inProgress),
        );

        final row = _rowsOf(bytes, _scenesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownScenesXlsxColumn.number.index), "1");
        expect(_cellAt(row, OcptBreakdownScenesXlsxColumn.heading.index), "INT. KITCHEN - DAY");
        expect(
          _cellAt(row, OcptBreakdownScenesXlsxColumn.status.index),
          OcptBreakdownSceneStatus.inProgress.name,
        );
      });

      test("writes the scene's own breakdown notes", () {
        final bytes = generate(buildSnapshot(firstSceneNotes: "The lamp is the only light."));

        final row = _rowsOf(bytes, _scenesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownScenesXlsxColumn.notes.index), "The lamp is the only light.");
      });

      test("writes the scene's length in eighths", () {
        final bytes = generate(buildSnapshot());

        final row = _rowsOf(bytes, _scenesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownScenesXlsxColumn.length.index), isNotNull);
      });

      test("a scene whose position outruns the screenplay writes no length at all", () {
        final bytes = generate(
          OcptBreakdownSnapshot.build(
            screenplayId: "screenplay",
            scenes: [_buildScene(id: "scene-1", position: 0), _buildScene(id: "scene-3", position: 2)],
            tags: const [],
            elements: const [],
            roles: const [],
            sets: const [],
            locations: const [],
            people: const [],
          ),
        );

        final row = _rowsOf(bytes, _scenesSheetName)[2];
        expect(_cellAt(row, OcptBreakdownScenesXlsxColumn.length.index), isNull);
      });

      test("writes the sets linked to the scene, named with their location", () {
        final location = _buildLocation(id: "location-1", name: "Maison des Martin");
        final set = _buildSet(
          id: "set-1",
          locationId: "location-1",
          name: "Cuisine",
          sceneIds: const ["scene-1"],
        );

        final bytes = generate(buildSnapshot(taggedSet: set, locations: [location]));

        final row = _rowsOf(bytes, _scenesSheetName)[1];
        expect(
          _cellAt(row, OcptBreakdownScenesXlsxColumn.sets.index),
          "Cuisine · Maison des Martin",
        );
      });

      test("counts the distinct targets tagged in the scene", () {
        final bytes = generate(
          buildSnapshot(
            elements: [
              _buildElement(id: "element-1", name: "Desk lamp"),
              _buildElement(id: "element-2", name: "Umbrella"),
            ],
          ),
        );

        final row = _rowsOf(bytes, _scenesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownScenesXlsxColumn.neededCount.index), 2);
      });

      test("an untagged scene counts nothing needed", () {
        final bytes = generate(buildSnapshot());

        final row = _rowsOf(bytes, _scenesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownScenesXlsxColumn.neededCount.index), 0);
      });
    });

    group("the Breakdown sheet", () {
      test("writes one row per tagged target in a scene", () {
        final bytes = generate(
          buildSnapshot(elements: [_buildElement(id: "element-1", name: "Desk lamp")]),
        );

        // Header + 1 tagged element.
        expect(_rowsOf(bytes, _entriesSheetName), hasLength(2));
      });

      test("an untagged snapshot writes no row at all beyond the header", () {
        final bytes = generate(buildSnapshot());

        expect(_rowsOf(bytes, _entriesSheetName), hasLength(1));
      });

      test("writes the scene number and heading beside the target", () {
        final bytes = generate(
          buildSnapshot(elements: [_buildElement(id: "element-1", name: "Desk lamp")]),
        );

        final row = _rowsOf(bytes, _entriesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.sceneNumber.index), "1");
        expect(
          _cellAt(row, OcptBreakdownEntriesXlsxColumn.sceneHeading.index),
          "INT. KITCHEN - DAY",
        );
      });

      test("an element's row carries its category group, code, name and status", () {
        final bytes = generate(
          buildSnapshot(
            elements: [
              _buildElement(
                id: "element-1",
                name: "Desk lamp",
                code: "PRP-1",
                status: OcptElementStatus.confirmed,
              ),
            ],
          ),
        );

        final row = _rowsOf(bytes, _entriesSheetName)[1];
        expect(
          _cellAt(row, OcptBreakdownEntriesXlsxColumn.group.index),
          OcptElementCategory.prop.name,
        );
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.code.index), "PRP-1");
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.name.index), "Desk lamp");
        expect(
          _cellAt(row, OcptBreakdownEntriesXlsxColumn.status.index),
          OcptElementStatus.confirmed.name,
        );
      });

      test("an element's row carries its owner's name", () {
        final person = _buildPerson(id: "person-1", firstName: "Léa", lastName: "Martin");
        final bytes = generate(
          buildSnapshot(
            elements: [
              _buildElement(id: "element-1", name: "Desk lamp", ownerPersonId: person.id),
            ],
            people: [person],
          ),
        );

        final row = _rowsOf(bytes, _entriesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.owner.index), "Léa Martin");
      });

      test("an element's row carries the quantity and notes of its own scene link", () {
        final bytes = generate(
          buildSnapshot(
            elements: [
              _buildElement(
                id: "element-1",
                name: "Desk lamp",
                sceneLinks: const [
                  OcptSceneElementLink(id: "link-1", sceneId: "scene-1", quantity: "2", notes: "Cassé"),
                ],
              ),
            ],
          ),
        );

        final row = _rowsOf(bytes, _entriesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.quantity.index), "2");
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.notes.index), "Cassé");
      });

      test("writes the tagged passage's own text", () {
        final bytes = generate(
          buildSnapshot(elements: [_buildElement(id: "element-1", name: "Desk lamp")]),
        );

        final row = _rowsOf(bytes, _entriesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.taggedText.index), "desk lamp");
      });

      test("a role's row carries its own number as its code, and no status or owner", () {
        final bytes = generate(buildSnapshot(taggedRole: _buildRole(id: "role-1", name: "LÉA", number: 3)));

        final row = _rowsOf(bytes, _entriesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.group.index), "Roles");
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.code.index), "3");
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.name.index), "LÉA");
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.status.index), isNull);
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.owner.index), isNull);
      });

      test("a set's row carries its own code, and no status or owner", () {
        final set = _buildSet(id: "set-1", locationId: "location-1", code: "A", name: "Cuisine");

        final bytes = generate(buildSnapshot(taggedSet: set));

        final row = _rowsOf(bytes, _entriesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.group.index), "Sets");
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.code.index), "A");
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.name.index), "Cuisine");
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.status.index), isNull);
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.owner.index), isNull);
      });

      test("a target tagged in two scenes yields two rows", () {
        final element = _buildElement(id: "element-1", name: "Desk lamp");
        final snapshot = OcptBreakdownSnapshot.build(
          screenplayId: "screenplay",
          scenes: [
            _buildScene(id: "scene-1", position: 0),
            _buildScene(id: "scene-2", position: 1),
          ],
          tags: [
            _buildTag(id: "tag-1", sceneId: "scene-1", targetId: element.id),
            _buildTag(id: "tag-2", sceneId: "scene-2", targetId: element.id),
          ],
          elements: [element],
          roles: const [],
          sets: const [],
          locations: const [],
          people: const [],
        );

        final bytes = generate(snapshot);

        final rows = _rowsOf(bytes, _entriesSheetName);
        // Header + 2 occurrences of the same element, one per scene.
        expect(rows, hasLength(3));
        expect(_cellAt(rows[1], OcptBreakdownEntriesXlsxColumn.sceneNumber.index), "1");
        expect(_cellAt(rows[2], OcptBreakdownEntriesXlsxColumn.sceneNumber.index), "2");
        expect(_cellAt(rows[1], OcptBreakdownEntriesXlsxColumn.name.index), "Desk lamp");
        expect(_cellAt(rows[2], OcptBreakdownEntriesXlsxColumn.name.index), "Desk lamp");
      });

      test("a tag whose target has been tombstoned writes no row at all", () {
        // The snapshot never receives the element itself, mirroring a catalogue row tombstoned
        // underneath — `OcptBreakdownSnapshot.build` drops it from `targets`, so there is no sheet
        // left behind it to write a row for.
        final snapshot = OcptBreakdownSnapshot.build(
          screenplayId: "screenplay",
          scenes: [_buildScene(id: "scene-1", position: 0)],
          tags: [_buildTag(id: "tag-1", sceneId: "scene-1", targetId: "element-gone")],
          elements: const [],
          roles: const [],
          sets: const [],
          locations: const [],
          people: const [],
        );

        final bytes = generate(snapshot);

        expect(_rowsOf(bytes, _entriesSheetName), hasLength(1));
      });

      test("leaves every unset field as an empty cell, never as a placeholder", () {
        final bytes = generate(
          buildSnapshot(elements: [_buildElement(id: "element-1")]),
        );

        final row = _rowsOf(bytes, _entriesSheetName)[1];
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.name.index), isNull);
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.owner.index), isNull);
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.quantity.index), isNull);
        expect(_cellAt(row, OcptBreakdownEntriesXlsxColumn.notes.index), isNull);
      });
    });
  });
}
