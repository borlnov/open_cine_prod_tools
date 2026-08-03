// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_removed_character_alert.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_removed_character_banner.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a box as wide
/// as the shot list's centre area is.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 700, child: child)),
);

void main() {
  const alert = OcptShotRemovedCharacterAlert(
    characterName: "CLARA",
    shotCodes: ["1/4", "3/1", "3/2"],
  );

  /// Pumps the banner for [alert], recording the actions it reports.
  Future<({List<String> removals, List<String> replacements})> pumpBanner(
    WidgetTester tester, {
    List<String> replacementCandidates = const ["LÉA", "MARC"],
    bool isReadOnly = false,
  }) async {
    final removals = <String>[];
    final replacements = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptShotListRemovedCharacterBanner(
          alert: alert,
          replacementCandidates: replacementCandidates,
          onRemoveFromEveryShot: () => removals.add(alert.characterName),
          onReplaced: replacements.add,
          isReadOnly: isReadOnly,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return (removals: removals, replacements: replacements);
  }

  testWidgets("names the character and lists every shot still carrying it", (tester) async {
    await pumpBanner(tester);

    expect(
      find.text(
        "CLARA was removed from the screenplay but still appears in 3 shots: 1/4 · 3/1 · 3/2.",
      ),
      findsOneWidget,
    );
  });

  testWidgets("reports the remove-from-every-shot action", (tester) async {
    final actions = await pumpBanner(tester);

    await tester.tap(find.text("Remove from every shot"));
    await tester.pump();

    expect(actions.removals, ["CLARA"]);
    expect(actions.replacements, isEmpty);
  });

  testWidgets("offers one replacement chip per still-speaking character", (tester) async {
    final actions = await pumpBanner(tester);

    expect(find.text("Replace with:"), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(2));

    await tester.tap(find.text("MARC"));
    await tester.pump();

    expect(actions.replacements, ["MARC"]);
    expect(actions.removals, isEmpty);
  });

  testWidgets("a screenplay with no speaking role left shows no replacement row", (tester) async {
    await pumpBanner(tester, replacementCandidates: const []);

    expect(find.text("Replace with:"), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    // The way out that always exists stays offered.
    expect(find.text("Remove from every shot"), findsOneWidget);
  });

  testWidgets("a read-only banner still reports the mismatch, with no way out of it", (
    tester,
  ) async {
    await pumpBanner(tester, isReadOnly: true);

    expect(
      find.text(
        "CLARA was removed from the screenplay but still appears in 3 shots: 1/4 · 3/1 · 3/2.",
      ),
      findsOneWidget,
    );
    expect(find.text("Remove from every shot"), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });
}
