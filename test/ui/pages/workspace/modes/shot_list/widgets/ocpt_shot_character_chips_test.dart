// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
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

/// A minimal live role of [id] and [name], for a test that only cares about the chips.
OcptRole _role(String id, String name) => OcptRole(
  id: id,
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
  episodeIds: const [],
);

void main() {
  testWidgets("lists every role of the cast, selected exactly when attached", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptShotCharacterChips(
          roles: [_role("r1", "LÉA"), _role("r2", "MARC")],
          attachedRoleIds: const ["r1"],
          onToggled: (_) {},
          onCharacterAdded: (_) {},
        ),
      ),
    );

    expect(find.text("LÉA"), findsOneWidget);
    expect(find.text("MARC"), findsOneWidget);

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
    expect(chips.singleWhere((chip) => (chip.label as Text).data == "LÉA").selected, isTrue);
    expect(chips.singleWhere((chip) => (chip.label as Text).data == "MARC").selected, isFalse);
  });

  testWidgets("tapping a chip reports the role's id", (tester) async {
    final toggled = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptShotCharacterChips(
          roles: [_role("r1", "LÉA"), _role("r2", "MARC")],
          attachedRoleIds: const ["r1"],
          onToggled: toggled.add,
          onCharacterAdded: (_) {},
        ),
      ),
    );

    await tester.tap(find.text("MARC"));
    await tester.pump();

    expect(toggled, ["r2"]);
  });

  testWidgets("shows the empty hint when the cast is empty and read-only", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        const OcptShotCharacterChips(
          roles: [],
          attachedRoleIds: [],
          onToggled: null,
          onCharacterAdded: null,
        ),
      ),
    );

    expect(find.text("No speaking characters yet."), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets("chips with no onToggled read the cast out without reacting to a click", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptShotCharacterChips(
          roles: [_role("r1", "LÉA"), _role("r2", "MARC")],
          attachedRoleIds: const ["r1"],
          onToggled: null,
          onCharacterAdded: (_) {},
        ),
      ),
    );

    expect(find.byType(FilterChip), findsNWidgets(2));
    expect(tester.widget<FilterChip>(find.byType(FilterChip).first).onSelected, isNull);

    // Tapping is a no-op rather than an error: a disabled chip simply doesn't report anything.
    await tester.tap(find.text("MARC"));
    await tester.pump();
  });

  testWidgets("the ＋ Add affordance is withheld while read-only", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptShotCharacterChips(
          roles: [_role("r1", "LÉA")],
          attachedRoleIds: const [],
          onToggled: (_) {},
          onCharacterAdded: null,
        ),
      ),
    );

    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets("clicking ＋ Add opens an inline field, and submitting reports the typed name", (
    tester,
  ) async {
    final added = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptShotCharacterChips(
          roles: [_role("r1", "LÉA")],
          attachedRoleIds: const [],
          onToggled: (_) {},
          onCharacterAdded: added.add,
        ),
      ),
    );

    expect(find.byType(ActionChip), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byType(ActionChip));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);

    await tester.enterText(find.byType(TextField), "Nouveau");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(added, ["Nouveau"]);
    // Collapses back to the chip once submitted.
    expect(find.byType(ActionChip), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets("submitting an empty name reports nothing and simply collapses back", (
    tester,
  ) async {
    final added = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptShotCharacterChips(
          roles: const [],
          attachedRoleIds: const [],
          onToggled: (_) {},
          onCharacterAdded: added.add,
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pump();

    await tester.enterText(find.byType(TextField), "   ");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(added, isEmpty);
    expect(find.byType(ActionChip), findsOneWidget);
  });
}
