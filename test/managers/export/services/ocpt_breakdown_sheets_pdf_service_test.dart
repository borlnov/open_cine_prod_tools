// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_breakdown_sheets_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// A two-scene screenplay, short enough that every sheet the export writes is one page of its own.
const _screenplay =
    "INT. KITCHEN - DAY\n"
    "\n"
    "A room lit by the desk lamp alone.\n"
    "\n"
    "EXT. STREET - NIGHT\n"
    "\n"
    "Rain falls on the empty pavement.\n";

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the breakdown does.
const _labels = OcptBreakdownSheetsLabels(
  fileNameSuffix: "breakdown",
  documentTitle: "Breakdown sheets",
  sceneTitles: {"scene-1": "Scene 1", "scene-2": "Scene 2"},
  statusLabel: "Breakdown",
  lengthLabel: "Length",
  notesLabel: "Breakdown notes",
  targetsSectionTitle: "What the scene needs",
  toFindSectionTitle: "Still to find",
  nameHeader: "Name",
  statusHeader: "Status",
  ownerHeader: "Owner",
  sceneStatusLabels: {
    OcptBreakdownSceneStatus.toDo: "To do",
    OcptBreakdownSceneStatus.inProgress: "In progress",
    OcptBreakdownSceneStatus.done: "Done",
  },
  elementStatusLabels: {
    OcptElementStatus.toFind: "To find",
    OcptElementStatus.reserved: "Reserved",
    OcptElementStatus.beingMade: "Being made",
    OcptElementStatus.confirmed: "Confirmed",
  },
  elementCategoryLabels: {OcptElementCategory.prop: "Props"},
  roleGroupLabel: "Roles",
  setGroupLabel: "Sets",
  emptySceneNote: "Nothing tagged in this scene.",
  emptyDocumentNote: "No scene to print.",
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
  heading: "INT. KITCHEN - DAY",
  sceneNumber: null,
  charStart: 0,
  charEnd: 40,
  status: status,
  notes: notes,
  tags: const [],
  episodeNumber: null,
);

/// Builds a tag pointing scene [sceneId] at ([targetKind], [targetId]); these tests only ever read
/// the scene and the target it names.
OcptBreakdownTag _buildTag({
  required String id,
  required String sceneId,
  required String targetId,
  OcptBreakdownTargetKind targetKind = OcptBreakdownTargetKind.element,
}) => OcptBreakdownTag(
  id: id,
  sceneId: sceneId,
  targetKind: targetKind,
  targetId: targetId,
  startOffset: 0,
  endOffset: 9,
  taggedText: "desk lamp",
  needsCheck: false,
);

/// Builds an element named [name], optionally owned by [ownerPersonId].
OcptElement _buildElement({
  required String id,
  required String name,
  OcptElementStatus status = OcptElementStatus.toFind,
  String? ownerPersonId,
}) => OcptElement(
  id: id,
  category: OcptElementCategory.prop,
  subCategory: "",
  name: name,
  code: "",
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
  sceneLinks: const [],
  roleLinks: const [],
);

/// Builds a role named [name].
OcptRole _buildRole({required String id, required String name}) => OcptRole(
  id: id,
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
  episodeIds: const [],
);

