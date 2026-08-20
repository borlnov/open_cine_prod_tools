// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_sheet_candidates_card.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// Builds a minimal [OcptPerson] for these tests, every free-text field left blank except the ones
/// a case cares about.
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

/// Builds a minimal [OcptRoleCandidate] for these tests.
OcptRoleCandidate _candidate({
  required String id,
  required OcptPerson person,
  OcptRoleCandidateStatus status = OcptRoleCandidateStatus.seen,
  DateTime? auditionedOn,
  String notes = "",
}) => OcptRoleCandidate(
  id: id,
  roleId: "r1",
  person: person,
  status: status,
  auditionedOn: auditionedOn,
  notes: notes,
);

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 500, height: 700, child: child)),
);

/// Builds an [OcptRoleSheetCandidatesCard], every callback a no-op unless overridden.
Widget _buildCard({
  required List<OcptRoleCandidate> candidates,
  List<OcptPerson> people = const [],
  String Function(String candidateId)? notesValueOf,
  ValueChanged<String>? onCandidateAdded,
  void Function(String candidateId, OcptRoleCandidateStatus status)? onStatusChanged,
  void Function(String candidateId, DateTime? auditionedOn)? onAuditionDateChanged,
  void Function(String candidateId, String rawValue)? onNotesChanged,
  ValueChanged<String>? onCandidateRemoveRequested,
}) => _wrapInApp(
  OcptRoleSheetCandidatesCard(
    candidates: candidates,
    people: people,
    notesValueOf: notesValueOf ?? (candidateId) => "",
    onCandidateAdded: onCandidateAdded,
    onStatusChanged: onStatusChanged,
    onAuditionDateChanged: onAuditionDateChanged,
    onNotesChanged: onNotesChanged,
    onCandidateRemoveRequested: onCandidateRemoveRequested,
  ),
);

