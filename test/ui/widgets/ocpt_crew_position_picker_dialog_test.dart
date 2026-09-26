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
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_crew_position_picker_dialog.dart';
import 'package:open_cine_prod_tools/utils/ocpt_crew_position_prefill.dart';

/// A router manager whose [pop] only records the last call and its value: the dialog is pumped
/// directly, without a real GoRouter for it to operate on — mirrors
/// `ocpt_schedule_shot_picker_dialog_test.dart`'s own double.
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

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests, forced to
/// [locale] (English by default) so a test asserting on one language's own label text does not
/// depend on the host machine's own locale.
Widget _wrapWithLocalization(Widget child, {Locale locale = const Locale('en', 'GB')}) => MaterialApp(
  locale: locale,
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

  /// Pumps [OcptCrewPositionPickerDialog] directly (no `showDialog`/`.show`).
  ///
  /// The default test surface (800x600) is too short for the catalogue's own thirteen
  /// departments once the search matches most of them, which this app never runs at in practice
  /// (a resizable desktop window) — widened the same way `ocpt_home_header_test.dart` does.
  Future<void> pumpDialog(
    WidgetTester tester, {
    List<OcptCrewPositionRef> promoted = const [],
    Set<OcptCrewPositionRef> excluded = const {},
    bool allowCustomLabel = false,
    Locale locale = const Locale('en', 'GB'),
  }) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptCrewPositionPickerDialog(promoted: promoted, excluded: excluded, allowCustomLabel: allowCustomLabel),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("the catalogue is grouped under a department heading per section", (tester) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptCrewPositionPickerDialog));
    final tr = Tr.of(context);

    expect(find.text(ocptCrewDepartmentLabel(tr, OcptCrewDepartment.direction).toUpperCase()), findsOneWidget);
    expect(find.text(ocptCrewPositionLabel(tr, "director")), findsOneWidget);
    expect(find.text(ocptCrewPositionLabel(tr, "soundEngineer")), findsOneWidget);
  });

  testWidgets("the search filters positions, case- and accent-insensitively", (tester) async {
    await pumpDialog(tester, locale: const Locale('fr'));
    final context = tester.element(find.byType(OcptCrewPositionPickerDialog));
    final tr = Tr.of(context);

    // "director"'s French label is "Réalisateur·rice" — typed upper-case and unaccented.
    await tester.enterText(find.byType(TextField), "REALISATEUR");
    await tester.pumpAndSettle();

    expect(find.text(ocptCrewPositionLabel(tr, "director")), findsOneWidget);
    expect(find.text(ocptCrewPositionLabel(tr, "soundEngineer")), findsNothing);
  });

  testWidgets("the search ignores a French label's own inclusive-writing middle dot", (tester) async {
    await pumpDialog(tester, locale: const Locale('fr'));
    final context = tester.element(find.byType(OcptCrewPositionPickerDialog));
    final tr = Tr.of(context);

    // "gaffer"'s French label is "Chef·fe électricien·ne" — typed without the dot or the accent.
    await tester.enterText(find.byType(TextField), "cheffe electricienne");
    await tester.pumpAndSettle();

    expect(find.text(ocptCrewPositionLabel(tr, "gaffer")), findsOneWidget);
  });

  testWidgets("promoted positions are shown first, under their own heading", (tester) async {
    // Nothing here is excluded, so "gaffer" prints twice — once as the promoted entry, once as
    // the catalogue's own "Electric & grip" entry — which is what proves the promoted section
    // sits ahead of the catalogue rather than replacing part of it.
    await pumpDialog(
      tester,
      promoted: const [OcptCrewPositionRef(positionId: "gaffer", customLabel: "")],
    );
    final context = tester.element(find.byType(OcptCrewPositionPickerDialog));
    final tr = Tr.of(context);

    expect(find.text(tr.resourcesCrewPositionPickerPromotedHeading), findsOneWidget);
    expect(find.text(ocptCrewPositionLabel(tr, "gaffer")), findsNWidgets(2));

    final promotedHeadingY = tester.getTopLeft(find.text(tr.resourcesCrewPositionPickerPromotedHeading)).dy;
    final firstGafferY = tester.getTopLeft(find.text(ocptCrewPositionLabel(tr, "gaffer")).first).dy;
    final directionHeadingY = tester
        .getTopLeft(find.text(ocptCrewDepartmentLabel(tr, OcptCrewDepartment.direction).toUpperCase()))
        .dy;

    expect(promotedHeadingY, lessThan(firstGafferY));
    expect(firstGafferY, lessThan(directionHeadingY));
  });

  testWidgets("an excluded ref is left out of both the promoted section and the catalogue", (tester) async {
    await pumpDialog(
      tester,
      promoted: const [OcptCrewPositionRef(positionId: "gaffer", customLabel: "")],
      excluded: {const OcptCrewPositionRef(positionId: "gaffer", customLabel: "")},
    );
    final context = tester.element(find.byType(OcptCrewPositionPickerDialog));
    final tr = Tr.of(context);

    expect(find.text(ocptCrewPositionLabel(tr, "gaffer")), findsNothing);
    expect(find.text(tr.resourcesCrewPositionPickerPromotedHeading), findsNothing);
  });

  testWidgets("no custom entry is offered unless the caller asks for it", (tester) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptCrewPositionPickerDialog));
    final tr = Tr.of(context);

    expect(find.text(tr.resourcesPositionCustomOptionLabel), findsNothing);
  });

  testWidgets("the custom entry is offered last, unaffected by the search", (tester) async {
    await pumpDialog(tester, allowCustomLabel: true);
    final context = tester.element(find.byType(OcptCrewPositionPickerDialog));
    final tr = Tr.of(context);

    expect(find.text(tr.resourcesPositionCustomOptionLabel), findsOneWidget);

    await tester.enterText(find.byType(TextField), "nothing matches this at all");
    await tester.pumpAndSettle();

    expect(find.text(tr.resourcesPositionCustomOptionLabel), findsOneWidget);
  });

  testWidgets("tapping a catalogue position pops the router manager with its ref", (tester) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptCrewPositionPickerDialog));
    final tr = Tr.of(context);

    await tester.tap(find.text(ocptCrewPositionLabel(tr, "director")));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final result = routerManager.poppedValue! as OcptCrewPositionPickResult;
    expect(result.isCustom, isFalse);
    expect(result.position, const OcptCrewPositionRef(positionId: "director", customLabel: ""));
  });

  testWidgets("tapping the custom entry pops the router manager with a custom result", (tester) async {
    await pumpDialog(tester, allowCustomLabel: true);
    final context = tester.element(find.byType(OcptCrewPositionPickerDialog));
    final tr = Tr.of(context);

    await tester.ensureVisible(find.text(tr.resourcesPositionCustomOptionLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.resourcesPositionCustomOptionLabel));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final result = routerManager.poppedValue! as OcptCrewPositionPickResult;
    expect(result.isCustom, isTrue);
    expect(result.position, isNull);
  });

  testWidgets("Cancel pops with no value", (tester) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptCrewPositionPickerDialog));
    final tr = Tr.of(context);

    await tester.tap(find.text(tr.resourcesCrewPositionPickerCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });

  testWidgets("a search matching nothing shows the muted empty-state line", (tester) async {
    await pumpDialog(tester);
    final context = tester.element(find.byType(OcptCrewPositionPickerDialog));
    final tr = Tr.of(context);

    await tester.enterText(find.byType(TextField), "nothing in this catalogue matches this text");
    await tester.pumpAndSettle();

    expect(find.text(tr.resourcesCrewPositionPickerNoResultsHint), findsOneWidget);
  });
}
