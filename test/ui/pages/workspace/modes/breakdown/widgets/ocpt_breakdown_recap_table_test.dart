// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_recap_table.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// The width/height the table is pumped at — wide and tall enough that every column and every row
/// of these small fixtures renders without scrolling, so a widget test never has to scroll to find
/// what it is asserting on.
const double _tableWidth = 1100;
const double _tableHeight = 700;

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a
/// [_tableWidth]×[_tableHeight] band, and widens the test surface to match first (the default
/// 800×600 test surface would otherwise clamp it).
Future<void> _pumpInApp(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(_tableWidth + 200, _tableHeight + 200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: _tableWidth, height: _tableHeight, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Builds a scene at [position], carrying [tags] — empty by default, since most tests here read
/// only `OcptBreakdownTarget.sceneIds` (what the recap table itself renders from), never a scene's
/// own tags; the one test that cross-checks against `ocptBreakdownSceneTargetsOf` (which does read
/// a scene's own tags) builds them explicitly to stay consistent with its own targets.
OcptBreakdownScene _buildScene({
  required String id,
  int position = 0,
  String? sceneNumber,
  List<OcptBreakdownTag> tags = const [],
}) => OcptBreakdownScene(
  id: id,
  position: position,
  heading: "INT. HOUSE - DAY",
  sceneNumber: sceneNumber,
  charStart: 0,
  charEnd: 40,
  status: OcptBreakdownSceneStatus.toDo,
  notes: "",
  tags: tags,
);

/// Builds a live tag of scene [sceneId] pointing at [targetKind]/[targetId].
OcptBreakdownTag _buildTag({
  required String id,
  required String sceneId,
  required OcptBreakdownTargetKind targetKind,
  required String targetId,
}) => OcptBreakdownTag(
  id: id,
  sceneId: sceneId,
  targetKind: targetKind,
  targetId: targetId,
  startOffset: 0,
  endOffset: 4,
  taggedText: "prop",
  needsCheck: false,
);

/// Builds an element target of [category]/[status], tagged in [sceneIds].
OcptBreakdownTarget _buildElementTarget({
  required String id,
  required String name,
  OcptElementCategory category = OcptElementCategory.prop,
  OcptElementStatus status = OcptElementStatus.toFind,
  List<String> sceneIds = const ["scene-1"],
  int? occurrenceCount,
}) => OcptBreakdownTarget(
  kind: OcptBreakdownTargetKind.element,
  id: id,
  name: name,
  category: category,
  status: status,
  sceneIds: sceneIds,
  occurrenceCount: occurrenceCount ?? sceneIds.length,
);

/// Builds a role target: no category, no status.
OcptBreakdownTarget _buildRoleTarget({
  required String id,
  required String name,
  List<String> sceneIds = const ["scene-1"],
  int? occurrenceCount,
}) => OcptBreakdownTarget(
  kind: OcptBreakdownTargetKind.role,
  id: id,
  name: name,
  category: null,
  status: null,
  sceneIds: sceneIds,
  occurrenceCount: occurrenceCount ?? sceneIds.length,
);

/// Builds a set target: no category, no status.
OcptBreakdownTarget _buildSetTarget({
  required String id,
  required String name,
  List<String> sceneIds = const ["scene-1"],
  int? occurrenceCount,
}) => OcptBreakdownTarget(
  kind: OcptBreakdownTargetKind.set,
  id: id,
  name: name,
  category: null,
  status: null,
  sceneIds: sceneIds,
  occurrenceCount: occurrenceCount ?? sceneIds.length,
);

/// Builds the [OcptElement] row an element target of the same [id] resolves to.
OcptElement _buildElement({
  required String id,
  required String name,
  OcptElementCategory category = OcptElementCategory.prop,
  OcptElementStatus status = OcptElementStatus.toFind,
  String subCategory = "",
  String notes = "",
  String? ownerPersonId,
}) => OcptElement(
  id: id,
  category: category,
  subCategory: subCategory,
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
  notes: notes,
  photoAssetId: null,
  sceneLinks: const [],
);

/// Builds a person, every field left at a neutral value.
OcptPerson _buildPerson({required String id, String firstName = "Léa", String lastName = "Martin"}) =>
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

/// The inner `Container` a scene cell's own dot renders, found through the key
/// `OcptBreakdownRecapTable` gives every (target, scene) cell.
Container _sceneCellContainer(WidgetTester tester, OcptBreakdownTarget target, String sceneId) =>
    tester.widget<Container>(
      find.descendant(
        of: find.byKey(ValueKey((target.kind, target.id, sceneId))),
        matching: find.byType(Container),
      ),
    );

void main() {
  testWidgets("nothing tagged at all shows its own empty state, not the no-match one", (tester) async {
    await _pumpInApp(
      tester,
      const OcptBreakdownRecapTable(
        scenes: [],
        targets: [],
        elements: [],
        people: [],
        searchQuery: "",
        selectedTargetRef: null,
        onTargetSelected: _noop3,
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownRecapTable)));
    expect(find.text(tr.breakdownRecapNothingTaggedHint), findsOneWidget);
  });

  testWidgets("a search matching nothing shows a distinct hint naming the query", (tester) async {
    final target = _buildElementTarget(id: "element-1", name: "Desk lamp");

    await _pumpInApp(
      tester,
      OcptBreakdownRecapTable(
        scenes: [_buildScene(id: "scene-1")],
        targets: [target],
        elements: [_buildElement(id: "element-1", name: "Desk lamp")],
        people: const [],
        searchQuery: "peugeot",
        selectedTargetRef: null,
        onTargetSelected: _noop3,
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownRecapTable)));
    expect(find.text(tr.breakdownRecapNoMatchesHint("peugeot")), findsOneWidget);
    expect(find.text(tr.breakdownRecapNothingTaggedHint), findsNothing);
  });

  testWidgets("groups render in ocptBreakdownLegendEntriesOf's own order", (tester) async {
    // Vehicle sorts after prop in OcptElementCategory.values, and a role always sorts after every
    // element category — so the expected top-to-bottom order is prop, vehicle, role.
    final targets = [
      _buildRoleTarget(id: "role-1", name: "LÉA"),
      _buildElementTarget(id: "element-2", name: "Car", category: OcptElementCategory.vehicle),
      _buildElementTarget(id: "element-1", name: "Desk lamp"),
    ];

    await _pumpInApp(
      tester,
      OcptBreakdownRecapTable(
        scenes: [_buildScene(id: "scene-1")],
        targets: targets,
        elements: [
          _buildElement(id: "element-1", name: "Desk lamp"),
          _buildElement(id: "element-2", name: "Car", category: OcptElementCategory.vehicle),
        ],
        people: const [],
        searchQuery: "",
        selectedTargetRef: null,
        onTargetSelected: _noop3,
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownRecapTable)));
    final propY = tester.getTopLeft(find.text(tr.resourcesElementCategoryProp.toUpperCase())).dy;
    final vehicleY = tester.getTopLeft(find.text(tr.resourcesElementCategoryVehicle.toUpperCase())).dy;
    final roleY = tester.getTopLeft(find.text(tr.breakdownTargetKindRoleLabel.toUpperCase())).dy;

    expect(propY, lessThan(vehicleY));
    expect(vehicleY, lessThan(roleY));
  });

  testWidgets("a row shows a filled dot for a tagged scene, a muted one for an untagged one",
      (tester) async {
    final target = _buildElementTarget(id: "element-1", name: "Desk lamp", sceneIds: ["scene-1"]);

    await _pumpInApp(
      tester,
      OcptBreakdownRecapTable(
        scenes: [_buildScene(id: "scene-1"), _buildScene(id: "scene-2", position: 1)],
        targets: [target],
        elements: [_buildElement(id: "element-1", name: "Desk lamp")],
        people: const [],
        searchQuery: "",
        selectedTargetRef: null,
        onTargetSelected: _noop3,
      ),
    );

    final taggedCell = _sceneCellContainer(tester, target, "scene-1");
    final untaggedCell = _sceneCellContainer(tester, target, "scene-2");

    // The tagged scene's own dot is strictly larger (filled) than the untagged one's (muted).
    expect(taggedCell.constraints!.maxWidth, greaterThan(untaggedCell.constraints!.maxWidth));
  });

  testWidgets("the occurrence count is the target's own occurrenceCount", (tester) async {
    final target = _buildElementTarget(
      id: "element-1",
      name: "Desk lamp",
      sceneIds: ["scene-1", "scene-2"],
      occurrenceCount: 5,
    );

    await _pumpInApp(
      tester,
      OcptBreakdownRecapTable(
        scenes: [_buildScene(id: "scene-1"), _buildScene(id: "scene-2")],
        targets: [target],
        elements: [_buildElement(id: "element-1", name: "Desk lamp")],
        people: const [],
        searchQuery: "",
        selectedTargetRef: null,
        onTargetSelected: _noop3,
      ),
    );

    expect(find.text("5"), findsOneWidget);
  });

  testWidgets("a role's row leaves the status and owner cells empty", (tester) async {
    final target = _buildRoleTarget(id: "role-1", name: "LÉA");

    await _pumpInApp(
      tester,
      OcptBreakdownRecapTable(
        scenes: [_buildScene(id: "scene-1")],
        targets: [target],
        elements: const [],
        people: [_buildPerson(id: "person-1")],
        searchQuery: "",
        selectedTargetRef: null,
        onTargetSelected: _noop3,
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownRecapTable)));
    // None of the four element statuses (the only possible pill labels) is shown anywhere, and
    // the address book's only person's name is not shown either — there is no owner to resolve.
    for (final status in OcptElementStatus.values) {
      expect(find.text(_statusLabel(tr, status)), findsNothing);
    }
    expect(find.text("Léa Martin"), findsNothing);
  });

  testWidgets("a set's row leaves the status and owner cells empty, same as a role's", (tester) async {
    final target = _buildSetTarget(id: "set-1", name: "La cuisine");

    await _pumpInApp(
      tester,
      OcptBreakdownRecapTable(
        scenes: [_buildScene(id: "scene-1")],
        targets: [target],
        elements: const [],
        people: const [],
        searchQuery: "",
        selectedTargetRef: null,
        onTargetSelected: _noop3,
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownRecapTable)));
    for (final status in OcptElementStatus.values) {
      expect(find.text(_statusLabel(tr, status)), findsNothing);
    }
  });

  testWidgets("an element's row shows its status pill and its owner's name", (tester) async {
    final target = _buildElementTarget(
      id: "element-1",
      name: "Desk lamp",
      status: OcptElementStatus.confirmed,
    );

    await _pumpInApp(
      tester,
      OcptBreakdownRecapTable(
        scenes: [_buildScene(id: "scene-1")],
        targets: [target],
        elements: [
          _buildElement(
            id: "element-1",
            name: "Desk lamp",
            status: OcptElementStatus.confirmed,
            ownerPersonId: "person-1",
          ),
        ],
        people: [_buildPerson(id: "person-1")],
        searchQuery: "",
        selectedTargetRef: null,
        onTargetSelected: _noop3,
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownRecapTable)));
    expect(find.text(_statusLabel(tr, OcptElementStatus.confirmed)), findsOneWidget);
    expect(find.text("Léa Martin"), findsOneWidget);
  });

  testWidgets("clicking a row reports its kind, id and its own first scene's id", (tester) async {
    final reported = <(OcptBreakdownTargetKind, String, String)>[];
    final target = _buildElementTarget(
      id: "element-1",
      name: "Desk lamp",
      sceneIds: ["scene-1", "scene-2"],
    );

    await _pumpInApp(
      tester,
      OcptBreakdownRecapTable(
        scenes: [_buildScene(id: "scene-1"), _buildScene(id: "scene-2")],
        targets: [target],
        elements: [_buildElement(id: "element-1", name: "Desk lamp")],
        people: const [],
        searchQuery: "",
        selectedTargetRef: null,
        onTargetSelected: (kind, id, sceneId) => reported.add((kind, id, sceneId)),
      ),
    );

    await tester.tap(find.text("Desk lamp"));
    await tester.pump();

    expect(reported, [(OcptBreakdownTargetKind.element, "element-1", "scene-1")]);
  });

  testWidgets("the search filters rows while every scene column stays", (tester) async {
    final lamp = _buildElementTarget(id: "element-1", name: "Desk lamp", sceneIds: ["scene-1"]);
    final chair = _buildElementTarget(
      id: "element-2",
      name: "Chair",
      sceneIds: ["scene-2"],
    );

    await _pumpInApp(
      tester,
      OcptBreakdownRecapTable(
        scenes: [_buildScene(id: "scene-1", sceneNumber: "1"), _buildScene(id: "scene-2", sceneNumber: "2")],
        targets: [lamp, chair],
        elements: [
          _buildElement(id: "element-1", name: "Desk lamp"),
          _buildElement(id: "element-2", name: "Chair"),
        ],
        people: const [],
        searchQuery: "lamp",
        selectedTargetRef: null,
        onTargetSelected: _noop3,
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownRecapTable)));

    expect(find.text("Desk lamp"), findsOneWidget);
    expect(find.text("Chair"), findsNothing);
    // Both scene columns still show, whatever the query filtered out of the rows.
    expect(find.text(tr.breakdownRecapSceneColumnLabel("1")), findsOneWidget);
    expect(find.text(tr.breakdownRecapSceneColumnLabel("2")), findsOneWidget);
  });

  testWidgets(
    "the recap's group counts, row count and per-scene tagging agree with the shared utilities",
    (tester) async {
      // Two prop elements (occurrence counts 5 and 6, so they can never be confused with a group's
      // own count) and one role (occurrence count 7), tagged across two scenes.
      final lamp = _buildElementTarget(
        id: "element-1",
        name: "Desk lamp",
        sceneIds: ["scene-1"],
        occurrenceCount: 5,
      );
      final chair = _buildElementTarget(
        id: "element-2",
        name: "Chair",
        sceneIds: ["scene-1", "scene-2"],
        occurrenceCount: 6,
      );
      final role = _buildRoleTarget(id: "role-1", name: "LÉA", sceneIds: ["scene-2"], occurrenceCount: 7);
      final targets = [lamp, chair, role];
      // Each scene's own tags mirror the targets' `sceneIds` above exactly, the way
      // `OcptBreakdownSnapshot.build` derives one from the other in the real app: scene-1 tags
      // lamp and chair, scene-2 tags chair and the role.
      final scenes = [
        _buildScene(
          id: "scene-1",
          tags: [
            _buildTag(
              id: "tag-1",
              sceneId: "scene-1",
              targetKind: OcptBreakdownTargetKind.element,
              targetId: "element-1",
            ),
            _buildTag(
              id: "tag-2",
              sceneId: "scene-1",
              targetKind: OcptBreakdownTargetKind.element,
              targetId: "element-2",
            ),
          ],
        ),
        _buildScene(
          id: "scene-2",
          position: 1,
          tags: [
            _buildTag(
              id: "tag-3",
              sceneId: "scene-2",
              targetKind: OcptBreakdownTargetKind.element,
              targetId: "element-2",
            ),
            _buildTag(
              id: "tag-4",
              sceneId: "scene-2",
              targetKind: OcptBreakdownTargetKind.role,
              targetId: "role-1",
            ),
          ],
        ),
      ];

      await _pumpInApp(
        tester,
        OcptBreakdownRecapTable(
          scenes: scenes,
          targets: targets,
          elements: [
            _buildElement(id: "element-1", name: "Desk lamp"),
            _buildElement(id: "element-2", name: "Chair"),
          ],
          people: const [],
          searchQuery: "",
          selectedTargetRef: null,
          onTargetSelected: _noop3,
        ),
      );

      // The group counts shown must equal `ocptBreakdownLegendEntriesOf`'s own count for each key —
      // the same function the legend and the scene panel's bars read off the very same targets.
      for (final entry in ocptBreakdownLegendEntriesOf(targets)) {
        expect(find.text("${entry.count}"), findsOneWidget);
      }

      // Every row's own occurrence count is rendered verbatim.
      for (final target in targets) {
        expect(find.text("${target.occurrenceCount}"), findsOneWidget);
      }

      // Each scene's own filled-dot count — a cell reads as filled once its own width exceeds the
      // muted dot's own 4 px, the widget's own two diameters (see the dedicated dot test above,
      // which pins the ordering these hard-coded values assume rather than the exact pixels) —
      // must equal `ocptBreakdownSceneTargetsOf`'s own count for that scene against the very same
      // targets: the scene panel's own per-scene counter, and the milestone's own exit criterion.
      final targetById = ocptBreakdownTargetsById(targets);
      for (final scene in scenes) {
        final expectedTaggedCount = ocptBreakdownSceneTargetsOf(scene, targetById).length;

        final filledCount = targets
            .where((target) => _sceneCellContainer(tester, target, scene.id).constraints!.maxWidth > 4)
            .length;

        expect(filledCount, expectedTaggedCount);
      }
    },
  );
}

/// A no-op `onTargetSelected` for tests that never click a row.
void _noop3(OcptBreakdownTargetKind kind, String id, String sceneId) {}

/// The display label of [status], read off the generated `Tr` the same way the recap table's own
/// status pill does.
String _statusLabel(Tr tr, OcptElementStatus status) => switch (status) {
  OcptElementStatus.toFind => tr.breakdownElementStatusToFind,
  OcptElementStatus.reserved => tr.breakdownElementStatusReserved,
  OcptElementStatus.beingMade => tr.breakdownElementStatusBeingMade,
  OcptElementStatus.confirmed => tr.breakdownElementStatusConfirmed,
};