/// Builds a person named [firstName] [lastName], the only two fields a printed sheet ever reads.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate` calls must not re-read the asset bundle).
  final service = OcptBreakdownSheetsPdfService();
  const parser = FountainParser();
  const pageSetup = OcptPageSetup.standard();

  final document = parser.parse(_screenplay);

  /// A breakdown of the two scenes, the first one tagging [elements] and — when [taggedRole] is set
  /// — the role of the same name.
  OcptBreakdownSnapshot buildSnapshot({
    List<OcptElement> elements = const [],
    OcptBreakdownSceneStatus firstSceneStatus = OcptBreakdownSceneStatus.toDo,
    String firstSceneNotes = "",
    OcptRole? taggedRole,
    List<OcptPerson> people = const [],
  }) => OcptBreakdownSnapshot.build(
    screenplayId: "screenplay",
    scenes: [
      _buildScene(id: "scene-1", position: 0, status: firstSceneStatus, notes: firstSceneNotes),
      _buildScene(id: "scene-2", position: 1),
    ],
    tags: [
      for (final (index, element) in elements.indexed)
        _buildTag(id: "tag-$index", sceneId: "scene-1", targetId: element.id),
      if (taggedRole != null)
        _buildTag(
          id: "tag-role",
          sceneId: "scene-1",
          targetId: taggedRole.id,
          targetKind: OcptBreakdownTargetKind.role,
        ),
    ],
    elements: elements,
    roles: [if (taggedRole != null) taggedRole],
    sets: const [],
    locations: const [],
    people: people,
  );

  Future<Uint8List> generate({
    required OcptBreakdownSnapshot snapshot,
    bool onlyDoneScenes = false,
    bool includeNotes = true,
    bool includeToFindList = true,
  }) => service.generate(
    document: document,
    snapshot: snapshot,
    pageSetup: pageSetup,
    labels: _labels,
    projectName: "My Movie",
    onlyDoneScenes: onlyDoneScenes,
    includeNotes: includeNotes,
    includeToFindList: includeToFindList,
  );

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await generate(
        snapshot: buildSnapshot(elements: [_buildElement(id: "element-1", name: "Desk lamp")]),
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("prints one sheet per scene, tagged or not", () async {
      final bytes = await generate(
        snapshot: buildSnapshot(elements: [_buildElement(id: "element-1", name: "Desk lamp")]),
      );

      expect(_pageCount(bytes), 2);
    });

    test("only the scenes marked done are printed when asked for", () async {
      final bytes = await generate(
        snapshot: buildSnapshot(firstSceneStatus: OcptBreakdownSceneStatus.done),
        onlyDoneScenes: true,
      );

      expect(_pageCount(bytes), 1);
    });

    test("selecting no scene at all still writes a readable one-page document", () async {
      // An empty PDF is not a file anybody can open, so the export says "nothing to print" rather
      // than writing zero pages.
      final bytes = await generate(snapshot: buildSnapshot(), onlyDoneScenes: true);

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("the same breakdown exported twice draws exactly the same pages", () async {
      // The category palette is fixed and the groups are alphabetised, so two exports of one
      // project must be comparable page by page — which is the whole point of a printed copy a
      // department head annotates.
      final first = await generate(
        snapshot: buildSnapshot(elements: [_buildElement(id: "element-1", name: "Desk lamp")]),
      );
      final second = await generate(
        snapshot: buildSnapshot(elements: [_buildElement(id: "element-1", name: "Desk lamp")]),
      );

      expect(_contentStreams(first), _contentStreams(second));
    });
  });

  group("what a sheet prints", () {
    // Every assertion below compares the *content streams* of two generated documents rather than
    // reading their text: Courier Prime is embedded as an Identity-H composite font, so a content
    // stream's text operands are font-specific glyph indices rather than readable characters.
    // Deflate being deterministic, two documents printing the same thing hold byte-identical
    // streams and two documents printing different things do not — a genuine, parser-free oracle.
    test("a tagged scene prints something the same scene untagged does not", () async {
      final tagged = await generate(
        snapshot: buildSnapshot(elements: [_buildElement(id: "element-1", name: "Desk lamp")]),
      );
      final untagged = await generate(snapshot: buildSnapshot());

      expect(_contentStreams(tagged), isNot(_contentStreams(untagged)));
    });

    test("a target's owner reaches its row", () async {
      final person = _buildPerson(id: "person-1", firstName: "Léa", lastName: "Martin");
      final withOwner = await generate(
        snapshot: buildSnapshot(
          elements: [
            _buildElement(id: "element-1", name: "Desk lamp", ownerPersonId: person.id),
          ],
          people: [person],
        ),
      );
      final withoutOwner = await generate(
        snapshot: buildSnapshot(
          elements: [_buildElement(id: "element-1", name: "Desk lamp")],
          people: [person],
        ),
      );

      expect(_contentStreams(withOwner), isNot(_contentStreams(withoutOwner)));
    });

    test("a role is grouped under its own band beside the element categories", () async {
      final withRole = await generate(
        snapshot: buildSnapshot(
          elements: [_buildElement(id: "element-1", name: "Desk lamp")],
          taggedRole: _buildRole(id: "role-1", name: "LÉA"),
        ),
      );
      final withoutRole = await generate(
        snapshot: buildSnapshot(elements: [_buildElement(id: "element-1", name: "Desk lamp")]),
      );

      expect(_contentStreams(withRole), isNot(_contentStreams(withoutRole)));
    });

    test("the notes section is left out when the export asked for it to be", () async {
      final snapshot = buildSnapshot(firstSceneNotes: "The lamp is the only light source.");

      final withNotes = await generate(snapshot: snapshot);
      final withoutNotes = await generate(snapshot: snapshot, includeNotes: false);

      expect(_contentStreams(withNotes), isNot(_contentStreams(withoutNotes)));
    });

    test("a scene with no notes at all prints the same either way", () async {
      // The section is only printed for a scene that actually has notes, so turning it off changes
      // nothing on a scene that has none.
      final snapshot = buildSnapshot(
        elements: [_buildElement(id: "element-1", name: "Desk lamp")],
      );

      final withNotes = await generate(snapshot: snapshot);
      final withoutNotes = await generate(snapshot: snapshot, includeNotes: false);

      expect(_contentStreams(withNotes), _contentStreams(withoutNotes));
    });

    test("the to-find list is left out when the export asked for it to be", () async {
      final snapshot = buildSnapshot(
        elements: [_buildElement(id: "element-1", name: "Desk lamp")],
      );

      final withList = await generate(snapshot: snapshot);
      final withoutList = await generate(snapshot: snapshot, includeToFindList: false);

      expect(_contentStreams(withList), isNot(_contentStreams(withoutList)));
    });

    test("a scene whose targets are all secured prints no to-find list either way", () async {
      final snapshot = buildSnapshot(
        elements: [
          _buildElement(id: "element-1", name: "Desk lamp", status: OcptElementStatus.confirmed),
        ],
      );

      final withList = await generate(snapshot: snapshot);
      final withoutList = await generate(snapshot: snapshot, includeToFindList: false);

      expect(_contentStreams(withList), _contentStreams(withoutList));
    });

    test("a snapshot whose scenes outrun the screenplay still prints every sheet", () async {
      // A scene's length is read off the screenplay by position, so a snapshot indexed against
      // another text must print no length rather than throw on a document being written out.
      final snapshot = OcptBreakdownSnapshot.build(
        screenplayId: "screenplay",
        scenes: [
          _buildScene(id: "scene-1", position: 0),
          _buildScene(id: "scene-2", position: 1),
          _buildScene(id: "scene-3", position: 2),
        ],
        tags: const [],
        elements: const [],
        roles: const [],
        sets: const [],
        locations: const [],
        people: const [],
      );

      final bytes = await generate(snapshot: snapshot);

      expect(_pageCount(bytes), 3);
    });
  });

  group("sheetsFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.sheetsFileName(projectName: "My Movie", suffix: "breakdown"),
        "My Movie - breakdown.pdf",
      );
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.sheetsFileName(projectName: "My Movie", suffix: "   "), "My Movie.pdf");
    });

    test("a padded suffix is trimmed rather than printed as is", () {
      expect(
        service.sheetsFileName(projectName: "My Movie", suffix: " breakdown "),
        "My Movie - breakdown.pdf",
      );
    });

    test("appends the episode tag last, after the suffix, when there is one", () {
      expect(
        service.sheetsFileName(projectName: "My Movie", suffix: "breakdown", episodeTag: "ep. 2"),
        "My Movie - breakdown - ep. 2.pdf",
      );
    });
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node), a cheap way to assert on page count without pulling in a full PDF parser as a test
/// dependency.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order.
///
/// This is a boundary search, not a PDF parser: it never inspects the surrounding object
/// dictionaries (so it can't tell a page's content stream from a font's embedded file), which is
/// fine for an equality comparison between two documents built from the same `generate` call shape
/// — both sides always contain the same kind of streams in the same order, so any content
/// difference between them still shows up.
List<String> _contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
