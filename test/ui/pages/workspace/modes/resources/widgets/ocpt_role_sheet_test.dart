// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_removed_role_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_element_link.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_sheet_header.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

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

/// Builds a minimal [OcptRole] for these tests.
OcptRole _role({
  String id = "r1",
  String name = "Le Client",
  String? personId,
  OcptRoleKind kind = OcptRoleKind.speaking,
  bool? isFromScreenplay,
  String? orphanedName,
  String castingNotes = "",
  int number = 3,
  List<String> episodeIds = const [],
}) => OcptRole(
  id: id,
  name: name,
  personId: personId,
  kind: kind,
  isFromScreenplay: isFromScreenplay ?? (kind == OcptRoleKind.speaking),
  orphanedName: orphanedName,
  castingNotes: castingNotes,
  number: number,
  episodeIds: episodeIds,
);

/// Two episodes the episodes-card tests toggle chips over.
const _episodes = [
  OcptEpisode(id: "ep-1", number: 1, title: "Le départ"),
  OcptEpisode(id: "ep-2", number: 2, title: ""),
];

/// An element the things card reads and its picker offers.
OcptElement _element({
  required String id,
  required String name,
  required OcptElementCategory category,
  String code = "",
  List<OcptRoleElementLink> roleLinks = const [],
}) => OcptElement(
  id: id,
  category: category,
  subCategory: "",
  name: name,
  code: code,
  quantity: "",
  sourceKind: OcptElementSourceKind.owned,
  status: OcptElementStatus.toFind,
  ownerPersonId: null,
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
  roleLinks: roleLinks,
);

/// Builds a minimal [OcptRoleCandidate] for these tests.
OcptRoleCandidate _candidate({
  required String id,
  required String roleId,
  required OcptPerson person,
  OcptRoleCandidateStatus status = OcptRoleCandidateStatus.seen,
}) => OcptRoleCandidate(
  id: id,
  roleId: roleId,
  person: person,
  status: status,
  auditionedOn: null,
  notes: "",
);

/// Finds [text] inside the header alone: the cast member's name and the not-cast placeholder both
/// appear a second time in the casting card's own picker.
Finder _inHeader(String text) =>
    find.descendant(of: find.byType(OcptRoleSheetHeader), matching: find.text(text));

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 700, height: 700, child: child)),
);

/// Builds an [OcptRoleSheet] over [role], every callback a no-op unless overridden.
Widget _buildSheet({
  required OcptRole role,
  OcptPerson? castMember,
  List<OcptRole> otherRoles = const [],
  List<OcptPerson> people = const [],
  List<OcptRoleCandidate> candidates = const [],
  List<OcptElement> elements = const [],
  List<OcptEpisode> episodes = const [],
  bool isReadOnly = false,
  void Function(OcptRoleField field, String rawValue)? onFieldChanged,
  ValueChanged<String?>? onCastChanged,
  ValueChanged<OcptRoleKind>? onKindChanged,
  VoidCallback? onDeleteRequested,
  VoidCallback? onOrphanedRoleKept,
  ValueChanged<String>? onPersonSheetOpenRequested,
  ValueChanged<String>? onCandidateAdded,
  void Function(String candidateId, OcptRoleCandidateStatus status)? onCandidateStatusChanged,
  void Function(String candidateId, DateTime? auditionedOn)? onCandidateAuditionDateChanged,
  void Function(String candidateId, String rawValue)? onCandidateNotesChanged,
  ValueChanged<String>? onCandidateRemoveRequested,
  ValueChanged<String>? onElementLinked,
  void Function(String id, String notes)? onRoleElementUpdated,
  ValueChanged<String>? onRoleElementRemoved,
  ValueChanged<Set<String>>? onEpisodesChanged,
}) => _wrapInApp(
  OcptRoleSheet(
    role: role,
    castMember: castMember,
    otherRoles: otherRoles,
    people: people,
    candidates: candidates,
    candidateNotesValueOf: (candidateId) => "",
    elements: elements,
    episodes: episodes,
    removedRoleAlert: OcptRemovedRoleAlert.of(role),
    isReadOnly: isReadOnly,
    fieldValueOf: (field) => switch (field) {
      OcptRoleField.name => role.name,
      OcptRoleField.castingNotes => role.castingNotes,
    },
    onFieldChanged: onFieldChanged ?? (field, rawValue) {},
    onCastChanged: onCastChanged ?? (personId) {},
    onKindChanged: onKindChanged ?? (kind) {},
    onDeleteRequested: onDeleteRequested ?? () {},
    onOrphanedRoleKept: onOrphanedRoleKept ?? () {},
    onPersonSheetOpenRequested: onPersonSheetOpenRequested ?? (personId) {},
    onCandidateAdded: onCandidateAdded ?? (personId) {},
    onCandidateStatusChanged: onCandidateStatusChanged ?? (candidateId, status) {},
    onCandidateAuditionDateChanged: onCandidateAuditionDateChanged ?? (candidateId, auditionedOn) {},
    onCandidateNotesChanged: onCandidateNotesChanged ?? (candidateId, rawValue) {},
    onCandidateRemoveRequested: onCandidateRemoveRequested ?? (candidateId) {},
    onElementLinked: onElementLinked ?? (elementId) {},
    onRoleElementUpdated: onRoleElementUpdated ?? (id, notes) {},
    onRoleElementRemoved: onRoleElementRemoved ?? (id) {},
    onEpisodesChanged: onEpisodesChanged ?? (episodeIds) {},
  ),
);