void main() {
  testWidgets("the retained candidacy is drawn first, the rest keep their own order", (
    tester,
  ) async {
    final personA = _person(id: "pa", firstName: "Alice", lastName: "Adam");
    final personB = _person(id: "pb", firstName: "Bruno", lastName: "Bernard");
    final personC = _person(id: "pc", firstName: "Chloé", lastName: "Chevalier");

    await tester.pumpWidget(
      _buildCard(
        candidates: [
          _candidate(id: "c-b", person: personB),
          _candidate(id: "c-c", person: personC, status: OcptRoleCandidateStatus.retained),
          _candidate(id: "c-a", person: personA),
        ],
      ),
    );
    await tester.pumpAndSettle();

    double yOf(String text) => tester.getTopLeft(find.text(text)).dy;
    // The retained one (Chloé) comes first, then the two others in the order they were given.
    expect(yOf("Chloé Chevalier"), lessThan(yOf("Bruno Bernard")));
    expect(yOf("Bruno Bernard"), lessThan(yOf("Alice Adam")));
  });

  testWidgets("a candidacy's status pill reads its own label", (tester) async {
    final person = _person(id: "p1", firstName: "Léa", lastName: "Marchand");

    await tester.pumpWidget(
      _buildCard(
        candidates: [
          _candidate(id: "c1", person: person, status: OcptRoleCandidateStatus.shortlisted),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheetCandidatesCard)));
    expect(
      find.text(ocptRoleCandidateStatusLabel(tr, OcptRoleCandidateStatus.shortlisted)),
      findsOneWidget,
    );
  });

  testWidgets("the menu offers every status once, retaining among them and only there", (
    tester,
  ) async {
    final retained = _person(id: "p1", firstName: "Léa", lastName: "Marchand");
    final seen = _person(id: "p2", firstName: "Paul", lastName: "Ilyes");

    await tester.pumpWidget(
      _buildCard(
        candidates: [
          _candidate(id: "c1", person: retained, status: OcptRoleCandidateStatus.retained),
          _candidate(id: "c2", person: seen),
        ],
        onStatusChanged: (candidateId, status) {},
        onCandidateRemoveRequested: (candidateId) {},
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheetCandidatesCard)));
    final menus = find.byIcon(Icons.more_vert);
    expect(menus, findsNWidgets(2));

    // The retained row is drawn first, so its own menu is the first icon. Every status is offered,
    // whatever this row currently holds — a status list is a vocabulary, not a workflow — and each
    // is offered exactly **once**: retaining is picking `Retained`, never a second entry beside it.
    // Scoped to the menu's own entries, the rows' status pills carrying the same words behind it.
    await tester.tap(menus.first);
    await tester.pumpAndSettle();
    for (final status in OcptRoleCandidateStatus.values) {
      expect(
        find.descendant(
          of: find.byType(PopupMenuItem<VoidCallback>),
          matching: find.text(ocptRoleCandidateStatusLabel(tr, status)),
        ),
        findsOneWidget,
        reason: "for $status, on the retained row",
      );
    }
    expect(find.text(tr.resourcesRemoveCandidateAction), findsOneWidget);
  });

  testWidgets("picking the retained status reports it, exactly as any other status is", (
    tester,
  ) async {
    final reported = <(String, OcptRoleCandidateStatus)>[];
    final person = _person(id: "p1", firstName: "Léa", lastName: "Marchand");

    await tester.pumpWidget(
      _buildCard(
        candidates: [_candidate(id: "c1", person: person)],
        onStatusChanged: (candidateId, status) => reported.add((candidateId, status)),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheetCandidatesCard)));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(PopupMenuItem<VoidCallback>),
        matching: find.text(ocptRoleCandidateStatusLabel(tr, OcptRoleCandidateStatus.retained)),
      ),
    );
    await tester.pumpAndSettle();

    // The card only ever asks: what retaining *does* to `roles.personId`, and to whoever was
    // retained before, is `OcptRoleCandidatesService`'s and is tested there.
    expect(reported, [("c1", OcptRoleCandidateStatus.retained)]);
  });

  testWidgets("typing the note reports it raw, riding no local debounce", (tester) async {
    final reported = <(String, String)>[];
    final person = _person(id: "p1", firstName: "Léa", lastName: "Marchand");

    await tester.pumpWidget(
      _buildCard(
        candidates: [_candidate(id: "c1", person: person)],
        onNotesChanged: (candidateId, rawValue) => reported.add((candidateId, rawValue)),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheetCandidatesCard)));
    // No note yet: the field starts folded, so the toggle has to be opened first.
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text(tr.resourcesRoleCandidateNotesLabel.toUpperCase()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), "Bon jeu, disponible en mars");
    await tester.pumpAndSettle();

    expect(reported, [("c1", "Bon jeu, disponible en mars")]);
  });

  testWidgets("a candidacy already carrying a note starts unfolded", (tester) async {
    final person = _person(id: "p1", firstName: "Léa", lastName: "Marchand");

    await tester.pumpWidget(
      _buildCard(
        candidates: [_candidate(id: "c1", person: person, notes: "Très bon jeu")],
        notesValueOf: (candidateId) => "Très bon jeu",
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, "Très bon jeu"), findsOneWidget);
  });

  testWidgets("the picker excludes the people already candidates for this role", (tester) async {
    final added = <String>[];
    final alreadyIn = _person(id: "p1", firstName: "Léa", lastName: "Marchand");
    final notYetIn = _person(id: "p2", firstName: "Paul", lastName: "Ilyes");

    await tester.pumpWidget(
      _buildCard(
        candidates: [_candidate(id: "c1", person: alreadyIn)],
        people: [alreadyIn, notYetIn],
        onCandidateAdded: added.add,
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheetCandidatesCard)));
    await tester.tap(find.text(tr.resourcesAddCandidateToRoleAction));
    await tester.pumpAndSettle();

    Finder inMenu(String text) =>
        find.descendant(of: find.byType(PopupMenuItem<String>), matching: find.text(text));

    expect(inMenu("Paul Ilyes"), findsOneWidget);
    expect(inMenu("Léa Marchand"), findsNothing);

    await tester.tap(inMenu("Paul Ilyes"));
    await tester.pumpAndSettle();
    expect(added, ["p2"]);
  });

  testWidgets("the picker renders nothing once there is nobody left to offer", (tester) async {
    final onlyPerson = _person(id: "p1", firstName: "Léa", lastName: "Marchand");

    await tester.pumpWidget(
      _buildCard(
        candidates: [_candidate(id: "c1", person: onlyPerson)],
        people: [onlyPerson],
        onCandidateAdded: (personId) {},
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheetCandidatesCard)));
    expect(find.text(tr.resourcesAddCandidateToRoleAction), findsNothing);
  });

  testWidgets("the empty hint shows while nobody has been seen yet", (tester) async {
    await tester.pumpWidget(_buildCard(candidates: const []));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheetCandidatesCard)));
    expect(find.text(tr.resourcesRoleNoCandidateHint), findsOneWidget);
  });

  testWidgets("every affordance is withheld when every callback is null", (tester) async {
    final person = _person(id: "p1", firstName: "Léa", lastName: "Marchand");

    await tester.pumpWidget(
      _buildCard(
        candidates: [
          _candidate(
            id: "c1",
            person: person,
            status: OcptRoleCandidateStatus.retained,
            auditionedOn: DateTime(2026, 3, 12),
            notes: "Très bon jeu",
          ),
        ],
        people: [person, _person(id: "p2", firstName: "Paul", lastName: "Ilyes")],
        notesValueOf: (candidateId) => "Très bon jeu",
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRoleSheetCandidatesCard)));

    // No `+ Candidate` picker…
    expect(find.text(tr.resourcesAddCandidateToRoleAction), findsNothing);
    // …no `⋮` menu…
    expect(find.byIcon(Icons.more_vert), findsNothing);
    // …no calendar affordance on the audition date field…
    expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
    // …and the note field, though still shown (a note already exists), reads out only.
    final noteField = tester.widget<TextField>(find.widgetWithText(TextField, "Très bon jeu"));
    expect(noteField.readOnly, isTrue);
    // What only reads stays: the name, the pill and the date value are still on screen.
    expect(find.text("Léa Marchand"), findsOneWidget);
    expect(
      find.text(ocptRoleCandidateStatusLabel(tr, OcptRoleCandidateStatus.retained)),
      findsOneWidget,
    );
  });
}
