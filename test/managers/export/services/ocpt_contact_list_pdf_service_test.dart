// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_contact_list_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the catalogue does.
const _labels = OcptContactListLabels(
  fileNameSuffix: "contacts",
  documentTitle: "Contact list",
  versionLabel: "Version",
  crewSectionTitle: "Crew",
  castSectionTitle: "Cast",
  nameHeader: "Name",
  positionHeader: "Position",
  phoneHeader: "Phone",
  emailHeader: "Email",
  crewDepartmentLabels: {
    OcptCrewDepartment.direction: "Direction",
    OcptCrewDepartment.image: "Image",
    OcptCrewDepartment.sound: "Sound",
    OcptCrewDepartment.artDepartment: "Art department",
    OcptCrewDepartment.hmc: "HMC",
    OcptCrewDepartment.production: "Production",
  },
  crewPositionLabels: {
    "director": "Director",
    "firstAssistantDirector": "1st AD",
    "grip": "Grip",
  },
  unassignedDepartmentLabel: "Unassigned",
  emptyDocumentNote: "Nothing to print.",
);

/// Builds a person, every field left at a neutral/empty value unless the test overrides it. Mirrors
/// `ocpt_resources_xlsx_export_service_test.dart`'s own `_buildPerson`.
OcptPerson _buildPerson({
  required String id,
  String firstName = "",
  String lastName = "",
  String email = "",
  String phone = "",
  List<OcptPersonPosition> positions = const [],
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
  commuteKmMilli: null,
  mileageRateId: null,
  positions: positions,
  skills: const [],
  unavailabilities: const [],
);

/// Builds a `person_positions` assignment of [personId], every field left at a neutral value unless
/// overridden.
OcptPersonPosition _buildPosition({
  required String id,
  required String personId,
  String positionId = "",
  String customLabel = "",
}) => OcptPersonPosition(id: id, personId: personId, positionId: positionId, customLabel: customLabel);

/// Builds a role, every field left at a neutral value unless the test overrides it. Mirrors
/// `ocpt_resources_xlsx_export_service_test.dart`'s own `_buildRole`.
OcptRole _buildRole({required String id, required int number, String name = "", String? personId}) =>
    OcptRole(
      id: id,
      name: name,
      personId: personId,
      kind: OcptRoleKind.speaking,
      isFromScreenplay: true,
      orphanedName: null,
      castingNotes: "",
      number: number,
      episodeIds: const [],
    );

/// Builds a snapshot of [people] and [roles] alone: neither locations nor elements are read by this
/// document.
OcptResourcesSnapshot _buildSnapshot({List<OcptPerson> people = const [], List<OcptRole> roles = const []}) =>
    OcptResourcesSnapshot.build(people: people, roles: roles, locations: const [], elements: const [], candidatesByRoleId: const {}, scenes: const []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = OcptContactListPdfService();
  const pageSetup = OcptPageSetup.standard();

  Future<Uint8List> generate({
    List<OcptPerson> people = const [],
    List<OcptRole> roles = const [],
    DateTime? exportDate,
  }) => service.generate(
    snapshot: _buildSnapshot(people: people, roles: roles),
    pageSetup: pageSetup,
    labels: _labels,
    projectName: "My Movie",
    exportDate: exportDate,
  );

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await generate(
        people: [
          _buildPerson(
            id: "person-1",
            firstName: "Léa",
            positions: [_buildPosition(id: "position-1", personId: "person-1", positionId: "director")],
          ),
        ],
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("an empty catalogue prints a readable note rather than an empty file", () async {
      final bytes = await generate();

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("a person with a position but no role still prints the crew alone", () async {
      final withPosition = await generate(
        people: [
          _buildPerson(
            id: "person-1",
            positions: [_buildPosition(id: "position-1", personId: "person-1", positionId: "director")],
          ),
        ],
      );
      final empty = await generate();

      expect(_contentStreams(withPosition), isNot(_contentStreams(empty)));
    });

    test("a role with no cast crew still prints the cast alone", () async {
      final withRole = await generate(roles: [_buildRole(id: "role-1", number: 1, name: "LÉA")]);
      final empty = await generate();

      expect(_contentStreams(withRole), isNot(_contentStreams(empty)));
    });
  });

  group("the crew, grouped by department", () {
    test("a person holding two positions is printed under both departments", () async {
      final withBoth = await generate(
        people: [
          _buildPerson(
            id: "person-1",
            firstName: "Léa",
            positions: [
              _buildPosition(id: "position-1", personId: "person-1", positionId: "director"),
              _buildPosition(id: "position-2", personId: "person-1", positionId: "grip"),
            ],
          ),
        ],
      );
      final withDirectorAlone = await generate(
        people: [
          _buildPerson(
            id: "person-1",
            firstName: "Léa",
            positions: [_buildPosition(id: "position-1", personId: "person-1", positionId: "director")],
          ),
        ],
      );

      // Both documents print the Direction department's own band and Léa's row under it, so the
      // difference between them is exactly the Grip department's own band and row — the second
      // occurrence of her contact details holding a different position label.
      expect(_contentStreams(withBoth), isNot(_contentStreams(withDirectorAlone)));
      expect(_pageCount(withBoth), _pageCount(withDirectorAlone));
    });

    test("a free-label position lands in the trailing group, not under a department", () async {
      final withCatalogued = await generate(
        people: [
          _buildPerson(
            id: "person-1",
            positions: [_buildPosition(id: "position-1", personId: "person-1", positionId: "director")],
          ),
        ],
      );
      final withFreeLabel = await generate(
        people: [
          _buildPerson(
            id: "person-1",
            positions: [
              _buildPosition(id: "position-1", personId: "person-1", customLabel: "Runner"),
            ],
          ),
        ],
      );

      // A catalogued position prints one department band (Direction); a free-label one prints a
      // different band (the trailing, unassigned group) — two distinct documents.
      expect(_contentStreams(withCatalogued), isNot(_contentStreams(withFreeLabel)));
    });

    test("two exports of the same catalogue draw exactly the same pages", () async {
      final people = [
        _buildPerson(
          id: "person-1",
          firstName: "Léa",
          positions: [_buildPosition(id: "position-1", personId: "person-1", positionId: "director")],
        ),
      ];

      final first = await generate(people: people);
      final second = await generate(people: people);

      expect(_contentStreams(first), _contentStreams(second));
    });
  });

  group("the cast", () {
    test("an uncast role still gets its row, distinct from no role at all", () async {
      final uncast = await generate(roles: [_buildRole(id: "role-1", number: 1, name: "LÉA")]);
      final empty = await generate();

      expect(_contentStreams(uncast), isNot(_contentStreams(empty)));
    });

    test("casting the role changes what is printed, since its contact details now show", () async {
      final person = _buildPerson(id: "person-1", firstName: "Camille", phone: "0102030405");
      final uncast = await generate(
        people: [person],
        roles: [_buildRole(id: "role-1", number: 1, name: "LÉA")],
      );
      final cast = await generate(
        people: [person],
        roles: [_buildRole(id: "role-1", number: 1, name: "LÉA", personId: "person-1")],
      );

      expect(_contentStreams(uncast), isNot(_contentStreams(cast)));
    });
  });

  group("a person who holds no position and plays no role", () {
    test("appears nowhere: the document reads the same with or without them", () async {
      final withBystander = await generate(
        people: [_buildPerson(id: "person-1", firstName: "Nobody"), _buildPerson(id: "person-2")],
        roles: [_buildRole(id: "role-1", number: 1, name: "LÉA", personId: "person-2")],
      );
      final withoutBystander = await generate(
        people: [_buildPerson(id: "person-2")],
        roles: [_buildRole(id: "role-1", number: 1, name: "LÉA", personId: "person-2")],
      );

      expect(_contentStreams(withBystander), _contentStreams(withoutBystander));
    });
  });

  group("the generated-at stamp", () {
    test("is the injected exportDate rather than the wall clock", () async {
      final pinned = await generate(
        people: [
          _buildPerson(
            id: "person-1",
            positions: [_buildPosition(id: "position-1", personId: "person-1", positionId: "director")],
          ),
        ],
        exportDate: DateTime(2026, 8, 8, 14, 32),
      );
      final pinnedAgain = await generate(
        people: [
          _buildPerson(
            id: "person-1",
            positions: [_buildPosition(id: "position-1", personId: "person-1", positionId: "director")],
          ),
        ],
        exportDate: DateTime(2026, 8, 8, 14, 32),
      );
      final differentMoment = await generate(
        people: [
          _buildPerson(
            id: "person-1",
            positions: [_buildPosition(id: "position-1", personId: "person-1", positionId: "director")],
          ),
        ],
        exportDate: DateTime(2026, 8, 9, 9),
      );

      // Two exports pinned to the same instant draw byte-identical pages; a different instant
      // draws a different running head on every one of them.
      expect(_contentStreams(pinned), _contentStreams(pinnedAgain));
      expect(_contentStreams(pinned), isNot(_contentStreams(differentMoment)));
    });
  });

  group("contactListFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.contactListFileName(projectName: "My Movie", suffix: "contacts"),
        "My Movie - contacts.pdf",
      );
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.contactListFileName(projectName: "My Movie", suffix: "   "), "My Movie.pdf");
    });

    test("a padded suffix is trimmed rather than printed as is", () {
      expect(
        service.contactListFileName(projectName: "My Movie", suffix: " contacts "),
        "My Movie - contacts.pdf",
      );
    });
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node), a cheap way to assert on page count without pulling in a full PDF parser as a test
/// dependency. Mirrors `ocpt_breakdown_sheets_pdf_service_test.dart`'s own `_pageCount`.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order.
///
/// This is a boundary search, not a PDF parser: it never inspects the surrounding object
/// dictionaries, which is fine for an equality comparison between two documents built from the same
/// `generate` call shape — both sides always contain the same kind of streams in the same order, so
/// any content difference between them still shows up. Mirrors
/// `ocpt_breakdown_sheets_pdf_service_test.dart`'s own `_contentStreams`.
List<String> _contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