void main() {
  testWidgets("the header names the role, its rank and its cast member", (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        role: _role(personId: "p1"),
        castMember: _person(id: "p1", firstName: "Léa", lastName: "Martin"),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text("Le Client"), findsOneWidget);
    expect(find.text(tr.resourcesRoleNumberBadge(3)), findsOneWidget);
    expect(find.text("Léa Martin"), findsWidgets);
  });

  testWidgets("the name is read-only for a role the screenplay owns", (tester) async {
    await tester.pumpWidget(_buildSheet(role: _role()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text(tr.resourcesRoleNameFromScreenplayNote), findsOneWidget);
    expect(find.widgetWithText(TextField, "Le Client"), findsNothing);
  });

  testWidgets("an action-detected role reads its own note, naming the action rather than a cue", (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSheet(role: _role(kind: OcptRoleKind.silent, isFromScreenplay: true)),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text(tr.resourcesRoleNameFromActionNote), findsOneWidget);
    expect(find.text(tr.resourcesRoleNameFromScreenplayNote), findsNothing);
    expect(find.widgetWithText(TextField, "Le Client"), findsNothing);
  });

  testWidgets("a hand-added role types its own name", (tester) async {
    final changes = <(OcptRoleField, String)>[];

    await tester.pumpWidget(
      _buildSheet(
        role: _role(name: "Le Serveur", kind: OcptRoleKind.silent, isFromScreenplay: false),
        onFieldChanged: (field, rawValue) => changes.add((field, rawValue)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, "Le Serveur"), "Le Serveur du bar");
    await tester.pumpAndSettle();

    expect(changes, [(OcptRoleField.name, "Le Serveur du bar")]);
  });

  testWidgets("typing casting notes reports them raw", (tester) async {
    final changes = <(OcptRoleField, String)>[];

    await tester.pumpWidget(
      _buildSheet(
        role: _role(castingNotes: "Agent"),
        onFieldChanged: (field, rawValue) => changes.add((field, rawValue)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, "Agent"), "Agent : Dupont");
    await tester.pumpAndSettle();

    expect(changes, [(OcptRoleField.castingNotes, "Agent : Dupont")]);
  });

  testWidgets("the casting card picks a cast member, and uncasts through its own entry", (
    tester,
  ) async {
    final casts = <String?>[];

    await tester.pumpWidget(
      _buildSheet(
        role: _role(personId: "p1"),
        castMember: _person(id: "p1", firstName: "Léa", lastName: "Martin"),
        people: [
          _person(id: "p1", firstName: "Léa", lastName: "Martin"),
          _person(id: "p2", firstName: "Nour", lastName: "Bakri"),
        ],
        onCastChanged: casts.add,
      ),
    );
    await tester.pumpAndSettle();

    // The header's kind picker carries the first arrow, the casting card's the second.
    await tester.tap(find.byIcon(Icons.arrow_drop_down).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Nour Bakri").last);
    await tester.pumpAndSettle();

    expect(casts, ["p2"]);

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    await tester.tap(find.byIcon(Icons.arrow_drop_down).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesRoleNotCast).last);
    await tester.pumpAndSettle();

    expect(casts, ["p2", null]);
  });

  testWidgets("the header picks the role's kind", (tester) async {
    final kinds = <OcptRoleKind>[];

    await tester.pumpWidget(
      _buildSheet(role: _role(), onKindChanged: kinds.add),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    // The kind picker is the header's own, so it carries the first of the two arrows.
    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesRoleKindSilent).last);
    await tester.pumpAndSettle();

    expect(kinds, [OcptRoleKind.silent]);
  });

  testWidgets("the other roles the cast member holds are named", (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        role: _role(personId: "p1"),
        castMember: _person(id: "p1", firstName: "Léa", lastName: "Martin"),
        otherRoles: [_role(id: "r2", name: "La Voisine", personId: "p1", number: 5)],
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text(tr.resourcesRolesListOtherRolesLabel("La Voisine")), findsOneWidget);
  });

  testWidgets("the delete action is withheld while the screenplay still speaks the role", (
    tester,
  ) async {
    await tester.pumpWidget(_buildSheet(role: _role()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    // Deleting it would cost the casting and the notes without removing anything: the next save's
    // reconciliation inserts that character right back.
    expect(find.text(tr.resourcesRoleDeleteAction), findsNothing);
  });

  testWidgets("clicking Delete this role reports it for a hand-added role", (tester) async {
    var deleted = 0;

    await tester.pumpWidget(
      _buildSheet(
        role: _role(kind: OcptRoleKind.extra, isFromScreenplay: false),
        onDeleteRequested: () => deleted++,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    await tester.tap(find.text(tr.resourcesRoleDeleteAction));
    await tester.pumpAndSettle();

    // The sheet only asks: the question itself is the mode's confirmation dialog.
    expect(deleted, 1);
  });

  testWidgets("the delete action is offered for an action-detected role too", (tester) async {
    var deleted = 0;

    await tester.pumpWidget(
      _buildSheet(
        role: _role(kind: OcptRoleKind.silent, isFromScreenplay: true),
        onDeleteRequested: () => deleted++,
      ),
    );
    await tester.pumpAndSettle();

    // Unlike a cued role, the screenplay still naming this one is not what withholds the
    // action: reconcile's rejection rule is exactly what a deletion here is meant to reach.
    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    await tester.tap(find.text(tr.resourcesRoleDeleteAction));
    await tester.pumpAndSettle();

    expect(deleted, 1);
  });

  testWidgets("an orphaned role reports its alert in its own sheet, with both ways out", (
    tester,
  ) async {
    var deleted = 0;
    var kept = 0;

    await tester.pumpWidget(
      _buildSheet(
        role: _role(orphanedName: "LE CLIENT"),
        onDeleteRequested: () => deleted++,
        onOrphanedRoleKept: () => kept++,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text(tr.resourcesRemovedRoleBanner("LE CLIENT")), findsOneWidget);

    // The banner carries the deletion, so the bottom of the sheet does not ask for it again.
    expect(find.text(tr.resourcesRemovedRoleDeleteAction), findsOneWidget);

    await tester.tap(find.text(tr.resourcesRemovedRoleKeepAction));
    await tester.pumpAndSettle();
    expect(kept, 1);

    // The banner's own delete needs no second question: the banner is that question.
    await tester.tap(find.text(tr.resourcesRemovedRoleDeleteAction));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets("a role still spoken in the screenplay reports no alert", (tester) async {
    await tester.pumpWidget(_buildSheet(role: _role()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_off_outlined), findsNothing);
  });

  testWidgets("the whole cast member line opens their sheet, name included", (tester) async {
    final opened = <String>[];

    await tester.pumpWidget(
      _buildSheet(
        role: _role(personId: "p1"),
        castMember: _person(id: "p1", firstName: "Léa", lastName: "Martin"),
        onPersonSheetOpenRequested: opened.add,
      ),
    );
    await tester.pumpAndSettle();

    // The name is the target one actually aims at, not only the 14 px arrow beside it.
    await tester.tap(_inHeader("Léa Martin"));
    await tester.pumpAndSettle();
    expect(opened, ["p1"]);

    await tester.tap(find.byIcon(Icons.north_east));
    await tester.pumpAndSettle();
    expect(opened, ["p1", "p1"]);
  });

  testWidgets("an uncast role offers nothing to open", (tester) async {
    await tester.pumpWidget(_buildSheet(role: _role()));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.byIcon(Icons.north_east), findsNothing);
    expect(_inHeader(tr.resourcesRoleNotCast), findsOneWidget);
  });

  testWidgets("every write affordance disappears when read-only", (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        role: _role(kind: OcptRoleKind.silent, isFromScreenplay: false, personId: "p1"),
        castMember: _person(id: "p1", firstName: "Léa", lastName: "Martin"),
        people: [_person(id: "p1", firstName: "Léa", lastName: "Martin")],
        isReadOnly: true,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));

    // No dropdown arrow on either picker: withheld, not disabled.
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    // No delete action, even for a role that could be deleted.
    expect(find.text(tr.resourcesRoleDeleteAction), findsNothing);
    // The name field still reads its value out, but not through a writable control.
    final nameField = tester.widget<TextField>(find.widgetWithText(TextField, "Le Client"));
    expect(nameField.readOnly, isTrue);
    // What only reads stays: the ↗ affordance still opens the cast member's sheet.
    expect(find.byIcon(Icons.north_east), findsOneWidget);
  });

  testWidgets("the things card reads this role's links, grouped by category", (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        role: _role(),
        elements: [
          _element(
            id: "e1",
            name: "Manteau rouge",
            code: "COS-1",
            category: OcptElementCategory.costume,
            roleLinks: const [
              OcptRoleElementLink(id: "l1", roleId: "r1", notes: "Taché"),
            ],
          ),
          _element(
            id: "e2",
            name: "Valise",
            code: "PRP-1",
            category: OcptElementCategory.prop,
            // Linked to another role: this card must not show it.
            roleLinks: const [OcptRoleElementLink(id: "l2", roleId: "r9", notes: "")],
          ),
          _element(id: "e3", name: "Perruque", category: OcptElementCategory.makeup),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));

    expect(find.text(tr.resourcesRoleElementsCardTitle), findsOneWidget);
    expect(find.text("COS-1 · Manteau rouge"), findsOneWidget);
    // The category heading above it, and no heading for a category holding nothing.
    expect(
      find.text(ocptElementCategoryLabel(tr, OcptElementCategory.costume).toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(ocptElementCategoryLabel(tr, OcptElementCategory.prop).toUpperCase()),
      findsNothing,
    );
    // Another role's link, and an element nobody wears, are both absent.
    expect(find.text("PRP-1 · Valise"), findsNothing);
    expect(find.text("Perruque"), findsNothing);
    // The link's own note is in its row.
    expect(find.widgetWithText(TextField, "Taché"), findsOneWidget);
  });

  testWidgets("the picker offers every unlinked element, whatever its category", (tester) async {
    final linked = <String>[];

    await tester.pumpWidget(
      _buildSheet(
        role: _role(),
        elements: [
          _element(
            id: "e1",
            name: "Manteau rouge",
            category: OcptElementCategory.costume,
            roleLinks: const [OcptRoleElementLink(id: "l1", roleId: "r1", notes: "")],
          ),
          _element(id: "e2", name: "Valise", category: OcptElementCategory.prop),
          _element(id: "e3", name: "Voiture", category: OcptElementCategory.vehicle),
        ],
        onElementLinked: linked.add,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    await tester.tap(find.text(tr.resourcesAddElementToRoleAction));
    await tester.pumpAndSettle();

    /// Finds [text] among the picker's own entries: the linked element's name also reads out in
    /// its row of the card, which is not what this test is about.
    Finder inMenu(String text) =>
        find.descendant(of: find.byType(PopupMenuItem<String>), matching: find.text(text));

    // The one already linked is not offered again; a vehicle is, the table knowing no category
    // restriction.
    expect(inMenu("Manteau rouge"), findsNothing);
    expect(inMenu("Valise"), findsOneWidget);
    expect(inMenu("Voiture"), findsOneWidget);

    await tester.tap(inMenu("Voiture"));
    await tester.pumpAndSettle();
    expect(linked, ["e3"]);
  });

  testWidgets("a things row unlinks its element, the catalogue untouched", (tester) async {
    final removed = <String>[];

    await tester.pumpWidget(
      _buildSheet(
        role: _role(),
        elements: [
          _element(
            id: "e1",
            name: "Manteau rouge",
            category: OcptElementCategory.costume,
            roleLinks: const [OcptRoleElementLink(id: "l1", roleId: "r1", notes: "")],
          ),
        ],
        onRoleElementRemoved: removed.add,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(removed, ["l1"]);
  });

  testWidgets("the things card offers nothing to write when read-only", (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        role: _role(),
        elements: [
          _element(
            id: "e1",
            name: "Manteau rouge",
            category: OcptElementCategory.costume,
            roleLinks: const [OcptRoleElementLink(id: "l1", roleId: "r1", notes: "Taché")],
          ),
          _element(id: "e2", name: "Valise", category: OcptElementCategory.prop),
        ],
        isReadOnly: true,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));

    // What only reads stays: the link and its note are still there…
    expect(find.text("Manteau rouge"), findsOneWidget);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, "Taché")).readOnly, isTrue);
    // …while the picker and the unlink control are withheld, not disabled.
    expect(find.text(tr.resourcesAddElementToRoleAction), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets("the episodes card is absent on a single-episode project", (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        role: _role(episodeIds: const ["ep-1"]),
        episodes: const [OcptEpisode(id: "ep-1", number: 1, title: "")],
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text(tr.resourcesRoleEpisodesCardTitle), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets("a from-screenplay role's chips are present and not tappable", (tester) async {
    await tester.pumpWidget(
      _buildSheet(role: _role(episodeIds: const ["ep-1"]), episodes: _episodes),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text(tr.resourcesRoleEpisodesCardTitle), findsOneWidget);
    expect(find.text("1. Le départ"), findsOneWidget);
    expect(find.text(tr.workspaceEpisodeUntitledLabel(2)), findsOneWidget);

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(chips, hasLength(2));
    for (final chip in chips) {
      expect(chip.onSelected, isNull);
    }
  });

  testWidgets("a hand-added role's chips toggle and report the new set", (tester) async {
    final reported = <Set<String>>[];

    await tester.pumpWidget(
      _buildSheet(
        role: _role(kind: OcptRoleKind.extra, isFromScreenplay: false, episodeIds: const ["ep-1"]),
        episodes: _episodes,
        onEpisodesChanged: reported.add,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));

    // Episode 2 isn't checked yet: toggling it on adds it to the set already holding episode 1.
    await tester.tap(find.text(tr.workspaceEpisodeUntitledLabel(2)));
    await tester.pumpAndSettle();
    expect(reported, [
      {"ep-1", "ep-2"},
    ]);

    // Episode 1 is checked: toggling it off drops it, whatever [reported] already holds.
    await tester.tap(find.text("1. Le départ"));
    await tester.pumpAndSettle();
    expect(reported, [
      {"ep-1", "ep-2"},
      <String>{},
    ]);
  });

  testWidgets("a read-only preview withholds the episodes card's affordance", (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        role: _role(kind: OcptRoleKind.extra, isFromScreenplay: false, episodeIds: const ["ep-1"]),
        episodes: _episodes,
        isReadOnly: true,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    // What only reads stays: the card and its chips are still there…
    expect(find.text(tr.resourcesRoleEpisodesCardTitle), findsOneWidget);
    expect(find.text("1. Le départ"), findsOneWidget);
    // …while every chip is withheld, not disabled.
    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(chips, hasLength(2));
    for (final chip in chips) {
      expect(chip.onSelected, isNull);
    }
  });

  testWidgets("the candidates card sits between the casting and the episodes cards", (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSheet(
        role: _role(episodeIds: const ["ep-1"]),
        candidates: [
          _candidate(id: "c1", roleId: "r1", person: _person(id: "p1", firstName: "Léa")),
        ],
        episodes: _episodes,
        elements: [
          _element(
            id: "e1",
            name: "Manteau rouge",
            category: OcptElementCategory.costume,
            roleLinks: const [OcptRoleElementLink(id: "l1", roleId: "r1", notes: "")],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheet)));
    expect(find.text(tr.resourcesRoleCandidatesCardTitle), findsOneWidget);
    expect(find.text("Léa"), findsOneWidget);

    double yOf(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(
      yOf(tr.resourcesRoleCastingCardTitle),
      lessThan(yOf(tr.resourcesRoleCandidatesCardTitle)),
    );
    expect(
      yOf(tr.resourcesRoleCandidatesCardTitle),
      lessThan(yOf(tr.resourcesRoleEpisodesCardTitle)),
    );
    expect(
      yOf(tr.resourcesRoleEpisodesCardTitle),
      lessThan(yOf(tr.resourcesRoleElementsCardTitle)),
    );
  });
}
