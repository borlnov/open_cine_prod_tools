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
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';

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
  home: child,
);

void main() {
  late _RecordingRouterManager routerManager;

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

  /// Pumps [OcptProjectVersionCreateDialog] directly (no [showDialog]/`.show`).
  Future<Tr> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithLocalization(const OcptProjectVersionCreateDialog()));
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptProjectVersionCreateDialog)));
  }

  testWidgets('submitting a name and a note pops the router manager with both, trimmed', (
    tester,
  ) async {
    final tr = await pumpDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.projectVersionCreateNameLabel),
      "  v4 — Shot list seq. 1 to 3  ",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.projectVersionCreateNoteLabel),
      " Before the rewrite ",
    );
    await tester.tap(find.text(tr.projectVersionCreateConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, (name: "v4 — Shot list seq. 1 to 3", note: "Before the rewrite"));
  });

  testWidgets('a version with no name is refused, and nothing is popped', (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.projectVersionCreateConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.projectVersionCreateNameRequiredError), findsOneWidget);
    expect(routerManager.popped, isFalse);
  });

  testWidgets('the note is optional', (tester) async {
    final tr = await pumpDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.projectVersionCreateNameLabel),
      "End of the day",
    );
    await tester.tap(find.text(tr.projectVersionCreateConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.poppedValue, (name: "End of the day", note: ""));
  });

  testWidgets('cancelling pops with nothing', (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.projectVersionCreateCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });
}
