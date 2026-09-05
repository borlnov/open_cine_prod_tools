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
    expect(find.text(tr.workspaceModeBreakdown), findsOneWidget);
    expect(find.text(tr.workspaceModeShotList), findsOneWidget);
    expect(find.text(tr.workspaceModeResources), findsOneWidget);
    expect(find.text(tr.workspaceModeSchedule), findsOneWidget);
    expect(find.text(tr.workspaceModeBudget), findsOneWidget);
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

  group('narrow band', () {
    testWidgets('drops the labels for an icon-only band that still fits every mode', (
      tester,
    ) async {
      // A phone-narrow row, below the labelled band's own width, so the switcher reduces to icons.
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      OcptWorkspaceMode? selected;

      await tester.pumpWidget(
        _wrapInApp(
          OcptWorkspaceModeSwitcher(
            activeMode: OcptWorkspaceMode.screenplay,
            onModeSelected: (mode) => selected = mode,
          ),
        ),
      );
      // A silent RenderFlex overflow would fail the pump here, proving every mode still fits.
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptWorkspaceModeSwitcher)));

      // No label is drawn, but every mode is still reachable, its label carried by the tooltip.
      expect(find.text(tr.workspaceModeScreenplay), findsNothing);
      expect(find.text(tr.workspaceModeBudget), findsNothing);
      expect(find.byTooltip(tr.workspaceModeBudget), findsOneWidget);

      await tester.tap(find.byTooltip(tr.workspaceModeBudget));
      await tester.pumpAndSettle();

      expect(selected, OcptWorkspaceMode.budget);
    });
  });
}
