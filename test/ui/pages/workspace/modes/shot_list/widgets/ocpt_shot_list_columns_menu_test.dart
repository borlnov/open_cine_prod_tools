// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_columns_menu.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
);

void main() {
  /// Pumps the menu with [visibleColumns] checked, recording every toggle it reports.
  Future<List<OcptShotListColumn>> pumpMenu(
    WidgetTester tester, {
    required Set<OcptShotListColumn> visibleColumns,
  }) async {
    final toggled = <OcptShotListColumn>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptShotListColumnsMenu(
          visibleColumns: visibleColumns,
          onColumnToggled: toggled.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return toggled;
  }

  testWidgets("lists one entry per optional column, and none for the always-shown ones",
      (tester) async {
    await pumpMenu(tester, visibleColumns: OcptShotListColumn.defaultVisibleColumns);

    await tester.tap(find.text("Columns"));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxMenuButton), findsNWidgets(OcptShotListColumn.values.length));
    for (final label in const [
      "Set",
      "Lens",
      "Format",
      "Duration (mm:ss)",
      "Planned takes",
      "Sound",
    ]) {
      expect(find.text(label), findsOneWidget, reason: "missing the $label entry");
    }
    // The always-shown columns aren't toggleable, so they aren't listed at all.
    expect(find.text("Framing & composition"), findsNothing);
    expect(find.text("Diff."), findsNothing);
  });

  testWidgets("each entry is checked exactly when its column is visible", (tester) async {
    await pumpMenu(tester, visibleColumns: {OcptShotListColumn.lens});

    await tester.tap(find.text("Columns"));
    await tester.pumpAndSettle();

    final entries = tester.widgetList<CheckboxMenuButton>(find.byType(CheckboxMenuButton));
    expect(entries.where((entry) => entry.value ?? false), hasLength(1));
  });

  testWidgets("toggling an entry reports its column and leaves the menu open", (tester) async {
    final toggled = await pumpMenu(tester, visibleColumns: const {});

    await tester.tap(find.text("Columns"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Lens"));
    await tester.pumpAndSettle();

    expect(toggled, [OcptShotListColumn.lens]);
    // Turning several columns on must stay one trip through the menu.
    expect(find.text("Duration (mm:ss)"), findsOneWidget);
  });
}
