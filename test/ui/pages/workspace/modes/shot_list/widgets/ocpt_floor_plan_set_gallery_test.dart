// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_set_gallery.dart';

/// A location holding [sets], every other field at a plain empty default — the fixture builder
/// every test below shares.
OcptLocation _location({required String id, required String name, List<OcptSet> sets = const []}) =>
    OcptLocation(
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
      permitStatus: OcptPermitStatus.toRequest,
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

OcptSet _set({required String id, required String name, String code = ""}) => OcptSet(
  id: id,
  locationId: "loc",
  code: code,
  name: name,
  notes: "",
  sceneIds: const [],
);

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(1400, 900)}) async {
  tester.view.physicalSize = size;
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
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets("shows the gallery's own title and one card per set, across every location", (
    tester,
  ) async {
    final locations = [
      _location(id: "loc-1", name: "Maison", sets: [_set(id: "set-a", name: "Cuisine")]),
      _location(id: "loc-2", name: "Hangar", sets: [_set(id: "set-b", name: "Salon")]),
    ];

    await _pump(
      tester,
      OcptFloorPlanSetGallery(
        locations: locations,
        symbolsBySetId: const {},
        suggestedSetId: null,
        onSetLinkRequested: (_) {},
        onSetCreationRequested: (_) {},
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetGallery)));

    expect(find.text(tr.shotListFloorPlanGalleryTitle), findsOneWidget);
    expect(find.text("Cuisine"), findsOneWidget);
    expect(find.text("Salon"), findsOneWidget);
    // Neither set holds a set-scope symbol: both cards show the empty placeholder.
    expect(find.text(tr.shotListFloorPlanGalleryEmptyPlanLabel), findsNWidgets(2));
  });

  testWidgets("the suggested set is starred and drawn first", (tester) async {
    final locations = [
      _location(
        id: "loc-1",
        name: "Maison",
        sets: [_set(id: "set-a", name: "Cuisine"), _set(id: "set-b", name: "Salon")],
      ),
    ];

    await _pump(
      tester,
      OcptFloorPlanSetGallery(
        locations: locations,
        symbolsBySetId: const {},
        suggestedSetId: "set-b",
        onSetLinkRequested: (_) {},
        onSetCreationRequested: (_) {},
      ),
    );

    // Exactly one star, on the suggested card.
    expect(find.byIcon(Icons.star), findsOneWidget);

    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    // "Salon" (the suggestion) reads before "Cuisine" in the rendered tree — first and starred.
    expect(names.indexOf("Salon"), lessThan(names.indexOf("Cuisine")));
  });

  testWidgets("clicking a card links its own set", (tester) async {
    String? linked;
    final locations = [
      _location(id: "loc-1", name: "Maison", sets: [_set(id: "set-a", name: "Cuisine")]),
    ];

    await _pump(
      tester,
      OcptFloorPlanSetGallery(
        locations: locations,
        symbolsBySetId: const {},
        suggestedSetId: null,
        onSetLinkRequested: (setId) => linked = setId,
        onSetCreationRequested: (_) {},
      ),
    );

    await tester.tap(find.text("Cuisine"));
    await tester.pumpAndSettle();

    expect(linked, "set-a");
  });

  testWidgets("a set with a set-scope symbol draws its own thumbnail, not the empty placeholder", (
    tester,
  ) async {
    final locations = [
      _location(id: "loc-1", name: "Maison", sets: [_set(id: "set-a", name: "Cuisine")]),
    ];
    const symbol = OcptFloorPlanSymbol(
      id: "symbol-1",
      setId: "set-a",
      sceneId: null,
      shotId: null,
      layer: OcptFloorPlanLayer.set,
      sortKey: "a",
      xM: 0,
      yM: 0,
      rotationDeg: 0,
      widthM: 1,
      heightM: 1,
      fovDeg: null,
      fovReachM: null,
      label: "",
      setElementShape: null,
      overridesSymbolId: null,
      isHidden: false,
    );

    await _pump(
      tester,
      OcptFloorPlanSetGallery(
        locations: locations,
        symbolsBySetId: {"set-a": [symbol]},
        suggestedSetId: null,
        onSetLinkRequested: (_) {},
        onSetCreationRequested: (_) {},
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetGallery)));

    expect(find.text(tr.shotListFloorPlanGalleryEmptyPlanLabel), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets("read-only preview draws the cards but never links, and hides Create a set…", (
    tester,
  ) async {
    final locations = [
      _location(id: "loc-1", name: "Maison", sets: [_set(id: "set-a", name: "Cuisine")]),
    ];

    await _pump(
      tester,
      OcptFloorPlanSetGallery(
        locations: locations,
        symbolsBySetId: const {},
        suggestedSetId: null,
        onSetLinkRequested: null,
        onSetCreationRequested: null,
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetGallery)));

    expect(find.text("Cuisine"), findsOneWidget);
    expect(find.text(tr.shotListFloorPlanGalleryCreateSetAction), findsNothing);

    // A withheld card ignores the tap outright rather than throwing: no callback to call at all.
    await tester.tap(find.text("Cuisine"));
    await tester.pumpAndSettle();
  });

  testWidgets("Create a set… opens the location menu and reports the location picked", (
    tester,
  ) async {
    String? createdIn = "unset";
    final locations = [_location(id: "loc-1", name: "Maison")];

    await _pump(
      tester,
      OcptFloorPlanSetGallery(
        locations: locations,
        symbolsBySetId: const {},
        suggestedSetId: null,
        onSetLinkRequested: (_) {},
        onSetCreationRequested: (locationId) => createdIn = locationId,
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetGallery)));

    await tester.tap(find.text(tr.shotListFloorPlanGalleryCreateSetAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Maison"));
    await tester.pumpAndSettle();

    expect(createdIn, "loc-1");
  });

  testWidgets("the grid wraps at a compact width", (tester) async {
    final locations = [
      _location(
        id: "loc-1",
        name: "Maison",
        sets: [
          _set(id: "set-a", name: "Cuisine"),
          _set(id: "set-b", name: "Salon"),
          _set(id: "set-c", name: "Chambre"),
        ],
      ),
    ];

    await _pump(
      tester,
      OcptFloorPlanSetGallery(
        locations: locations,
        symbolsBySetId: const {},
        suggestedSetId: null,
        onSetLinkRequested: (_) {},
        onSetCreationRequested: (_) {},
      ),
      size: const Size(400, 900),
    );

    final positions = [
      tester.getTopLeft(find.text("Cuisine")),
      tester.getTopLeft(find.text("Salon")),
      tester.getTopLeft(find.text("Chambre")),
    ];
    // At 400px wide, a 244px-wide card cannot share a row with a second one: every card must have
    // wrapped onto its own line, each one strictly lower than the previous.
    expect(positions[1].dy, greaterThan(positions[0].dy));
    expect(positions[2].dy, greaterThan(positions[1].dy));
  });
}
