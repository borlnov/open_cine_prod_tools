// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_roles_list.dart';

/// Builds a minimal [OcptPerson] for these tests, every free-text field left blank except the ones
/// a case cares about.
OcptPerson _person({required String id, String firstName = "", String lastName = "", int colorIndex = 0}) =>
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
      colorIndex: colorIndex,
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
  required String id,
  String name = "",
  String? personId,
  OcptRoleKind kind = OcptRoleKind.speaking,
  String? orphanedName,
  int number = 1,
  List<String> episodeIds = const [],
}) => OcptRole(
  id: id,
  name: name,
  personId: personId,
  kind: kind,
  isFromScreenplay: kind == OcptRoleKind.speaking,
  orphanedName: orphanedName,
  castingNotes: "",
  number: number,
  episodeIds: episodeIds,
);

/// Builds a minimal [OcptRoleCandidate] for these tests, seen for role [roleId].
OcptRoleCandidate _candidate({
  required String id,
  required String roleId,
  OcptRoleCandidateStatus status = OcptRoleCandidateStatus.seen,
}) => OcptRoleCandidate(
  id: id,
  roleId: roleId,
  person: _person(id: "candidate-person-$id"),
  status: status,
  auditionedOn: null,
  notes: "",
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
  home: Scaffold(body: SizedBox(width: 260, height: 400, child: child)),
);

