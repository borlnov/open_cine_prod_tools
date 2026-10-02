// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_set_tabs.dart';

/// Wraps [child] with the localization delegates so `Tr.of` lookups resolve, and sets the test
/// surface past the 800 px compact breakpoint (`docs/architecture/foundations.md`), matching every
/// other shot list widget test of this milestone.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1400, 900);
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
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
    ),
  );
}

OcptFloorPlanSet _set({required String id, required String name}) => OcptFloorPlanSet(
      id: id,
      name: name,
      underlayAssetId: null,
      underlayPath: null,
      underlayXM: null,
      underlayYM: null,
      underlayWidthM: null,
      underlayHeightM: null,
      underlayRotationDeg: null,
      symbols: const [],
      arrows: const [],
    );

/// A bare [OcptFloorPlanSetTabs], every optional field at its own withheld/empty default — the
/// tests below only override what they mean to exercise.
Widget _tabs({
  List<OcptFloorPlanSet> sets = const [],
  String? selectedSetId,
  String? suggestedSetId,
  String? suggestedSetName,
  List<(String, List<(String, String)>)> linkableSetsByLocation = const [],
  List<(String, String)> locationsForCreation = const [],
  ValueChanged<String>? onSetLinkRequested,
  void Function(String?)? onSetCreationRequested,
  ValueChanged<String>? onSetDuplicateRequested,
  ValueChanged<String>? onCopyBlockingRequested,
  void Function(String, String)? onSetNameChanged,
  void Function(String, int)? onSetReordered,
  ValueChanged<String>? onSetDeleteRequested,
}) => OcptFloorPlanSetTabs(
  sets: sets,
  selectedSetId: selectedSetId,
  nameValueOf: (setId) => sets.firstWhere((set) => set.id == setId, orElse: () => _set(id: setId, name: "")).name,
  placedShotCountOf: (_) => 0,
  suggestedSetId: suggestedSetId,
  suggestedSetName: suggestedSetName,
  linkableSetsByLocation: linkableSetsByLocation,
  locationsForCreation: locationsForCreation,
  onSetSelected: (_) {},
  onSetLinkRequested: onSetLinkRequested,
  onSetCreationRequested: onSetCreationRequested,
  onSetDuplicateRequested: onSetDuplicateRequested,
  onCopyBlockingRequested: onCopyBlockingRequested,
  onSetNameChanged: onSetNameChanged,
  onSetReordered: onSetReordered,
  onSetDeleteRequested: onSetDeleteRequested,
);

void main() {
  testWidgets("the ＋ Set button's own visible text is the word alone, no + repeated", (
    tester,
  ) async {
    await _pump(tester, _tabs(onSetCreationRequested: (_) {}));
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetTabs)));

    final label = tr.shotListFloorPlanAddSetButtonLabel;
    expect(label.contains("+"), isFalse);
    expect(label.contains("＋"), isFalse);
    expect(find.text(label), findsOneWidget);
  });

  testWidgets("a tab shows its own placed-shot count badge, hidden when the count is zero", (
    tester,
  ) async {
    final setA = _set(id: "set-a", name: "Kitchen");
    final setB = _set(id: "set-b", name: "Hallway");

    await _pump(
      tester,
      OcptFloorPlanSetTabs(
        sets: [setA, setB],
        selectedSetId: "set-a",
        nameValueOf: (setId) => setId == "set-a" ? "Kitchen" : "Hallway",
        placedShotCountOf: (setId) => setId == "set-a" ? 3 : 0,
        onSetSelected: (_) {},
        onSetCreationRequested: (_) {},
        onSetDuplicateRequested: null,
        onCopyBlockingRequested: null,
        onSetNameChanged: null,
        onSetReordered: null,
        onSetDeleteRequested: null,
      ),
    );

    expect(find.text("3"), findsOneWidget);
    expect(find.text("0"), findsNothing);
  });

  testWidgets(
    "clicking ＋ Set opens a menu whose Create a set submenu fires the creation callback per location",
    (tester) async {
      String? createdIn;

      await _pump(
        tester,
        _tabs(
          locationsForCreation: const [("loc-1", "Maison")],
          onSetCreationRequested: (locationId) => createdIn = locationId ?? "new-location",
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetTabs)));

      await tester.tap(find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.shotListFloorPlanCreateSetMenuAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Maison"));
      await tester.pumpAndSettle();

      expect(createdIn, "loc-1");
    },
  );

  testWidgets("the Create a set submenu's own New location… entry fires with a null location", (
    tester,
  ) async {
    String? createdIn = "unset";

    await _pump(
      tester,
      _tabs(onSetCreationRequested: (locationId) => createdIn = locationId),
    );
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetTabs)));

    await tester.tap(find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.shotListFloorPlanCreateSetMenuAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.shotListFloorPlanNewLocationMenuAction));
    await tester.pumpAndSettle();

    expect(createdIn, isNull);
  });

  testWidgets("the suggestion entry, starred, links the suggested set", (tester) async {
    String? linked;

    await _pump(
      tester,
      _tabs(
        suggestedSetId: "set-a",
        suggestedSetName: "Kitchen",
        onSetLinkRequested: (setId) => linked = setId,
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetTabs)));

    await tester.tap(find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsOneWidget);

    await tester.tap(find.text(tr.shotListFloorPlanSuggestedSetMenuAction("Kitchen")));
    await tester.pumpAndSettle();

    expect(linked, "set-a");
  });

  testWidgets(
    "Link an existing set groups its own entries by location, and links the one picked",
    (tester) async {
      String? linked;

      await _pump(
        tester,
        _tabs(
          linkableSetsByLocation: const [
            ("Maison", [("set-a", "Cuisine"), ("set-b", "Salon")]),
          ],
          onSetLinkRequested: (setId) => linked = setId,
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetTabs)));

      await tester.tap(find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.shotListFloorPlanLinkExistingSetMenuAction));
      await tester.pumpAndSettle();
      expect(find.text("Maison"), findsOneWidget);

      await tester.tap(find.text("Salon"));
      await tester.pumpAndSettle();

      expect(linked, "set-b");
    },
  );

  testWidgets("Link an existing set is omitted from the menu when there is nothing to link", (
    tester,
  ) async {
    await _pump(tester, _tabs(onSetLinkRequested: (_) {}, onSetCreationRequested: (_) {}));
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetTabs)));

    await tester.tap(find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel));
    await tester.pumpAndSettle();

    expect(find.text(tr.shotListFloorPlanLinkExistingSetMenuAction), findsNothing);
  });

  testWidgets(
    "the menu's Duplicate this set and Copy blocking entries report the selected set's id",
    (tester) async {
      String? duplicated;
      String? copiedFrom;
      final setA = _set(id: "set-a", name: "Kitchen");

      await _pump(
        tester,
        _tabs(
          sets: [setA],
          selectedSetId: "set-a",
          onSetCreationRequested: (_) {},
          onSetDuplicateRequested: (setId) => duplicated = setId,
          onCopyBlockingRequested: (setId) => copiedFrom = setId,
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetTabs)));

      await tester.tap(find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.shotListFloorPlanDuplicateSetMenuAction));
      await tester.pumpAndSettle();
      expect(duplicated, "set-a");

      await tester.tap(find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.shotListFloorPlanCopyBlockingMenuAction));
      await tester.pumpAndSettle();
      expect(copiedFrom, "set-a");
    },
  );

  testWidgets("no writable callback at all shows a disabled ＋ Set button, no menu", (
    tester,
  ) async {
    await _pump(tester, _tabs());
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetTabs)));

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(MenuAnchor), findsNothing);
  });
}
