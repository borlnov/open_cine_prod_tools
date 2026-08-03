// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_locations_list.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a dock-sized
/// box.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 280, child: child)),
);

/// A set carrying nothing but a name, enough to be counted on a row.
OcptSet _set(String id) => OcptSet(
  id: id,
  locationId: "l1",
  code: "",
  name: id,
  notes: "",
  sceneIds: const [],
);

/// A location with only the fields a row of the list reads.
OcptLocation _location({
  required String id,
  required String name,
  String city = "",
  OcptPermitStatus permitStatus = OcptPermitStatus.notNeeded,
  List<OcptSet> sets = const [],
}) => OcptLocation(
  id: id,
  name: name,
  colorIndex: 0,
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: city,
  region: "",
  country: "",
  latitude: null,
  longitude: null,
  contactPersonId: null,
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
  availabilities: const [],
);

void main() {
  /// Pumps the list over [locations].
  Future<void> pumpList(
    WidgetTester tester, {
    required List<OcptLocation> locations,
    String? selectedLocationId,
    ValueChanged<String>? onLocationSelected,
  }) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptLocationsList(
          locations: locations,
          selectedLocationId: selectedLocationId,
          onLocationSelected: onLocationSelected ?? (locationId) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("a row reads its name, its city, its set count and its permit", (tester) async {
    await pumpList(
      tester,
      locations: [
        _location(
          id: "l1",
          name: "La maison des Pains",
          city: "Lyon",
          permitStatus: OcptPermitStatus.granted,
          sets: [_set("s1"), _set("s2")],
        ),
      ],
    );

    expect(find.text("La maison des Pains"), findsOneWidget);
    expect(find.text("Lyon · 2 sets"), findsOneWidget);
    expect(find.text("Permit granted"), findsOneWidget);
  });

  testWidgets("a location with no city reads its set count alone", (tester) async {
    await pumpList(tester, locations: [_location(id: "l1", name: "Le hangar")]);

    // No leading separator: it would read as a word missing rather than as an empty city.
    expect(find.text("0 sets"), findsOneWidget);
  });

  testWidgets("a location with no name yet reads as unnamed rather than blank", (tester) async {
    await pumpList(tester, locations: [_location(id: "l1", name: "")]);

    expect(find.text("Unnamed location"), findsOneWidget);
  });

  testWidgets("clicking a row selects it", (tester) async {
    String? selectedLocationId;

    await pumpList(
      tester,
      locations: [
        _location(id: "l1", name: "La maison des Pains"),
        _location(id: "l2", name: "Le hangar"),
      ],
      onLocationSelected: (locationId) => selectedLocationId = locationId,
    );

    await tester.tap(find.text("Le hangar"));
    await tester.pumpAndSettle();

    expect(selectedLocationId, "l2");
  });

  testWidgets("an empty catalogue shows the hint rather than a bare list", (tester) async {
    await pumpList(tester, locations: const []);

    expect(find.text("No location yet. Add the first place the film is shot in."), findsOneWidget);
  });
}
