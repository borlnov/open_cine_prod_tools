// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_export_dialog.dart';

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

  /// Pumps [OcptStoryboardExportDialog] directly (no [showDialog]/`.show`), pre-filled with
  /// [current] (defaulting to the standard setup).
  Future<void> pumpDialog(
    WidgetTester tester, {
    OcptPageSetup current = const OcptPageSetup.standard(),
  }) async {
    await tester.pumpWidget(_wrapWithLocalization(OcptStoryboardExportDialog(current: current)));
    await tester.pumpAndSettle();
  }

  testWidgets(
    "tapping Export pops the router manager with the format, the default shots-per-page and the "
    "floor plans toggle off",
    (tester) async {
      await pumpDialog(tester);
      final context = tester.element(find.byType(OcptStoryboardExportDialog));
      final tr = Tr.of(context);

      await tester.tap(find.text(tr.editorExportPdfExportAction));
      await tester.pumpAndSettle();

      expect(routerManager.popped, isTrue);
      final popped = routerManager.poppedValue! as OcptStoryboardExportOptions;
      expect(popped.format, OcptPageFormat.usLetter);
      expect(popped.margins, const OcptPageSetup.standard().margins);
      expect(popped.shotsPerPage, 2);
      expect(popped.includeFloorPlansAfterEachSequence, isFalse);
    },
  );

  testWidgets("picking A4 in the format dropdown carries it into the popped options, margins unchanged", (
    tester,
  ) async {
    const current = OcptPageSetup(
      format: OcptPageFormat.usLetter,
      margins: FountainPageMargins(leftInches: 2, rightInches: 2, topInches: 2, bottomInches: 2),
    );
    await pumpDialog(tester, current: current);
    final context = tester.element(find.byType(OcptStoryboardExportDialog));
    final tr = Tr.of(context);

    await tester.tap(find.byType(DropdownButtonFormField<OcptPageFormat>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.editorPageSetupA4Option).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr.editorExportPdfExportAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final popped = routerManager.poppedValue! as OcptStoryboardExportOptions;
    expect(popped.format, OcptPageFormat.a4);
    expect(popped.margins, current.margins);
  });

  testWidgets("picking a shots-per-page value carries it into the popped options", (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("4").last);
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OcptStoryboardExportDialog));
    final tr = Tr.of(context);
    await tester.tap(find.text(tr.editorExportPdfExportAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final popped = routerManager.poppedValue! as OcptStoryboardExportOptions;
    expect(popped.shotsPerPage, 4);
  });

  testWidgets("checking the floor plans toggle carries it into the popped options", (tester) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptStoryboardExportDialog));
    final tr = Tr.of(context);

    await tester.tap(
      find.widgetWithText(CheckboxListTile, tr.shotListExportStoryboardIncludeFloorPlansLabel),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr.editorExportPdfExportAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final popped = routerManager.poppedValue! as OcptStoryboardExportOptions;
    expect(popped.includeFloorPlansAfterEachSequence, isTrue);
  });

  testWidgets("Cancel pops with no value", (tester) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptStoryboardExportDialog));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.editorPageSetupCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });
}
