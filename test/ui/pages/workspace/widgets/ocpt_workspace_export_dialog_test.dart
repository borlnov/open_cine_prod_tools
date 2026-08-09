// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_export_dialog.dart';

/// A stand-in for a mode's own export enum, so this test needs no real mode.
enum _TestExportKind { alpha, beta }

/// A router manager whose [pop] only records the last call and its value: this dialog is pumped
/// directly, without a real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  /// The value [pop] was last called with.
  Object? poppedValue;

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
    poppedValue = result;
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
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

void main() {
  late _RecordingRouterManager routerManager;

  final entries = [
    const OcptWorkspaceExportEntry<_TestExportKind>(
      value: _TestExportKind.alpha,
      title: "Alpha document",
      description: "What the alpha document is",
      formatLabel: "PDF",
    ),
    const OcptWorkspaceExportEntry<_TestExportKind>(
      value: _TestExportKind.beta,
      title: "Beta document",
      description: "What the beta document is",
      formatLabel: "XLSX",
      unavailableReason: "The catalogue is empty",
    ),
  ];

  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }

    routerManager = _RecordingRouterManager();
    managers.registerSingleton<OcptRouterManager>(routerManager);
  });

  /// Pumps [OcptWorkspaceExportDialog] directly (no [showDialog]/`.show`), over the same [entries]
  /// for every test.
  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptWorkspaceExportDialog<_TestExportKind>(
          title: "Export",
          message: "Choose a document.",
          entries: entries,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("every entry is rendered, available or not", (tester) async {
    await pumpDialog(tester);

    expect(find.text("Alpha document"), findsOneWidget);
    expect(find.text("Beta document"), findsOneWidget);
    expect(find.text("PDF"), findsOneWidget);
    expect(find.text("XLSX"), findsOneWidget);
  });

  testWidgets("an available card pops its own value and nothing else", (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.text("Alpha document"));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, _TestExportKind.alpha);
  });

  testWidgets("an unavailable card pops nothing and shows its reason in place of its description", (
    tester,
  ) async {
    await pumpDialog(tester);

    expect(find.text("What the beta document is"), findsNothing);
    expect(find.text("The catalogue is empty"), findsOneWidget);

    await tester.tap(find.text("Beta document"));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isFalse);
  });
}
