// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_mode_switcher.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve (the switcher's own
/// labels and tooltips read them).
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('shows exactly one entry per workspace mode', (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceModeSwitcher(
          activeMode: OcptWorkspaceMode.screenplay,
          onModeSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceModeSwitcher)));

    expect(find.text(tr.workspaceModeScreenplay), findsOneWidget);
    expect(find.text(tr.workspaceModeBudget), findsOneWidget);
    expect(find.text(tr.workspaceModeSchedule), findsOneWidget);
    expect(find.text(tr.workspaceModeShotList), findsOneWidget);
  });

  testWidgets('the active mode is tinted primary, the others onSurfaceVariant', (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceModeSwitcher(activeMode: OcptWorkspaceMode.budget, onModeSelected: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceModeSwitcher)));
    final colorScheme = Theme.of(tester.element(find.byType(OcptWorkspaceModeSwitcher))).colorScheme;

    final activeText = tester.widget<Text>(find.text(tr.workspaceModeBudget));
    final inactiveText = tester.widget<Text>(find.text(tr.workspaceModeScreenplay));

    expect(activeText.style?.color, colorScheme.primary);
    expect(inactiveText.style?.color, colorScheme.onSurfaceVariant);
  });

  testWidgets('tapping an entry dispatches its mode through onModeSelected', (tester) async {
    OcptWorkspaceMode? selected;

    await tester.pumpWidget(
      _wrapInApp(
        OcptWorkspaceModeSwitcher(
          activeMode: OcptWorkspaceMode.screenplay,
          onModeSelected: (mode) => selected = mode,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptWorkspaceModeSwitcher)));
    await tester.tap(find.text(tr.workspaceModeBudget));
    await tester.pumpAndSettle();

    expect(selected, OcptWorkspaceMode.budget);
  });
}
