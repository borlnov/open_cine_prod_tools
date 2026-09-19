// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panels_group.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, and sets the test
/// surface past the 800 px compact breakpoint, matching every other shot list widget/bloc test of
/// this milestone.
Future<void> _pumpGroup(WidgetTester tester, Widget child) async {
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
      home: Scaffold(body: child),
    ),
  );
}

/// A minimal panel of [id], for a test that only cares about the group's own affordances.
OcptStoryboardPanel _panel(String id, {String comment = ""}) => OcptStoryboardPanel(
  id: id,
  shotId: "shot-1",
  sortKey: id,
  imageAssetId: null,
  imagePath: null,
  comment: comment,
  annotations: const [],
);

void main() {
  testWidgets("lists every panel with its rank and its comment field", (tester) async {
    await _pumpGroup(
      tester,
      OcptStoryboardPanelsGroup(
        panels: [_panel("p1", comment: "Wide"), _panel("p2", comment: "Push in")],
        commentValueOf: (id) => id == "p1" ? "Wide" : "Push in",
        isReadOnly: false,
        onCommentChanged: (_, __) {},
        onReordered: (_, __) {},
        onDeleteRequested: (_) {},
      ),
    );

    expect(find.text("1/2"), findsOneWidget);
    expect(find.text("2/2"), findsOneWidget);
    expect(find.text("Wide"), findsOneWidget);
    expect(find.text("Push in"), findsOneWidget);
  });

  testWidgets("typing into a panel's comment field reports its id and the raw text", (
    tester,
  ) async {
    final changed = <(String, String)>[];

    await _pumpGroup(
      tester,
      OcptStoryboardPanelsGroup(
        panels: [_panel("p1")],
        commentValueOf: (_) => "",
        isReadOnly: false,
        onCommentChanged: (id, value) => changed.add((id, value)),
        onReordered: (_, __) {},
        onDeleteRequested: (_) {},
      ),
    );

    await tester.enterText(find.byType(TextField), "Dolly in");
    await tester.pump();

    expect(changed, [("p1", "Dolly in")]);
  });

  testWidgets("Delete panel only asks: it reports the panel's id and nothing else", (
    tester,
  ) async {
    final deleteRequested = <String>[];

    await _pumpGroup(
      tester,
      OcptStoryboardPanelsGroup(
        panels: [_panel("p1")],
        commentValueOf: (_) => "",
        isReadOnly: false,
        onCommentChanged: (_, __) {},
        onReordered: (_, __) {},
        onDeleteRequested: deleteRequested.add,
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(deleteRequested, ["p1"]);
  });

  testWidgets(
    "the reorder affordance withholds the boundary moves: no move-up on the first panel, no "
    "move-down on the last",
    (tester) async {
      await _pumpGroup(
        tester,
        OcptStoryboardPanelsGroup(
          panels: [_panel("p1"), _panel("p2")],
          commentValueOf: (_) => "",
          isReadOnly: false,
          onCommentChanged: (_, __) {},
          onReordered: (_, __) {},
          onDeleteRequested: (_) {},
        ),
      );

      final upButtons = tester
          .widgetList<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_upward))
          .toList();
      final downButtons = tester
          .widgetList<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_downward))
          .toList();

      // First panel: no move-up. Second (last) panel: no move-down.
      expect(upButtons[0].onPressed, isNull);
      expect(upButtons[1].onPressed, isNotNull);
      expect(downButtons[0].onPressed, isNotNull);
      expect(downButtons[1].onPressed, isNull);
    },
  );

  testWidgets(
    "read-only withholds the comment field, the reorder affordance and Delete panel",
    (tester) async {
      await _pumpGroup(
        tester,
        OcptStoryboardPanelsGroup(
          panels: [_panel("p1")],
          commentValueOf: (_) => "Wide",
          isReadOnly: true,
          onCommentChanged: null,
          onReordered: null,
          onDeleteRequested: null,
        ),
      );

      expect(tester.widget<TextField>(find.byType(TextField)).onChanged, isNull);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      final upButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_upward),
      );
      expect(upButton.onPressed, isNull);
      final downButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_downward),
      );
      expect(downButton.onPressed, isNull);
    },
  );

  testWidgets("no panel at all shows the 'no panel yet' hint", (tester) async {
    await _pumpGroup(
      tester,
      OcptStoryboardPanelsGroup(
        panels: const [],
        commentValueOf: (_) => "",
        isReadOnly: false,
        onCommentChanged: (_, __) {},
        onReordered: (_, __) {},
        onDeleteRequested: (_) {},
      ),
    );

    expect(find.text("no panel yet"), findsOneWidget);
  });
}
