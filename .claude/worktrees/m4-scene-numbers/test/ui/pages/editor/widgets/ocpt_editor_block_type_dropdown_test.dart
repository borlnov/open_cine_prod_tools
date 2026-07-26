// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_block_type_dropdown.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, matching
/// `editor_page_test.dart`'s own `_wrapWithLocalization` helper.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

/// The 11 assignable [FountainLineType]s (every value except [FountainLineType.blank]) and the
/// localized label [OcptEditorBlockTypeDropdown] is expected to show for each of them.
const _assignableTypesAndLabels = {
  FountainLineType.sceneHeading: "Scene heading",
  FountainLineType.action: "Action",
  FountainLineType.character: "Character",
  FountainLineType.parenthetical: "Parenthetical",
  FountainLineType.dialogue: "Dialogue",
  FountainLineType.transition: "Transition",
  FountainLineType.centeredText: "Centered text",
  FountainLineType.lyrics: "Lyrics",
  FountainLineType.section: "Section",
  FountainLineType.synopsis: "Synopsis",
  FountainLineType.pageBreak: "Page break",
};

void main() {
  testWidgets("shows the localized label of currentType", (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptEditorBlockTypeDropdown(currentType: FountainLineType.character, onTypeSelected: (_) {}),
      ),
    );

    expect(find.text("Character"), findsOneWidget);
  });

  testWidgets("lists all 11 assignable types when opened", (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptEditorBlockTypeDropdown(currentType: FountainLineType.action, onTypeSelected: (_) {}),
      ),
    );

    await tester.tap(find.byType(DropdownButton<FountainLineType>));
    await tester.pumpAndSettle();

    for (final label in _assignableTypesAndLabels.values) {
      expect(find.text(label).evaluate(), isNotEmpty, reason: "missing item for $label");
    }
  });

  testWidgets("tapping a different item invokes onTypeSelected with that type", (tester) async {
    FountainLineType? selected;

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptEditorBlockTypeDropdown(
          currentType: FountainLineType.action,
          onTypeSelected: (type) => selected = type,
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButton<FountainLineType>));
    await tester.pumpAndSettle();

    // The menu now shows two "Dialogue" texts (the closed button's own selected-value display
    // plus the open menu's item list); `last` targets the menu item, not the closed button.
    await tester.tap(find.text("Dialogue").last);
    await tester.pumpAndSettle();

    expect(selected, FountainLineType.dialogue);
  });

  testWidgets("has a tooltip", (tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptEditorBlockTypeDropdown(currentType: FountainLineType.action, onTypeSelected: (_) {}),
      ),
    );

    expect(find.byType(Tooltip), findsOneWidget);
  });
}