void main() {
  testWidgets("a cast role shows its name and its cast member", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [_role(id: "r1", name: "Le Client", personId: "p1")],
          people: [_person(id: "p1", firstName: "Léa", lastName: "Martin")],
          candidatesByRoleId: const {},
          episodes: const [],
          selectedRoleId: null,
          searchQuery: "",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Le Client"), findsOneWidget);
    expect(find.text("Léa Martin"), findsOneWidget);
  });

  testWidgets("an uncast role shows the not-cast placeholder", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [_role(id: "r1", name: "Le Client")],
          people: const [],
          candidatesByRoleId: const {},
          episodes: const [],
          selectedRoleId: null,
          searchQuery: "",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
    expect(find.text(tr.resourcesRoleNotCast), findsOneWidget);
  });

  testWidgets("a cast member holding another role shows it on a muted line", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [
            _role(id: "r1", name: "Le Client", personId: "p1"),
            _role(id: "r2", name: "Le Voisin", personId: "p1", number: 2),
          ],
          people: [_person(id: "p1", firstName: "Léa", lastName: "Martin")],
          candidatesByRoleId: const {},
          episodes: const [],
          selectedRoleId: null,
          searchQuery: "",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
    expect(find.text(tr.resourcesRolesListOtherRolesLabel("Le Voisin")), findsOneWidget);
    expect(find.text(tr.resourcesRolesListOtherRolesLabel("Le Client")), findsOneWidget);
  });

  testWidgets("an empty cast shows the empty hint instead of a list", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: const [],
          people: const [],
          candidatesByRoleId: const {},
          episodes: const [],
          selectedRoleId: null,
          searchQuery: "",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
    expect(find.text(tr.resourcesRolesEmptyHint), findsOneWidget);
  });

  testWidgets("an orphaned role is flagged, an ordinary one is not", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [
            _role(id: "r1", name: "Le Client", orphanedName: "LE CLIENT"),
            _role(id: "r2", name: "Le Voisin", number: 2),
          ],
          people: const [],
          candidatesByRoleId: const {},
          episodes: const [],
          selectedRoleId: null,
          searchQuery: "",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The alert itself lives in the role's own sheet: this list only says which one to go and read.
    expect(find.byIcon(Icons.person_off_outlined), findsOneWidget);
  });

  testWidgets("tapping a row reports that role's id", (tester) async {
    String? selected;

    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [_role(id: "r1", name: "Le Client")],
          people: const [],
          candidatesByRoleId: const {},
          episodes: const [],
          selectedRoleId: null,
          searchQuery: "",
          onRoleSelected: (roleId) => selected = roleId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Le Client"));
    await tester.pumpAndSettle();

    expect(selected, "r1");
  });

  testWidgets("a query finds a role by its cast member's name", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [
            _role(id: "r1", name: "Le Client", personId: "p1"),
            _role(id: "r2", name: "Le Voisin", number: 2),
          ],
          people: [_person(id: "p1", firstName: "Léa", lastName: "Martin")],
          candidatesByRoleId: const {},
          episodes: const [],
          selectedRoleId: null,
          searchQuery: "martin",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Le Client"), findsOneWidget);
    expect(find.text("Le Voisin"), findsNothing);
  });

  testWidgets("a query finds a role by its orphaned name", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [
            _role(id: "r1", name: "Le Client", orphanedName: "LE VIEUX CLIENT"),
            _role(id: "r2", name: "Le Voisin", number: 2),
          ],
          people: const [],
          candidatesByRoleId: const {},
          episodes: const [],
          selectedRoleId: null,
          searchQuery: "vieux",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Le Client"), findsOneWidget);
    expect(find.text("Le Voisin"), findsNothing);
  });

  testWidgets("a query matching nothing shows the no-match line, not the empty hint", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [_role(id: "r1", name: "Le Client")],
          people: const [],
          candidatesByRoleId: const {},
          episodes: const [],
          selectedRoleId: null,
          searchQuery: "zzz",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
    expect(find.text(tr.resourcesSearchNoMatchHint("zzz")), findsOneWidget);
    expect(find.text(tr.resourcesRolesEmptyHint), findsNothing);
  });

  testWidgets("a role's episodes line shows its printed numbers, own order, comma-separated", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [_role(id: "r1", name: "Le Client", episodeIds: const ["ep-1", "ep-5", "ep-2"])],
          people: const [],
          candidatesByRoleId: const {},
          episodes: const [
            OcptEpisode(id: "ep-1", number: 1, title: ""),
            OcptEpisode(id: "ep-2", number: 2, title: ""),
            OcptEpisode(id: "ep-5", number: 5, title: ""),
          ],
          selectedRoleId: null,
          searchQuery: "",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
    expect(find.text(tr.resourcesRolesListEpisodesLabel("1, 5, 2")), findsOneWidget);
  });

  testWidgets("a single-episode project draws no episodes line", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [_role(id: "r1", name: "Le Client", episodeIds: const ["ep-1"])],
          people: const [],
          candidatesByRoleId: const {},
          episodes: const [OcptEpisode(id: "ep-1", number: 1, title: "")],
          selectedRoleId: null,
          searchQuery: "",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
    // The role is named in episode 1, but a single-episode project names no episode anywhere.
    expect(find.text(tr.resourcesRolesListEpisodesLabel("1")), findsNothing);
  });

  testWidgets("a cast role wears the `Cast` pill", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [_role(id: "r1", name: "Le Client", personId: "p1")],
          people: [_person(id: "p1", firstName: "Léa", lastName: "Martin")],
          candidatesByRoleId: const {},
          episodes: const [],
          selectedRoleId: null,
          searchQuery: "",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
    expect(find.text(tr.resourcesRolesListCastPill), findsOneWidget);
    expect(find.text(tr.resourcesRolesListCandidatesPill(0)), findsNothing);
  });

  testWidgets(
    "an uncast role wears the `{n} leads` pill, counting its leads alone",
    (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          OcptRolesList(
            roles: [_role(id: "r1", name: "Le Client")],
            people: const [],
            candidatesByRoleId: {
              "r1": [
                _candidate(id: "c1", roleId: "r1"),
                _candidate(id: "c2", roleId: "r1"),
                // Turned down: still on the sheet, no longer a possibility, so out of the count.
                _candidate(
                  id: "c3",
                  roleId: "r1",
                  status: OcptRoleCandidateStatus.notRetained,
                ),
              ],
            },
            episodes: const [],
            selectedRoleId: null,
            searchQuery: "",
            onRoleSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
      expect(find.text(tr.resourcesRolesListCandidatesPill(2)), findsOneWidget);
      expect(find.text(tr.resourcesRolesListCastPill), findsNothing);
      expect(find.text(tr.resourcesRolesListNoLeadPill), findsNothing);
    },
  );

  testWidgets(
    "an uncast role whose every candidate has fallen out wears the `No lead` pill",
    (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          OcptRolesList(
            roles: [_role(id: "r1", name: "Le Client")],
            people: const [],
            candidatesByRoleId: {
              "r1": [
                _candidate(id: "c1", roleId: "r1", status: OcptRoleCandidateStatus.declined),
                _candidate(
                  id: "c2",
                  roleId: "r1",
                  status: OcptRoleCandidateStatus.unavailable,
                ),
              ],
            },
            episodes: const [],
            selectedRoleId: null,
            searchQuery: "",
            onRoleSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nobody is left, and the row says so rather than reading like a part nobody has started —
      // the two states look identical on every other line of it.
      final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
      expect(find.text(tr.resourcesRolesListNoLeadPill), findsOneWidget);
      expect(find.text(tr.resourcesRolesListCandidatesPill(0)), findsNothing);
      expect(find.text(tr.resourcesRolesListCastPill), findsNothing);
    },
  );

  testWidgets("an uncast role with no candidate wears no pill at all", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptRolesList(
          roles: [_role(id: "r1", name: "Le Client")],
          people: const [],
          candidatesByRoleId: const {},
          episodes: const [],
          selectedRoleId: null,
          searchQuery: "",
          onRoleSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptRolesList)));
    expect(find.text(tr.resourcesRolesListCastPill), findsNothing);
    expect(find.text(tr.resourcesRolesListCandidatesPill(0)), findsNothing);
  });
}
