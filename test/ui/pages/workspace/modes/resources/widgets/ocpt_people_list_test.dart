// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_people_list.dart';

/// Builds a minimal [OcptPerson] for these tests, every free-text field left blank except the ones
/// a case cares about.
OcptPerson _person({
  required String id,
  String firstName = "",
  String lastName = "",
  int colorIndex = 0,
  List<OcptPersonPosition> positions = const [],
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
  colorIndex: colorIndex,
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
  imageRightsDocument: null,
  photoAssetId: null,
  photo: null,
  notes: "",
  positions: positions,
  skills: const [],
  unavailabilities: const [],
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
  testWidgets("shows a name, initials and positions summary per person", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptPeopleList(
          people: [
            _person(
              id: "p1",
              firstName: "Léa",
              lastName: "Martin",
              positions: const [
                OcptPersonPosition(
                  id: "pos1",
                  personId: "p1",
                  positionId: "director",
                  customLabel: "",
                ),
              ],
            ),
          ],
          selectedPersonId: null,
          searchQuery: "",
          onPersonSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Léa Martin"), findsOneWidget);
    expect(find.text("LM"), findsOneWidget);
    expect(find.text("Director"), findsOneWidget);
  });

  testWidgets("a person with no name shows the unnamed placeholder", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptPeopleList(
          people: [_person(id: "p1")],
          selectedPersonId: null,
          searchQuery: "",
          onPersonSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPeopleList)));
    expect(find.text(tr.resourcesUnnamedPerson), findsOneWidget);
  });

  testWidgets("an empty address book shows the empty hint instead of a list", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptPeopleList(
          people: const [],
          selectedPersonId: null,
          searchQuery: "",
          onPersonSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPeopleList)));
    expect(find.text(tr.resourcesPeopleEmptyHint), findsOneWidget);
  });

  testWidgets("tapping a row reports that person's id", (tester) async {
    String? selected;

    await tester.pumpWidget(
      _wrapInApp(
        OcptPeopleList(
          people: [_person(id: "p1", firstName: "Léa")],
          selectedPersonId: null,
          searchQuery: "",
          onPersonSelected: (personId) => selected = personId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Léa"));
    await tester.pumpAndSettle();

    expect(selected, "p1");
  });

  testWidgets("a query finds an accented name by its unaccented spelling", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptPeopleList(
          people: [
            _person(id: "p1", firstName: "Léa", lastName: "Martin"),
            _person(id: "p2", firstName: "Marc", lastName: "Dupont"),
          ],
          selectedPersonId: null,
          searchQuery: "lea",
          onPersonSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Léa Martin"), findsOneWidget);
    expect(find.text("Marc Dupont"), findsNothing);
  });

  testWidgets("a query also matches a position's localized label", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptPeopleList(
          people: [
            _person(
              id: "p1",
              firstName: "Léa",
              lastName: "Martin",
              positions: const [
                OcptPersonPosition(
                  id: "pos1",
                  personId: "p1",
                  positionId: "director",
                  customLabel: "",
                ),
              ],
            ),
            _person(id: "p2", firstName: "Marc", lastName: "Dupont"),
          ],
          selectedPersonId: null,
          searchQuery: "director",
          onPersonSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Léa Martin"), findsOneWidget);
    expect(find.text("Marc Dupont"), findsNothing);
  });

  testWidgets("a query matching nothing shows the no-match line, not the empty hint", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptPeopleList(
          people: [_person(id: "p1", firstName: "Léa", lastName: "Martin")],
          selectedPersonId: null,
          searchQuery: "zzz",
          onPersonSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptPeopleList)));
    expect(find.text(tr.resourcesSearchNoMatchHint("zzz")), findsOneWidget);
    expect(find.text(tr.resourcesPeopleEmptyHint), findsNothing);
  });
}
