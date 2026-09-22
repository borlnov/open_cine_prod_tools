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

OcptFloorPlanSet _set({required String id, required String name, required String sortKey}) =>
    OcptFloorPlanSet(
      id: id,
      sceneId: "scene-1",
      name: name,
      sortKey: sortKey,
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

void main() {
  testWidgets("the ＋ Set button's own visible text is the word alone, no + repeated", (
    tester,
  ) async {
    await _pump(
      tester,
      OcptFloorPlanSetTabs(
        sets: const [],
        selectedSetId: null,
        nameValueOf: (_) => "",
        placedShotCountOf: (_) => 0,
        onSetSelected: (_) {},
        onSetCreationRequested: () {},
        onSetDuplicateRequested: null,
        onCopyBlockingRequested: null,
        onSetNameChanged: null,
        onSetReordered: null,
        onSetDeleteRequested: null,
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetTabs)));

    final label = tr.shotListFloorPlanAddSetButtonLabel;
    expect(label.contains("+"), isFalse);
    expect(label.contains("＋"), isFalse);
    expect(find.text(label), findsOneWidget);
  });

  testWidgets("a tab shows its own placed-shot count badge, hidden when the count is zero", (
    tester,
  ) async {
    final setA = _set(id: "set-a", name: "Kitchen", sortKey: "a0");
    final setB = _set(id: "set-b", name: "Hallway", sortKey: "a1");

    await _pump(
      tester,
      OcptFloorPlanSetTabs(
        sets: [setA, setB],
        selectedSetId: "set-a",
        nameValueOf: (setId) => setId == "set-a" ? "Kitchen" : "Hallway",
        placedShotCountOf: (setId) => setId == "set-a" ? 3 : 0,
        onSetSelected: (_) {},
        onSetCreationRequested: () {},
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

  testWidgets("clicking ＋ Set opens a menu whose Create set entry fires the creation callback", (
    tester,
  ) async {
    var created = false;

    await _pump(
      tester,
      OcptFloorPlanSetTabs(
        sets: const [],
        selectedSetId: null,
        nameValueOf: (_) => "",
        placedShotCountOf: (_) => 0,
        onSetSelected: (_) {},
        onSetCreationRequested: () => created = true,
        onSetDuplicateRequested: null,
        onCopyBlockingRequested: null,
        onSetNameChanged: null,
        onSetReordered: null,
        onSetDeleteRequested: null,
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetTabs)));

    await tester.tap(find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.shotListFloorPlanCreateSetMenuAction));
    await tester.pumpAndSettle();

    expect(created, isTrue);
  });

  testWidgets(
    "the menu's Duplicate this set and Copy blocking entries report the selected set's id",
    (tester) async {
      String? duplicated;
      String? copiedFrom;
      final setA = _set(id: "set-a", name: "Kitchen", sortKey: "a0");

      await _pump(
        tester,
        OcptFloorPlanSetTabs(
          sets: [setA],
          selectedSetId: "set-a",
          nameValueOf: (_) => "Kitchen",
          placedShotCountOf: (_) => 0,
          onSetSelected: (_) {},
          onSetCreationRequested: () {},
          onSetDuplicateRequested: (setId) => duplicated = setId,
          onCopyBlockingRequested: (setId) => copiedFrom = setId,
          onSetNameChanged: null,
          onSetReordered: null,
          onSetDeleteRequested: null,
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
    await _pump(
      tester,
      OcptFloorPlanSetTabs(
        sets: const [],
        selectedSetId: null,
        nameValueOf: (_) => "",
        placedShotCountOf: (_) => 0,
        onSetSelected: (_) {},
        onSetCreationRequested: null,
        onSetDuplicateRequested: null,
        onCopyBlockingRequested: null,
        onSetNameChanged: null,
        onSetReordered: null,
        onSetDeleteRequested: null,
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanSetTabs)));

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, tr.shotListFloorPlanAddSetButtonLabel),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(MenuAnchor), findsNothing);
  });
}
