// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_character_chips.dart';

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
  testWidgets("lists every speaking character, selected exactly when attached", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptShotCharacterChips(
          speakingCharacters: const ["LÉA", "MARC"],
          attachedCharacters: const ["LÉA"],
          onToggled: (_) {},
        ),
      ),
    );

    expect(find.text("LÉA"), findsOneWidget);
    expect(find.text("MARC"), findsOneWidget);

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
    expect(chips.singleWhere((chip) => (chip.label as Text).data == "LÉA").selected, isTrue);
    expect(chips.singleWhere((chip) => (chip.label as Text).data == "MARC").selected, isFalse);
  });

  testWidgets("a character attached but no longer speaking trails the list, struck through",
      (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptShotCharacterChips(
          speakingCharacters: const ["LÉA"],
          attachedCharacters: const ["LÉA", "CLARA"],
          onToggled: (_) {},
        ),
      ),
    );

    expect(find.text("CLARA (removed)"), findsOneWidget);
    final removedChip = tester.widget<FilterChip>(
      find.ancestor(of: find.text("CLARA (removed)"), matching: find.byType(FilterChip)),
    );
    expect(removedChip.selected, isTrue);
    expect(removedChip.labelStyle?.decoration, TextDecoration.lineThrough);
  });

  testWidgets("tapping a chip reports its name", (tester) async {
    final toggled = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptShotCharacterChips(
          speakingCharacters: const ["LÉA", "MARC"],
          attachedCharacters: const ["LÉA"],
          onToggled: toggled.add,
        ),
      ),
    );

    await tester.tap(find.text("MARC"));
    await tester.pump();

    expect(toggled, ["MARC"]);
  });

  testWidgets("shows the empty hint when the screenplay has no speaking character", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptShotCharacterChips(
          speakingCharacters: const [],
          attachedCharacters: const [],
          onToggled: (_) {},
        ),
      ),
    );

    expect(find.text("No speaking characters yet."), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
  });
}
