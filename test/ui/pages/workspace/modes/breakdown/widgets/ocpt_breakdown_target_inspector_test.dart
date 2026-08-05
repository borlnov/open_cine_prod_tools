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
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_target_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_suggestions.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 320, child: child)),
);

/// Grows the test surface tall enough that the whole (long, scrolling) panel is built and
/// hit-testable without having to scroll it.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(320, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Builds a scene at [position] carrying [tags], everything else left at a neutral value.
OcptBreakdownScene _buildScene({
  required String id,
  int position = 0,
  String heading = "INT. HOUSE - DAY",
  String? sceneNumber,
  List<OcptBreakdownTag> tags = const [],
}) => OcptBreakdownScene(
  id: id,
  position: position,
  heading: heading,
  sceneNumber: sceneNumber,
  charStart: 0,
  charEnd: 40,
  status: OcptBreakdownSceneStatus.toDo,
  notes: "",
  tags: tags,
);

/// Builds a live tag pointing at [targetKind]/[targetId], the passage [taggedText].
OcptBreakdownTag _buildTag({
  required String id,
  required String sceneId,
  required OcptBreakdownTargetKind targetKind,
  required String targetId,
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

/// Builds a suggested occurrence of element-1, in [sceneId], the passage [text].
OcptBreakdownSuggestion _buildSuggestion({required String sceneId, required String text}) =>
    OcptBreakdownSuggestion(
      targetKind: OcptBreakdownTargetKind.element,
      targetId: "element-1",
      sceneId: sceneId,
      startOffset: 0,
      endOffset: text.length,
      text: text,
    );

/// Builds an element target, its category and status overridable.
OcptBreakdownTarget _buildElementTarget({
  String id = "element-1",
  String name = "Desk lamp",
  OcptElementCategory category = OcptElementCategory.prop,
  OcptElementStatus status = OcptElementStatus.toFind,
  List<String> sceneIds = const ["scene-1"],
}) => OcptBreakdownTarget(
  kind: OcptBreakdownTargetKind.element,
  id: id,
  name: name,
  category: category,
  status: status,
  sceneIds: sceneIds,
  occurrenceCount: sceneIds.length,
);

/// Builds a role target: no category, no status.
OcptBreakdownTarget _buildRoleTarget({
  String id = "role-1",
  String name = "LÉA",
  List<String> sceneIds = const ["scene-1"],
}) => OcptBreakdownTarget(
  kind: OcptBreakdownTargetKind.role,
  id: id,
  name: name,
  category: null,
  status: null,
  sceneIds: sceneIds,
  occurrenceCount: sceneIds.length,
);

/// Builds the matching [OcptElement] row of [_buildElementTarget]'s default.
OcptElement _buildElement({
  String id = "element-1",
  String name = "Desk lamp",
  OcptElementCategory category = OcptElementCategory.prop,
  OcptElementStatus status = OcptElementStatus.toFind,
  String subCategory = "",
  String quantity = "",
  String notes = "",
  String? ownerPersonId,
  String? broughtByPersonId,
}) => OcptElement(
  id: id,
  category: category,
  subCategory: subCategory,
  name: name,
  code: "",
  quantity: quantity,
  sourceKind: OcptElementSourceKind.owned,
  status: status,
  ownerPersonId: ownerPersonId,
  ownerNotes: "",
  broughtByPersonId: broughtByPersonId,
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
OcptPerson _buildPerson({required String id, String firstName = "Jean", String lastName = "Dupont"}) =>
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

/// The text field of the details field labelled [label] — the labels are rendered upper-cased, and
/// the panel now holds several fields, so no test may reach for `find.byType(TextField).first`.
Finder _fieldLabelled(String label) => find.descendant(
  of: find.ancestor(
    of: find.text(label.toUpperCase()),
    matching: find.byType(OcptResourcesSheetField),
  ),
  matching: find.byType(TextField),
);

void main() {
  testWidgets("an element target shows its status, category and details sections", (tester) async {
    await _useTallSurface(tester);
    final target = _buildElementTarget();
    final scene = _buildScene(
      id: "scene-1",
      tags: [
        _buildTag(
          id: "tag-1",
          sceneId: "scene-1",
          targetKind: OcptBreakdownTargetKind.element,
          targetId: "element-1",
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: target,
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: [scene],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: (_) {},
          onCategoryChanged: (_) {},
          onFieldChanged: (_, __) {},
          onOwnerChanged: (_) {},
          onBringerChanged: (_) {},
          onOccurrenceSelected: (_) {},
          suggestions: const [],
          onSuggestionAccepted: (_) {},
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () {},
        ),
      ),
    );

    expect(find.text("Desk lamp"), findsOneWidget);
    expect(find.text("Props · 1 scene"), findsOneWidget);
    expect(find.text("Status"), findsOneWidget);
    expect(find.text("Category"), findsOneWidget);
    expect(find.text("Details"), findsOneWidget);
    expect(find.text("Confirmed"), findsOneWidget);
    expect(find.text("Open in Resources"), findsOneWidget);
    expect(find.text("Remove from the breakdown"), findsOneWidget);
  });

  testWidgets("a role target shows no status, category or details section", (tester) async {
    await _useTallSurface(tester);
    final target = _buildRoleTarget();
    final scene = _buildScene(
      id: "scene-1",
      tags: [
        _buildTag(
          id: "tag-1",
          sceneId: "scene-1",
          targetKind: OcptBreakdownTargetKind.role,
          targetId: "role-1",
          taggedText: "LÉA",
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: target,
          element: null,
          owner: null,
          bringer: null,
          people: const [],
          scenes: [scene],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "LÉA",
          // A role's name is the screenplay's, so the panel reads it out rather than offering it.
          onNameChanged: null,
          onStatusChanged: (_) {},
          onCategoryChanged: (_) {},
          onFieldChanged: (_, __) {},
          onOwnerChanged: (_) {},
          onBringerChanged: (_) {},
          onOccurrenceSelected: (_) {},
          suggestions: const [],
          onSuggestionAccepted: (_) {},
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () {},
        ),
      ),
    );

    expect(find.text("LÉA"), findsOneWidget);
    expect(find.text("Characters · 1 scene"), findsOneWidget);
    expect(find.text("Status"), findsNothing);
    expect(find.text("Category"), findsNothing);
    expect(find.text("Details"), findsNothing);
    expect(find.text("Open in Resources"), findsOneWidget);
    expect(find.text("Remove from the breakdown"), findsOneWidget);
  });

  testWidgets("clicking a status chip reports the status", (tester) async {
    await _useTallSurface(tester);
    final reported = <OcptElementStatus>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: const [],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: reported.add,
          onCategoryChanged: (_) {},
          onFieldChanged: (_, __) {},
          onOwnerChanged: (_) {},
          onBringerChanged: (_) {},
          onOccurrenceSelected: (_) {},
          suggestions: const [],
          onSuggestionAccepted: (_) {},
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () {},
        ),
      ),
    );

    await tester.tap(find.text("Confirmed"));
    await tester.pump();

    expect(reported, [OcptElementStatus.confirmed]);
  });

  testWidgets("clicking a category chip reports the category", (tester) async {
    await _useTallSurface(tester);
    final reported = <OcptElementCategory>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: const [],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: (_) {},
          onCategoryChanged: reported.add,
          onFieldChanged: (_, __) {},
          onOwnerChanged: (_) {},
          onBringerChanged: (_) {},
          onOccurrenceSelected: (_) {},
          suggestions: const [],
          onSuggestionAccepted: (_) {},
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () {},
        ),
      ),
    );

    await tester.tap(find.text("Vehicles"));
    await tester.pump();

    expect(reported, [OcptElementCategory.vehicle]);
  });

  testWidgets("typing into the sub-category field reports it", (tester) async {
    await _useTallSurface(tester);
    final reported = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: const [],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: (_) {},
          onCategoryChanged: (_) {},
          onFieldChanged: (field, value) {
            if (field == OcptElementField.subCategory) {
              reported.add(value);
            }
          },
          onOwnerChanged: (_) {},
          onBringerChanged: (_) {},
          onOccurrenceSelected: (_) {},
          suggestions: const [],
          onSuggestionAccepted: (_) {},
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () {},
        ),
      ),
    );

    await tester.enterText(_fieldLabelled("Sub-category"), "1960s");

    expect(reported, ["1960s"]);
  });

  testWidgets("the panel's own title is the name field, and typing into it reports it", (
    tester,
  ) async {
    await _useTallSurface(tester);
    final reported = <String>[];
    var name = "Desk lamp";

    await tester.pumpWidget(
      _wrapInApp(
        StatefulBuilder(
          builder: (context, setState) => OcptBreakdownTargetInspector(
            target: _buildElementTarget(),
            element: _buildElement(),
            owner: null,
            bringer: null,
            people: const [],
            scenes: const [],
            fieldValueOf: (_) => "",
            onBackToSceneRequested: () {},
            // What the bloc's own pending rename gives the panel back while the debounce runs.
            nameValue: name,
            onNameChanged: (value) {
              reported.add(value);
              setState(() => name = value);
            },
            onStatusChanged: (_) {},
            onCategoryChanged: (_) {},
            onFieldChanged: (_, __) {},
            onOwnerChanged: (_) {},
            onBringerChanged: (_) {},
            onOccurrenceSelected: (_) {},
            suggestions: const [],
            onSuggestionAccepted: (_) {},
            onOpenInResourcesRequested: () {},
            onTagRemovalRequested: () {},
          ),
        ),
      ),
    );

    // The title carries the name, and it is the only place the panel does: the details below hold
    // the sub-category, the quantity and the notes, never a second field repeating it.
    final title = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == "Desk lamp",
    );
    expect(title, findsOneWidget);
    expect(_fieldLabelled("Name"), findsNothing);

    await tester.enterText(title, "Queen's crown");
    await tester.pump();

    expect(reported, ["Queen's crown"]);
    expect(find.text("Desk lamp"), findsNothing);
  });

  testWidgets("a target that may not be renamed reads its name out rather than offering it", (
    tester,
  ) async {
    await _useTallSurface(tester);

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: const [],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: null,
          onStatusChanged: (_) {},
          onCategoryChanged: (_) {},
          onFieldChanged: (_, __) {},
          onOwnerChanged: (_) {},
          onBringerChanged: (_) {},
          onOccurrenceSelected: (_) {},
          suggestions: const [],
          onSuggestionAccepted: (_) {},
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () {},
        ),
      ),
    );

    expect(find.text("Desk lamp"), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == "Desk lamp",
      ),
      findsNothing,
    );
  });

  testWidgets("clicking an occurrence row reports its own scene", (tester) async {
    await _useTallSurface(tester);
    final reported = <String>[];
    final scene = _buildScene(
      id: "scene-1",
      sceneNumber: "4",
      tags: [
        _buildTag(
          id: "tag-1",
          sceneId: "scene-1",
          targetKind: OcptBreakdownTargetKind.element,
          targetId: "element-1",
          taggedText: "a lamp",
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: [scene],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: (_) {},
          onCategoryChanged: (_) {},
          onFieldChanged: (_, __) {},
          onOwnerChanged: (_) {},
          onBringerChanged: (_) {},
          onOccurrenceSelected: reported.add,
          suggestions: const [],
          onSuggestionAccepted: (_) {},
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () {},
        ),
      ),
    );

    expect(find.text("…a lamp…"), findsOneWidget);

    await tester.tap(find.text("…a lamp…"));
    await tester.pump();

    expect(reported, ["scene-1"]);
  });

  testWidgets("shows the suggested occurrences section with its own count and rows", (tester) async {
    await _useTallSurface(tester);
    final sceneA = _buildScene(id: "scene-a", sceneNumber: "8", heading: "INT. OFFICE - DAY");
    final sceneB = _buildScene(id: "scene-b", sceneNumber: "14", heading: "INT. BEDROOM - NIGHT");

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: [sceneA, sceneB],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: (_) {},
          onCategoryChanged: (_) {},
          onFieldChanged: (_, __) {},
          onOwnerChanged: (_) {},
          onBringerChanged: (_) {},
          onOccurrenceSelected: (_) {},
          suggestions: [
            _buildSuggestion(sceneId: "scene-a", text: "switches the desk lamp on"),
            _buildSuggestion(sceneId: "scene-b", text: "the desk lamp falls"),
          ],
          onSuggestionAccepted: (_) {},
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () {},
        ),
      ),
    );

    expect(find.text("Suggested occurrences (2)"), findsOneWidget);
    expect(find.text("…switches the desk lamp on…"), findsOneWidget);
    expect(find.text("…the desk lamp falls…"), findsOneWidget);
  });

  testWidgets("the suggested occurrences section is absent when there is nothing to suggest",
      (tester) async {
    await _useTallSurface(tester);

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: const [],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: (_) {},
          onCategoryChanged: (_) {},
          onFieldChanged: (_, __) {},
          onOwnerChanged: (_) {},
          onBringerChanged: (_) {},
          onOccurrenceSelected: (_) {},
          suggestions: const [],
          onSuggestionAccepted: (_) {},
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () {},
        ),
      ),
    );

    expect(find.textContaining("Suggested occurrences"), findsNothing);
  });

  testWidgets("clicking a suggestion's add control reports it, and its row still jumps",
      (tester) async {
    await _useTallSurface(tester);
    final scene = _buildScene(id: "scene-a", sceneNumber: "8", heading: "INT. OFFICE - DAY");
    final suggestion = _buildSuggestion(sceneId: "scene-a", text: "switches the desk lamp on");
    final accepted = <OcptBreakdownSuggestion>[];
    final jumped = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: [scene],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: (_) {},
          onCategoryChanged: (_) {},
          onFieldChanged: (_, __) {},
          onOwnerChanged: (_) {},
          onBringerChanged: (_) {},
          onOccurrenceSelected: jumped.add,
          suggestions: [suggestion],
          onSuggestionAccepted: accepted.add,
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(accepted, [suggestion]);
    expect(jumped, isEmpty);

    await tester.tap(find.text("…switches the desk lamp on…"));
    await tester.pump();

    expect(jumped, ["scene-a"]);
  });

  testWidgets(
    "a read-only panel withholds a suggestion's add control while its row still jumps",
    (tester) async {
      await _useTallSurface(tester);
      final scene = _buildScene(id: "scene-a", sceneNumber: "8", heading: "INT. OFFICE - DAY");
      final suggestion = _buildSuggestion(sceneId: "scene-a", text: "switches the desk lamp on");
      final jumped = <String>[];

      await tester.pumpWidget(
        _wrapInApp(
          OcptBreakdownTargetInspector(
            target: _buildElementTarget(),
            element: _buildElement(),
            owner: null,
            bringer: null,
            people: const [],
            scenes: [scene],
            fieldValueOf: (_) => "",
            onBackToSceneRequested: () {},
            nameValue: "Desk lamp",
            onNameChanged: (_) {},
            onStatusChanged: null,
            onCategoryChanged: null,
            onFieldChanged: null,
            onOwnerChanged: null,
            onBringerChanged: null,
            onOccurrenceSelected: jumped.add,
            suggestions: [suggestion],
            onSuggestionAccepted: null,
            onOpenInResourcesRequested: () {},
            onTagRemovalRequested: null,
            isReadOnly: true,
          ),
        ),
      );

      // The section still reads, but the add control is gone.
      expect(find.text("Suggested occurrences (1)"), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);

      await tester.tap(find.text("…switches the desk lamp on…"));
      await tester.pump();

      expect(jumped, ["scene-a"]);
    },
  );

  testWidgets("shows the owner's name, and picking another one from the menu reports its id",
      (tester) async {
    await _useTallSurface(tester);
    final owner = _buildPerson(id: "person-1", lastName: "Owner");
    final other = _buildPerson(id: "person-2", firstName: "Léa", lastName: "Other");
    final ownerReported = <String?>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: owner,
          bringer: null,
          people: [owner, other],
          scenes: const [],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: (_) {},
          onCategoryChanged: (_) {},
          onFieldChanged: (_, __) {},
          onOwnerChanged: ownerReported.add,
          onBringerChanged: (_) {},
          onOccurrenceSelected: (_) {},
          suggestions: const [],
          onSuggestionAccepted: (_) {},
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () {},
        ),
      ),
    );

    expect(find.text("Jean Owner"), findsOneWidget);

    await tester.tap(find.text("Jean Owner"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Léa Other").last);
    await tester.pumpAndSettle();

    expect(ownerReported, ["person-2"]);
  });

  testWidgets("clicking Open in Resources reports it, even read-only", (tester) async {
    await _useTallSurface(tester);
    var requested = false;

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: const [],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: null,
          onCategoryChanged: null,
          onFieldChanged: null,
          onOwnerChanged: null,
          onBringerChanged: null,
          onOccurrenceSelected: (_) {},
          suggestions: const [],
          onSuggestionAccepted: null,
          onOpenInResourcesRequested: () => requested = true,
          onTagRemovalRequested: null,
          isReadOnly: true,
        ),
      ),
    );

    await tester.tap(find.text("Open in Resources"));
    await tester.pump();

    expect(requested, isTrue);
  });

  testWidgets("the tag-removal action only asks, the confirmation being the mode's own dialog",
      (tester) async {
    await _useTallSurface(tester);
    var requested = false;

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: const [],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: (_) {},
          onCategoryChanged: (_) {},
          onFieldChanged: (_, __) {},
          onOwnerChanged: (_) {},
          onBringerChanged: (_) {},
          onOccurrenceSelected: (_) {},
          suggestions: const [],
          onSuggestionAccepted: (_) {},
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: () => requested = true,
        ),
      ),
    );

    await tester.tap(find.text("Remove from the breakdown"));
    await tester.pumpAndSettle();

    expect(requested, isTrue);
    // The panel itself never shows the question: it is the `OcptConfirmDialog` the mode opens.
    expect(
      find.text("This removes the tag from this scene. The link it created in Resources, if any, stays."),
      findsNothing,
    );
    expect(find.text("Remove from the breakdown"), findsOneWidget);
  });

  testWidgets("a read-only panel withholds every write and hides the removal action",
      (tester) async {
    await _useTallSurface(tester);
    final statusReported = <OcptElementStatus>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownTargetInspector(
          target: _buildElementTarget(),
          element: _buildElement(),
          owner: null,
          bringer: null,
          people: const [],
          scenes: const [],
          fieldValueOf: (_) => "",
          onBackToSceneRequested: () {},
          nameValue: "Desk lamp",
          onNameChanged: (_) {},
          onStatusChanged: null,
          onCategoryChanged: null,
          onFieldChanged: null,
          onOwnerChanged: null,
          onBringerChanged: null,
          onOccurrenceSelected: (_) {},
          suggestions: const [],
          onSuggestionAccepted: null,
          onOpenInResourcesRequested: () {},
          onTagRemovalRequested: null,
          isReadOnly: true,
        ),
      ),
    );

    // The sheet still reads, but nothing writes.
    expect(find.text("Confirmed"), findsOneWidget);
    expect(find.text("Remove from the breakdown"), findsNothing);

    await tester.tap(find.text("Confirmed"));
    await tester.pump();

    expect(statusReported, isEmpty);
  });
}
